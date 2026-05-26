<script setup lang="ts">
import type { MarketIndex } from '@/services/api'

const props = defineProps<{ idx: MarketIndex }>()

const W = 70, H = 32

function sparkPoints(spark: number[]) {
  if (spark.length < 2) return ''
  const min = Math.min(...spark), max = Math.max(...spark)
  return spark.map((v, i) => {
    const x = (i / (spark.length - 1)) * W
    const y = H - ((v - min) / (max - min || 1)) * H
    return `${x.toFixed(1)},${y.toFixed(1)}`
  }).join(' ')
}

function fmtVal(v: number) {
  if (props.idx.symbol === 'USDCAD=X') return v.toFixed(4)
  if (props.idx.symbol === 'CL=F' || props.idx.symbol === 'GC=F') return v.toFixed(2)
  return new Intl.NumberFormat('en-CA', { maximumFractionDigits: 2 }).format(v)
}

const positive = props.idx.change_pct >= 0
const delta = props.idx.last - props.idx.prev
</script>

<template>
  <div class="idx-tile">
    <div class="symbol">{{ idx.symbol }}</div>
    <div class="name">{{ idx.name }}</div>
    <div class="last">{{ fmtVal(idx.last) }}</div>
    <div class="chg" :class="positive ? 'pos' : 'neg'">
      <span>{{ positive ? '▲' : '▼' }}</span>
      <span>{{ positive ? '+' : '' }}{{ fmtVal(Math.abs(delta)) }}</span>
      <span>({{ positive ? '+' : '' }}{{ idx.change_pct.toFixed(2) }}%)</span>
    </div>
    <svg class="spark" :viewBox="`0 0 ${W} ${H}`" preserveAspectRatio="none">
      <polyline
        :points="sparkPoints(idx.spark)"
        fill="none"
        :stroke="positive ? 'var(--buy)' : 'var(--sell)'"
        stroke-width="1.5"
        stroke-linejoin="round"
        stroke-linecap="round"
      />
    </svg>
  </div>
</template>
