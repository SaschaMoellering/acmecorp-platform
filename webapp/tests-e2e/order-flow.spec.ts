import { test, expect } from '@playwright/test';

/**
 * Mocks gateway endpoints used by the Orders view:
 * - catalog: list products to populate product selectors
 * - orders: GET (paged) + POST create; latest for dashboard tiles
 * - analytics/system: lightweight stubs for navigation checks
 * The test creates a new order via the UI and asserts it renders in the table.
 */

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

let ordersResponse: Array<{
  id: number;
  orderNumber: string;
  customerEmail: string;
  status: string;
  totalAmount: number;
  currency: string;
  createdAt: string;
  updatedAt: string;
  items: any[];
}> = [];

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
  page.on('console', (msg) => console.log('BROWSER', msg.type(), msg.text()));
  // reset shared state per test run
  ordersResponse = [];

  await page.route('**/api/gateway/catalog**', (route) => route.fulfill({ json: catalogResponse }));
  await page.route('**/api/gateway/orders/latest**', (route) => {
    console.log('route orders/latest', route.request().method(), route.request().url());
    return route.fulfill({ json: ordersResponse });
  });
  await page.route('**/api/gateway/orders**', async (route) => {
    console.log('route orders', route.request().method(), route.request().url());
    const req = route.request();
    const url = new URL(req.url());
    if (req.method() === 'GET') {
      if (url.searchParams.has('page')) {
        return route.fulfill({
          json: { content: ordersResponse, page: 0, size: 20, totalElements: ordersResponse.length, totalPages: 1 }
        });
      }
      return route.fulfill({ json: ordersResponse });
    }
    if (req.method() === 'POST') {
      const body = await req.postDataJSON();
      const nextId = ordersResponse.length + 1;
      const newOrder = {
        id: nextId,
        orderNumber: `ORD-E2E-${nextId}`,
        customerEmail: body.customerEmail,
        status: body.status ?? 'NEW',
        totalAmount: 100,
        currency: 'USD',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        items: body.items ?? []
      };
      ordersResponse = [...ordersResponse, newOrder];
      return route.fulfill({ status: 201, json: newOrder });
    }
    return route.fallback();
  });
  await page.route('**/api/gateway/analytics/counters', (route) => route.fulfill({ json: analyticsResponse }));
  await page.route('**/api/gateway/system/status', (route) => route.fulfill({ json: statusResponse }));

  const email = `e2e-order-${Date.now()}@example.com`;

  await page.goto('/orders');
  await page.getByLabel(/Customer Email/i).fill(email);
  await page.getByLabel(/^Product ID/i).fill('p-1');
  await page.getByLabel(/Quantity/i).fill('1');
  await page.getByLabel(/Status/i).selectOption('NEW');
  await page.getByRole('button', { name: /Create Order/i }).click();
  await page.reload();
  await expect(page.getByRole('row', { name: new RegExp(email, 'i') })).toBeVisible({ timeout: 20000 });

  await page.getByRole('link', { name: 'Analytics' }).click();
  await expect(page.getByText('Orders Created')).toBeVisible();
  await expect(page.getByText('320')).toBeVisible();

  await page.getByRole('link', { name: 'System' }).click();
  await expect(page.getByText('Service Status')).toBeVisible();
  await expect(page.locator('.catalog-card', { hasText: 'Gateway' }).first()).toBeVisible();
});
