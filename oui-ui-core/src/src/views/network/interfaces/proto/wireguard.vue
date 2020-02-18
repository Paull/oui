<template>
  <div>
    <override-mtu></override-mtu>
  </div>
</template>

<script>
import mixin from './proto'
import OverrideMtu from './override-mtu'

export default {
  mixins: [mixin],
  data() {
    return {}
  },
  components: {
    OverrideMtu
  }
}
</script>
