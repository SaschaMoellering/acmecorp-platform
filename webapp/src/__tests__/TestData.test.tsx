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

    const { container } = render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>
    );

    const buttons = container.querySelectorAll('button');
    const loadButton = Array.from(buttons).find(btn => btn.textContent?.includes('Load Demo Data'))!;
    fireEvent.click(loadButton);
    await waitFor(() => expect(mockedSeed).toHaveBeenCalled());
    await waitFor(() => expect(container.textContent).toMatch(/Demo data loaded/i));
  });

  it('shows error message when seeding fails', async () => {
    mockedSeed.mockRejectedValue(new Error('fail'));

    const { container } = render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>
    );

    const buttons = container.querySelectorAll('button');
    const loadButton = Array.from(buttons).find(btn => btn.textContent?.includes('Load Demo Data'))!;
    fireEvent.click(loadButton);
    await waitFor(() => expect(container.textContent).toMatch(/Failed to seed demo data/i));
  });
});
