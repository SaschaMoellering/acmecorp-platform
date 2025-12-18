import { describe, expect, it, vi } from 'vitest';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import ProductFormDialog from '../components/forms/ProductFormDialog';

describe('ProductFormDialog', () => {
  it('validates required fields including price', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    const { container } = render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    const submitButton = container.querySelector('button[type="submit"]')!;
    expect(submitButton).toBeDisabled();

    const form = container.querySelector('[data-testid="product-form"]')!;
    fireEvent.submit(form);
    await waitFor(() => expect(container.textContent).toMatch(/SKU is required/i));
    expect(container.textContent).toMatch(/Price is required/i);
    expect(onSubmit).not.toHaveBeenCalled();
  });

  it('enables submit when price becomes valid', () => {
    const { container } = render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={vi.fn()} />
    );

    const submitButton = container.querySelector('button[type="submit"]')!;
    expect(submitButton).toBeDisabled();

    const inputs = container.querySelectorAll('input');
    const priceInput = Array.from(inputs).find(input => input.type === 'text' && input.previousElementSibling?.textContent?.includes('Price'));
    if (priceInput) {
      fireEvent.change(priceInput, { target: { value: 'abc' } });
      expect(submitButton).toBeDisabled();

      fireEvent.change(priceInput, { target: { value: '49,99' } });
      expect(submitButton).not.toBeDisabled();
    }
  });

  it('submits when valid data is provided', async () => {
    const onSubmit = vi.fn().mockResolvedValue(undefined);

    const { container } = render(
      <ProductFormDialog title="Create Product" open mode="create" onClose={() => {}} onSubmit={onSubmit} />
    );

    const form = container.querySelector('[data-testid="product-form"]')!;
    const inputs = Array.from(form.querySelectorAll('input'));
    const textarea = form.querySelector('textarea')!;
    const select = form.querySelector('select')!;
    
    // Fill out all required fields
    fireEvent.change(inputs[0], { target: { value: 'SKU-1' } }); // SKU
    fireEvent.change(inputs[1], { target: { value: 'Product' } }); // Name
    fireEvent.change(textarea, { target: { value: 'Test Description' } }); // Description
    fireEvent.change(inputs[2], { target: { value: '19.90' } }); // Price
    fireEvent.change(inputs[3], { target: { value: 'USD' } }); // Currency
    fireEvent.change(inputs[4], { target: { value: 'General' } }); // Category
    fireEvent.change(select, { target: { value: 'true' } }); // Active

    fireEvent.submit(form);

    await waitFor(() => expect(onSubmit).toHaveBeenCalledWith(expect.objectContaining({ price: 19.9 })));
  });
});
