import { describe, expect, it } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { render, screen } from '@testing-library/react';
import App from '../App';

describe('App shell', () => {
  it('renders core navigation without crashing', () => {
    render(
      <MemoryRouter initialEntries={['/']}>
        <App />
      </MemoryRouter>
    );
    expect(screen.getByText(/AcmeCorp Platform/i)).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /Dashboard/i })).toBeInTheDocument();
    expect(screen.getAllByRole('link', { name: /Orders/i }).length).toBeGreaterThan(0);
    expect(screen.getAllByRole('link', { name: /Catalog/i }).length).toBeGreaterThan(0);
    expect(screen.getByRole('link', { name: /Analytics/i })).toBeInTheDocument();
    expect(screen.getByRole('link', { name: /System/i })).toBeInTheDocument();
  });
});
