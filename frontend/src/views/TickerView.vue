<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { issuersApi, type Issuer, type TransactionRow, type OHLCVBar, type TradeEvent } from '@/services/api'
import CandleChart from '@/components/ticker/CandleChart.vue'

const route = useRoute()
const router = useRouter()

const symbol = computed(() => route.params.symbol as string)
const issuer = ref<Issuer | null>(null)
const allTxns = ref<TransactionRow[]>([])
const ohlcvAll = ref<OHLCVBar[]>([])
const tradeEvents = ref<TradeEvent[]>([])
const issuerLoading = ref(false)
const notFound = ref(false)
const totalRecords = ref(0)

const period = ref('2y')
const sortKey = ref('filing_date')
const sortDir = ref<'asc' | 'desc'>('desc')
const page = ref(1)
const perPage = ref(25)

// period filter
const ohlcv = computed(() => {
  if (!ohlcvAll.value.length) return []
  const last = new Date(ohlcvAll.value[ohlcvAll.value.length - 1]!.time)
  const ms: Record<string, number> = { '1m': 30, '3m': 90, '6m': 180, '1y': 365, '2y': 730 }
  const cutoff = new Date(last.getTime() - (ms[period.value] ?? 730) * 86400000)
  return ohlcvAll.value.filter((c) => new Date(c.time) >= cutoff)
})

// stats
const stats = computed(() => {
  const rows = allTxns.value
  const buys = rows.filter((r) => (r.number_of_securities ?? 0) > 0)
  const sells = rows.filter((r) => (r.number_of_securities ?? 0) < 0)
  const sum = (rs: TransactionRow[]) =>
    rs.reduce((acc, r) => acc + Math.abs(r.number_of_securities ?? 0) * parseFloat(r.unit_price ?? '0'), 0)
  const lastPrice = ohlcvAll.value.length ? ohlcvAll.value[ohlcvAll.value.length - 1]!.close : null
  const prevPrice = ohlcvAll.value.length > 1 ? ohlcvAll.value[ohlcvAll.value.length - 2]!.close : lastPrice
  const dayChange = lastPrice != null && prevPrice != null ? ((lastPrice - prevPrice) / prevPrice) * 100 : null
  return {
    lastPrice, dayChange,
    totalFilings: rows.length,
    buys: buys.length, sells: sells.length,
    buyValue: sum(buys), sellValue: sum(sells),
    netValue: sum(buys) - sum(sells),
    insiders: new Set(rows.map((r) => r.insider_name)).size,
  }
})

// table pagination (client-side from allTxns)
const sortedTxns = computed(() => {
  const out = [...allTxns.value]
  const key = sortKey.value, dir = sortDir.value
  out.sort((a, b) => {
    let av: number | string, bv: number | string
    if (key === 'number_of_securities') { av = a.number_of_securities ?? 0; bv = b.number_of_securities ?? 0 }
    else if (key === 'unit_price') { av = parseFloat(a.unit_price ?? '0'); bv = parseFloat(b.unit_price ?? '0') }
    else if (key === 'balance') { av = a.balance ?? 0; bv = b.balance ?? 0 }
    else if (key === 'filing_date') { av = a.filing_date; bv = b.filing_date }
    else if (key === 'transaction_date') { av = a.transaction_date; bv = b.transaction_date }
    else if (key === 'insider_name') { av = a.insider_name; bv = b.insider_name }
    else { av = a.filing_date; bv = b.filing_date }
    if (av < bv) return dir === 'asc' ? -1 : 1
    if (av > bv) return dir === 'asc' ? 1 : -1
    return 0
  })
  return out
})

const pagedTxns = computed(() => sortedTxns.value.slice((page.value - 1) * perPage.value, page.value * perPage.value))
const totalPages = computed(() => Math.max(1, Math.ceil(sortedTxns.value.length / perPage.value)))

function handleSort(key: string) {
  if (sortKey.value === key) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = key; sortDir.value = 'desc' }
  page.value = 1
}
function sortInd(key: string) {
  return sortKey.value === key ? (sortDir.value === 'asc' ? '▲' : '▼') : ''
}

// loaders
async function loadAll() {
  issuerLoading.value = true
  notFound.value = false
  try {
    const [issuerRes, txnRes, ohlcvRes, eventsRes] = await Promise.allSettled([
      issuersApi.get(symbol.value),
      issuersApi.transactions(symbol.value, { page: 1, per_page: 1000, sort: 'filing_date', direction: 'desc' }),
      issuersApi.ohlcv(symbol.value),
      issuersApi.tradeEvents(symbol.value),
    ])
    if (issuerRes.status === 'fulfilled') issuer.value = issuerRes.value.data
    else if ((issuerRes.reason as any)?.response?.status === 404) notFound.value = true
    if (txnRes.status === 'fulfilled') {
      allTxns.value = txnRes.value.data.data
      totalRecords.value = txnRes.value.data.meta.total
    }
    if (ohlcvRes.status === 'fulfilled') ohlcvAll.value = ohlcvRes.value.data.data
    if (eventsRes.status === 'fulfilled') tradeEvents.value = eventsRes.value.data
  } finally {
    issuerLoading.value = false
  }
}

