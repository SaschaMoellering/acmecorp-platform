import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen, waitFor } from '@testing-library/react';
import SystemStatus from '../views/SystemStatus';
import { fetchSystemStatus } from '../api/client';

vi.mock('../api/client', () => ({
  fetchSystemStatus: vi.fn()
}));

const mockedFetchSystemStatus = vi.mocked(fetchSystemStatus);

describe('SystemStatus view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('renders service statuses', async () => {
    mockedFetchSystemStatus.mockResolvedValue([
      { service: 'orders-service', status: 'OK' },
      { service: 'billing-service', status: 'DOWN' }
    ]);

    render(
      <MemoryRouter>
        <SystemStatus />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('orders-service')).toBeInTheDocument());
    expect(screen.getByText('billing-service')).toBeInTheDocument();
    expect(screen.getByText('DOWN')).toBeInTheDocument();
  });
});
