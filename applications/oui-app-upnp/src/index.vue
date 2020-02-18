<template>
  <el-table :data="activeRedirects" :label="$t('Active UPnP Redirects')">
    <el-table-column prop="proto" :label="$t('Protocol')"></el-table-column>
    <el-table-column prop="extport" :label="$t('External port')"></el-table-column>
    <el-table-column prop="intaddr" :label="$t('Client Address')"></el-table-column>
    <el-table-column prop="host_hint" :label="$t('Host')"></el-table-column>
    <el-table-column prop="intport" :label="$t('Client Port')"></el-table-column>
    <el-table-column prop="descr" :label="$t('Description')"></el-table-column>
  </el-table>
</template>

<script>
  export default {
    data() {
      return {
        activeRedirects: []
      }
    },
    created() {
      this.$ubus.call('upnp', 'status').then(r => {
        this.activeRedirects = r.entries;
      });
    }
  }
</script>
