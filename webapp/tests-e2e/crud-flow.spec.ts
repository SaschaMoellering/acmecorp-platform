import { test, expect } from '@playwright/test';

/**
 * Mocks gateway endpoints used by catalog + orders manage views:
 * - catalog CRUD (list/create/update/delete) with in-memory products
 * - orders CRUD (list/create/update/delete) plus confirm/cancel
 * - seed endpoint to reset fixtures when the UI requests it
 * The test creates, edits, and deletes both a product and an order via UI flows.
 */

const seedProducts = [
  {
    id: 'p-1',
    sku: 'SKU-001',
    name: 'Demo Laptop',
    description: 'High-performance laptop.',
    price: 1999,
    currency: 'USD',
    category: 'Hardware',
    active: true
  }
];

const seedOrders = [
  {
    id: 1,
    orderNumber: 'ORD-SEED-1',
    customerEmail: 'seed@example.com',
    status: 'CONFIRMED',
    totalAmount: 1999,
    currency: 'USD',
    createdAt: '2024-01-01T00:00:00Z',
    updatedAt: '2024-01-01T00:00:00Z',
    items: [{ id: 1, productId: 'p-1', productName: 'Demo Laptop', unitPrice: 1999, quantity: 1, lineTotal: 1999 }]
  }
];

async function closeDialogIfVisible(page: Parameters<typeof test>[0]['page']) {
  const closeButton = page.getByLabel('Close dialog');
  if ((await closeButton.count()) > 0) {
    await closeButton.click();
  }
}

