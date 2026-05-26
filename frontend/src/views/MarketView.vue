<script setup lang="ts">
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useMarketStore } from '@/stores/market'
import { transactionsApi } from '@/services/api'
import IndexTile from '@/components/market/IndexTile.vue'
import SectorMap from '@/components/market/SectorMap.vue'
import MoversPanel from '@/components/market/MoversPanel.vue'
import SentimentChart from '@/components/market/SentimentChart.vue'

const router = useRouter()
const store = useMarketStore()

const moverTab = ref<'gainers' | 'losers' | 'active'>('gainers')
const sectorMetric = ref<'day' | 'week' | 'month' | 'ytd'>('day')

// build SEDI ticker set for mover cross-reference
const sediTickers = ref<Set<string>>(new Set())

async function loadSediTickers() {
  try {
    const { data } = await transactionsApi.list({ page: 1, per_page: 1000 })
    sediTickers.value = new Set(data.data.map((r) => r.ticker).filter(Boolean) as string[])
  } catch {
    // non-critical
  }
}

function openTicker(ticker: string) {
  router.push({ name: 'ticker', params: { symbol: ticker } })
}

onMounted(() => {
  store.fetchAll()
  loadSediTickers()
})
</script>

<template>
  <div class="view market-view">
    <!-- View header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Canadian Market Overview</h1>
        <div class="view-subtitle">TSX · indices, sectors, movers · cross-referenced with insider activity</div>
      </div>
      <div v-if="store.asOf" class="market-asof">
        <span class="pulse" />
        As of {{ store.asOf }}
      </div>
    </div>

    <div style="padding: 0 0 16px">
      <!-- Loading / error states -->
      <div v-if="store.loading && !store.indices.length" class="empty-state">Loading market data…</div>
      <div v-else-if="store.error && !store.indices.length" class="empty-state" style="color: var(--sell)">
        Market data unavailable — enrichment service may be offline.
      </div>

      <template v-else>
        <!-- Index strip -->
        <div v-if="store.indices.length" class="idx-strip">
          <IndexTile v-for="idx in store.indices" :key="idx.symbol" :idx="idx" />
        </div>

        <div class="market-grid">
          <!-- Left: sector heatmap + insider sentiment -->
          <div style="display: flex; flex-direction: column; gap: 16px">
            <SectorMap
              v-if="store.sectors.length"
              :sectors="store.sectors"
              :metric="sectorMetric"
              @update:metric="sectorMetric = $event as typeof sectorMetric"
            />
            <div v-else class="market-panel">
              <div class="panel-head">TSX Sector Performance</div>
              <div class="empty-state">Sector data unavailable.</div>
            </div>

            <SentimentChart
              v-if="store.sentiment.length"
              :rows="store.sentiment"
            />
            <div v-else class="market-panel">
              <div class="panel-head">Aggregate Insider Sentiment — TSX</div>
              <div class="empty-state">No sentiment data yet — import transactions first.</div>
            </div>
          </div>

          <!-- Right: movers -->
          <MoversPanel
            :tab="moverTab"
            :gainers="store.gainers"
            :losers="store.losers"
            :most-active="store.mostActive"
            :sedi-tickers="sediTickers"
            @update:tab="moverTab = $event as typeof moverTab"
            @select="openTicker"
          />
        </div>
      </template>
    </div>
  </div>
</template>
