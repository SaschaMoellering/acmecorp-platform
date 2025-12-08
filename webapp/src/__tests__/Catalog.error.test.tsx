import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import Catalog from '../views/Catalog';
import { fetchCatalog } from '../api/client';

vi.mock('../api/client', () => ({
  fetchCatalog: vi.fn()
}));

const mockedFetchCatalog = vi.mocked(fetchCatalog);

describe('Catalog view - error handling', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders a fallback when the catalog API fails', async () => {
    mockedFetchCatalog.mockRejectedValue(new Error('network down'));

    render(
      <MemoryRouter>
        <Catalog />
      </MemoryRouter>
    );

    await waitFor(() => {
      expect(screen.getByText(/Failed to load catalog/i)).toBeInTheDocument();
    });
    expect(screen.getByText(/No products match the filters/i)).toBeInTheDocument();
  });
});
