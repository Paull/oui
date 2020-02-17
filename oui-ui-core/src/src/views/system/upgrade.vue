<template>
  <div>
    <el-card :header="$t('Reboot / Reset')" style="margin-bottom: 15px">
      <el-button type="primary" size="small" @click="reboot">{{ $t('Reboot now') }}</el-button>
      <el-button type="danger" size="small" @click="performReset">{{ $t('Perform reset') }}</el-button>
    </el-card>
    <el-card :header="$t('Flash new firmware image')">
      <el-upload ref="firmware" action="/cgi-bin/oui-upload" :on-success="onUploadFirmwareSuccess" :file-list="fileListFirmware" :auto-upload="true" :limit="1" :data="{filename: '/tmp/firmware.bin', sessionid: sid}">
        <el-button slot="trigger" size="small" type="primary">{{ $t('Upload Firmware...') }}</el-button>
      </el-upload>
    </el-card>
  </div>
</template>

<script>
export default {
  name: 'upgrade',
  data() {
    return {
      sid: '',
      fileListFirmware: []
    }
  },
  methods: {
    reboot() {
      this.$confirm(this.$t('Really reboot now?'), this.$t('Reboot')).then(() => {
        this.$system.reboot().then(() => {
          this.$reconnect('Rebooting...');
        });
      });
    },
    testUpgrade() {
      return this.$ubus.call('rpc-sys', 'upgrade_test');
    },
    startUpgrade(keep) {
      return this.$ubus.call('rpc-sys', 'upgrade_start', {keep});
    },
    cleanUpgrade() {
      return this.$ubus.call('rpc-sys', 'upgrade_clean');
    },
    performReset() {
      this.$confirm(this.$t('This will reset the system to its initial configuration, all changes made since the initial flash will be lost!'), this.$t('Really reset all changes?')).then(() => {
        this.$ubus.call('rpc-sys', 'factory').then(() => {
          this.$reconnect(this.$t('Rebooting...'));
        });
      });
    },
    onUploadFirmwareSuccess(info, file) {
      this.testUpgrade().then(res => {
        if (res.code === 0) {
          let title = this.$t('Verify firmware');
          let content = '<p>' + this.$t('The firmware image was uploaded completely', {btn: this.$t('OK')}) + '</p>'
          content += '<ul>';
          content += `<li><strong>${this.$t('Filename')}: </strong>${file.name}</li>`;
          content += `<li><strong>${this.$t('Checksum')}: </strong>${info.checksum}</li>`;

          const size = (info.size / 1024 / 1024).toFixed(2);
          content += `<li><strong>${this.$t('Size')}: </strong>${size} MB</li>`;
          content += '</ul>';

          this.$confirm(content, title, {
            showClose: false,
            closeOnClickModal: false,
            dangerouslyUseHTMLString: true
          }).then(() => {
            const keep = false;
            this.startUpgrade(keep).then(() => {
              this.$reconnect(this.$t('Upgrading...'));
            });
          });
        } else {
          const content = this.$t('The uploaded image file does not contain a supported format. Make sure that you choose the generic image format for your platform.');
          this.$confirm(content, this.$t('Invalid image'), {
            showCancelButton: false,
            confirmButtonText: this.$t('Close')
          }).then(() => {
            this.cleanUpgrade();
          });
        }
      });
    }
  },
  created() {
    this.sid = this.$session.sid();
  }
}
</script>
