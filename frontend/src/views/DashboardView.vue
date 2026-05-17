<script setup lang="ts">
import { ref, reactive, onMounted, watch } from 'vue'
import { RouterLink } from 'vue-router'
import DataTable from 'primevue/datatable'
import Column from 'primevue/column'
import InputText from 'primevue/inputtext'
import DatePicker from 'primevue/datepicker'
import Select from 'primevue/select'
import Button from 'primevue/button'
import Tag from 'primevue/tag'
import { transactionsApi, filtersApi, type TransactionRow, type TransactionFilters } from '@/services/api'

const transactions = ref<TransactionRow[]>([])
const loading = ref(false)
const totalRecords = ref(0)

const filters = reactive<TransactionFilters>({
  page: 1,
  per_page: 25,
  date_from: '',
  date_to: '',
  ticker: '',
  insider_name: '',
  nature_of_transaction_id: undefined,
  sort: 'filing_date',
  direction: 'desc'
})

const dateFrom = ref<Date | null>(null)
const dateTo = ref<Date | null>(null)
const natureOptions = ref<{ id: number; label: string }[]>([])
const selectedNature = ref<{ id: number; label: string } | null>(null)

async function loadNatureOptions() {
  const { data } = await filtersApi.natureOfTransactions()
  natureOptions.value = data.map((n) => ({ id: n.id, label: `${n.code} - ${n.description}` }))
}

async function loadTransactions() {
  loading.value = true
  try {
    const params: TransactionFilters = { ...filters }
    if (dateFrom.value) params.date_from = formatDate(dateFrom.value)
    if (dateTo.value) params.date_to = formatDate(dateTo.value)
    if (selectedNature.value) params.nature_of_transaction_id = selectedNature.value.id
    const { data } = await transactionsApi.list(params)
    transactions.value = data.data
    totalRecords.value = data.meta.total
  } finally {
    loading.value = false
  }
}

function formatDate(d: Date): string {
  return d.toISOString().slice(0, 10)
}

function onPage(event: { page: number; rows: number }) {
  filters.page = event.page + 1
  filters.per_page = event.rows
  loadTransactions()
}

function onSort(event: { sortField: string; sortOrder: number }) {
  filters.sort = event.sortField
  filters.direction = event.sortOrder === 1 ? 'asc' : 'desc'
  filters.page = 1
  loadTransactions()
}

function applyFilters() {
  filters.page = 1
  loadTransactions()
}

function clearFilters() {
  filters.ticker = ''
  filters.insider_name = ''
  filters.nature_of_transaction_id = undefined
  selectedNature.value = null
  dateFrom.value = null
  dateTo.value = null
  filters.page = 1
  loadTransactions()
}

onMounted(() => {
  loadNatureOptions()
  loadTransactions()
})
</script>

<template>
  <div>
    <h1 class="page-title">Canadian Insider Transactions</h1>

    <!-- Filter bar -->
    <div class="filter-bar">
      <div class="filter-group">
        <label>Date From</label>
        <DatePicker v-model="dateFrom" date-format="yy-mm-dd" placeholder="YYYY-MM-DD" show-button-bar />
      </div>
      <div class="filter-group">
        <label>Date To</label>
        <DatePicker v-model="dateTo" date-format="yy-mm-dd" placeholder="YYYY-MM-DD" show-button-bar />
      </div>
      <div class="filter-group">
        <label>Ticker</label>
        <InputText v-model="filters.ticker" placeholder="e.g. CNQ" style="width: 100px" />
      </div>
      <div class="filter-group">
        <label>Insider</label>
        <InputText v-model="filters.insider_name" placeholder="Name search" style="width: 180px" />
      </div>
      <div class="filter-group">
        <label>Transaction Type</label>
        <Select v-model="selectedNature" :options="natureOptions" option-label="label"
          placeholder="All types" show-clear style="width: 280px" />
      </div>
      <div class="filter-actions">
        <Button label="Apply" icon="pi pi-search" @click="applyFilters" />
        <Button label="Clear" icon="pi pi-times" severity="secondary" @click="clearFilters" />
      </div>
    </div>

    <!-- Table -->
    <DataTable
      :value="transactions"
      :loading="loading"
      lazy
      paginator
      :rows="filters.per_page"
      :total-records="totalRecords"
      :rows-per-page-options="[25, 50, 100]"
      sort-mode="single"
      removable-sort
      @page="onPage"
      @sort="onSort"
      striped-rows
      scroll-height="calc(100vh - 280px)"
      scrollable
      class="transactions-table"
    >
      <Column field="filing_date" header="Filed" sortable style="min-width: 100px" />
      <Column field="transaction_date" header="Transaction" sortable style="min-width: 110px" />
      <Column field="insider_name" header="Insider" style="min-width: 180px" />
      <Column header="Relationship" style="min-width: 200px">
        <template #body="{ data }">
          <span>{{ data.relationships?.join(', ') }}</span>
        </template>
      </Column>
      <Column field="ticker" header="Ticker" style="min-width: 90px">
        <template #body="{ data }">
          <RouterLink v-if="data.ticker" :to="`/ticker/${data.ticker}`" class="ticker-link">
            {{ data.ticker }}
          </RouterLink>
          <span v-else class="no-ticker">—</span>
        </template>
      </Column>
      <Column field="issuer_name" header="Issuer" style="min-width: 200px" />
      <Column field="security_designation" header="Security" style="min-width: 220px" />
      <Column field="nature_of_transaction" header="Transaction Type" style="min-width: 260px" />
      <Column field="number_of_securities" header="Shares" sortable style="min-width: 100px">
        <template #body="{ data }">
          <span :class="data.number_of_securities < 0 ? 'negative' : 'positive'">
            {{ data.number_of_securities?.toLocaleString() }}
          </span>
        </template>
      </Column>
      <Column field="unit_price" header="Price" sortable style="min-width: 80px">
        <template #body="{ data }">
          {{ data.unit_price ? `$${parseFloat(data.unit_price).toFixed(2)}` : '—' }}
        </template>
      </Column>
      <Column field="balance" header="Balance" sortable style="min-width: 100px">
        <template #body="{ data }">
          {{ data.balance?.toLocaleString() }}
        </template>
      </Column>
    </DataTable>
  </div>
</template>

<style scoped>
.page-title {
  font-size: 1.6rem;
  font-weight: 700;
  margin-bottom: 1rem;
}

.filter-bar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-end;
  gap: 1rem;
  margin-bottom: 1rem;
  padding: 1rem;
  background: var(--p-surface-50, #f8f8f8);
  border-radius: 8px;
}

.filter-group {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.filter-group label {
  font-size: 0.8rem;
  font-weight: 600;
  color: #555;
}

.filter-actions {
  display: flex;
  gap: 0.5rem;
  align-items: flex-end;
  padding-bottom: 2px;
}

.ticker-link {
  font-weight: 700;
  color: #2563eb;
  text-decoration: none;
  font-family: monospace;
  font-size: 0.95rem;
}

.ticker-link:hover {
  text-decoration: underline;
}

.no-ticker {
  color: #aaa;
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
