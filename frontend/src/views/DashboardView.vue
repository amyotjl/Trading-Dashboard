<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import DatePicker from 'primevue/datepicker'
import { transactionsApi, filtersApi, type TransactionRow, type TransactionFilters } from '@/services/api'
import FilingsSummaryPanel from '@/components/dashboard/FilingsSummaryPanel.vue'
import IssuerHeatmap, { type HeatmapItem } from '@/components/dashboard/IssuerHeatmap.vue'
import InsiderLeaderboard, { type LeaderboardEntry } from '@/components/dashboard/InsiderLeaderboard.vue'

const router = useRouter()

// ── table state ──────────────────────────────────────────────────────────────
const transactions = ref<TransactionRow[]>([])
const allFiltered = ref<TransactionRow[]>([])   // full filtered set for aggregations
const loading = ref(false)
const totalRecords = ref(0)

const filters = reactive<TransactionFilters>({
  page: 1, per_page: 50,
  date_from: '', date_to: '',
  ticker: '', insider_name: '',
  nature_of_transaction_id: undefined,
  sort: 'filing_date', direction: 'desc',
})

const dateFrom = ref<Date | null>(null)
const dateTo = ref<Date | null>(null)
const natureOptions = ref<{ id: number; code: string; description: string }[]>([])
const selectedNatureId = ref<number | null>(null)
const minInsiders = ref('')
const sortKey = ref('filing_date')
const sortDir = ref<'asc' | 'desc'>('desc')

// nature select dropdown
const natureOpen = ref(false)
const selectedNature = computed(() => natureOptions.value.find((n) => n.id === selectedNatureId.value) ?? null)

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

// ── data loading ──────────────────────────────────────────────────────────────
async function loadNatureOptions() {
  const { data } = await filtersApi.natureOfTransactions()
  natureOptions.value = data
}

function buildParams(extra?: Partial<TransactionFilters>): TransactionFilters {
  const p: TransactionFilters = {
    ...filters,
    sort: sortKey.value,
    direction: sortDir.value,
  }
  if (dateFrom.value) p.date_from = formatDate(dateFrom.value)
  if (dateTo.value) p.date_to = formatDate(dateTo.value)
  if (selectedNatureId.value) p.nature_of_transaction_id = selectedNatureId.value
  if (minInsiders.value && parseInt(minInsiders.value, 10) > 1)
    p.min_insiders = parseInt(minInsiders.value, 10)
  return { ...p, ...extra }
}

async function loadTransactions() {
  loading.value = true
  try {
    const [paged, all] = await Promise.all([
      transactionsApi.list(buildParams()),
      transactionsApi.list(buildParams({ page: 1, per_page: 1000 })),
    ])
    transactions.value = paged.data.data
    totalRecords.value = paged.data.meta.total
    allFiltered.value = all.data.data
  } finally {
    loading.value = false
  }
}

// ── aggregations ──────────────────────────────────────────────────────────────
const kpi = computed(() => {
  const rows = allFiltered.value
  const buys = rows.filter((r) => (r.number_of_securities ?? 0) > 0)
  const sells = rows.filter((r) => (r.number_of_securities ?? 0) < 0)
  const sumVal = (rs: TransactionRow[]) =>
    rs.reduce((acc, r) => acc + Math.abs(r.number_of_securities ?? 0) * parseFloat(r.unit_price ?? '0'), 0)
  return {
    total: rows.length,
    buys: buys.length, sells: sells.length,
    buyValue: sumVal(buys), sellValue: sumVal(sells),
    issuers: new Set(rows.map((r) => r.ticker)).size,
    insiders: new Set(rows.map((r) => r.insider_name)).size,
  }
})

// const heatmapItems = computed<HeatmapItem[]>(() => {
//   const byTicker: Record<string, HeatmapItem> = {}
//   allFiltered.value.forEach((r) => {
//     const t = r.ticker ?? '—'
//     if (!byTicker[t]) byTicker[t] = { ticker: t, name: r.issuer_name, sector: '', net: 0, count: 0 }
//     const cell = byTicker[t]!
//     cell.count++
//     cell.net += (r.number_of_securities ?? 0) * parseFloat(r.unit_price ?? '0')
//   })
//   return Object.values(byTicker).sort((a, b) => b.count - a.count).slice(0, 12)
// })

// const leaderboardItems = computed<LeaderboardEntry[]>(() => {
//   const map: Record<string, LeaderboardEntry & { tickers: Set<string> }> = {}
//   allFiltered.value.forEach((r) => {
//     if (!map[r.insider_name])
//       map[r.insider_name] = { name: r.insider_name, buys: 0, sells: 0, total: 0, tickerCount: 0, tickers: new Set() }
//     const entry = map[r.insider_name]!
//     if ((r.number_of_securities ?? 0) > 0) entry.buys++
//     else entry.sells++
//     entry.tickers.add(r.ticker ?? '')
//   })
//   return Object.values(map)
//     .map((m) => ({ ...m, total: m.buys + m.sells, tickerCount: m.tickers.size }))
//     .sort((a, b) => b.total - a.total)
//     .slice(0, 8)
// })

