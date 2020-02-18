<template>
  <div>
    <el-row :gutter="20" style="margin-bottom: 15px">
      <el-col :span="12">
        <card-list :title="$t('System information')" :list="sysinfo"></card-list>
      </el-col>
      <el-col :span="12">
        <el-card :header="$t('Resource usage')">
          <e-charts :options="resourceChart"></e-charts>
        </el-card>
      </el-col>
    </el-row>
  </div>
</template>

<script>
import 'echarts/lib/chart/line'
import 'echarts/lib/chart/gauge'
import 'echarts/lib/component/title'
import 'echarts/lib/component/polar'
import 'echarts/lib/component/tooltip'
import 'echarts/lib/component/legendScroll'

export default {
  data() {
    return {
      sysinfo: [],
      lastCPUTime: null,
      resourceChart: {
        tooltip: {
          formatter: '{b}: {c}%'
        },
        series: [
          {
            type: 'gauge',
            radius: '60%',
            center: ['25%', '50%'],
            splitLine: {length: 20},
            axisLine: {lineStyle: {width: 8}},
            detail: {formatter: '{value}%', fontSize: 15},
            data: [{value: 0, name: this.$t('CPU usage')}]
          },
          {
            type: 'gauge',
            radius: '60%',
            center: ['75%', '50%'],
            splitLine: {length: 20},
            axisLine: {lineStyle: {width: 8}},
            detail: {formatter: '{value}%', fontSize: 15},
            data: [{value: 0, name: this.$t('Memory usage')}]
          }
        ]
      }
    }
  },
  timers: {
    update: {time: 2000, autostart: true, immediate: true, repeat: true}
  },
  methods: {
    calcDevFlow(flow) {
      return flow[0] * 1000000000 + flow[1] * 1000000 + flow[2] * 1000 + flow[3];
    },
    update() {
      this.$ubus.call('oui.system', 'cpu_time').then(({times}) => {
        if (!this.lastCPUTime) {
          this.lastCPUTime = times;
          return;
        }

        let idle1 = this.lastCPUTime[3] + this.lastCPUTime[4];
        let idle2 = times[3] + times[4];

        let total1 = 0;
        let total2 = 0;

        this.lastCPUTime.forEach(t => {
          total1 += t;
        });

        times.forEach(t => {
          total2 += t;
        });

        this.resourceChart.series[0].data[0].value = (((total2 - total1) - (idle2 - idle1)) / (total2 - total1) * 100).toFixed(2)
        this.lastCPUTime = times;
      });

      this.$system.getInfo().then(({model, system, localtime, uptime, memory}) => {
        this.sysinfo = [
          [this.$t('Model'), model],
          [this.$t('Architecture'), system],
          [this.$t('Local Time'), new Date(localtime * 1000).toString()],
          [this.$t('Uptime'), '%t'.format(uptime)]
        ];

        this.resourceChart.series[1].data[0].value = ((memory.total - memory.free) / memory.total * 100).toFixed(2);
      });
    }
  }
}
</script>