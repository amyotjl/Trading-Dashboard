import { createRouter, createWebHistory } from 'vue-router'
import DashboardView from '../views/DashboardView.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    {
      path: '/',
      name: 'dashboard',
      component: DashboardView,
    },
    {
      path: '/market',
      name: 'market',
      component: () => import('../views/MarketView.vue'),
    },
    {
      path: '/ticker/:symbol',
      name: 'ticker',
      component: () => import('../views/TickerView.vue'),
    },
    {
      path: '/import',
      name: 'import',
      component: () => import('../views/UploadView.vue'),
    },
  ],
})

export default router