// ── active filter chips ───────────────────────────────────────────────────────
const activeFilters = computed(() => {
  const out: { key: string; label: string }[] = []
  if (filters.date_from) out.push({ key: 'date_from', label: '≥ ' + filters.date_from })
  if (filters.date_to) out.push({ key: 'date_to', label: '≤ ' + filters.date_to })
  if (filters.ticker) out.push({ key: 'ticker', label: 'Ticker: ' + filters.ticker })
  if (filters.insider_name) out.push({ key: 'insider_name', label: 'Insider: ' + filters.insider_name })
  if (selectedNature.value) out.push({ key: 'nature', label: selectedNature.value.code + ' – ' + selectedNature.value.description.slice(0, 28) })
  if (minInsiders.value) out.push({ key: 'min_insiders', label: '≥ ' + minInsiders.value + ' insiders' })
  return out
})

function clearChip(key: string) {
  if (key === 'date_from') { filters.date_from = ''; dateFrom.value = null }
  else if (key === 'date_to') { filters.date_to = ''; dateTo.value = null }
  else if (key === 'ticker') filters.ticker = ''
  else if (key === 'insider_name') filters.insider_name = ''
  else if (key === 'nature') { selectedNatureId.value = null; filters.nature_of_transaction_id = undefined }
  else if (key === 'min_insiders') minInsiders.value = ''
  filters.page = 1
  loadTransactions()
}

// ── filter / sort actions ─────────────────────────────────────────────────────
function applyFilters() {
  filters.page = 1
  loadTransactions()
}

function clearFilters() {
  filters.ticker = ''; filters.insider_name = ''; filters.date_from = ''; filters.date_to = ''
  filters.nature_of_transaction_id = undefined
  selectedNatureId.value = null
  dateFrom.value = null; dateTo.value = null
  minInsiders.value = ''
  filters.page = 1
  loadTransactions()
}

function handleSort(key: string) {
  if (sortKey.value === key) sortDir.value = sortDir.value === 'asc' ? 'desc' : 'asc'
  else { sortKey.value = key; sortDir.value = 'desc' }
  filters.page = 1
  loadTransactions()
}

function sortInd(key: string) {
  if (sortKey.value !== key) return ''
  return sortDir.value === 'asc' ? '▲' : '▼'
}

// ── pagination ────────────────────────────────────────────────────────────────
const totalPages = computed(() => Math.max(1, Math.ceil(totalRecords.value / (filters.per_page ?? 50))))
const pageStart = computed(() => totalRecords.value === 0 ? 0 : ((filters.page ?? 1) - 1) * (filters.per_page ?? 50) + 1)
const pageEnd = computed(() => Math.min(totalRecords.value, (filters.page ?? 1) * (filters.per_page ?? 50)))

const pageButtons = computed(() => {
  const out: (number | '...')[] = []
  const p = filters.page ?? 1, tp = totalPages.value, win = 2
  let last = 0
  for (let i = 1; i <= tp; i++) {
    if (i === 1 || i === tp || (i >= p - win && i <= p + win)) {
      if (last && i - last > 1) out.push('...')
      out.push(i); last = i
    }
  }
  return out
})

function goPage(p: number) {
  filters.page = p
  loadTransactions()
}

function changePerPage(n: number) {
  filters.per_page = n
  filters.page = 1
  loadTransactions()
}

// ── ticker navigation ─────────────────────────────────────────────────────────
function openTicker(ticker: string) {
  router.push({ name: 'ticker', params: { symbol: ticker } })
}

// function selectInsider(lastName: string) {
//   filters.insider_name = lastName
//   filters.page = 1
//   loadTransactions()
// }

// ── nature display ────────────────────────────────────────────────────────────
function txnTypeDisplay(raw: string | Record<string, string> | null | undefined) {
  if (!raw) return { code: '', desc: '—' }
  if (typeof raw === 'object') return { code: raw.code ?? '', desc: raw.description ?? '' }
  const m = String(raw).match(/^(\d+)\s*[-–]\s*(.+)$/)
  if (m) return { code: m[1], desc: m[2] }
  return { code: '', desc: String(raw) }
}

function relFirst(rels: string[] | undefined) {
  if (!rels?.length) return { first: '—', extra: 0 }
  const first = rels[0]!.replace(/^\d+\s*[-–]\s*/, '')
  return { first, extra: rels.length - 1 }
}

function fmtSigned(n: number | null | undefined) {
  if (n == null) return '—'
  return (n > 0 ? '+' : n < 0 ? '−' : '') + Math.abs(n).toLocaleString('en-CA')
}

