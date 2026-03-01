import { test, expect } from '@playwright/test';

let ordersResponse: Array<{
  id: number;
  orderNumber: string;
  customerEmail: string;
  status: string;
  totalAmount: number;
  currency: string;
  createdAt: string;
  updatedAt: string;
  items: Array<{ productId: string; quantity: number }>;
}> = [];

const seedOrder = {
  id: 1,
  orderNumber: 'ORD-E2E-1',
  customerEmail: 'initial@example.com',
  status: 'NEW',
  totalAmount: 100,
  currency: 'USD',
  createdAt: '2026-01-01T00:00:00.000Z',
  updatedAt: '2026-01-01T00:00:00.000Z',
  items: [{ productId: 'p-1', quantity: 1 }]
};

test('orders screen edits and deletes an order via gateway endpoints', async ({ page }) => {
  ordersResponse = [{ ...seedOrder }];
  let updateCount = 0;
  let deleteCount = 0;

  await page.route('**/api/gateway/orders**', async (route) => {
    const req = route.request();
    const method = req.method();
    const url = new URL(req.url());

    if (method === 'GET') {
      if (url.searchParams.has('page')) {
        return route.fulfill({
          json: { content: ordersResponse, page: 0, size: 20, totalElements: ordersResponse.length, totalPages: 1 }
        });
      }
      return route.fulfill({ json: ordersResponse });
    }

    if (method === 'PUT' && /\/api\/gateway\/orders\/\d+$/.test(url.pathname)) {
      updateCount += 1;
      const id = Number(url.pathname.split('/').pop());
      const body = await req.postDataJSON();
      const updated = {
        ...ordersResponse.find((o) => o.id === id)!,
        customerEmail: body.customerEmail,
        status: body.status,
        items: body.items,
        updatedAt: new Date().toISOString()
      };
      ordersResponse = ordersResponse.map((o) => (o.id === id ? updated : o));
      return route.fulfill({ status: 200, json: updated });
    }

    if (method === 'DELETE' && /\/api\/gateway\/orders\/\d+$/.test(url.pathname)) {
      deleteCount += 1;
      const id = Number(url.pathname.split('/').pop());
      ordersResponse = ordersResponse.filter((o) => o.id !== id);
      return route.fulfill({ status: 204, body: '' });
    }

    return route.fallback();
  });

  await page.goto('/orders');

  await page.getByRole('button', { name: /^Edit$/ }).first().click();
  await expect(page.getByText(/Edit Order #1/i)).toBeVisible();

  const updatedEmail = `updated-${Date.now()}@example.com`;
  await page.getByLabel(/Customer Email/i).last().fill(updatedEmail);
  await page.getByLabel(/Status/i).last().selectOption('CONFIRMED');

  await Promise.all([
    page.waitForResponse(
      (res) =>
        /\/api\/gateway\/orders\/1$/.test(new URL(res.url()).pathname) &&
        res.request().method() === 'PUT' &&
        res.ok()
    ),
    page.getByRole('button', { name: /Update Order/i }).click()
  ]);

  await expect(page.getByText('Order updated').first()).toBeVisible();
  await expect(page.getByRole('row', { name: new RegExp(updatedEmail, 'i') })).toBeVisible();
  expect(updateCount).toBe(1);

  page.once('dialog', (dialog) => dialog.accept());
  await Promise.all([
    page.waitForResponse(
      (res) =>
        /\/api\/gateway\/orders\/1$/.test(new URL(res.url()).pathname) &&
        res.request().method() === 'DELETE' &&
        res.status() === 204
    ),
    page.getByRole('button', { name: /^Delete$/ }).first().click()
  ]);

  await expect(page.getByText('Order deleted')).toBeVisible();
  await expect(page.getByRole('row', { name: new RegExp(updatedEmail, 'i') })).toHaveCount(0);
  expect(deleteCount).toBe(1);
});

test('delete row action does not trigger create form submit', async ({ page }) => {
  ordersResponse = [{ ...seedOrder }];
  let deleteCount = 0;

  await page.route('**/api/gateway/orders**', async (route) => {
    const req = route.request();
    const method = req.method();
    const url = new URL(req.url());

    if (method === 'GET') {
      if (url.searchParams.has('page')) {
        return route.fulfill({
          json: { content: ordersResponse, page: 0, size: 20, totalElements: ordersResponse.length, totalPages: 1 }
        });
      }
      return route.fulfill({ json: ordersResponse });
    }

    if (method === 'DELETE' && /\/api\/gateway\/orders\/\d+$/.test(url.pathname)) {
      deleteCount += 1;
      const id = Number(url.pathname.split('/').pop());
      ordersResponse = ordersResponse.filter((o) => o.id !== id);
      return route.fulfill({ status: 204, body: '' });
    }

    return route.fallback();
  });

  await page.goto('/orders');
  page.once('dialog', (dialog) => dialog.accept());

  await Promise.all([
    page.waitForResponse(
      (res) =>
        /\/api\/gateway\/orders\/1$/.test(new URL(res.url()).pathname) &&
        res.request().method() === 'DELETE' &&
        res.status() === 204
    ),
    page.getByRole('button', { name: /^Delete$/ }).first().click()
  ]);

  await expect(page.getByText('Customer email is required')).toHaveCount(0);
  await expect(page.getByText('Order deleted')).toBeVisible();
  expect(deleteCount).toBe(1);
});
