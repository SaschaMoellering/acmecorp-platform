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

test('orders create shows validation feedback and submits successfully', async ({ page }) => {
  ordersResponse = [];
  let postCount = 0;

  await page.route('**/api/gateway/orders**', async (route) => {
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
      postCount += 1;
      const body = await req.postDataJSON();
      const nextId = ordersResponse.length + 1;
      const now = new Date().toISOString();
      const created = {
        id: nextId,
        orderNumber: `ORD-E2E-${nextId}`,
        customerEmail: body.customerEmail,
        status: body.status ?? 'NEW',
        totalAmount: 100,
        currency: 'USD',
        createdAt: now,
        updatedAt: now,
        items: body.items ?? []
      };
      ordersResponse = [...ordersResponse, created];
      return route.fulfill({ status: 201, json: created });
    }

    return route.fallback();
  });

  await page.goto('/orders');

  await page.getByRole('button', { name: /Create Order/i }).click();
  await expect(page.getByText('Customer email is required')).toBeVisible();
  expect(postCount).toBe(0);

  const email = `create-feedback-${Date.now()}@example.com`;
  await page.getByLabel(/Customer Email/i).fill(email);
  await page.getByLabel(/^Product ID/i).fill('p-1');
  await page.getByLabel(/Quantity/i).fill('1');

  await Promise.all([
    page.waitForResponse((res) => res.url().includes('/api/gateway/orders') && res.request().method() === 'POST' && res.ok()),
    page.getByRole('button', { name: /Create Order/i }).click()
  ]);

  await expect(page.locator('form').getByText('Order saved')).toBeVisible();
  await expect(page.getByRole('row', { name: new RegExp(email, 'i') })).toBeVisible();
  expect(postCount).toBe(1);
});
