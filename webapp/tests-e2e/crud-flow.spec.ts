import { test, expect } from '@playwright/test';

test('seed data and perform basic CRUD actions', async ({ page }) => {
  let products = [
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

  let orders = [
    {
      id: 1,
      orderNumber: 'ORD-1',
      customerEmail: 'demo@example.com',
      status: 'CONFIRMED',
      totalAmount: 1999,
      currency: 'USD',
      createdAt: '2024-01-01T00:00:00Z',
      updatedAt: '2024-01-01T00:00:00Z',
      items: [
        { id: 1, productId: 'p-1', productName: 'Demo Laptop', unitPrice: 1999, quantity: 1, lineTotal: 1999 }
      ]
    }
  ];

  await page.route('**/api/gateway/catalog**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const method = req.method();
    const parts = url.pathname.split('/');
    const id = parts[parts.length - 1];

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

  await page.route('**/api/gateway/orders**', async (route) => {
    const req = route.request();
    const url = new URL(req.url());
    const method = req.method();
    const parts = url.pathname.split('/');
    const idPart = parts[parts.length - 1];

    if (method === 'GET') {
      if (url.pathname.endsWith('/latest') || url.pathname.endsWith('/orders')) {
        return route.fulfill({ json: orders });
      }
      const order = orders.find((o) => String(o.id) === idPart);
      return route.fulfill({ status: order ? 200 : 404, json: order ?? {} });
    }

    if (method === 'POST') {
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

  await page.route('**/api/gateway/seed/catalog', (route) => {
    products = [
      {
        id: 'p-1',
        sku: 'SKU-001',
        name: 'Demo Laptop',
        description: 'High-performance laptop.',
        price: 1999,
        currency: 'USD',
        category: 'Hardware',
        active: true
      },
      {
        id: 'p-2',
        sku: 'SKU-002',
        name: 'Cloud Subscription',
        description: 'Managed capacity.',
        price: 499,
        currency: 'USD',
        category: 'Subscriptions',
        active: true
      }
    ];
    return route.fulfill({ status: 200, body: '' });
  });

  await page.route('**/api/gateway/seed/orders', (route) => {
    orders = [
      {
        id: 1,
        orderNumber: 'ORD-1',
        customerEmail: 'demo@example.com',
        status: 'CONFIRMED',
        totalAmount: 1999,
        currency: 'USD',
        createdAt: '2024-01-01T00:00:00Z',
        updatedAt: '2024-01-01T00:00:00Z',
        items: [
          { id: 1, productId: 'p-1', productName: 'Demo Laptop', unitPrice: 1999, quantity: 1, lineTotal: 1999 }
        ]
      },
      {
        id: 2,
        orderNumber: 'ORD-2',
        customerEmail: 'seed@example.com',
        status: 'NEW',
        totalAmount: 499,
        currency: 'USD',
        createdAt: '2024-01-02T00:00:00Z',
        updatedAt: '2024-01-02T00:00:00Z',
        items: [{ id: 2, productId: 'p-2', productName: 'Cloud Subscription', unitPrice: 499, quantity: 1, lineTotal: 499 }]
      }
    ];
    return route.fulfill({ status: 200, body: '' });
  });

  await page.goto('/test-data');

  await page.getByRole('button', { name: /Seed Catalog Demo Data/i }).click();
  await expect(page.getByText(/Catalog demo data seeded/i)).toBeVisible();

  await page.getByRole('button', { name: /Seed Orders Demo Data/i }).click();
  await expect(page.getByText(/Orders demo data seeded/i)).toBeVisible();

  await page.getByRole('link', { name: 'Catalog' }).click();
  await expect(page.getByText('Demo Laptop')).toBeVisible();

  // Create a product
  await page.getByLabel('SKU').fill('SKU-999');
  await page.getByLabel('Name').fill('Playwright Product');
  await page.getByLabel('Description').fill('Created during E2E');
  await page.getByLabel('Price').fill('123');
  await page.getByLabel('Currency').fill('USD');
  await page.getByLabel('Category').fill('Testing');
  await page.getByLabel('Active').selectOption('true');
  await page.getByRole('button', { name: /Create Product/i }).click();
  await expect(page.getByText('Playwright Product')).toBeVisible();

  // Delete first product
  page.once('dialog', (dialog) => dialog.accept());
  await page.getByRole('button', { name: 'Delete' }).first().click();
  await expect(page.getByText('Demo Laptop')).toHaveCount(0);
  await expect(page.getByText('Playwright Product')).toBeVisible();

  await page.getByRole('link', { name: 'Orders' }).click();
  await expect(page.getByText(/ORD-2/)).toBeVisible();

  await page.getByLabel(/Customer Email/i).fill('browser@example.com');
  await page.getByLabel(/^Product ID/i).fill('p-2');
  await page.getByLabel(/Quantity/i).fill('2');
  await page.getByLabel(/Status/i).selectOption('NEW');
  await page.getByRole('button', { name: /Create Order/i }).click();

  await expect(page.getByText(/browser@example.com/i)).toBeVisible();
});
