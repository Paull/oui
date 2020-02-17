#!/usr/bin/lua

local libubus = require "ubus"
local uloop = require "uloop"
local cjson = require "cjson"
local uci = require "uci"
local crypt = require "oui.c".crypt
local statvfs = require "oui.c".statvfs
local parse_route_addr = require "oui.c".parse_route_addr
local parse_flow = require "oui.c".parse_flow
local readdir = require "oui.c".readdir

local RPC_OUI_MENU_FILES = "/usr/share/oui/menu.d/*.json"

local UBUS_STATUS_OK = 0
local UBUS_STATUS_INVALID_COMMAND = 1
local UBUS_STATUS_INVALID_ARGUMENT = 2
local UBUS_STATUS_METHOD_NOT_FOUND = 3
local UBUS_STATUS_NOT_FOUND = 4
local UBUS_STATUS_NO_DATA = 5
local UBUS_STATUS_PERMISSION_DENIED = 6
local UBUS_STATUS_TIMEOUT = 7
local UBUS_STATUS_NOT_SUPPORTED = 8
local UBUS_STATUS_UNKNOWN_ERROR = 9
local UBUS_STATUS_CONNECTION_FAILED = 10

local ubus

local function file2json(path)
    local f = io.open(path)
    local json = {}
    if f then
        local data = f:read("*a")
        json = cjson.decode(data)
        f:close()
    end

    return json
end

local function read_file(path, pattern)
    local f = io.open(path)
    local data
    if f then
        data = f:read(pattern or "*a")
        f:close()
    end
    return data
end

local function write_file(path, data)
    local f = io.open(path, "w")
    if f then
        data = f:write(data)
        f:close()
    end
end

local function menu_access(sid, acls)
    for _, acl in ipairs(acls) do
        local r = ubus.call("session", "access", {ubus_rpc_session = sid, scope = "access-group", object = acl, ["function"] = "read"})
        if not r or not r.access then
            return false
        end
    end
    return true
end

local function menu_files(files)
    for _, file in ipairs(files) do
        local f = io.open(file)
        if not f then return false end
        f:close()
    end

    return true
end