function fmtMoney(n: string | number | null | undefined) {
  if (n == null || n === '') return '—'
  return '$' + parseFloat(String(n)).toFixed(2)
}

onMounted(() => {
  loadNatureOptions()
  loadTransactions()
})
</script>

<template>
  <div class="view">
    <!-- View header -->
    <div class="view-header">
      <div>
        <h1 class="view-title">Canadian Insider Transactions</h1>
        <div class="view-subtitle">{{ totalRecords }} filings</div>
      </div>
      <div class="view-meta">
        <span><b>{{ kpi.issuers }}</b> issuers</span>
        <span><b>{{ kpi.insiders }}</b> insiders</span>
        <span><b>{{ kpi.total.toLocaleString() }}</b> filings</span>
      </div>
    </div>

    <!-- Stats strip -->
    <!-- <div class="stats-strip">
      <FilingsSummaryPanel
        :buys="kpi.buys"
        :sells="kpi.sells"
        :buy-value="kpi.buyValue"
        :sell-value="kpi.sellValue"
      />
      <IssuerHeatmap :items="heatmapItems" @select="openTicker" />
      <InsiderLeaderboard :items="leaderboardItems" @select="selectInsider" />
    </div> -->

    <!-- Filter bar -->
    <div class="filter-bar">
      <div class="field">
        <div class="field-label">Date from</div>
        <DatePicker
          v-model="dateFrom"
          date-format="yy-mm-dd"
          placeholder="YYYY-MM-DD"
          show-button-bar
          @update:model-value="(v) => { filters.date_from = v ? formatDate(v as Date) : '' }"
          class="date-picker-field"
        />
      </div>
      <div class="field">
        <div class="field-label">Date to</div>
        <DatePicker
          v-model="dateTo"
          date-format="yy-mm-dd"
          placeholder="YYYY-MM-DD"
          show-button-bar
          @update:model-value="(v) => { filters.date_to = v ? formatDate(v as Date) : '' }"
          class="date-picker-field"
        />
      </div>
      <div class="field">
        <div class="field-label">Ticker</div>
        <input
          v-model="filters.ticker"
          class="field-input mono"
          style="width: 100px"
          placeholder="e.g. ENB.TO"
          @input="(e) => { filters.ticker = (e.target as HTMLInputElement).value.toUpperCase() }"
          @keydown.enter="applyFilters"
        />
      </div>
      <div class="field">
        <div class="field-label">Insider</div>
        <input
          v-model="filters.insider_name"
          class="field-input"
          style="width: 180px"
          placeholder="Search name…"
          @keydown.enter="applyFilters"
        />
      </div>
      <div class="field" style="position: relative">
        <div class="field-label">Transaction Type</div>
        <button
          class="field-input"
          style="width: 300px; text-align: left; display: flex; align-items: center; justify-content: space-between; cursor: pointer; background: var(--bg-panel)"
          @click="natureOpen = !natureOpen"
        >
          <span style="overflow: hidden; text-overflow: ellipsis; white-space: nowrap; color: selectedNature ? 'var(--fg)' : 'var(--fg-faint)'">
            <template v-if="selectedNature">
              <span style="font-family: var(--font-mono); color: var(--fg-muted); margin-right: 6px">{{ selectedNature.code }}</span>{{ selectedNature.description }}
            </template>
            <template v-else>
              <span style="color: var(--fg-faint)">All transaction types</span>
            </template>
          </span>
          <span style="color: var(--fg-faint); margin-left: 6px">▾</span>
        </button>
        <template v-if="natureOpen">
          <div class="dropdown-overlay" @click="natureOpen = false" />
          <div class="select-menu" style="top: 56px; left: 0; width: 320px; position: absolute; z-index: 200">
            <div class="item" @click="() => { selectedNatureId = null; natureOpen = false }">
              <span style="color: var(--fg-faint)">—</span>
              <span>All transaction types</span>
            </div>
            <div
              v-for="n in natureOptions"
              :key="n.id"
              class="item"
              :class="{ active: selectedNatureId === n.id }"
              @click="() => { selectedNatureId = n.id; natureOpen = false }"
            >
              <span class="code">{{ n.code }}</span>
              <span>{{ n.description }}</span>
            </div>
          </div>
        </template>
      </div>
      <div class="divider" />
      <div class="field">
        <div class="field-label">Min. insiders / ticker</div>
        <input
          v-model="minInsiders"
          class="field-input mono"
          style="width: 78px"
          type="number"
          min="1"
          placeholder="1"
          @keydown.enter="applyFilters"
        />
      </div>
      <div style="flex: 1" />
      <button class="btn btn-ghost" @click="clearFilters">Clear</button>
      <button class="btn btn-primary" @click="applyFilters">Apply Filters</button>
    </div>

    <!-- Table -->
    <div class="table-wrap">
      <div class="table-toolbar">
        <span>Showing <b style="color: var(--fg)">{{ totalRecords.toLocaleString() }}</b> filings</span>
        <template v-if="activeFilters.length">
          <span style="color: var(--fg-faint)">·</span>
          <span
            v-for="f in activeFilters"
            :key="f.key"
            class="chip"
          >
            {{ f.label }}
            <span class="x" @click="clearChip(f.key)">×</span>
          </span>
        </template>
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
              <th style="width: 110px" @click="handleSort('ticker')">Ticker <span class="sort-ind">{{ sortInd('ticker') }}</span></th>
              <th>Issuer</th>
              <th>Security</th>
              <th>Txn Type</th>
              <th class="num" @click="handleSort('number_of_securities')">Shares <span class="sort-ind">{{ sortInd('number_of_securities') }}</span></th>
              <th class="num" @click="handleSort('unit_price')">Price <span class="sort-ind">{{ sortInd('unit_price') }}</span></th>
              <th class="num" @click="handleSort('balance')">Balance <span class="sort-ind">{{ sortInd('balance') }}</span></th>
            </tr>
          </thead>
          <tbody>
            <tr v-if="loading && !transactions.length">
              <td colspan="11" class="empty-state">Loading…</td>
            </tr>
            <tr v-else-if="!transactions.length">
              <td colspan="11" class="empty-state">No transactions match the current filters.</td>
            </tr>
            <tr v-for="row in transactions" :key="row.id">
              <td class="mono">{{ row.filing_date }}</td>
              <td class="mono">{{ row.transaction_date }}</td>
              <td>{{ row.insider_name }}</td>
              <td>
                <span class="rel-cell">
                  {{ relFirst(row.relationships).first }}
                  <span v-if="relFirst(row.relationships).extra > 0" class="more">+{{ relFirst(row.relationships).extra }}</span>
                </span>
              </td>
              <td>
                <a
                  v-if="row.ticker"
                  class="ticker-link"
                  @click.stop="openTicker(row.ticker!)"
                >{{ row.ticker }}</a>
                <span v-else style="color: var(--fg-faint)">—</span>
              </td>
              <td style="color: var(--fg-muted)">{{ row.issuer_name }}</td>
              <td style="color: var(--fg-muted)">{{ row.security_designation }}</td>
              <td>
                <div class="txn-type-cell">
                  <span class="code">{{ txnTypeDisplay(row.nature_of_transaction as any).code }}</span>
                  <span class="desc">{{ txnTypeDisplay(row.nature_of_transaction as any).desc }}</span>
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
      <!-- Pagination -->
      <div class="pagination">
        <span>
          <b style="color: var(--fg)">{{ pageStart.toLocaleString() }}</b>–<b style="color: var(--fg)">{{ pageEnd.toLocaleString() }}</b>
          of <b style="color: var(--fg)">{{ totalRecords.toLocaleString() }}</b>
        </span>
        <span class="spacer" />
        <button class="page-btn" :disabled="(filters.page ?? 1) === 1" @click="goPage(1)">«</button>
        <button class="page-btn" :disabled="(filters.page ?? 1) === 1" @click="goPage((filters.page ?? 1) - 1)">‹</button>
        <template v-for="(p, i) in pageButtons" :key="i">
          <span v-if="p === '...'" style="color: var(--fg-faint); padding: 0 2px">…</span>
          <button v-else class="page-btn" :class="{ active: p === filters.page }" @click="goPage(p as number)">{{ p }}</button>
        </template>
        <button class="page-btn" :disabled="(filters.page ?? 1) === totalPages" @click="goPage((filters.page ?? 1) + 1)">›</button>
        <button class="page-btn" :disabled="(filters.page ?? 1) === totalPages" @click="goPage(totalPages)">»</button>
        <span style="margin-left: 8px">
          <select class="page-size" :value="filters.per_page" @change="changePerPage(Number(($event.target as HTMLSelectElement).value))">
            <option :value="25">25</option>
            <option :value="50">50</option>
            <option :value="100">100</option>
          </select>
          <span style="margin-left: 4px">per page</span>
        </span>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* Force PrimeVue DatePicker to match the design field-input style */
.date-picker-field :deep(.p-datepicker-input) {
  height: 32px;
  background: var(--bg-panel);
  border: 1px solid var(--border);
  border-radius: 6px;
  padding: 0 10px;
  font-size: 12.5px;
  color: var(--fg);
  font-family: var(--font-mono);
  box-shadow: none;
  width: 138px;
}
.date-picker-field :deep(.p-datepicker-input:focus) {
  border-color: var(--accent);
  box-shadow: 0 0 0 3px oklch(58% 0.14 254 / 0.15);
}
.date-picker-field :deep(.p-inputicon) {
  display: none;
}
</style>
