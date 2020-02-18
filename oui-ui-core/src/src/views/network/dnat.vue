<template>
  <uci-form config="firewall" ref="form" tabbed :after-loaded="load">
    <uci-section type="redirect" :title="$t('Port Forwards')" table addable sortable :filter="filterDnat" :after-add="afterAdd">
      <uci-option-input :label="$t('Name')" name="name"></uci-option-input>
      <uci-option-list :label="$t('Protocol')" name="proto" :options="protos" initial="tcp udp" allow-create></uci-option-list>
      <uci-option-input :label="$t('External port')" name="src_dport" rules="port"></uci-option-input>
      <uci-option-list :label="$t('Internal IP address')" name="dest_ip" :options="arps" allow-create rules="ip4addr"></uci-option-list>
      <uci-option-input :label="$t('Internal port')" name="dest_port" rules="port"></uci-option-input>
      <uci-option-switch :label="$t('Enable')" name="enabled" initial="1"></uci-option-switch>
    </uci-section>
  </uci-form>
</template>

<script>
export default {
  data() {
    return {
      protos: [
        ['tcp', 'TCP'],
        ['udp', 'UDP'],
        ['tcp udp', 'TCP+UDP'],
        ['icmp', 'ICMP']
      ],
      arps: []
    }
  },
  methods: {
    load() {
      this.$firewall.load(true);
    },
    filterDnat(s) {
      return s.target !== 'SNAT';
    },
    afterAdd(sid) {
      this.$uci.set('firewall', sid, 'target', 'DNAT');
      this.$uci.set('firewall', sid, 'dest', 'lan');
      this.$uci.set('firewall', sid, 'src', 'wan');
    }
  },
  created() {
    this.$ubus.call('oui.network', 'arp_table').then(r => {
      r.entries.forEach(arp => {
        if (arp.macaddr === '00:00:00:00:00:00')
          return;

        this.arps.push([arp.ipaddr, `${arp.ipaddr} (${arp.macaddr})`]);
      });
    });
  }
}
</script>