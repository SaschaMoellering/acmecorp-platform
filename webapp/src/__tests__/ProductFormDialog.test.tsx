import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import ProductFormDialog from '../components/forms/ProductFormDialog';

describe('ProductFormDialog', () => {
  it('validates required fields including price', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    const submitButton = screen.getByRole('button', { name: /Create Product/i });
    expect(submitButton).toBeDisabled();

    fireEvent.submit(screen.getByTestId('product-form'));
    await waitFor(() => expect(screen.getByText(/SKU is required/i)).toBeInTheDocument());
    expect(screen.getByText(/Price is required/i)).toBeInTheDocument();
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('enables submit when price becomes valid', () => {
    render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={vi.fn()} />
    );

    const submitButton = screen.getByRole('button', { name: /Create Product/i });
    expect(submitButton).toBeDisabled();

    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: 'abc' } });
    expect(submitButton).toBeDisabled();

    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: '49,99' } });
    expect(submitButton).not.toBeDisabled();
  });

  it('submits when valid data is provided', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    fireEvent.change(screen.getByLabelText(/^SKU/i), { target: { value: 'SKU-1' } });
    fireEvent.change(screen.getByLabelText(/^Name/i), { target: { value: 'Product' } });
    fireEvent.change(screen.getByLabelText(/Description/i), { target: { value: 'Desc' } });
    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: '19,90' } });
    fireEvent.change(screen.getByLabelText(/Currency/i), { target: { value: 'USD' } });
    fireEvent.change(screen.getByLabelText(/Category/i), { target: { value: 'General' } });
    fireEvent.change(screen.getByLabelText(/Active/i), { target: { value: 'true' } });

    fireEvent.submit(screen.getByTestId('product-form'));

    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith(expect.objectContaining({ price: 19.9 })));
  });
});
