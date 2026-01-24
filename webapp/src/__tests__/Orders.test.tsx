import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import Orders from '../views/Orders';
import { listOrders } from '../api/client';

vi.mock('../api/client', () => ({
  listOrders: vi.fn()
}));

const mockOrders = [
  {
    id: 10,
    orderNumber: 'ORD-10',
    customerEmail: 'orders@example.com',
    status: 'CONFIRMED',
    totalAmount: 99,
    currency: 'USD',
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    items: []
  }
];

const mockedListOrders = vi.mocked(listOrders);

describe('Orders view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders fetched orders', async () => {
    mockedListOrders.mockResolvedValue(mockOrders);

    render(
      <MemoryRouter>
        <Orders />
      </MemoryRouter>
    );

    expect(screen.getByText(/Loading orders/i)).toBeInTheDocument();
    await waitFor(() => expect(screen.getByText('ORD-10')).toBeInTheDocument());
    expect(screen.getByText('orders@example.com')).toBeInTheDocument();
    expect(mockedListOrders).toHaveBeenCalled();
  });

  it('shows an error when the API fails', async () => {
    mockedListOrders.mockRejectedValue(new Error('boom'));

    render(
      <MemoryRouter>
        <Orders />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText(/Unable to load orders/i)).toBeInTheDocument());
  });
});