watch(() => symbol.value, () => { page.value = 1; loadAll() })
onMounted(loadAll)

// formatters
function moneyBig(n: number): string {
  if (Math.abs(n) >= 1e9) return '$' + (n / 1e9).toFixed(2) + 'B'
  if (Math.abs(n) >= 1e6) return '$' + (n / 1e6).toFixed(2) + 'M'
  if (Math.abs(n) >= 1e3) return '$' + (n / 1e3).toFixed(1) + 'K'
  return '$' + n.toFixed(2)
}
function fmtMoney(n: string | number | null | undefined) {
  if (n == null || n === '') return '—'
  return '$' + parseFloat(String(n)).toFixed(2)
}
function fmtSigned(n: number | null | undefined) {
  if (n == null) return '—'
  return (n > 0 ? '+' : n < 0 ? '−' : '') + Math.abs(n).toLocaleString('en-CA')
}
function relFirst(rels: string[] | undefined) {
  if (!rels?.length) return { first: '—', extra: 0 }
  return { first: rels[0]!.replace(/^\d+\s*[-–]\s*/, ''), extra: rels.length - 1 }
}
function txnTypeDisplay(raw: string | Record<string, string> | null | undefined) {
  if (!raw) return { code: '', desc: '—' }
  if (typeof raw === 'object') return { code: raw.code ?? '', desc: raw.description ?? '' }
  const m = String(raw).match(/^(\d+)\s*[-–]\s*(.+)$/)
  if (m) return { code: m[1], desc: m[2] }
  return { code: '', desc: String(raw) }
}
</script>

