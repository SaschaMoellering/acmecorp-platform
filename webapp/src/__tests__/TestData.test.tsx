import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import SeedTools from '../views/SeedTools';
import { seedDemoData } from '../api/client';

vi.mock('../api/client', () => ({
  seedDemoData: vi.fn()
}));

const mockedSeed = vi.mocked(seedDemoData);

describe('SeedTools view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('triggers seeding with success messages', async () => {
    mockedSeed.mockResolvedValue({ catalogSeeded: true, ordersSeeded: true });

    render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>
    );

    fireEvent.click(screen.getByRole('button', { name: /Load Demo Data/i }));
    await waitFor(() => expect(mockedSeed).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/Demo data loaded/i)).toBeInTheDocument());
  });

  it('shows error message when seeding fails', async () => {
    mockedSeed.mockRejectedValue(new Error('fail'));

    render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>
    );

    fireEvent.click(screen.getByRole('button', { name: /Load Demo Data/i }));
    await waitFor(() => expect(screen.getByText(/Failed to seed demo data/i)).toBeInTheDocument());
  });
});