local function opkg_list(action, msg)
    local limit = msg.limit or 100
    local offset = msg.offset or 0
    local pattern = msg.pattern

    if offset < 0 then offset = 0 end
    if limit > 100 then limit = 100 end

    local cmd = string.format( "opkg %s --size --nocase %s", action, msg.pattern or "")
    local upgradable = action == "list-upgradable"
    local packages = {}
    local total = 0

    local f = io.popen(cmd)
    if f then
        local i = -1
        local count = 0
        local prev

        for line in f:lines() do
            local name, version, field = line:match("(%S+) %- (%S+) %- (%S+)")
            if name and prev ~= name then
                total = total + 1
                prev = name
                i = i + 1
            end

            if name and i >= offset and count < limit then
                local pkg = packages[name]
                if not pkg then
                    count = count + 1
                    packages[name] = {size = 0, version = version}
                    pkg = packages[name]
                end

                if upgradable then
                    pkg.new_version = field
                else
                    local size = tonumber(field)
                    if size > 0 then pkg.size = size end

                    local description = line:sub(#name + #version + #field + 10)
                    if #description > 0 then pkg.description = description end
                end
            end
        end
        f:close()
    end

    local resp = {packages = {}, total = total}

    for name, pkg in pairs(packages) do
        resp.packages[#resp.packages + 1] = {
            name = name,
            version = pkg.version,
            size = pkg.size,
            new_version = pkg.new_version,
            description = pkg.description
        }
    end

    return resp
end

local function dnsmasq_leasefile()
    local c = uci.cursor()
    local leasefile

    c:foreach("dhcp", "dnsmasq", function(s)
        leasefile = s.leasefile
    end)

    return leasefile
end

local function network_cmd(name, cmd)
    local cmds = {
        ping = {"-c", "5", "-W", "1", name},
        ping6 = {"-c", "5", "-W", "1", name},
        traceroute = {"-q", "1", "-w", "1", "-n", name},
        traceroute6 = {"-q", "1", "-w", "2", "-n", name},
        nslookup = {name}
    }

    return ubus.call("file", "exec", {command = cmd, params = cmds[cmd]})
end

local function network_ifupdown(name, up)
    local cmd = up and "ifup" or "ifdown"
    return ubus.call("file", "exec", {command = cmd, params = {name}})
end

local methods = {
    ["oui.ui"] = {
        lang = {
            function(req, msg)
                local c = uci.cursor()

                if msg.lang then
                    c:set("oui", "main", "lang", msg.lang)
                    c:commit("oui")
                end

                local lang = c:get("oui", "main", "lang")

                ubus.reply(req, {lang = lang})
            end, {lang = libubus.STRING}
        },
        menu = {
            function(req, msg)
                local menus = {}

                local f = io.popen("ls " .. RPC_OUI_MENU_FILES .. " 2>/dev/null")
                if f then
                    for file in f:lines() do
                        local menu = file2json(file)

                        for path, item in pairs(menu) do
                            local access, files = true, true
                            local tmp = {}

                            for k, v in pairs(item) do
                                if k == "acls" then
                                    access = menu_access(msg.ubus_rpc_session, v)
                                elseif k == "files" then
                                    files = menu_files(v)
                                else
                                    tmp[k] = v
                                end
                            end

                            if access and files then
                                menus[path] = tmp
                            end
                        end
                    end
                    f:close()
                end

                ubus.reply(req, {menu = menus})
            end, {}
        },
        acls = {
            function(req, msg)
                local acls = {}

                local f = io.popen("ls /usr/share/rpcd/acl.d/*.json 2>/dev/null")
                if f then
                    for file in f:lines() do
                        local acl = file2json(file)
                        for k, v in pairs(acl) do
                            acls[#acls + 1] = {
                                [k] = v
                            }
                        end
                    end
                    f:close()
                end

                ubus.reply(req, {acls = acls})
            end, {}
        },
        crypt = {
            function(req, msg)
                if not msg.data or #msg.data >= 128 then
                    return UBUS_STATUS_INVALID_ARGUMENT
                end

                local hash = crypt(msg.data, "$1$")
                ubus.reply(req, {crypt = hash})
            end, {data = libubus.STRING}
        }
    },
    ["oui.network"] = {
        conntrack_count = {
            function(req, msg)
                local count = read_file("/proc/sys/net/netfilter/nf_conntrack_count", "*l")
                local limit = read_file("/proc/sys/net/netfilter/nf_conntrack_max", "*l")
                ubus.reply(req, {count = tonumber(count), limit = tonumber(limit)})
            end, {}
        },
        conntrack_table = {
            function(req, msg)
                local entries = {}

                for line in io.lines("/proc/net/nf_conntrack") do
                    local fam, l3, l4, expires, tuples = line:match("^(ipv[46]) +(%d+) +%S+ +(%d+) +(%d+) +(.+)$")

                    if fam and l3 and l4 and expires and not tuples:match("^TIME_WAIT ") then
                        local entry = {
                            ipv6 = fam == "ipv6",
                            protocol = tonumber(l4),
                            expires = tonumber(expires)
                        }

                        local key, val

                        for key, val in tuples:gmatch("(%w+)=(%S+)") do
                            if (key == "src" or key == "dst") and not entry[key] then
                                entry[key] = val
                            elseif key == "sport" or key == "dport" and not entry[key] then
                                entry[key] = tonumber(val)
                            elseif key == "packets" then
                                if entry["rx_packets"] then
                                    entry["tx_packets"] = tonumber(val)
                                else
                                    entry["rx_packets"] = tonumber(val)
                                end
                            elseif key == "bytes" then
                                if entry["rx_bytes"] then
                                    entry["tx_bytes"] = tonumber(val)
                                else
                                    entry["rx_bytes"] = tonumber(val)
                                end
                            end
                        end

                        entries[#entries + 1] = entry
                    end
                end

                ubus.reply(req, {entries = entries})
            end, {}
        },
        arp_table = {
            function(req, msg)
                local entries = {}
                local r, lines = pcall(io.lines, "/proc/net/arp")
                if r then
                    for line in lines do
                        local ipaddr, macaddr, device = line:match("(%S+) +%S+ +%S+ +(%S+) +%S+ +(%S+)")

                        if ipaddr ~= "IP" then
                            entries[#entries + 1] = {
                                ipaddr = ipaddr,
                                macaddr = macaddr,
                                device = device
                            }
                        end
                    end
                end
                ubus.reply(req, {entries = entries})
            end, {}
        },
        dhcp_leases = {
            function(req, msg)
                local leases = {}
                local leasefile = dnsmasq_leasefile()

                local r, lines = pcall(io.lines, leasefile)
                if r then
                    for line in lines do
                        local ts, mac, addr, name = line:match("(%S+) +(%S+) +(%S+) +(%S+)")
                        leases[#leases + 1] = {
                            ipaddr = addr,
                            macaddr = mac,
                            hostname = name ~= "*" and name,
                            expires = ts - os.time()
                        }
                    end
                end

                ubus.reply(req, {leases = leases})
            end, {}
        },
        routes = {
            function(req, msg)
                local routes = {}
                for line in io.lines("/proc/net/route") do
                    local field = {}
                    for e in line:gmatch("%S+") do
                        field[#field + 1] = e
                    end

                    if field[2] ~= "Destination" then
                        routes[#routes + 1] = {
                            target = parse_route_addr(field[2], field[8]),
                            nexthop = parse_route_addr(field[3]),
                            metric = field[7],
                            device = field[1]
                        }
                    end
                end
                ubus.reply(req, {routes = routes})
            end, {}
        },
        ping = {
            function(req, msg)
                if not msg.name then return UBUS_STATUS_INVALID_ARGUMENT end
                ubus.reply(req, network_cmd(msg.name, "ping"))
            end, {name = libubus.STRING}
        },
        traceroute = {
            function(req, msg)
                if not msg.name then return UBUS_STATUS_INVALID_ARGUMENT end
                ubus.reply(req, network_cmd(msg.name, "traceroute"))
            end, {name = libubus.STRING}
        },
        nslookup = {
            function(req, msg)
                if not msg.name then return UBUS_STATUS_INVALID_ARGUMENT end
                ubus.reply(req, network_cmd(msg.name, "nslookup"))
            end, {name = libubus.STRING}
        },
        ifup = {
            function(req, msg)
                if not msg.name then return UBUS_STATUS_INVALID_ARGUMENT end
                ubus.reply(req, network_ifupdown(msg.name, true))
            end, {name = libubus.STRING}
        },
        ifdown = {
            function(req, msg)
                if not msg.name then return UBUS_STATUS_INVALID_ARGUMENT end
                ubus.reply(req, network_ifupdown(msg.name, false))
            end, {name = libubus.STRING}
        },
        bwm = {
            function(req, msg)
                local entries = {}
                local r, lines = pcall(io.lines, "/proc/oui/term")
                if r then
                    for line in lines do
                        local mac, ip, rx, tx = line:match("(%S+) +(%S+) +(%S+) +(%S+)")

                        if mac and mac ~= "MAC" then
                            entries[#entries + 1] = {
                                macaddr = mac,
                                ipaddr = ip,
                                rx = {parse_flow(rx)},
                                tx = {parse_flow(tx)}
                            }
                        end
                    end
                end
                ubus.reply(req, {entries = entries})
            end, {name = libubus.STRING}
        }
    },
    ["oui.system"] = {
        init_list = {
            function(req, msg)
                local initscripts = {}
                local f = io.popen("ls /etc/init.d")
                if f then
                    for name in f:lines() do
                        local start, stop, enabled = false
                        local line = read_file("/etc/init.d/" .. name, "*l")
                        if line and line:match("/etc/rc.common") then
                            for line in io.lines("/etc/init.d/" .. name) do
                                local k, v = line:match("(%S+)=(%d+)")
                                if k == "START" then
                                    start = v
                                elseif k == "STOP" then
                                    stop = v
                                    break
                                end
                            end
                            if start then
                                if read_file("/etc/rc.d/S" .. start .. name, 1) then
                                    enabled = true
                                end

                                initscripts[#initscripts + 1] = {
                                    name = name,
                                    start = tonumber(start),
                                    stop = tonumber(stop),
                                    enabled = enabled
                                }
                            end
                        end
                    end
                    f:close()
                end
                ubus.reply(req, {initscripts = initscripts})
            end, {}
        },
        backup_restore = {
            function(req, msg)
                local resp = ubus.call("file", "exec", {command = "sysupgrade", params = {"--restore-backup", '/tmp/backup.tar.gz'}})
                ubus.reply(req, resp)
            end, {}
        },
        backup_clean = {
            function(req, msg)
                os.execute("rm -f /tmp/backup.tar.gz")
            end, {}
        },
        cpu_time = {
            function(req, msg)
                local line = read_file("/proc/stat", "*l")
                local times = {}
                for t in line:sub(4):gmatch("%S+") do
                    times[#times + 1] = tonumber(t)
                end
                ubus.reply(req, {times = times})
            end, {}
        }
    }
}

function ubus_init()
    local conn = libubus.connect()
    if not conn then
        error("Failed to connect to ubus")
    end

    conn:add(methods)

    return {
        call = function(object, method, params)
            return conn:call(object, method, params or {})
        end,
        reply = function(req, msg)
            conn:reply(req, msg)
        end
    }
end

local function main()
    uloop.init()

    ubus = ubus_init()

    uloop.run()
end

main()
