import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import App from '../App';
import { fetchOrders, fetchCatalog, fetchAnalyticsCounters, fetchSystemStatus, fetchOrderById } from '../api/client';

vi.mock('../api/client', () => ({
  fetchOrders: vi.fn(),
  fetchCatalog: vi.fn(),
  fetchAnalyticsCounters: vi.fn(),
  fetchSystemStatus: vi.fn(),
  fetchOrderById: vi.fn()
}));

const mockOrders = [
  {
    id: 1,
    orderNumber: 'ORD-ROUTE',
    customerEmail: 'route@example.com',
    status: 'NEW',
    totalAmount: 1,
    currency: 'USD',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    items: []
  }
];

const mockedFetchOrders = vi.mocked(fetchOrders);
const mockedFetchCatalog = vi.mocked(fetchCatalog);
const mockedFetchAnalytics = vi.mocked(fetchAnalyticsCounters);
const mockedFetchStatus = vi.mocked(fetchSystemStatus);
const mockedFetchOrderById = vi.mocked(fetchOrderById);

describe('App routing', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockedFetchOrders.mockResolvedValue(mockOrders);
    mockedFetchCatalog.mockResolvedValue([]);
    mockedFetchAnalytics.mockResolvedValue({});
    mockedFetchStatus.mockResolvedValue([]);
    mockedFetchOrderById.mockResolvedValue(mockOrders[0] as any);
  });

  it('renders Orders page when navigating to /orders', async () => {
    render(
      <MemoryRouter initialEntries={['/orders']}>
        <App />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('ORD-ROUTE')).toBeInTheDocument());
    expect(mockedFetchOrders).toHaveBeenCalled();
  });

  it('redirects unknown routes to Dashboard', async () => {
    render(
      <MemoryRouter initialEntries={['/does-not-exist']}>
        <App />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText(/Active Products/i)).toBeInTheDocument());
  });
});
