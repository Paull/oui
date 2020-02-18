<template>
  <el-tabs v-if="radios.length > 0" :value="radios[0].name">
    <el-tab-pane v-for="radio in radios" :key="radio.name" :name="radio.name" :label="radio.tab_name">
      <uci-form config="wireless" :apply-timeout="15">
        <uci-section type="wifi-iface" :options="{radio: radio.name}" :filter="filterInterface">
          <uci-tab :title="$t('General Settings')" name="general">
            <uci-option-switch :label="$t('Disable')" name="disabled"></uci-option-switch>
            <uci-option-input label="SSID" name="ssid" required></uci-option-input>
            <uci-option-list :label="$t('Encryption')" name="encryption" :options="encryptions" initial="none" :load="loadEncr" :save="saveEncr"></uci-option-list>
            <uci-option-list :label="$t('Cipher')" name="cipher" depend="encryption != 'none'" :options="ciphers" initial="auto" :load="loadCipher" :save="saveCipher"></uci-option-list>
            <uci-option-input :label="$t('Passphrase')" name="key" depend="encryption != 'none'" password></uci-option-input>
          </uci-tab>
          <uci-tab :title="$t('Advanced Settings')" name="advanced">
            <uci-option-switch :label="$t('Hide ESSID')" name="hidden"></uci-option-switch>
            <uci-option-list :label="$t('MAC-Filter')" name="macfilter" :options="macfilters"></uci-option-list>
            <uci-option-dlist :label="$t('MAC-List')" name="maclist" depend="macfilter == 'allow' || macfilter == 'deny'" rules="macaddr"></uci-option-dlist>
          </uci-tab>
        </uci-section>
        <uci-section :name="radio.name">
          <uci-tab :title="radio.hardware" name="band">
            <uci-option-switch :label="$t('Disable')" name="disabled"></uci-option-switch>
            <uci-option-list :label="$t('Band')" name="htmode" :options="radio.htmodes"></uci-option-list>
            <uci-option-list :label="$t('Channel')" name="channel" :options="radio.channels" :initial="radio.channel" required></uci-option-list>
          </uci-tab>
        </uci-section>
      </uci-form>
    </el-tab-pane>
  </el-tabs>
</template>

<script>
export default {
  data() {
    return {
      radios: [],
      encryptions: [
        ['none', this.$t('No encryption')],
        ['psk', 'WPA-PSK'],
        ['psk2', 'WPA2-PSK'],
        ['psk-mixed', 'WPA/WPA2-PSK ' + this.$t('mixed')]
      ],
      ciphers: [
        ['auto', this.$t('auto')],
        ['ccmp', this.$t('Force CCMP (AES)')],
        ['tkip', this.$t('Force TKIP')],
        ['tkip+ccmp', this.$t('Force TKIP and CCMP (AES)')]
      ],
      macfilters: [
        ['allow', this.$t('Allow listed only')],
        ['deny', this.$t('Allow all except listed')]
      ]
    }
  },
  methods: {
    filterInterface(s, self) {
      return self.options.radio === s.device;
    },
    loadEncr(sid) {
      const [v] = (this.$uci.get('wireless', sid, 'encryption') || '').split('+');
      return v;
    },
    loadCipher(sid) {
      let v = (this.$uci.get('wireless', sid, 'encryption') || '').split('+');

      if (v.length < 2)
        return 'auto';

      v = v.slice(1).join('+');

      if (v === 'aes')
        v = 'ccmp';
      else if (v === 'tkip+aes' || v === 'aes+tkip' || v === 'ccmp+tkip')
        v = 'tkip+ccmp';

      return v;
    },
    saveEncr(sid, value, self) {
      let cipher = self.uciSection.formValue('cipher', sid);

      if (cipher === 'tkip' || cipher === 'ccmp' || cipher === 'tkip+ccmp')
        value = `${value}+${cipher}`;

      this.$uci.set('wireless', sid, 'encryption', value);
    },
    saveCipher(sid, value, self) {
      let encr = self.uciSection.formValue('encryption', sid);

      if (value === 'tkip' || value === 'ccmp' || value === 'tkip+ccmp')
        encr = `${encr}+${value}`;

      this.$uci.set('wireless', sid, 'encryption', encr);
    }
  },
  created() {
    const loading = this.$getLoading();

    this.$uci.load('wireless').then(() => {
      const sections = this.$uci.sections('wireless', 'wifi-device');
      let radios_num = sections.length;

      sections.forEach(s => {
        const device = s['.name'];
        const batch = [];

        batch.push(['iwinfo', 'info', {device}]);
        batch.push(['iwinfo', 'freqlist', {device}]);

        this.$ubus.callBatch(batch).then(rs => {
          const channels = [['auto', this.$t('Automatic')]];
          const info = rs[0];
          const freqlist = rs[1].results

          freqlist.forEach(f => {
            if (f.restricted)
              return;
            channels.push([f.channel, `${f.channel} (${f.mhz} MHz)`]);
          });

          let tab_name = '2.4G WiFi';

          if (info.hwmodes.indexOf('a') > -1 || info.hwmodes.indexOf('ac') > -1) {
            tab_name = '5G WiFi';
          }

          this.radios.push({
            name: device,
            tab_name: tab_name,
            channel: info.channel,
            hardware: info.hardware.name,
            htmodes: info.htmodes,
            channels: channels
          });

          radios_num--;

          if (radios_num === 0)
            loading.close();
        });
      });
    });
  }
}
</script>
