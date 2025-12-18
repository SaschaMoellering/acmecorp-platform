import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import Catalog from '../views/Catalog';
import { listProducts } from '../api/client';

vi.mock('../api/client', () => ({
  listProducts: vi.fn()
}));

const mockedListProducts = vi.mocked(listProducts);

describe('Catalog view - error handling', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders a fallback when the catalog API fails', async () => {
    mockedListProducts.mockRejectedValue(new Error('network down'));

    const { container } = render(
      <MemoryRouter>
        <Catalog />
      </MemoryRouter>
    );

    await waitFor(() => {
      expect(container.textContent).toMatch(/Failed to load catalog/i);
    });
    expect(screen.getAllByText(/No products match the filters/i).length).toBeGreaterThan(0);
  });
});
