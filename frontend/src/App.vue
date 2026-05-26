<script setup lang="ts">
import { computed, ref, onMounted, onUnmounted } from 'vue'
import { RouterView, useRoute, useRouter } from 'vue-router'

const route = useRoute()
const router = useRouter()

const now = ref(new Date())
let timer: ReturnType<typeof setInterval>

onMounted(() => {
  timer = setInterval(() => { now.value = new Date() }, 30000)
})
onUnmounted(() => clearInterval(timer))

const timeStr = computed(() =>
  now.value.toLocaleTimeString('en-CA', { hour: '2-digit', minute: '2-digit', hour12: false })
)

const currentTicker = computed(() => route.params.symbol as string | undefined)

const tabs = computed(() => [
  { label: 'Transactions', to: '/', name: 'dashboard' },
  { label: 'Market', to: '/market', name: 'market' },
  {
    label: currentTicker.value ? `Ticker · ${currentTicker.value}` : 'Ticker',
    to: currentTicker.value ? `/ticker/${currentTicker.value}` : null,
    name: 'ticker',
    disabled: !currentTicker.value,
  },
])

const activeTab = computed(() => route.name as string)

function navigate(tab: typeof tabs.value[0]) {
  if (tab.disabled || !tab.to) return
  router.push(tab.to)
}
</script>

<template>
  <div class="app-layout">
    <header class="app-header">
      <div class="brand">
        <div class="brand-mark">S</div>
        <span class="brand-name">SEDI Dashboard</span>
        <span class="brand-sub">v1.0</span>
      </div>

      <nav class="tabs">
        <button
          v-for="tab in tabs"
          :key="tab.name"
          class="tab"
          :class="{ active: activeTab === tab.name, disabled: tab.disabled }"
          @click="navigate(tab)"
        >
          {{ tab.label }}
        </button>
      </nav>

      <div class="header-spacer" />

      <div class="header-meta">
        <span><span class="dot" />enrichment online</span>
        <span>api v1</span>
        <span>{{ timeStr }}</span>
      </div>
    </header>

    <main class="app-main">
      <RouterView />
    </main>
  </div>
</template>

<style scoped>
.app-layout {
  display: flex;
  flex-direction: column;
  height: 100vh;
  overflow: hidden;
}
</style>
