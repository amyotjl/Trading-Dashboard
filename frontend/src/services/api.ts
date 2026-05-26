import axios from 'axios'

const api = axios.create({ baseURL: '/api/v1' })

export interface TransactionRow {
  id: number
  sedi_transaction_id: number
  transaction_date: string
  filing_date: string
  number_of_securities: number | null
  unit_price: string | null
  balance: number | null
  insider_name: string
  issuer_name: string
  ticker: string | null
  security_designation: string
  ownership_type: string
  ownership_entity: string | null
  nature_of_transaction: string
  relationships: string[]
}

export interface PaginatedResponse<T> {
  data: T[]
  meta: {
    total: number
    page: number
    per_page: number
    total_pages: number
  }
}

export interface Issuer {
  id: number
  ticker: string | null
  name: string
  sector: string | null
  home_page: string | null
  description: string | null
}

export interface OHLCVBar {
  time: string
  open: number
  high: number
  low: number
  close: number
}

export interface TradeEvent {
  date: string
  type: 'buy' | 'sell'
}

export interface TransactionFilters {
  page?: number
  per_page?: number
  date_from?: string
  date_to?: string
  ticker?: string
  insider_name?: string
  nature_of_transaction_id?: number
  min_insiders?: number
  insider_date_from?: string
  insider_date_to?: string
  sort?: string
  direction?: 'asc' | 'desc'
}

// ── Market types ──────────────────────────────────────────────────────────────

export interface MarketIndex {
  symbol: string
  name: string
  last: number
  prev: number
  change_pct: number
  spark: number[]
}

export interface MarketSector {
  name: string
  weight: number
  day: number
  week: number
  month: number
  ytd: number
}

export interface MarketMover {
  ticker: string
  name: string
  last: number
  chg: number
  vol?: number
}

export interface SentimentRow {
  date: string
  buys: number
  sells: number
  buy_value: number
  sell_value: number
}

// ── API clients ───────────────────────────────────────────────────────────────

export const transactionsApi = {
  list: (params: TransactionFilters = {}) =>
    api.get<PaginatedResponse<TransactionRow>>('/transactions', { params }),

  sentiment: (params?: { date_from?: string; date_to?: string }) =>
    api.get<SentimentRow[]>('/insider_sentiment', { params }),
}

export const issuersApi = {
  get: (ticker: string) =>
    api.get<Issuer>(`/issuers/${ticker}`),

  transactions: (ticker: string, params: TransactionFilters = {}) =>
    api.get<PaginatedResponse<TransactionRow> & { issuer: Issuer }>(
      `/issuers/${ticker}/transactions`, { params }
    ),

  ohlcv: (ticker: string) =>
    api.get<{ ticker: string; data: OHLCVBar[] }>(`/issuers/${ticker}/ohlcv`),

  tradeEvents: (ticker: string) =>
    api.get<TradeEvent[]>(`/issuers/${ticker}/trade_events`),
}

export const marketApi = {
  indices: () => api.get<MarketIndex[]>('/market/indices'),
  sectors: () => api.get<MarketSector[]>('/market/sectors'),
  movers: (type: 'gainers' | 'losers' | 'active') =>
    api.get<MarketMover[]>('/market/movers', { params: { type } }),
}

export const importsApi = {
  uploadTransactions: (file: File) => {
    const form = new FormData()
    form.append('file', file)
    return api.post('/imports', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  },

  uploadIssuers: (file: File) => {
    const form = new FormData()
    form.append('file', file)
    return api.post('/imports/issuers', form, { headers: { 'Content-Type': 'multipart/form-data' } })
  },
}

export const filtersApi = {
  natureOfTransactions: () =>
    api.get<{ id: number; code: string; description: string }[]>('/nature_of_transactions'),
}
