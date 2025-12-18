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

    const { container } = render(
      <OrderFormDialog title="Create Order" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    const form = container.querySelector('[data-testid="order-form"]')!;
    const emailInput = form.querySelector('input[type="email"]');
    const inputs = form.querySelectorAll('input');
    const productInput = Array.from(inputs).find(input => input.type !== 'email' && input.type !== 'number');
    const numberInput = form.querySelector('input[type="number"]');
    const selectInput = form.querySelector('select');
    
    if (emailInput) fireEvent.change(emailInput, { target: { value: 'valid@example.com' } });
    if (productInput) fireEvent.change(productInput, { target: { value: 'p-1' } });
    if (numberInput) fireEvent.change(numberInput, { target: { value: '1' } });
    if (selectInput) fireEvent.change(selectInput, { target: { value: 'NEW' } });

    fireEvent.submit(form);

    await waitFor(() => expect(onSubmit).toHaveBeenCalled());
  });
});
