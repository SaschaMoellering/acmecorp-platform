import { describe, expect, it, vi, beforeEach, afterEach } from 'vitest'
import { MemoryRouter } from 'react-router-dom'
import { cleanup, fireEvent, render, screen, waitFor } from '@testing-library/react'
import SeedTools from '../views/SeedTools'
import { seedDemoData } from '../api/client'

vi.mock('../api/client', () => ({
  seedDemoData: vi.fn(),
}))

const mockedSeed = vi.mocked(seedDemoData)

describe('SeedTools view', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  // IMPORTANT:
  // Ensure Testing Library DOM is reset between tests.
  // Otherwise multiple renders accumulate and queries like getByRole become ambiguous.
  afterEach(() => {
    cleanup()
  })

  it('triggers seeding with success messages', async () => {
    mockedSeed.mockResolvedValue({ catalogSeeded: true, ordersSeeded: true })

    render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>,
    )

    fireEvent.click(screen.getByRole('button', { name: /Load Demo Data/i }))

    await waitFor(() => expect(mockedSeed).toHaveBeenCalledTimes(1))
    await waitFor(() =>
      expect(screen.getByText(/Demo data loaded/i)).toBeInTheDocument(),
    )
  })

  it('shows error message when seeding fails', async () => {
    mockedSeed.mockRejectedValue(new Error('fail'))

    render(
      <MemoryRouter>
        <SeedTools />
      </MemoryRouter>,
    )

    fireEvent.click(screen.getByRole('button', { name: /Load Demo Data/i }))

    await waitFor(() =>
      expect(screen.getByText(/Failed to seed demo data/i)).toBeInTheDocument(),
    )
  })
})
