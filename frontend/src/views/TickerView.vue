<script setup lang="ts">
import { ref, onMounted, watch } from 'vue'
import { useRoute } from 'vue-router'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import Tag from 'primevue/tag'
import Button from 'primevue/button'
import ProgressSpinner from 'primevue/progressspinner'
import { issuersApi, type Issuer, type TransactionRow, type TransactionFilters } from '@/services/api'

const route = useRoute()
const symbol = ref(route.params.symbol as string)

const issuer = ref<Issuer | null>(null)
const transactions = ref<TransactionRow[]>([])
const loading = ref(false)
const issuerLoading = ref(false)
const totalRecords = ref(0)
const notFound = ref(false)

const tableFilters = ref<TransactionFilters>({
  page: 1,
  per_page: 25,
  sort: 'filing_date',
  direction: 'desc'
})

async function loadIssuer() {
  issuerLoading.value = true
  notFound.value = false
  try {
    const { data } = await issuersApi.get(symbol.value)
    issuer.value = data
  } catch (err: any) {
    if (err.response?.status === 404) notFound.value = true
  } finally {
    issuerLoading.value = false
  }
}

async function loadTransactions() {
  loading.value = true
  try {
    const { data } = await issuersApi.transactions(symbol.value, tableFilters.value)
    transactions.value = data.data
    totalRecords.value = data.meta.total
  } finally {
    loading.value = false
  }
}

function onPage(event: { page: number; rows: number }) {
  tableFilters.value.page = event.page + 1
  tableFilters.value.per_page = event.rows
  loadTransactions()
}

function onSort(event: { sortField: string; sortOrder: number }) {
  tableFilters.value.sort = event.sortField
  tableFilters.value.direction = event.sortOrder === 1 ? 'asc' : 'desc'
  tableFilters.value.page = 1
  loadTransactions()
}

watch(() => route.params.symbol, (newSymbol) => {
  symbol.value = newSymbol as string
  loadIssuer()
  loadTransactions()
})

onMounted(() => {
  loadIssuer()
  loadTransactions()
})
</script>

<template>
  <div>
    <!-- Loading state -->
    <div v-if="issuerLoading" class="center-spinner">
      <ProgressSpinner />
    </div>

    <!-- Not found -->
    <div v-else-if="notFound" class="not-found">
      <h2>Ticker "{{ symbol }}" not found</h2>
      <p>No issuer data available for this symbol.</p>
    </div>

    <div v-else>
      <!-- Header -->
      <div class="ticker-header">
        <div class="ticker-info">
          <div class="ticker-badge">{{ symbol }}</div>
          <div>
            <h1 class="issuer-name">{{ issuer?.name }}</h1>
            <div class="issuer-meta">
              <span v-if="issuer?.sector" class="meta-chip">
                <i class="pi pi-tag" /> {{ issuer.sector }}
              </span>
              <a v-if="issuer?.home_page" :href="issuer.home_page" target="_blank" rel="noopener"
                class="home-link">
                <i class="pi pi-external-link" /> Website
              </a>
            </div>
          </div>
        </div>
      </div>

      <!-- TradingView Chart -->
      <div class="chart-container">
        <iframe
          :src="`https://s.tradingview.com/widgetembed/?frameurl=%2F&symbol=${encodeURIComponent(symbol)}&interval=D&hidesidetoolbar=0&symboledit=1&saveimage=0&toolbarbg=f4f7f9&studies=[]&theme=light&style=1&timezone=America%2FToronto&withdateranges=1&hideideas=1&studies_overrides=%7B%7D&overrides=%7B%7D&enabled_features=%5B%5D&disabled_features=%5B%5D&locale=en&utm_source=localhost&utm_medium=widget`"
          style="width: 100%; height: 500px; border: none;"
          allowtransparency="true"
          frameborder="0"
          scrolling="no"
          title="TradingView Chart"
        />
      </div>

      <!-- Transactions for this ticker -->
      <h2 class="section-title">Insider Transactions ({{ totalRecords.toLocaleString() }})</h2>
      <DataTable
        :value="transactions"
        :loading="loading"
        lazy
        paginator
        :rows="tableFilters.per_page"
        :total-records="totalRecords"
        :rows-per-page-options="[25, 50, 100]"
        sort-mode="single"
        removable-sort
        @page="onPage"
        @sort="onSort"
        striped-rows
        class="transactions-table"
      >
        <Column field="filing_date" header="Filed" sortable />
        <Column field="transaction_date" header="Transaction Date" sortable />
        <Column field="insider_name" header="Insider" />
        <Column header="Relationship">
          <template #body="{ data }">
            {{ data.relationships?.join(', ') }}
          </template>
        </Column>
        <Column field="security_designation" header="Security" />
        <Column field="nature_of_transaction" header="Transaction Type" />
        <Column field="number_of_securities" header="Shares" sortable>
          <template #body="{ data }">
            <span :class="(data.number_of_securities ?? 0) < 0 ? 'negative' : 'positive'">
              {{ data.number_of_securities?.toLocaleString() }}
            </span>
          </template>
        </Column>
        <Column field="unit_price" header="Price" sortable>
          <template #body="{ data }">
            {{ data.unit_price ? `$${parseFloat(data.unit_price).toFixed(2)}` : '—' }}
          </template>
        </Column>
        <Column field="balance" header="Balance" sortable>
          <template #body="{ data }">
            {{ data.balance?.toLocaleString() }}
          </template>
        </Column>
      </DataTable>
    </div>
  </div>
</template>

<style scoped>
.center-spinner {
  display: flex;
  justify-content: center;
  padding: 4rem;
}

.not-found {
  text-align: center;
  padding: 4rem;
  color: #888;
}

.ticker-header {
  display: flex;
  align-items: flex-start;
  gap: 1.5rem;
  margin-bottom: 1.5rem;
}

.ticker-info {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.ticker-badge {
  background: #1a1a2e;
  color: white;
  font-family: monospace;
  font-size: 1.4rem;
  font-weight: 700;
  padding: 0.4rem 0.8rem;
  border-radius: 6px;
  letter-spacing: 0.05em;
}

.issuer-name {
  font-size: 1.5rem;
  font-weight: 700;
  margin: 0 0 0.25rem 0;
}

.issuer-meta {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  flex-wrap: wrap;
}

.meta-chip {
  background: #f0f0f0;
  padding: 0.2rem 0.6rem;
  border-radius: 12px;
  font-size: 0.85rem;
  color: #555;
}

.home-link {
  color: #2563eb;
  font-size: 0.85rem;
  text-decoration: none;
}

.home-link:hover {
  text-decoration: underline;
}

.chart-container {
  margin-bottom: 2rem;
  border-radius: 8px;
  overflow: hidden;
  border: 1px solid #e5e5e5;
}

.section-title {
  font-size: 1.2rem;
  font-weight: 700;
  margin-bottom: 0.75rem;
}

.positive {
  color: #16a34a;
  font-weight: 600;
}

.negative {
  color: #dc2626;
  font-weight: 600;
}
</style>
