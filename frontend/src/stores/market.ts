import { defineStore } from 'pinia'
import { ref } from 'vue'
import { marketApi, transactionsApi, type MarketIndex, type MarketSector, type MarketMover, type SentimentRow } from '@/services/api'

export const useMarketStore = defineStore('market', () => {
  const indices = ref<MarketIndex[]>([])
  const sectors = ref<MarketSector[]>([])
  const gainers = ref<MarketMover[]>([])
  const losers = ref<MarketMover[]>([])
  const mostActive = ref<MarketMover[]>([])
  const sentiment = ref<SentimentRow[]>([])
  const asOf = ref<string | null>(null)
  const loading = ref(false)
  const error = ref<string | null>(null)

  async function fetchAll() {
    loading.value = true
    error.value = null
    try {
      const results = await Promise.allSettled([
        marketApi.indices(),
        marketApi.sectors(),
        marketApi.movers('gainers'),
        marketApi.movers('losers'),
        marketApi.movers('active'),
        transactionsApi.sentiment(),
      ])
      if (results[0].status === 'fulfilled') indices.value = results[0].value.data
      if (results[1].status === 'fulfilled') sectors.value = results[1].value.data
      if (results[2].status === 'fulfilled') gainers.value = results[2].value.data
      if (results[3].status === 'fulfilled') losers.value = results[3].value.data
      if (results[4].status === 'fulfilled') mostActive.value = results[4].value.data
      if (results[5].status === 'fulfilled') sentiment.value = results[5].value.data
      asOf.value = new Date().toLocaleTimeString('en-CA', { hour: '2-digit', minute: '2-digit', hour12: false })
    } catch (e) {
      error.value = String(e)
    } finally {
      loading.value = false
    }
  }

  return { indices, sectors, gainers, losers, mostActive, sentiment, asOf, loading, error, fetchAll }
})
