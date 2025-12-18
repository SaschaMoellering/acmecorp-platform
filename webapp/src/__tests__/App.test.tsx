import { describe, expect, it } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen } from '@testing-library/react';
import App from '../App';

describe('App shell', () => {
  it('renders core navigation without crashing', () => {
    const { container } = render(
      <MemoryRouter initialEntries={['/']}>
        <App />
      </MemoryRouter>
    );
    expect(container.textContent).toMatch(/AcmeCorp Platform/i);
    expect(screen.getAllByText(/AcmeCorp Platform/i).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('link', { name: /Dashboard/i }).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('link', { name: /Orders/i }).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('link', { name: /Catalog/i }).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('link', { name: /Analytics/i })[0]).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: /System/i })[0]).toBeInTheDocument();
  });
});
