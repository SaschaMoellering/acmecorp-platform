import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import Dashboard from '../views/Dashboard';
import { fetchCatalog, fetchOrders } from '../api/client';

vi.mock('../api/client', () => ({
  fetchOrders: vi.fn(),
  fetchCatalog: vi.fn()
}));

const mockOrders = [
  {
    id: 1,
    orderNumber: 'ORD-100',
    customerEmail: 'dash@example.com',
    status: 'NEW',
    totalAmount: 42,
    currency: 'USD',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    items: []
  }
];

const mockProducts = [
  { id: 'p1', sku: 'SKU-1', name: 'Demo', description: 'Demo product', price: 10, currency: 'USD', category: 'demo', active: true },
  { id: 'p2', sku: 'SKU-2', name: 'Another', description: 'Another product', price: 20, currency: 'USD', category: 'demo', active: true }
];

const mockedFetchOrders = vi.mocked(fetchOrders);
const mockedFetchCatalog = vi.mocked(fetchCatalog);

describe('Dashboard view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockedFetchOrders.mockResolvedValue(mockOrders);
    mockedFetchCatalog.mockResolvedValue(mockProducts);
  });

  it('shows KPI tiles and recent orders table', async () => {
    render(
      <MemoryRouter>
        <Dashboard />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText(/Active Products/i)).toBeInTheDocument());

    expect(screen.getByText('2')).toBeInTheDocument();
    expect(screen.getByText('ORD-100')).toBeInTheDocument();
    expect(screen.getByText('dash@example.com')).toBeInTheDocument();
    expect(mockedFetchOrders).toHaveBeenCalled();
    expect(mockedFetchCatalog).toHaveBeenCalled();
  });
});
