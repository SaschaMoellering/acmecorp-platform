import { describe, expect, it, vi } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import Analytics from '../views/Analytics';

vi.mock('../api/client', async () => {
  const actual = await vi.importActual<any>('../api/client');
  return {
    ...actual,
    fetchAnalyticsCounters: vi.fn().mockResolvedValue({
      'orders.created': 7,
      'orders.confirmed': 5,
      'billing.invoice.paid': 3,
      'notification.sent': 9
    })
  };
});

describe('Analytics view', () => {
  it('renders KPI tiles from API data', async () => {
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
  });
});
