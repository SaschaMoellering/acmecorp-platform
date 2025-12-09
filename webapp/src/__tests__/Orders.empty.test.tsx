import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import Orders from '../views/Orders';
import { listOrders } from '../api/client';

vi.mock('../api/client', () => ({
  listOrders: vi.fn()
}));

const mockedListOrders = vi.mocked(listOrders);

describe('Orders view - empty state', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('shows a friendly empty message when no orders exist', async () => {
    mockedListOrders.mockResolvedValue([]);

    render(
      <MemoryRouter>
        <Orders />
      </MemoryRouter>
    );

    expect(screen.getByText(/Loading orders/i)).toBeInTheDocument();

    await waitFor(() => {
      expect(screen.getByText(/No orders available/i)).toBeInTheDocument();
    });
  });
});
