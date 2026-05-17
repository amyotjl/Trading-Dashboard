<script setup lang="ts">
import { RouterLink, RouterView } from 'vue-router'
import Toast from 'primevue/toast'
</script>

<template>
  <Toast />
  <nav class="app-nav">
    <div class="nav-brand">SEDI Dashboard</div>
    <div class="nav-links">
      <RouterLink to="/">Transactions</RouterLink>
      <RouterLink to="/import">Import Data</RouterLink>
    </div>
  </nav>
  <main class="app-main">
    <RouterView />
  </main>
</template>

<style scoped>
.app-nav {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1.5rem;
  background: #1a1a2e;
  color: white;
  position: sticky;
  top: 0;
  z-index: 100;
}

.nav-brand {
  font-size: 1.2rem;
  font-weight: 700;
  letter-spacing: 0.05em;
}

.nav-links {
  display: flex;
  gap: 1.5rem;
}

.nav-links a {
  color: #ccc;
  text-decoration: none;
  font-size: 0.95rem;
  transition: color 0.2s;
}

.nav-links a:hover,
.nav-links a.router-link-active {
  color: white;
}

.app-main {
  padding: 1.5rem;
  max-width: 1600px;
  margin: 0 auto;
}
</style>
