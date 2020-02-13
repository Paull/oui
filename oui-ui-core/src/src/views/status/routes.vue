<template>
  <div>
    <CardTable title="ARP" :columns="arp.columns" :data="arp.data"></CardTable>
    <CardTable :title="$t('Active IPv4-Routes')" :columns="routes.columns" :data="routes.data"></CardTable>
  </div>
</template>

<script>

export default {
  data() {
    return {
      arp: {
        columns: [
          {key: 'ipaddr', title: this.$t('IPv4-Address')},
          {key: 'macaddr', title: this.$t('MAC-Address')},
          {key: 'device', title: this.$t('Device')}
        ],
        data: []
      },
      routes: {
        columns: [
          {key: 'target', title: this.$t('Target')},
          {key: 'nexthop', title: this.$t('Nexthop')},
          {key: 'metric', title: this.$t('Metric')},
          {key: 'device', title: this.$t('Device')}
        ],
        data: []
      }
    }
  },
  created() {
    this.$ubus.callBatch([
      ['oui.network', 'arp_table'],
      ['oui.network', 'routes']
    ]).then(r => {
      this.arp.data = r[0].entries;
      this.routes.data = r[1].routes;
    });
  }
}
</script>
