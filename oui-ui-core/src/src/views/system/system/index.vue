<template>
  <uci-form config="system" tabbed>
    <uci-section :title="$t('General Settings')" type="system">
        <uci-option-dummy :label="$t('Local Time')" :load="localTime" name="__time"></uci-option-dummy>
        <uci-option-input type="input" :label="$t('Hostname')" name="hostname" required rules="hostname" @applied="updateHostname"></uci-option-input>
        <uci-option-list :label="$t('Timezone')" name="zonename" required initial="UTC" :options="zoneinfo" :save="saveTimezone"></uci-option-list>
    </uci-section>
    <uci-section :title="$t('Time Synchronization')" name="ntp">
      <uci-option-switch :label="$t('Enable NTP client')" name="enable" save="" :load="ntpCliEnabled" :apply="ntpCliEnableApply"></uci-option-switch>
      <uci-option-switch :label="$t('Provide NTP server')" name="enable_server" depend="enable"></uci-option-switch>
      <uci-option-dlist :label="$t('NTP server candidates')" name="server" depend="enable"></uci-option-dlist>
    </uci-section>
  </uci-form>
</template>

<script>
import zoneinfo from './zoneinfo'

export default {
  data() {
    return {
      localTime: ''
    }
  },
  computed: {
    zoneinfo() {
      return zoneinfo.map(item => item[0]);
    }
  },
  timers: {
    loadLocalTime: {time: 3000, autostart: true, immediate: true, repeat: true}
  },
  methods: {
    loadLocalTime() {
      this.$system.getSystemInfo().then(r => {
        this.localTime = new Date(r.localtime * 1000).toString();
      });
    },
    saveTimezone(sid, value) {
      let timezone = 'UTC';

      for (let i = 0; i < zoneinfo.length; i++) {
        if (zoneinfo[i][0] === value) {
          timezone = zoneinfo[i][1];
          break;
        }
      }

      this.$uci.set('system', sid, 'zonename', value);
      this.$uci.set('system', sid, 'timezone', timezone);
    },
    ntpCliEnabled() {
      return this.$system.initEnabled('sysntpd');
    },
    ntpCliEnableApply(v) {
      return new Promise(resolve => {
        if (v) {
          this.$system.initStart('sysntpd').then(() => {
            this.$system.initEnable('sysntpd').then(() => {
              resolve();
            });
          });
        } else {
          this.$system.initStop('sysntpd').then(() => {
            this.$system.initDisable('sysntpd').then(() => {
              resolve();
            });
          });
        }
      });
    },
    updateHostname(value) {
      this.$store.commit('setHostname', value);
    }
  }
}
</script>
