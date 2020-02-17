<template>
  <div>
    <el-row :gutter="20">
      <el-col :span="12"><CardList :title="$t('Lan Network')" :list="laninfo"></CardList></el-col>
      <el-col :span="12"><CardList :title="$t('Wan Network')" :list="waninfo"></CardList></el-col>
    </el-row>
    <el-card :header="$t('Terminal devices')" style="margin-bottom: 15px;">
      <el-table :data="devices">
        <el-table-column :label="$t('Hostname')" prop="hostname"></el-table-column>
        <el-table-column :label="$t('IPv4-Address')" prop="ipaddr"></el-table-column>
        <el-table-column :label="$t('MAC-Address')" prop="macaddr"></el-table-column>
        <el-table-column :label="$t('RX Rate')" prop="rxrate"></el-table-column>
        <el-table-column :label="$t('TX Rate')" prop="txrate"></el-table-column>
      </el-table>
    </el-card>
    <el-card :header="$t('Active DHCP Leases')" style="margin-bottom: 15px;">
      <el-table :data="leases">
        <el-table-column :label="$t('Hostname')" prop="hostname"></el-table-column>
        <el-table-column :label="$t('IPv4-Address')" prop="ipaddr"></el-table-column>
        <el-table-column :label="$t('MAC-Address')" prop="macaddr"></el-table-column>
        <el-table-column :label="$t('Leasetime remaining')" :formatter="row => row.expires <= 0 ? $t('expired') : '%t'.format(row.expires)"></el-table-column>
      </el-table>
    </el-card>
    <el-card :header="$t('Associated Stations')">
      <el-table :data="assoclist">
        <el-table-column :label="$t('MAC-Address')" prop="mac"></el-table-column>
        <el-table-column :label="$t('Host')" prop="host"></el-table-column>
        <el-table-column :label="$t('Signal') + ' / ' + $t('Noise')">
          <template v-slot="{row}">
            <img :src="wifiSignalIcon(row)" />
            <span>{{' ' + row.signal + '/' + row.noise + ' dBm' }}</span>
          </template>
        </el-table-column>
        <el-table-column :label="$t('RX Rate')" :formatter="formatWifiRxRate"></el-table-column>
        <el-table-column :label="$t('TX Rate')" :formatter="formatWifiTxRate"></el-table-column>
      </el-table>
    </el-card>
  </div>
</template>

<script>
export default {
  data() {
    return {
      statusLineLength: '27%',
      laninfo: [],
      waninfo: [],
      devices: [],
      devicesMap: {},
      leases: [],
      assoclist: [],
      wanIsUp: false
    }
  },
  timers: {
    update: {time: 2000, autostart: true, immediate: true, repeat: true}
  },
  methods: {
    wifirate(sta, rx) {
      const rate = rx ? sta.rx : sta.tx;
      let s = '%.1f Mbit/s'.format(rate.rate / 1000);
      s += ', %dMHz'.format(rate['40mhz'] ? 40 : 20);

      if (rate.mcs > 0)
        s += ', MCS ' + rate.mcs;

      if (rate.short_gi)
        s += ', Short GI'

      return s;
    },
    wifiSignalIcon(s) {
      let q = (-1 * (s.noise - s.signal)) / 5;
      if (q < 1)
        q = 1;
      else if (q < 2)
        q = 2;
      else if (q < 3)
        q = 3;
      else if (q < 4)
        q = 4;
      else
        q = 5;
      return `/icons/signal_${q}.png`;
    },
    formatWifiRxRate(row) {
      return this.wifirate(row, true);
    },
    formatWifiTxRate(row) {
      return this.wifirate(row, false);
    },
    calcDevFlow(flow) {
      return flow[0] * 1000000000 + flow[1] * 1000000 + flow[2] * 1000 + flow[3];
    },
    update() {
      this.$network.load().then(() => {
        const lan_iface = this.$network.getInterface('lan');
        const wan_iface = this.$network.getInterface('wan');

        this.laninfo = [
          [this.$t('Protocal'), this.$t(lan_iface.status['proto'])],
          [this.$t('IP Address'), lan_iface.getIPv4Addrs().join(', ')],
          [this.$t('netmask'), '255.255.255.0'],
          [this.$t('Online devices'), this.devices.length],
          [this.$t('Uptime'), '%t'.format(lan_iface.status['uptime'])]
        ];

        this.lanIsUp = lan_iface.status['up'];
        this.waninfo = [
          [this.$t('Protocal'), this.$t(wan_iface.status['proto'])],
          [this.$t('IP Address'), wan_iface.getIPv4Addrs().join(', ')],
          [this.$t('Gateway'), wan_iface.getIPv4Gateway()],
          ['DNS', wan_iface.getIPv4DNS().join(', ')],
          [this.$t('Uptime'), '%t'.format(wan_iface.status['uptime'])]
        ];
        this.wanIsUp = wan_iface.status['up'];
      });

      this.$ubus.call('oui.network', 'dhcp_leases').then(r => {
        const leasesMap = {};

        this.leases = r.leases;

        this.leases.forEach(l => {
          leasesMap[l.macaddr] = {hostname: l.hostname, ipaddr: l.ipaddr};
        });

        this.$ubus.call('oui.network', 'bwm').then(r => {
          this.devices = r.entries.map(dev => {
            const lease = leasesMap[dev.macaddr];

            dev = {...dev, txrate: 0, rxrate: 0};
            dev.tx = this.calcDevFlow(dev.tx);
            dev.rx = this.calcDevFlow(dev.rx);

            const ldev = this.devicesMap[dev.macaddr];
            if (ldev) {
              dev.txrate = '%mB/s'.format((dev.tx - ldev.tx) / 2);
              dev.rxrate = '%mB/s'.format((dev.rx - ldev.rx) / 2);
            }

            this.devicesMap[dev.macaddr] = {tx: dev.tx, rx: dev.rx};

            if (lease)
              dev.hostname = lease.hostname;

            return dev;
          });
        });

        this.$wireless.getAssoclist().then(assoclist => {
          this.assoclist = assoclist.map(sta => {
            const lease = leasesMap[sta.mac.toLowerCase()];
            if (lease)
              sta.host = `${lease.hostname} (${lease.ipaddr})`
            return sta;
          });
        });
      });
    }
  }
}
</script>