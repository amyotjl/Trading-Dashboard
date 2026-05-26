<script setup lang="ts">
import { ref, computed } from 'vue'
import type { SentimentRow } from '@/services/api'

const props = defineProps<{ rows: SentimentRow[] }>()

function moneyBig(n: number): string {
  if (Math.abs(n) >= 1e9) return '$' + (n / 1e9).toFixed(2) + 'B'
  if (Math.abs(n) >= 1e6) return '$' + (n / 1e6).toFixed(2) + 'M'
  if (Math.abs(n) >= 1e3) return '$' + (n / 1e3).toFixed(1) + 'K'
  return '$' + n.toFixed(2)
}

// totals
const totals = computed(() => {
  let buys = 0, sells = 0, buyValue = 0, sellValue = 0
  props.rows.forEach((d) => { buys += d.buys; sells += d.sells; buyValue += d.buy_value; sellValue += d.sell_value })
  const ratio = sells === 0 ? Infinity : buys / sells
  return { buys, sells, ratio, net: buyValue - sellValue }
})

// SVG geometry
const W = 880, H = 200, padL = 40, padR = 12, padT = 12, padB = 22
const innerW = W - padL - padR
const innerH = H - padT - padB
const splitY = padT + innerH * 0.55

const cumPoints = computed(() => {
  let cum = 0
  return props.rows.map((d) => { cum += d.buy_value - d.sell_value; return { date: d.date, cum } })
})

const dates = computed(() => props.rows.map((d) => d.date))
const minT = computed(() => dates.value.length ? new Date(dates.value[0]!).getTime() : 0)
const maxT = computed(() => dates.value.length ? new Date(dates.value[dates.value.length - 1]!).getTime() : 1)

function xFor(d: string) {
  return padL + ((new Date(d).getTime() - minT.value) / ((maxT.value - minT.value) || 1)) * innerW
}

const cumMax = computed(() => Math.max(...cumPoints.value.map((p) => p.cum), 0))
const cumMin = computed(() => Math.min(...cumPoints.value.map((p) => p.cum), 0))
const cumRange = computed(() => (cumMax.value - cumMin.value) || 1)

function yForCum(v: number) {
  return padT + (1 - (v - cumMin.value) / cumRange.value) * (splitY - padT - 6)
}

const linePath = computed(() =>
  cumPoints.value.map((p, i) => `${i === 0 ? 'M' : 'L'} ${xFor(p.date).toFixed(1)} ${yForCum(p.cum).toFixed(1)}`).join(' ')
)
const areaPath = computed(() => {
  const pts = cumPoints.value
  if (!pts.length) return ''
  const last = pts[pts.length - 1]!
  return linePath.value + ` L ${xFor(last.date).toFixed(1)} ${splitY.toFixed(1)} L ${xFor(pts[0]!.date).toFixed(1)} ${splitY.toFixed(1)} Z`
})

const maxDaily = computed(() => Math.max(...props.rows.map((d) => Math.max(d.buys, d.sells)), 1))
const barH = (n: number) => (n / maxDaily.value) * (H - padB - splitY - 4)
const barW = computed(() => Math.max(1, Math.min(8, innerW / (props.rows.length || 1) - 1)))

const monthTicks = computed(() => {
  const seen = new Set<string>()
  return dates.value.filter((d) => { const m = d.slice(0, 7); if (seen.has(m)) return false; seen.add(m); return true })
})

// hover
const hover = ref<(SentimentRow & { cum: number }) | null>(null)
const svgEl = ref<SVGSVGElement | null>(null)

function handleMove(e: MouseEvent) {
  if (!svgEl.value || !props.rows.length) return
  const rect = svgEl.value.getBoundingClientRect()
  const px = ((e.clientX - rect.left) / rect.width) * W
  if (px < padL || px > W - padR) { hover.value = null; return }
  const t = minT.value + ((px - padL) / innerW) * (maxT.value - minT.value)
  let best: SentimentRow | null = null, bestDist = Infinity
  props.rows.forEach((s) => {
    const dist = Math.abs(new Date(s.date).getTime() - t)
    if (dist < bestDist) { bestDist = dist; best = s }
  })
  if (best) {
    const b = best as SentimentRow
    const c = cumPoints.value.find((p) => p.date === b.date)
    hover.value = { ...b, cum: c?.cum ?? 0 }
  }
}
</script>

