import { test, expect } from '@playwright/test';

const catalogResponse = [
  {
    id: 'p-1',
    sku: 'SKU-001',
    name: 'Performance Laptop',
    description: 'High-performance laptop for analytics workloads.',
    price: 1999,
    currency: 'USD',
    category: 'Hardware',
    active: true
  },
  {
    id: 'p-2',
    sku: 'SKU-002',
    name: 'Cloud Subscription',
    description: 'Managed cluster capacity for burst workloads.',
    price: 499,
    currency: 'USD',
    category: 'Subscriptions',
    active: true
  }
];

const ordersResponse = [
  {
    id: 501,
    orderNumber: 'ORD-501',
    customerEmail: 'demo@example.com',
    status: 'CONFIRMED',
    totalAmount: 1999,
    currency: 'USD',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    items: [
      {
        id: 1,
        productId: 'p-1',
        productName: 'Performance Laptop',
        unitPrice: 1999,
        quantity: 1,
        lineTotal: 1999
      }
    ]
  }
];

const analyticsResponse = {
  'orders.created': 320,
  'orders.confirmed': 310,
  'orders.cancelled': 10,
  'billing.invoice.paid': 305,
  'notification.sent': 820
};

const statusResponse = [
  { service: 'Gateway', status: 'OK' },
  { service: 'Orders', status: 'OK' },
  { service: 'Analytics', status: 'OK' }
];

test('demo order flow', async ({ page }) => {
  await page.route('**/api/gateway/catalog', (route) => route.fulfill({ json: catalogResponse }));
  await page.route('**/api/gateway/orders/latest', (route) => route.fulfill({ json: ordersResponse }));
  await page.route('**/api/gateway/analytics/counters', (route) => route.fulfill({ json: analyticsResponse }));
  await page.route('**/api/gateway/system/status', (route) => route.fulfill({ json: statusResponse }));

  await page.goto('/');

  await page.getByRole('link', { name: 'Catalog' }).click();
  const firstProduct = page.locator('.catalog-card').first();
  await expect(firstProduct.locator('.catalog-name', { hasText: 'Performance Laptop' })).toBeVisible();
  await firstProduct.getByRole('button', { name: 'Add Performance Laptop to order' }).click();

  await page.getByRole('link', { name: 'Orders' }).click();
  await expect(page.getByRole('link', { name: 'ORD-501' })).toBeVisible();
  await expect(page.getByText('demo@example.com')).toBeVisible();

  await page.getByRole('link', { name: 'Analytics' }).click();
  await expect(page.getByText('Orders Created')).toBeVisible();
  await expect(page.getByText('320')).toBeVisible();

  await page.getByRole('link', { name: 'System' }).click();
  await expect(page.getByText('Service Status')).toBeVisible();
  await expect(page.locator('.catalog-card', { hasText: 'Gateway' }).first()).toBeVisible();
});
