<template>
  <div>
    <el-table :data="interfaces">
      <el-table-column :label="$t('Network')" width="140">
        <template v-slot="{ row }">
          <network-badge :iface="row.name" :device="row.getDevice() && row.getDevice().name"></network-badge>
        </template>
      </el-table-column>
      <el-table-column :label="$t('Status')">
        <template v-slot="{ row }">
          <strong>{{ $t('IP Address') }}</strong>: {{ row.getIPv4Addrs().join(',') }}<br/>
          <strong>{{ $t('RX Total') }}</strong>: {{ '%mB'.format(row.getStatistics().rx_bytes) }}<br/>
          <strong>{{ $t('TX Total') }}</strong>: {{ '%mB'.format(row.getStatistics().tx_bytes) }}<br/>
          <strong>{{ $t('Uptime') }}</strong>: {{ row.isUp() ? '%t'.format(row.getUptime()) : $t('Interface is down') }}<br/>
        </template>
      </el-table-column>
      <el-table-column :label="$t('Operations')">
        <template v-slot="{ row }">
          <el-button size="mini" @click="ifup(row.name)">{{ $t('Restart') }}</el-button>
          <el-button size="mini" @click="ifdown(row.name)">{{ $t('Stop') }}</el-button>
          <el-button type="primary" size="mini" @click="edit(row.name)" v-show="row.status.proto !== 'wireguard'">{{ $t('Edit') }}</el-button>
        </template>
      </el-table-column>
    </el-table>
    <el-dialog :title="dialogTitle" :visible.sync="dialogVisible" custom-class="interface-edit-dialog">
      <uci-form config="network" v-if="dialogVisible" :apply-timeout="15">
        <uci-section :name="editorIface">
          <uci-tab :title="$t('General Settings')" name="general">
            <uci-option-switch :label="$t('Start on boot')" name="auto" initial="1"></uci-option-switch>
            <uci-option-list :label="$t('Protocol')" name="proto" :options="protocols" initial="none" required @change="protoChanged"></uci-option-list>
          </uci-tab>
          <uci-tab :title="$t('Advanced Settings')" name="advanced">
          </uci-tab>
          <!-- <uci-tab :title="$t('Firewall Settings')" name="firewall">
            <uci-option-list :label="$t('Create / Assign firewall-zone')" name="_fwzone" :options="zones" :load="loadZone" :save="saveZone" allow-create :description="$t('interface-config-zone-desc')"></uci-option-list>
          </uci-tab> -->
          <component v-if="proto !== '' && proto !== 'none'" :is="'proto-' + proto"></component>
        </uci-section>
      </uci-form>
    </el-dialog>
  </div>
</template>

<script>
import NetworkBadge from './network-badge.vue'
import ProtoDhcp from './proto/dhcp.vue'
import ProtoStatic from './proto/static.vue'
import ProtoPppoe from './proto/pppoe.vue'
import ProtoPptp from './proto/pptp.vue'
import ProtoL2tp from './proto/l2tp.vue'
import Ifname from './ifname.vue'

export default {
  data() {
    return {
      proto: '',
      interfaces: [],
      devices: [],
      // zones: [],
      dialogVisible: false,
      editorIface: '',
      protocols: [
        ['none', this.$t('Unmanaged')],
        ['dhcp', this.$t('DHCP Client')],
        ['static', this.$t('Static address')],
        ['pppoe', this.$t('pppoe')],
        ['pptp', 'PPTP'],
        ['l2tp', 'L2TP']
      ]
    }
  },
  components: {
    NetworkBadge,
    ProtoDhcp,
    ProtoStatic,
    ProtoPppoe,
    ProtoPptp,
    ProtoL2tp,
    Ifname
  },
  computed: {
    dialogTitle() {
      return `${this.$t('Configure')} "${this.editorIface}"`
    }
  },
  timers: {
    load: {time: 3000, autostart: true, immediate: true, repeat: true}
  },
  methods: {
    load() {
      this.$network.load().then(() => {
        this.interfaces = this.$network.getInterfaces();
      });
    },
    protoChanged(proto) {
      this.proto = proto;
    },
    saveType(sid, value) {
      this.$uci.set('network', sid, 'type', value || '');
    },
    // loadZone() {
    //   return new Promise(resolve => {
    //     this.$firewall.load().then(() => {
    //       this.zones = this.$firewall.zones.map(z => z.name());
    //       const z = this.$firewall.findZoneByNetwork(this.editorIface);
    //       if (z)
    //         resolve(z.name());
    //       resolve();
    //     });
    //   });
    // },
    // saveZone(sid, value) {
    //   let z = this.$firewall.findZoneByNetwork(this.editorIface);

    //   if (!value) {
    //     if (z)
    //       z.delNetwork(this.editorIface);
    //     return;
    //   }

    //   if (z) {
    //     if (value === z.name())
    //       return;
    //     z.delNetwork(this.editorIface);
    //   }

    //   z = this.$firewall.findZoneByName(value);
    //   if (!z)
    //     z = this.$firewall.createZone(value);
    //   z.addNetwork(this.editorIface);
    // },
    edit(iface) {
      this.editorIface = iface;
      this.dialogVisible = true;
    },
    ifup(name) {
      this.$ubus.call('oui.network', 'ifup', {name: name});
    },
    ifdown(name) {
      this.$ubus.call('oui.network', 'ifdown', {name: name});
    }
  }
}
</script>

<style lang="scss">
.interface-edit-dialog {
  .el-dialog__header {
    padding: 10px 20px 10px;
  }
  .el-dialog__body {
    padding: 0;
  }
}
</style>
