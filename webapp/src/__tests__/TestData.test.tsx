import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import TestData from '../views/TestData';
import { seedCatalogDemoData, seedOrdersDemoData } from '../api/client';

vi.mock('../api/client', () => ({
  seedCatalogDemoData: vi.fn(),
  seedOrdersDemoData: vi.fn()
}));

const mockedSeedCatalog = vi.mocked(seedCatalogDemoData);
const mockedSeedOrders = vi.mocked(seedOrdersDemoData);

describe('TestData view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('triggers catalog and orders seeding with success messages', async () => {
    mockedSeedCatalog.mockResolvedValue();
    mockedSeedOrders.mockResolvedValue();

    render(
      <MemoryRouter>
        <TestData />
      </MemoryRouter>
    );

    fireEvent.click(screen.getByRole('button', { name: /Seed Catalog Demo Data/i }));
    await waitFor(() => expect(mockedSeedCatalog).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/Catalog demo data seeded/i)).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: /Seed Orders Demo Data/i }));
    await waitFor(() => expect(mockedSeedOrders).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/Orders demo data seeded/i)).toBeInTheDocument());
  });

  it('shows error message when seeding fails', async () => {
    mockedSeedCatalog.mockRejectedValue(new Error('fail'));

    render(
      <MemoryRouter>
        <TestData />
      </MemoryRouter>
    );

    fireEvent.click(screen.getByRole('button', { name: /Seed Catalog Demo Data/i }));
    await waitFor(() => expect(screen.getByText(/Failed to seed catalog data/i)).toBeInTheDocument());
  });
});
