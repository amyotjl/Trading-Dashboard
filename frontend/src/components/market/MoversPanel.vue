<script setup lang="ts">
import { computed } from 'vue'
import type { MarketMover } from '@/services/api'

const props = defineProps<{
  tab: 'gainers' | 'losers' | 'active'
  gainers: MarketMover[]
  losers: MarketMover[]
  mostActive: MarketMover[]
  sediTickers: Set<string>
}>()

const emit = defineEmits<{
  'update:tab': [value: string]
  select: [ticker: string]
}>()

const list = computed(() =>
  props.tab === 'gainers' ? props.gainers
  : props.tab === 'losers' ? props.losers
  : props.mostActive
)
const showVol = computed(() => props.tab === 'active')
</script>

<template>
  <div class="market-panel" style="align-self: start">
    <div class="movers-tabs">
      <button :class="{ active: tab === 'gainers' }" @click="emit('update:tab', 'gainers')">Top Gainers</button>
      <button :class="{ active: tab === 'losers' }" @click="emit('update:tab', 'losers')">Top Losers</button>
      <button :class="{ active: tab === 'active' }" @click="emit('update:tab', 'active')">Most Active</button>
    </div>
    <div class="mover-list">
      <div
        v-for="m in list"
        :key="m.ticker"
        class="mover-row"
        :style="sediTickers.has(m.ticker) ? {} : { cursor: 'default', opacity: 0.95 }"
        :title="sediTickers.has(m.ticker) ? 'Open in SEDI dashboard' : 'No SEDI filings in dataset'"
        @click="sediTickers.has(m.ticker) && emit('select', m.ticker)"
      >
        <span class="mt">{{ m.ticker }}</span>
        <span class="mn">
          {{ m.name }}
          <span v-if="sediTickers.has(m.ticker)" style="margin-left: 6px; color: var(--accent); font-size: 10px">● SEDI</span>
        </span>
        <span class="mp">{{ showVol ? ((m.vol ?? 0) / 1e6).toFixed(1) + 'M' : '$' + m.last.toFixed(2) }}</span>
        <span class="mc" :class="m.chg >= 0 ? 'pos' : 'neg'">{{ m.chg >= 0 ? '+' : '' }}{{ m.chg.toFixed(2) }}%</span>
      </div>
    </div>
  </div>
</template>
