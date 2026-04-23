import { test, expect } from '@playwright/test';

test('clicking Edit opens the inline editor with visible feedback', async ({ page }) => {
  const ordersResponse = [
    {
      id: 1,
      orderNumber: 'ORD-E2E-EDIT-1',
      customerEmail: 'edit-target@example.com',
      status: 'NEW',
      totalAmount: 100,
      currency: 'USD',
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
      items: [{ productId: 'p-1', quantity: 1 }]
    }
  ];

  await page.route('**/api/gateway/orders**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    if (req.method() === 'GET' && url.searchParams.has('page')) {
      return route.fulfill({
        json: { content: ordersResponse, page: 0, size: 20, totalElements: ordersResponse.length, totalPages: 1 }
      });
    }
    return route.fallback();
  });

  await page.goto('/orders');
  await page.getByRole('button', { name: /^Edit$/ }).first().click();

  await expect(page.getByText('Editing order #1')).toBeVisible();
  await expect(page.getByText('Edit Order #1')).toBeVisible();
  await expect(page.getByRole('button', { name: /Update Order/i })).toBeVisible();
});
