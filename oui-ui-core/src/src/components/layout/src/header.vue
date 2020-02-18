<template>
  <el-header>
    <el-menu
      ref="navmenu"
      :default-active="$route.path"
      mode="horizontal"
      background-color="#545c64"
      text-color="#fff"
      active-text-color="#ffd04b"
      router>
      <el-menu-item index="/home">{{ hostname }}</el-menu-item>
      <template v-for="menu in menus">
        <el-submenu v-if="menu.children" :key="menu.path" :index="menu.path">
          <template slot="title">
            <span slot="title">{{ $t(menu.title) }}</span>
          </template>
          <el-menu-item v-for="submenu in menu.children" :key="submenu.path" :index="submenu.path">{{ $t(submenu.title) }}</el-menu-item>
        </el-submenu>
        <el-menu-item v-else :key="menu.path" :index="menu.path">{{ $t(menu.title) }}</el-menu-item>
      </template>
      <el-menu-item index="/login">{{ $t('Logout') }}</el-menu-item>
    </el-menu>
  </el-header>
</template>

<script>
export default {
  name: 'Header',
  data() {
    return {
      opened: ''
    }
  },
  computed: {
    menus() {
      return this.$store.state.menus;
    },
    hostname() {
      return this.$store.state.hostname;
    }
  },
  watch: {
    '$route.path'(path) {
      const paths = path.split('/');

      if (paths.length === 2 && this.opened !== '') {
        this.$refs['navmenu'].close(this.opened);
        return;
      }

      if (paths.length === 3)
        this.opened = '/' + paths[1];
    }
  },
  created() {
    this.$menu.load((menus, routes) => {
      this.$store.commit('setMenus', menus);
      this.$router.addRoutes(routes);
    });

    const paths = this.$route.path.split('/');
    if (paths.length === 3)
      this.opened = '/' + paths[1];
  }
}
</script>

<style scoped>
.el-header {
  padding: 0;
}
</style>