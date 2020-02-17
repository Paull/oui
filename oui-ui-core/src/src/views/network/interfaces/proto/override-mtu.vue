<template>
  <uci-option-input tab="advanced" :label="$t('Override MTU')" name="mtu" placeholder="1480" :rules="{type: 'uinteger', min: 1320, max: 1500}"></uci-option-input>
</template>