<template>
  <div class="market-panel">
    <div class="panel-head">
      Aggregate Insider Sentiment — TSX
      <span class="spacer" />
      <span style="font-family: var(--font-mono); font-size: 10px; text-transform: none; letter-spacing: 0; color: var(--fg-muted)">
        <span style="display: inline-block; width: 10px; height: 2px; background: var(--buy); vertical-align: middle; margin-right: 5px" />cum. net value
        <span style="display: inline-block; width: 8px; height: 8px; background: var(--buy); vertical-align: middle; margin: 0 5px 0 12px" />buys
        <span style="display: inline-block; width: 8px; height: 8px; background: var(--sell); vertical-align: middle; margin: 0 5px 0 8px" />sells
      </span>
    </div>
    <div class="sentiment-stats">
      <div class="item">
        <div class="l">Acquisitions</div>
        <div class="v pos">{{ totals.buys.toLocaleString() }}</div>
        <div class="sub">{{ totals.ratio === Infinity ? '—' : 'vs ' + totals.sells + ' disp.' }}</div>
      </div>
      <div class="item">
        <div class="l">Buy / Sell ratio</div>
        <div class="v">{{ totals.ratio === Infinity ? '∞' : totals.ratio.toFixed(2) }}</div>
        <div class="sub">{{ totals.ratio >= 1 ? 'Net bullish' : 'Net bearish' }}</div>
      </div>
      <div class="item">
        <div class="l">Net insider $</div>
        <div class="v" :class="totals.net >= 0 ? 'pos' : 'neg'">
          {{ totals.net >= 0 ? '+' : '−' }}{{ moneyBig(Math.abs(totals.net)) }}
        </div>
      </div>
    </div>
    <div class="sentiment-chart" style="position: relative">
      <svg
        ref="svgEl"
        :viewBox="`0 0 ${W} ${H}`"
        preserveAspectRatio="none"
        style="width: 100%; height: 100%; display: block"
        @mousemove="handleMove"
        @mouseleave="hover = null"
      >
        <!-- zero line for cumulative -->
        <line v-if="cumMin < 0 && cumMax > 0" :x1="padL" :x2="W - padR" :y1="yForCum(0)" :y2="yForCum(0)" stroke="var(--border)" stroke-dasharray="3,3" />

        <!-- x grid (month ticks) -->
        <line v-for="d in monthTicks" :key="d" :x1="xFor(d)" :x2="xFor(d)" :y1="padT" :y2="H - padB" stroke="var(--border)" opacity="0.4" />

        <!-- cumulative area + line -->
        <path :d="areaPath" fill="var(--buy)" opacity="0.10" />
        <path :d="linePath" fill="none" stroke="var(--buy)" stroke-width="1.5" />

        <!-- daily bars -->
        <g v-for="d in rows" :key="d.date">
          <rect v-if="d.buys > 0" :x="xFor(d.date) - barW / 2" :y="splitY - 1" :width="barW" :height="Math.max(1, barH(d.buys))" fill="var(--buy)" opacity="0.85" />
          <rect v-if="d.sells > 0" :x="xFor(d.date) + barW / 2 + 0.5" :y="splitY - 1" :width="barW" :height="Math.max(1, barH(d.sells))" fill="var(--sell)" opacity="0.85" />
        </g>

        <!-- split line -->
        <line :x1="padL" :x2="W - padR" :y1="splitY" :y2="splitY" stroke="var(--border-strong)" />

        <!-- y axis labels -->
        <text :x="padL - 6" :y="padT + 8" text-anchor="end" font-size="9" fill="var(--fg-faint)" font-family="var(--font-mono)">{{ moneyBig(cumMax) }}</text>
        <text :x="padL - 6" :y="splitY - 4" text-anchor="end" font-size="9" fill="var(--fg-faint)" font-family="var(--font-mono)">{{ cumMin < 0 ? moneyBig(cumMin) : '$0' }}</text>
        <text :x="padL - 6" :y="splitY + 12" text-anchor="end" font-size="9" fill="var(--fg-faint)" font-family="var(--font-mono)">0</text>
        <text :x="padL - 6" :y="H - padB - 2" text-anchor="end" font-size="9" fill="var(--fg-faint)" font-family="var(--font-mono)">{{ maxDaily }}</text>

        <!-- x axis labels -->
        <text v-for="d in monthTicks" :key="d" :x="xFor(d)" :y="H - 6" font-size="9.5" fill="var(--fg-muted)" font-family="var(--font-mono)" text-anchor="middle">
          {{ new Date(d + 'T12:00:00').toLocaleDateString('en-CA', { month: 'short' }) }}
        </text>

        <!-- hover cursor -->
        <line v-if="hover" :x1="xFor(hover.date)" :x2="xFor(hover.date)" :y1="padT" :y2="H - padB" stroke="var(--fg-muted)" stroke-dasharray="2,3" />
      </svg>

      <div
        v-if="hover"
        class="chart-tooltip"
        :style="{ left: `min(${(xFor(hover.date) / W) * 100}%, calc(100% - 200px))`, top: '12px', transform: 'translateX(8px)' }"
      >
        <div><span class="label">date </span>{{ hover.date }}</div>
        <div class="sep" />
        <div><span class="label">buys </span><span class="buy">{{ hover.buys }}</span> <span class="label">· </span>{{ moneyBig(hover.buy_value) }}</div>
        <div><span class="label">sells</span> <span class="sell">{{ hover.sells }}</span> <span class="label">· </span>{{ moneyBig(hover.sell_value) }}</div>
        <div class="sep" />
        <div><span class="label">cum. net </span><b :style="{ color: hover.cum >= 0 ? 'oklch(75% 0.16 148)' : 'oklch(72% 0.18 28)' }">{{ hover.cum >= 0 ? '+' : '−' }}{{ moneyBig(Math.abs(hover.cum)) }}</b></div>
      </div>
    </div>
  </div>
</template>
