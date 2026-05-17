<script setup lang="ts">
import { ref } from 'vue'
import FileUpload, { type FileUploadUploaderEvent } from 'primevue/fileupload'
import Card from 'primevue/card'
import Message from 'primevue/message'
import ProgressBar from 'primevue/progressbar'
import { importsApi } from '@/services/api'
import { useToast } from 'primevue/usetoast'

const toast = useToast()

interface ImportResult {
  inserted?: number
  skipped?: number
  created?: number
  updated?: number
  errors: { row: number; message: string }[]
}

const txnResult = ref<ImportResult | null>(null)
const txnUploading = ref(false)
const issuerResult = ref<ImportResult | null>(null)
const issuerUploading = ref(false)

async function uploadTransactions(event: FileUploadUploaderEvent) {
  const file = Array.isArray(event.files) ? event.files[0] : event.files
  if (!file) return
  txnUploading.value = true
  txnResult.value = null
  try {
    const { data } = await importsApi.uploadTransactions(file)
    txnResult.value = data
    toast.add({ severity: 'success', summary: 'Import complete', detail: `${data.inserted} inserted, ${data.skipped} skipped`, life: 4000 })
  } catch {
    toast.add({ severity: 'error', summary: 'Upload failed', detail: 'Check the file format and try again.', life: 5000 })
  } finally {
    txnUploading.value = false
  }
}

async function uploadIssuers(event: FileUploadUploaderEvent) {
  const file = Array.isArray(event.files) ? event.files[0] : event.files
  if (!file) return
  issuerUploading.value = true
  issuerResult.value = null
  try {
    const { data } = await importsApi.uploadIssuers(file)
    issuerResult.value = data
    toast.add({ severity: 'success', summary: 'Import complete', detail: `${data.created} created, ${data.updated} updated`, life: 4000 })
  } catch {
    toast.add({ severity: 'error', summary: 'Upload failed', detail: 'Check the file format and try again.', life: 5000 })
  } finally {
    issuerUploading.value = false
  }
}
</script>

<template>
  <div class="upload-page">
    <h1 class="page-title">Import Data</h1>

    <div class="upload-grid">
      <!-- Transaction CSV -->
      <Card class="upload-card">
        <template #title>Transaction CSV</template>
        <template #subtitle>
          Import SEDI insider transaction data
        </template>
        <template #content>
          <div class="format-hint">
            <strong>Expected columns:</strong><br />
            <code>insider_name, relationship, security_designation, issuer_name, ticker, transaction_id, transaction_date, filing_date, ownership_type, nature_of_transaction, number_of_securities, unit_price, balance</code>
          </div>

          <FileUpload
            mode="basic"
            accept=".csv"
            :auto="true"
            choose-label="Choose CSV file"
            :disabled="txnUploading"
            custom-upload
            @uploader="uploadTransactions"
          />

          <ProgressBar v-if="txnUploading" mode="indeterminate" style="height: 4px; margin-top: 1rem" />

          <div v-if="txnResult" class="result-box">
            <Message v-if="txnResult.errors.length === 0" severity="success">
              ✓ Inserted: <strong>{{ txnResult.inserted }}</strong> &nbsp;|&nbsp;
              Skipped (duplicates): <strong>{{ txnResult.skipped }}</strong>
            </Message>
            <Message v-else severity="warn">
              Inserted: {{ txnResult.inserted }} | Skipped: {{ txnResult.skipped }} |
              Errors: {{ txnResult.errors.length }}
            </Message>
            <div v-if="txnResult.errors.length" class="error-list">
              <div v-for="e in txnResult.errors" :key="e.row" class="error-row">
                Row {{ e.row }}: {{ e.message }}
              </div>
            </div>
          </div>
        </template>
      </Card>

      <!-- Issuer metadata CSV -->
      <Card class="upload-card">
        <template #title>Issuer Metadata CSV</template>
        <template #subtitle>
          Add or update ticker info (sector, homepage)
        </template>
        <template #content>
          <div class="format-hint">
            <strong>Expected columns:</strong><br />
            <code>ticker, name, sector, home_page</code>
          </div>

          <FileUpload
            mode="basic"
            accept=".csv"
            :auto="true"
            choose-label="Choose CSV file"
            :disabled="issuerUploading"
            custom-upload
            @uploader="uploadIssuers"
          />

          <ProgressBar v-if="issuerUploading" mode="indeterminate" style="height: 4px; margin-top: 1rem" />

          <div v-if="issuerResult" class="result-box">
            <Message v-if="issuerResult.errors.length === 0" severity="success">
              ✓ Created: <strong>{{ issuerResult.created }}</strong> &nbsp;|&nbsp;
              Updated: <strong>{{ issuerResult.updated }}</strong>
            </Message>
            <Message v-else severity="warn">
              Created: {{ issuerResult.created }} | Updated: {{ issuerResult.updated }} |
              Errors: {{ issuerResult.errors.length }}
            </Message>
            <div v-if="issuerResult.errors.length" class="error-list">
              <div v-for="e in issuerResult.errors" :key="e.row" class="error-row">
                Row {{ e.row }}: {{ e.message }}
              </div>
            </div>
          </div>
        </template>
      </Card>
    </div>
  </div>
</template>

<style scoped>
.upload-page {
  max-width: 1100px;
}

.page-title {
  font-size: 1.6rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
}

.upload-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1.5rem;
}

@media (max-width: 768px) {
  .upload-grid { grid-template-columns: 1fr; }
}

.upload-card {
  padding: 0.5rem;
}

.format-hint {
  background: #f5f5f5;
  border-radius: 6px;
  padding: 0.75rem 1rem;
  margin-bottom: 1rem;
  font-size: 0.82rem;
  line-height: 1.6;
}

.format-hint code {
  word-break: break-all;
  color: #333;
}

.result-box {
  margin-top: 1rem;
}

.error-list {
  margin-top: 0.5rem;
  background: #fff3f3;
  border: 1px solid #fca5a5;
  border-radius: 6px;
  padding: 0.5rem 0.75rem;
  max-height: 200px;
  overflow-y: auto;
}

.error-row {
  font-size: 0.82rem;
  color: #b91c1c;
  padding: 0.2rem 0;
  border-bottom: 1px solid #fee2e2;
}

.error-row:last-child {
  border-bottom: none;
}
</style>
