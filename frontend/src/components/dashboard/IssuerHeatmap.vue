<script setup lang="ts">
export interface HeatmapItem {
  ticker: string
  name: string
  sector: string
  net: number
  count: number
}

const props = defineProps<{
  items: HeatmapItem[]
}>()

const emit = defineEmits<{ select: [ticker: string] }>()

function moneyBig(n: number): string {
  if (Math.abs(n) >= 1e9) return '$' + (n / 1e9).toFixed(2) + 'B'
  if (Math.abs(n) >= 1e6) return '$' + (n / 1e6).toFixed(2) + 'M'
  if (Math.abs(n) >= 1e3) return '$' + (n / 1e3).toFixed(1) + 'K'
  return '$' + n.toFixed(2)
}

function cellStyle(item: HeatmapItem, maxAbsNet: number) {
  const intensity = Math.min(1, Math.abs(item.net) / (maxAbsNet || 1))
  const isBuy = item.net >= 0
  const bg = isBuy
    ? `oklch(${65 - intensity * 12}% ${0.05 + intensity * 0.13} 148)`
    : `oklch(${65 - intensity * 12}% ${0.05 + intensity * 0.16} 28)`
  const fg = intensity > 0.4 ? '#fff' : 'var(--fg)'
  return { background: bg, color: fg }
}

function sectorColor(item: HeatmapItem, maxAbsNet: number) {
  const intensity = Math.min(1, Math.abs(item.net) / (maxAbsNet || 1))
  return intensity > 0.4 ? 'rgba(255,255,255,0.7)' : 'var(--fg-muted)'
}

function getRows(items: HeatmapItem[]) {
  return [items.slice(0, 6), items.slice(6, 12)]
}

function rowTemplate(row: HeatmapItem[]) {
  const rowSum = row.reduce((a, b) => a + b.count, 0) || 1
  return row.map((i) => `${i.count / rowSum}fr`).join(' ')
}

function maxAbsNet(items: HeatmapItem[]) {
  return Math.max(...items.map((i) => Math.abs(i.net))) || 1
}
</script>

<template>
  <div class="panel">
    <div class="panel-header">
      Issuer Activity — by Filing Volume
      <span class="spacer" />
      <span style="font-family: var(--font-mono); font-size: 10px; color: var(--fg-faint); text-transform: none; letter-spacing: 0">
        <span style="display: inline-block; width: 8px; height: 8px; background: var(--buy); border-radius: 1px; vertical-align: middle; margin-right: 4px" />net buying
        <span style="display: inline-block; width: 8px; height: 8px; background: var(--sell); border-radius: 1px; vertical-align: middle; margin: 0 4px 0 8px" />net selling
      </span>
    </div>
    <div class="panel-body tight">
      <div v-if="!items.length" class="empty-state">No data.</div>
      <div v-else class="heatmap-grid">
        <div
          v-for="(row, ri) in getRows(items)"
          :key="ri"
          class="heatmap-row"
          :style="{ gridTemplateColumns: rowTemplate(row) }"
        >
          <div
            v-for="item in row"
            :key="item.ticker"
            class="heat-cell"
            :style="cellStyle(item, maxAbsNet(items))"
            :title="`${item.ticker} · ${item.count} filings · ${item.net >= 0 ? '+' : ''}${moneyBig(item.net)}`"
            @click="emit('select', item.ticker)"
          >
            <span class="ht-sector" :style="{ color: sectorColor(item, maxAbsNet(items)) }">{{ item.sector }}</span>
            <span class="ht-ticker">{{ item.ticker }}</span>
            <span class="ht-meta">
              <span>{{ item.count }} flg</span>
              <span>{{ item.net >= 0 ? '+' : '−' }}{{ moneyBig(Math.abs(item.net)) }}</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
