<template>
  <div>
    <el-input v-model="host" style="width:240px"></el-input>
    <el-select v-model="tool" style="width:160px">
      <el-option v-for="tool in tools" :key="tool[0]" :value="tool[0]" :label="tool[1]"></el-option>
    </el-select>
    <el-button type="primary" @click="test">>></el-button>
    <el-input v-if="stdout !== ''" style="margin-top: 10px" type="textarea" autosize readonly :value="stdout"></el-input>
    <span v-if="stderr !== ''" style="color: red; display: block">{{ stderr }}</span>
  </div>
</template>

<script>
export default {
  data() {
    return {
      host: '6j4kzg2-gosprod-qos01.i3d-hkg.ea.com',
      tool: 'runPing',
      tools: [],
      stdout: '',
      stderr: ''
    }
  },
  methods: {
    runPing(name) {
      return this.$ubus.call('oui.network', 'ping', {name});
    },
    runTraceroute(name) {
      return this.$ubus.call('oui.network', 'traceroute', {name});
    },
    runNslookup(name) {
      return this.$ubus.call('oui.network', 'nslookup', {name});
    },
    test() {
      const loading = this.$getLoading();

      this.stdout = '';
      this.stderr = '';

      this[this.tool](this.host).then(r => {
        if (r.stdout)
          this.stdout = r.stdout;

        if (r.stderr)
          this.stderr = r.stderr;
        loading.close();
      });
    }
  },
  created() {
    this.runPing('?').then(r => {
      if (r.code !== -1)
        this.tools.push(['runPing', 'IPv4 Ping']);
    });

    this.runTraceroute('?').then(r => {
      if (r.code !== -1)
        this.tools.push(['runTraceroute', 'IPv4 Traceroute']);
    });

    this.runNslookup('?').then(r => {
      if (r.code !== -1)
        this.tools.push(['runNslookup', 'DNS Lookup']);
    });
  }
}
</script>
