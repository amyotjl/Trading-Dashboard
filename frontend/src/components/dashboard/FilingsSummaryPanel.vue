<script setup lang="ts">
import { computed } from 'vue'

const props = defineProps<{
  buys: number
  sells: number
  buyValue: number
  sellValue: number
}>()

function moneyBig(n: number): string {
  if (Math.abs(n) >= 1e9) return '$' + (n / 1e9).toFixed(2) + 'B'
  if (Math.abs(n) >= 1e6) return '$' + (n / 1e6).toFixed(2) + 'M'
  if (Math.abs(n) >= 1e3) return '$' + (n / 1e3).toFixed(1) + 'K'
  return '$' + n.toFixed(2)
}

const ratio = computed(() =>
  props.sells === 0 ? '∞' : (props.buys / props.sells).toFixed(2)
)
</script>

<template>
  <div class="panel">
    <div class="panel-header">Filings Summary</div>
    <div class="kpi-stack">
      <div class="kpi-row">
        <span class="l">Acquisitions</span>
        <span class="v pos">{{ buys.toLocaleString() }}</span>
      </div>
      <div class="kpi-row" style="margin-top: -4px">
        <span class="l" style="visibility: hidden">x</span>
        <span style="font-family: var(--font-mono); font-size: 11px; color: var(--fg-muted)">{{ moneyBig(buyValue) }}</span>
      </div>
      <div class="kpi-divider" />
      <div class="kpi-row">
        <span class="l">Dispositions</span>
        <span class="v neg">{{ sells.toLocaleString() }}</span>
      </div>
      <div class="kpi-row" style="margin-top: -4px">
        <span class="l" style="visibility: hidden">x</span>
        <span style="font-family: var(--font-mono); font-size: 11px; color: var(--fg-muted)">{{ moneyBig(sellValue) }}</span>
      </div>
      <div class="kpi-divider" />
      <div class="kpi-row">
        <span class="l">Buy / Sell ratio</span>
        <span class="v">{{ ratio }}</span>
      </div>
    </div>
  </div>
</template>
