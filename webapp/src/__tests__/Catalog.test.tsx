import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import Catalog from '../views/Catalog';
import { listProducts } from '../api/client';

vi.mock('../api/client', () => ({
  listProducts: vi.fn()
}));

const mockProducts = [
  { id: '1', sku: 'SKU-1', name: 'Phone', description: 'Smart phone', price: 499, currency: 'USD', category: 'electronics', active: true },
  { id: '2', sku: 'SKU-2', name: 'Shoes', description: 'Running shoes', price: 99, currency: 'USD', category: 'apparel', active: true }
];

const mockedListProducts = vi.mocked(listProducts);

describe('Catalog view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockedListProducts.mockResolvedValue(mockProducts);
  });

  it('filters products by text and category', async () => {
    render(
      <MemoryRouter>
        <Catalog />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('Phone')).toBeInTheDocument());

    fireEvent.change(screen.getByPlaceholderText(/Search products/i), { target: { value: 'shoe' } });
    await waitFor(() => expect(screen.getByText('Shoes')).toBeInTheDocument());
    expect(screen.queryByText('Phone')).toBeNull();

    fireEvent.change(screen.getByDisplayValue('All categories'), { target: { value: 'electronics' } });
    expect(screen.getByText(/No products match/i)).toBeInTheDocument();
  });
});
