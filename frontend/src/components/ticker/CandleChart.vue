<script setup lang="ts">
import { ref, watch, onBeforeUnmount, onMounted } from 'vue'
import { createChart, LineStyle } from 'lightweight-charts'
import type { IChartApi, ISeriesApi, SeriesMarker, Time } from 'lightweight-charts'
import type { OHLCVBar, TradeEvent } from '@/services/api'

const props = defineProps<{
  ohlcv: OHLCVBar[]
  tradeEvents: TradeEvent[]
  period: string
}>()

const emit = defineEmits<{
  'update:period': [value: string]
}>()

const containerEl = ref<HTMLElement | null>(null)
let chart: IChartApi | null = null
let series: ISeriesApi<'Candlestick'> | null = null

const showBuys = ref(true)
const showSells = ref(true)
const hover = ref<{ time: string; open: number; high: number; low: number; close: number } | null>(null)

const periods = ['1m', '3m', '6m', '1y', '2y']

function buildChart() {
  if (!containerEl.value) return
  chart = createChart(containerEl.value, {
    autoSize: true,
    layout: {
      background: { type: 'solid' as any, color: 'transparent' },
      textColor: '#61656f',
      fontFamily: '"IBM Plex Mono", ui-monospace, monospace',
      fontSize: 11,
    },
    grid: {
      vertLines: { color: '#eeeeea' },
      horzLines: { color: '#eeeeea' },
    },
    rightPriceScale: { borderColor: '#e4e4e0' },
    timeScale: { borderColor: '#e4e4e0', timeVisible: false },
    crosshair: {
      mode: 1,
      vertLine: { color: '#9a9ea8', width: 1, style: LineStyle.Dashed, labelBackgroundColor: '#161726' },
      horzLine: { color: '#9a9ea8', width: 1, style: LineStyle.Dashed, labelBackgroundColor: '#161726' },
    },
  })

  series = chart.addCandlestickSeries({
    upColor: '#16a34a', downColor: '#dc2626',
    borderUpColor: '#16a34a', borderDownColor: '#dc2626',
    wickUpColor: '#16a34a', wickDownColor: '#dc2626',
  })

  chart.subscribeCrosshairMove((param) => {
    if (!param.time || !param.seriesData || !series) { hover.value = null; return }
    const data = param.seriesData.get(series) as any
    if (!data) { hover.value = null; return }
    hover.value = { time: param.time as string, open: data.open, high: data.high, low: data.low, close: data.close }
  })

  pushData()
}

function pushData() {
  if (!series) return

  series.setData(props.ohlcv.map((c) => ({
    time: c.time as Time,
    open: c.open, high: c.high, low: c.low, close: c.close,
  })))

  const dataDates = new Set(props.ohlcv.map((c) => c.time))
  const buckets: Record<string, { buy: number; sell: number }> = {}
  props.tradeEvents.forEach((e) => {
    if (!buckets[e.date]) buckets[e.date] = { buy: 0, sell: 0 }
    if (e.type === 'buy') buckets[e.date]!.buy++
    else buckets[e.date]!.sell++
  })

  const markers: SeriesMarker<Time>[] = []
  Object.entries(buckets).forEach(([date, b]) => {
    if (!dataDates.has(date)) return
    if (showBuys.value && b.buy > 0)
      markers.push({ time: date as Time, position: 'belowBar', color: '#16a34a', shape: 'arrowUp', text: 'B' + (b.buy > 1 ? '·' + b.buy : '') })
    if (showSells.value && b.sell > 0)
      markers.push({ time: date as Time, position: 'aboveBar', color: '#dc2626', shape: 'arrowDown', text: 'S' + (b.sell > 1 ? '·' + b.sell : '') })
  })
  markers.sort((a, b) => String(a.time).localeCompare(String(b.time)))
  series.setMarkers(markers)

  chart?.timeScale().fitContent()
}

onMounted(buildChart)

watch(() => props.ohlcv, pushData)
watch([showBuys, showSells], pushData)

onBeforeUnmount(() => { chart?.remove(); chart = null; series = null })
</script>

<template>
  <div class="chart-section">
    <div class="chart-toolbar">
      <div class="group">
        <button
          v-for="p in periods"
          :key="p"
          :class="{ active: period === p }"
          @click="emit('update:period', p)"
        >{{ p.toUpperCase() }}</button>
      </div>
      <label class="toggle" @click="showBuys = !showBuys">
        <span :style="{ color: showBuys ? 'var(--buy)' : 'var(--fg-faint)', fontFamily: 'var(--font-mono)' }">{{ showBuys ? '▲' : '△' }}</span>
        <span :style="{ color: showBuys ? 'var(--fg)' : 'var(--fg-faint)' }">Buys</span>
      </label>
      <label class="toggle" @click="showSells = !showSells">
        <span :style="{ color: showSells ? 'var(--sell)' : 'var(--fg-faint)', fontFamily: 'var(--font-mono)' }">{{ showSells ? '▼' : '▽' }}</span>
        <span :style="{ color: showSells ? 'var(--fg)' : 'var(--fg-faint)' }">Sells</span>
      </label>
      <span class="spacer" />
      <div v-if="hover" class="hover-info">
        <span><span class="label">D</span> <b>{{ hover.time }}</b></span>
        <span><span class="label">O</span> <b>{{ hover.open?.toFixed(2) }}</b></span>
        <span><span class="label">H</span> <b>{{ hover.high?.toFixed(2) }}</b></span>
        <span><span class="label">L</span> <b>{{ hover.low?.toFixed(2) }}</b></span>
        <span><span class="label">C</span> <b :class="hover.close >= hover.open ? 'pos' : 'neg'">{{ hover.close?.toFixed(2) }}</b></span>
      </div>
    </div>
    <div ref="containerEl" class="chart-container" />
  </div>
</template>
