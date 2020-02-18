<template>
  <el-container>
    <Header></Header>
    <el-main>
      <transition name="main" mode="out-in">
        <router-view></router-view>
      </transition>
    </el-main>
    <el-footer></el-footer>
  </el-container>
</template>

<script>
import Header from './header.vue'

export default {
  name: 'Layout',
  components: {
    Header
  },
  computed: {
    hostname() {
      return this.$store.state.hostname;
    }
  },
  created() {
    this.$system.getBoardInfo().then(r => {
      this.$store.commit('setHostname', r.hostname);
      document.title = r.hostname;
    });
  }
}
</script>