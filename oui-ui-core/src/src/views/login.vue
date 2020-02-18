<template>
  <el-card :header="$t('Authorization Required')" class="oui-login">
    <el-alert :title="$t('Wrong password given!')" type="error" effect="dark" :closable="false" v-if="!valid"></el-alert>
    <el-form ref="login" :model="form">
      <el-form-item>
        <el-input v-model="form.password" show-password prefix-icon="el-icon-lock" :placeholder="$t('Please input password')" @keyup.enter.native="handleLogin"></el-input>
      </el-form-item>
      <el-form-item right>
        <el-button type="primary" @click="handleLogin">{{ $t('Login') }}</el-button>
      </el-form-item>
    </el-form>
  </el-card>
</template>

<script>
export default {
  data() {
    return {
      form: {
        username: 'root',
        password: ''
      },
      valid: true
    }
  },
  methods: {
    handleLogin() {
      this.$refs['login'].validate(valid => {
        if (valid) {
          this.$session.login(this.form.username, this.form.password).then(valid => {
            if (valid) {
              this.$session.updateACLs().then(() => {
                this.$router.push('/');
              });
              return;
            }

            this.valid = false;
          });
        }
      });
    }
  },
  created() {
    this.$session.logout();
  }
}
</script>

<style lang="scss">
.oui-login {
  min-width: 300px;
  top: 50%;
  left: 50%;
  position: absolute;
  transform: translate(-50%, -50%);

  .el-alert {
    margin-bottom: 10px;
  }
}
</style>
