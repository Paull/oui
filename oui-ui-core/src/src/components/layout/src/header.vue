<template>
  <div>
    <el-header class="header" height="40px">
      <el-breadcrumb separator="/" class="crumbs">
        <el-breadcrumb-item v-for="(item, i) in breadcrumbs" :key="i" :to="item.to">{{ $t(item.title) }}</el-breadcrumb-item>
      </el-breadcrumb>
      <div class="header-right">
        <el-link type="primary" @click="logout">{{ $t('Logout') }}</el-link>
      </div>
    </el-header>
  </div>
</template>

<script>
export default {
  name: 'Header',
  data() {
    return {
      breadcrumbs: []
    }
  },
  methods: {
    getBreadCrumbList(route) {
      const homeRoute = this.$router.options.routes[1].children[0];
      const homeItem = {title: homeRoute.meta.title};
      const matched = route.matched;

      if (matched.some(item => item.path === '/home'))
        return [homeItem];

      homeItem.to = '/home';

      const list = [homeItem, matched[0].meta];

      if (!matched[0].redirect)
        list.push(matched[1].meta);

      return list;
    },
    logout() {
      this.$router.push('/login');
    }
  },
  watch: {
    '$route'(newRoute) {
      this.breadcrumbs = this.getBreadCrumbList(newRoute);
    }
  },
  created() {
    this.breadcrumbs = this.getBreadCrumbList(this.$route);

    this.$session.get(r => {
      this.username = r.username;
    });
  }
}
</script>

<style lang="scss">
.header {
  display: flex;
  justify-content: space-between;
  align-items: center;
}
</style>