test('manage catalog and orders with seed data', async ({ page }) => {
  page.on('console', (msg) => console.log('BROWSER', msg.type(), msg.text()));
  let products = [...seedProducts];
  let orders = [...seedOrders];

  const ordersPage = () => ({
    content: orders,
    page: 0,
    size: 20,
    totalElements: orders.length,
    totalPages: 1
  });

  await page.route('**/api/gateway/catalog**', async (route) => {
    console.log('route catalog', route.request().method(), route.request().url());
    const req = route.request();
    const url = new URL(req.url());
    const method = req.method();
    const id = url.pathname.split('/').pop()!;

    if (method === 'GET') {
      if (url.pathname.endsWith('/catalog')) {
        return route.fulfill({ json: products });
      }
      const product = products.find((p) => p.id === id);
      return route.fulfill({ status: product ? 200 : 404, json: product ?? {} });
    }

    if (method === 'POST') {
      const body = await req.postDataJSON();
      const newProduct = {
        ...body,
        id: body.id ?? `p-${products.length + 1}`,
        price: Number(body.price)
      };
      products = [...products, newProduct];
      return route.fulfill({ status: 201, json: newProduct });
    }

    if (method === 'PUT') {
      const body = await req.postDataJSON();
      products = products.map((p) => (p.id === id ? { ...p, ...body } : p));
      return route.fulfill({ status: 200, json: products.find((p) => p.id === id) });
    }

    if (method === 'DELETE') {
      products = products.filter((p) => p.id !== id);
      return route.fulfill({ status: 204, body: '' });
    }

    return route.fallback();
  });

  await page.route('**/api/gateway/orders/latest', (route) => route.fulfill({ json: orders }));

  await page.route('**/api/gateway/orders**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const method = req.method();
    const idPart = url.pathname.split('/').pop()!;

    if (method === 'GET') {
      if (url.searchParams.has('page')) {
        return route.fulfill({ json: ordersPage() });
      }
      return route.fulfill({ json: orders });
    }

    if (method === 'POST') {
      if (url.pathname.endsWith('/confirm')) {
        orders = orders.map((o) => (String(o.id) === idPart ? { ...o, status: 'CONFIRMED' } : o));
        return route.fulfill({ json: orders.find((o) => String(o.id) === idPart) });
      }
      if (url.pathname.endsWith('/cancel')) {
        orders = orders.map((o) => (String(o.id) === idPart ? { ...o, status: 'CANCELLED' } : o));
        return route.fulfill({ json: orders.find((o) => String(o.id) === idPart) });
      }
      const body = await req.postDataJSON();
      const newId = orders.length + 1;
      const newOrder = {
        id: newId,
        orderNumber: `ORD-${newId}`,
        customerEmail: body.customerEmail,
        status: body.status ?? 'NEW',
        totalAmount: 100,
        currency: body.currency ?? 'USD',
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        items: body.items ?? []
      };
      orders = [...orders, newOrder];
      return route.fulfill({ status: 201, json: newOrder });
    }

    if (method === 'PUT') {
      const body = await req.postDataJSON();
      orders = orders.map((o) => (String(o.id) === idPart ? { ...o, ...body } : o));
      return route.fulfill({ status: 200, json: orders.find((o) => String(o.id) === idPart) });
    }

    if (method === 'DELETE') {
      orders = orders.filter((o) => String(o.id) !== idPart);
      return route.fulfill({ status: 204, body: '' });
    }

    return route.fallback();
  });

  await page.route('**/api/gateway/seed', (route) => {
    products = [...seedProducts];
    orders = [...seedOrders];
    return route.fulfill({ json: { catalogSeeded: true, ordersSeeded: true } });
  });

  await page.route('**/api/gateway/analytics/counters', (route) => route.fulfill({ json: {} }));
  await page.route('**/api/gateway/system/status', (route) => route.fulfill({ json: [] }));

  const productName = `E2E Product ${Date.now()}`;
  const sku = `SKU-E2E-${Date.now()}`;
  const updatedName = `${productName} Updated`;
  const orderEmail = `e2e-${Date.now()}@example.com`;

  await page.goto('/catalog/manage');
  await expect(page.getByText('Demo Laptop')).toBeVisible();

  await page.getByRole('button', { name: /New Product/i }).click();
  await page.getByLabel('SKU').fill(sku);
  await page.getByLabel('Name').fill(productName);
  await page.getByLabel('Description').fill('Created during E2E');
  await page.getByLabel('Price').fill('123');
  await page.getByLabel('Currency').fill('USD');
  await page.getByLabel('Category').fill('Testing');
  await page.getByLabel('Active').selectOption('true');
  const newProduct = {
    id: `p-${products.length + 1}`,
    sku,
    name: productName,
    description: 'Created during E2E',
    price: 123,
    currency: 'USD',
    category: 'Testing',
    active: true
  };
  products = [...products, newProduct];
  await page.getByRole('button', { name: /Create Product/i }).click();
  await closeDialogIfVisible(page);
  await page.getByRole('button', { name: /Refresh/i }).click();
  const table = page.getByRole('table').first();
  const productRows = table.locator('tbody').getByRole('row');
  const createdProductRow = productRows.filter({ hasText: sku }).filter({ hasText: productName });
  await expect(createdProductRow).toHaveCount(1, { timeout: 15000 });
  await expect(createdProductRow.first()).toBeVisible();

  await createdProductRow.first().getByRole('button', { name: /^Edit$/ }).click();
  products = products.map((p) => (p.id === newProduct.id ? { ...p, name: updatedName } : p));
  await page.getByLabel('Name').fill(updatedName);
  await page.getByRole('button', { name: /Update Product/i }).click();
  await closeDialogIfVisible(page);
  await page.getByRole('button', { name: /Refresh/i }).click();
  const updatedTable = page.getByRole('table').first();
  const updatedRows = updatedTable.locator('tbody').getByRole('row');
  const updatedProductRow = updatedRows.filter({ hasText: sku }).filter({ hasText: updatedName });
  await expect(updatedProductRow).toHaveCount(1);
  await expect(updatedProductRow.first()).toBeVisible();

  await updatedProductRow.first().getByRole('button', { name: 'Delete' }).click();
  products = products.filter((p) => p.id !== newProduct.id);
  await page.getByRole('button', { name: /Delete Product/i }).click();
  const deletedRows = page
    .getByRole('table')
    .first()
    .locator('tbody')
    .getByRole('row')
    .filter({ hasText: sku });
  await expect(deletedRows).toHaveCount(0);

  await page.goto('/orders/manage');
  await page.getByRole('button', { name: /New Order/i }).click();
  await page.getByLabel(/Customer Email/i).fill(orderEmail);
  await page.getByLabel(/^Product ID/i).fill('p-1');
  await page.getByLabel(/Quantity/i).fill('1');
  await page.getByLabel(/Status/i).selectOption('NEW');
  await Promise.all([
    page.waitForResponse(
      (res) => res.url().includes('/api/gateway/orders') && res.request().method() === 'POST' && res.ok()
    ),
    page.getByRole('button', { name: /Create Order/i }).click()
  ]);
  const createdOrderRow = page.getByRole('row', { name: new RegExp(orderEmail, 'i') });
  await expect(createdOrderRow).toBeVisible({ timeout: 15000 });

  await createdOrderRow.getByRole('button', { name: 'Edit' }).click();
  await page.getByLabel(/Status/i).selectOption('CONFIRMED');
  await page.getByRole('button', { name: /Update Order/i }).click();
  await expect(page.getByRole('row', { name: new RegExp(orderEmail, 'i') })).toBeVisible();
  await expect(page.getByRole('row', { name: new RegExp(orderEmail, 'i') }).getByText('CONFIRMED')).toBeVisible();

  await page.getByRole('row', { name: new RegExp(orderEmail, 'i') }).getByRole('button', { name: 'Delete' }).click();
  await page.getByRole('button', { name: /Delete Order/i }).click();
  await expect(page.getByRole('row', { name: new RegExp(orderEmail, 'i') })).toHaveCount(0);
});