<template>
  <div class="view ticker-view">
    <!-- Loading -->
    <div v-if="issuerLoading" class="empty-state">Loading…</div>

    <!-- Not found -->
    <div v-else-if="notFound" class="empty-state">
      Ticker "{{ symbol }}" not found.
      <a @click="router.push('/')" style="cursor: pointer; margin-left: 6px">← Back</a>
    </div>

    <template v-else>
      <!-- Header -->
      <div class="ticker-header">
        <div class="ticker-badge">{{ symbol }}</div>
        <div class="ticker-title-wrap">
          <div class="back-link" @click="router.push('/')">← Back to transactions</div>
          <h1 class="ticker-title">{{ issuer?.name ?? symbol }}</h1>
          <div class="ticker-meta-row">
            <span v-if="issuer?.sector" class="sector-chip">{{ issuer.sector }}</span>
            <a
              v-if="issuer?.home_page"
              :href="issuer.home_page.startsWith('http') ? issuer.home_page : 'https://' + issuer.home_page"
              target="_blank"
              rel="noopener noreferrer"
              style="display: inline-flex; align-items: center; gap: 4px"
            >
              {{ issuer.home_page }}
              <svg width="11" height="11" viewBox="0 0 11 11" fill="none"><path d="M4 2H2v7h7V7M6 2h3v3M9 2L5 6" stroke="currentColor" stroke-width="1.2" stroke-linecap="round" stroke-linejoin="round"/></svg>
            </a>
            <span style="color: var(--fg-faint)">·</span>
            <span style="font-family: var(--font-mono); font-size: 11.5px">SEDI · TSX</span>
          </div>
          <p v-if="issuer?.description" class="ticker-description">{{ issuer.description }}</p>
        </div>
        <div class="stat-grid">
          <div class="stat">
            <div class="stat-label">Last</div>
            <div class="stat-value">{{ fmtMoney(stats.lastPrice) }}</div>
            <div v-if="stats.dayChange != null" class="stat-sub" :style="{ color: stats.dayChange >= 0 ? 'var(--buy)' : 'var(--sell)' }">
              {{ stats.dayChange >= 0 ? '+' : '' }}{{ stats.dayChange.toFixed(2) }}%
            </div>
          </div>
          <div class="stat">
            <div class="stat-label">Filings</div>
            <div class="stat-value">{{ stats.totalFilings }}</div>
            <div class="stat-sub">{{ stats.insiders }} insiders</div>
          </div>
          <div class="stat">
            <div class="stat-label">Buys / Sells</div>
            <div class="stat-value">
              <span style="color: var(--buy)">{{ stats.buys }}</span>
              <span style="color: var(--fg-faint)"> / </span>
              <span style="color: var(--sell)">{{ stats.sells }}</span>
            </div>
            <div class="stat-sub">{{ moneyBig(stats.buyValue) }} / {{ moneyBig(stats.sellValue) }}</div>
          </div>
          <div class="stat">
            <div class="stat-label">Net Insider</div>
            <div class="stat-value" :class="stats.netValue >= 0 ? 'buy' : 'sell'">
              {{ stats.netValue >= 0 ? '+' : '−' }}{{ moneyBig(Math.abs(stats.netValue)) }}
            </div>
            <div class="stat-sub">all time</div>
          </div>
        </div>
      </div>

      <!-- Chart -->
      <CandleChart
        :key="symbol"
        :ohlcv="ohlcv"
        :trade-events="tradeEvents"
        :period="period"
        @update:period="period = $event"
      />

      <!-- Filings table -->
      <div class="table-wrap" style="margin: 20px 24px; max-height: 520px">
        <div class="table-toolbar">
          <span>All filings for <b style="color: var(--fg)">{{ symbol }}</b> · <b style="color: var(--fg)">{{ stats.totalFilings }}</b> records</span>
          <span class="spacer" />
          <span>Sort: <b style="color: var(--fg)">{{ sortKey.replace(/_/g, ' ') }}</b> {{ sortDir === 'asc' ? '↑' : '↓' }}</span>
        </div>
        <div class="table-scroll">
          <table class="data">
            <thead>
              <tr>
                <th style="width: 92px" @click="handleSort('filing_date')">Filed <span class="sort-ind">{{ sortInd('filing_date') }}</span></th>
                <th style="width: 92px" @click="handleSort('transaction_date')">Txn Date <span class="sort-ind">{{ sortInd('transaction_date') }}</span></th>
                <th @click="handleSort('insider_name')">Insider <span class="sort-ind">{{ sortInd('insider_name') }}</span></th>
                <th>Relationship</th>
                <th>Security</th>
                <th>Txn Type</th>
                <th class="num" @click="handleSort('number_of_securities')">Shares <span class="sort-ind">{{ sortInd('number_of_securities') }}</span></th>
                <th class="num" @click="handleSort('unit_price')">Price <span class="sort-ind">{{ sortInd('unit_price') }}</span></th>
                <th class="num" @click="handleSort('balance')">Balance <span class="sort-ind">{{ sortInd('balance') }}</span></th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!pagedTxns.length">
                <td colspan="9" class="empty-state">No transactions.</td>
              </tr>
              <tr v-for="row in pagedTxns" :key="row.id">
                <td class="mono">{{ row.filing_date }}</td>
                <td class="mono">{{ row.transaction_date }}</td>
                <td>{{ row.insider_name }}</td>
                <td>
                  <span class="rel-cell">
                    {{ relFirst(row.relationships).first }}
                    <span v-if="relFirst(row.relationships).extra > 0" class="more">+{{ relFirst(row.relationships).extra }}</span>
                  </span>
                </td>
                <td style="color: var(--fg-muted)">{{ row.security_designation }}</td>
                <td>
                  <div class="txn-type-cell">
                    <span class="code">{{ txnTypeDisplay(row.nature_of_transaction as string).code }}</span>
                    <span class="desc">{{ txnTypeDisplay(row.nature_of_transaction as string).desc }}</span>
                  </div>
                </td>
                <td class="num">
                  <span class="shares-cell" :class="(row.number_of_securities ?? 0) > 0 ? 'shares-pos' : 'shares-neg'">
                    <span class="ind">{{ (row.number_of_securities ?? 0) > 0 ? '▲' : '▼' }}</span>
                    {{ fmtSigned(row.number_of_securities) }}
                  </span>
                </td>
                <td class="num">{{ fmtMoney(row.unit_price) }}</td>
                <td class="num">{{ row.balance?.toLocaleString('en-CA') ?? '—' }}</td>
              </tr>
            </tbody>
          </table>
        </div>
        <div class="pagination">
          <span>
            <b style="color: var(--fg)">{{ Math.min((page - 1) * perPage + 1, sortedTxns.length) }}</b>–<b style="color: var(--fg)">{{ Math.min(page * perPage, sortedTxns.length) }}</b>
            of <b style="color: var(--fg)">{{ sortedTxns.length }}</b>
          </span>
          <span class="spacer" />
          <button class="page-btn" :disabled="page === 1" @click="page = 1">«</button>
          <button class="page-btn" :disabled="page === 1" @click="page--">‹</button>
          <button class="page-btn" :disabled="page === totalPages" @click="page++">›</button>
          <button class="page-btn" :disabled="page === totalPages" @click="page = totalPages">»</button>
          <span style="margin-left: 8px">
            <select class="page-size" :value="perPage" @change="perPage = Number(($event.target as HTMLSelectElement).value); page = 1">
              <option :value="25">25</option>
              <option :value="50">50</option>
              <option :value="100">100</option>
            </select>
            <span style="margin-left: 4px">per page</span>
          </span>
        </div>
      </div>
    </template>
  </div>
</template>
