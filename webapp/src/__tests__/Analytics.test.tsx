import { describe, expect, it, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import Analytics from '../views/Analytics';
import { fetchAnalyticsCounters } from '../api/client';

vi.mock('../api/client', () => ({
  fetchAnalyticsCounters: vi.fn()
}));

const mockedCounters = vi.mocked(fetchAnalyticsCounters);

describe('Analytics view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders KPI tiles from live API data', async () => {
    mockedCounters.mockResolvedValue({
      'orders.created': 7,
      'orders.confirmed': 5,
      'billing.invoice.paid': 3,
      'notification.sent': 9
    });

    render(
      <MemoryRouter>
        <Analytics />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText(/orders created/i)).toBeInTheDocument());
    expect(screen.getByText('7')).toBeInTheDocument();
    expect(screen.getByText('5')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
    expect(screen.getByText('9')).toBeInTheDocument();
    expect(screen.getByText(/live data/i)).toBeInTheDocument();
  });

  it('falls back to demo counters when API returns empty', async () => {
    mockedCounters.mockResolvedValue({});

    render(
      <MemoryRouter>
        <Analytics />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText(/demo data/i)).toBeInTheDocument());
  });
});
