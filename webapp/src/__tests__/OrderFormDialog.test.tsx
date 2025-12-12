import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import OrderFormDialog from '../components/forms/OrderFormDialog';

describe('OrderFormDialog', () => {
  it('shows validation messages when fields are missing', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    render(
      <OrderFormDialog title="Create Order" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    fireEvent.submit(screen.getByTestId('order-form'));

    await waitFor(() => expect(screen.getByText(/valid customer email/i)).toBeInTheDocument());
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('submits when the form is valid', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    render(
      <OrderFormDialog title="Create Order" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    fireEvent.change(screen.getByLabelText(/Customer Email/i), { target: { value: 'valid@example.com' } });
    fireEvent.change(screen.getByLabelText(/^Product ID/i), { target: { value: 'p-1' } });
    fireEvent.change(screen.getByLabelText(/Quantity/i), { target: { value: '1' } });
    fireEvent.change(screen.getByLabelText(/Status/i), { target: { value: 'NEW' } });

    fireEvent.submit(screen.getByTestId('order-form'));

    await waitFor(() => expect(onSubmit).toHaveBeenCalled());
  });
});
