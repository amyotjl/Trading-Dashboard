<script setup lang="ts">
import { computed } from 'vue'
import type { MarketSector } from '@/services/api'

const props = defineProps<{
  sectors: MarketSector[]
  metric: 'day' | 'week' | 'month' | 'ytd'
}>()

const emit = defineEmits<{ 'update:metric': [value: string] }>()

const metrics = [
  { k: 'day', label: '1D' },
  { k: 'week', label: '1W' },
  { k: 'month', label: '1M' },
  { k: 'ytd', label: 'YTD' },
]

function colFor(cells: MarketSector[], totalCols = 12) {
  const total = cells.reduce((a, b) => a + b.weight, 0)
  const cols = cells.map((c) => Math.max(1, Math.round((c.weight / total) * totalCols)))
  let diff = totalCols - cols.reduce((a, b) => a + b, 0)
  while (diff !== 0) {
    const i = diff > 0 ? cols.indexOf(Math.min(...cols)) : cols.indexOf(Math.max(...cols))
    cols[i]! += diff > 0 ? 1 : -1
    diff += diff > 0 ? -1 : 1
  }
  return cols
}

const sorted = computed(() => [...props.sectors].sort((a, b) => b.weight - a.weight))
const top = computed(() => sorted.value.slice(0, 5))
const bot = computed(() => sorted.value.slice(5))
const topCols = computed(() => colFor(top.value))
const botCols = computed(() => colFor(bot.value))
const maxAbs = computed(() => Math.max(...props.sectors.map((s) => Math.abs(s[props.metric]))) || 1)

function cellStyle(s: MarketSector) {
  const v = s[props.metric]
  const intensity = Math.min(1, Math.abs(v) / maxAbs.value)
  const isPos = v >= 0
  const bg = isPos
    ? `oklch(${68 - intensity * 18}% ${0.04 + intensity * 0.14} 148)`
    : `oklch(${68 - intensity * 18}% ${0.04 + intensity * 0.17} 28)`
  const fg = intensity > 0.35 ? '#fff' : 'var(--fg)'
  const sw = intensity > 0.35 ? 'rgba(255,255,255,0.7)' : 'var(--fg-muted)'
  return { bg, fg, sw }
}
</script>

<template>
  <div class="market-panel">
    <div class="panel-head">
      TSX Sector Performance
      <span class="spacer" />
      <div class="seg">
        <button
          v-for="m in metrics"
          :key="m.k"
          :class="{ active: metric === m.k }"
          @click="emit('update:metric', m.k)"
        >{{ m.label }}</button>
      </div>
    </div>
    <div class="sector-map">
      <div
        v-for="(s, i) in top"
        :key="s.name"
        class="sector-cell"
        :style="{ background: cellStyle(s).bg, color: cellStyle(s).fg, gridColumn: `span ${topCols[i]}` }"
        :title="`${s.name} · ${s[metric] >= 0 ? '+' : ''}${s[metric].toFixed(2)}% (${metric})`"
      >
        <span class="sn">{{ s.name }}</span>
        <div class="row">
          <span class="sv">{{ s[metric] >= 0 ? '+' : '' }}{{ s[metric].toFixed(2) }}%</span>
          <span class="sw" :style="{ color: cellStyle(s).sw }">· {{ s.weight.toFixed(1) }}%</span>
        </div>
      </div>
      <div
        v-for="(s, i) in bot"
        :key="s.name"
        class="sector-cell"
        :style="{ background: cellStyle(s).bg, color: cellStyle(s).fg, gridColumn: `span ${botCols[i]}` }"
        :title="`${s.name} · ${s[metric] >= 0 ? '+' : ''}${s[metric].toFixed(2)}% (${metric})`"
      >
        <span class="sn">{{ s.name }}</span>
        <div class="row">
          <span class="sv">{{ s[metric] >= 0 ? '+' : '' }}{{ s[metric].toFixed(2) }}%</span>
          <span class="sw" :style="{ color: cellStyle(s).sw }">· {{ s.weight.toFixed(1) }}%</span>
        </div>
      </div>
    </div>
  </div>
</template>
