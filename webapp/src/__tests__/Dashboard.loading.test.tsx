import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import Dashboard from '../views/Dashboard';
import { fetchCatalog, fetchOrders, type Order, type Product } from '../api/client';

function deferred<T>() {
  let resolve!: (value: T | PromiseLike<T>) => void;
  let reject!: (reason?: unknown) => void;
  const promise = new Promise<T>((res, rej) => {
    resolve = res;
    reject = rej;
  });
  return { promise, resolve, reject };
}

vi.mock('../api/client', () => ({
  fetchOrders: vi.fn(),
  fetchCatalog: vi.fn()
}));

const mockedFetchOrders = vi.mocked(fetchOrders);
const mockedFetchCatalog = vi.mocked(fetchCatalog);

describe('Dashboard view - loading state', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows a loading indicator before rendering content', async () => {
    const ordersDeferred = deferred<Order[]>();
    const catalogDeferred = deferred<Product[]>();

    mockedFetchOrders.mockReturnValue(ordersDeferred.promise);
    mockedFetchCatalog.mockReturnValue(catalogDeferred.promise);

    render(<Dashboard />);

    expect(screen.getByText(/Loading dashboard/i)).toBeInTheDocument();

    ordersDeferred.resolve([
      {
        id: 1,
        orderNumber: 'ORD-1',
        customerEmail: 'demo@example.com',
        status: 'CONFIRMED',
        totalAmount: 42,
        currency: 'USD',
        createdAt: '2025-01-01T00:00:00Z',
        updatedAt: '2025-01-01T00:00:00Z'
      }
    ]);
    catalogDeferred.resolve([
      {
        id: 'p1',
        sku: 'SKU-1',
        name: 'Demo',
        description: 'Demo product',
        price: 10,
        currency: 'USD',
        category: 'General',
        active: true
      }
    ]);

    await waitFor(() => {
      expect(screen.queryByText(/Loading dashboard/i)).not.toBeInTheDocument();
    });

    expect(screen.getByText(/Active Products/i)).toBeInTheDocument();
    expect(screen.getAllByText(/Recent Orders/i)[0]).toBeInTheDocument();
  });
});
