<script setup lang="ts">
export interface LeaderboardEntry {
  name: string
  buys: number
  sells: number
  total: number
  tickerCount: number
}

const props = defineProps<{ items: LeaderboardEntry[] }>()
const emit = defineEmits<{ select: [lastName: string] }>()
</script>

<template>
  <div class="panel">
    <div class="panel-header">
      Most Active Insiders
      <span class="spacer" />
      <span class="count">Top 8</span>
    </div>
    <div class="panel-body tight">
      <div class="leaderboard">
        <div
          v-for="(lb, i) in items"
          :key="lb.name"
          class="lb-row"
          @click="emit('select', lb.name.split(',')[0] ?? lb.name)"
        >
          <span class="lb-rank">{{ String(i + 1).padStart(2, '0') }}</span>
          <span class="lb-name">
            {{ lb.name }}
            <span class="sub">{{ lb.tickerCount }} {{ lb.tickerCount === 1 ? 'ticker' : 'tickers' }}</span>
          </span>
          <span class="lb-bar">
            <span class="seg-buy" :style="{ width: ((lb.buys / (items[0]?.total || 1)) * 100) + '%' }" />
            <span
              class="seg-sell"
              :style="{
                width: ((lb.sells / (items[0]?.total || 1)) * 100) + '%',
                left: ((lb.buys / (items[0]?.total || 1)) * 100) + '%',
                right: 'auto',
                position: 'absolute',
              }"
            />
          </span>
          <span class="lb-count">{{ lb.total }}</span>
        </div>
      </div>
    </div>
  </div>
</template>
