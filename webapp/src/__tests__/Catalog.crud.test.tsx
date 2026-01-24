import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import CatalogManage from '../views/CatalogManage';
import { createProduct, deleteProduct, listProducts, updateProduct } from '../api/client';

vi.mock('../api/client', () => ({
  listProducts: vi.fn(),
  createProduct: vi.fn(),
  updateProduct: vi.fn(),
  deleteProduct: vi.fn()
}));

const mockedListProducts = vi.mocked(listProducts);
const mockedCreateProduct = vi.mocked(createProduct);
const mockedUpdateProduct = vi.mocked(updateProduct);
const mockedDeleteProduct = vi.mocked(deleteProduct);

const baseProduct = {
  id: 'p-1',
  sku: 'SKU-1',
  name: 'Base Product',
  description: 'A starter item',
  price: 10,
  currency: 'USD',
  category: 'General',
  active: true
};

describe('Catalog CRUD view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('creates, updates, and deletes products with feedback', async () => {
    const createdProduct = { ...baseProduct, id: 'p-2', name: 'New Product', sku: 'SKU-2' };
    const updatedProduct = { ...createdProduct, name: 'Updated Product', price: 42 };

    mockedListProducts
      .mockResolvedValueOnce([baseProduct]) // initial
      .mockResolvedValueOnce([baseProduct, createdProduct]) // after create
      .mockResolvedValueOnce([baseProduct, updatedProduct]); // after update

    mockedCreateProduct.mockResolvedValue(createdProduct);
    mockedUpdateProduct.mockResolvedValue(updatedProduct);
    mockedDeleteProduct.mockResolvedValue();

    render(
      <MemoryRouter>
        <CatalogManage />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('Base Product')).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: /New Product/i }));

    // Create
    fireEvent.change(screen.getByLabelText(/^SKU/i), { target: { value: 'SKU-2' } });
    fireEvent.change(screen.getByLabelText(/^Name/i), { target: { value: 'New Product' } });
    fireEvent.change(screen.getByLabelText(/Description/i), { target: { value: 'Brand new' } });
    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: '20' } });
    fireEvent.change(screen.getByLabelText(/Currency/i), { target: { value: 'USD' } });
    fireEvent.change(screen.getByLabelText(/Category/i), { target: { value: 'General' } });
    fireEvent.change(screen.getByLabelText(/Active/i), { target: { value: 'true' } });
    fireEvent.submit(screen.getByTestId('product-form'));

    await waitFor(() => expect(mockedCreateProduct).toHaveBeenCalled());
    await waitFor(() => expect(screen.getAllByText('New Product').length).toBeGreaterThan(0));

    // Update
    fireEvent.click(screen.getAllByRole('button', { name: /Edit/i })[0]);

    fireEvent.change(screen.getByLabelText(/^Name/i), { target: { value: 'Updated Product' } });
    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: '42' } });
    fireEvent.submit(screen.getByTestId('product-form'));

    await waitFor(() => expect(mockedUpdateProduct).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('Updated Product')).toBeInTheDocument());

    // Delete
    fireEvent.click(screen.getAllByRole('button', { name: /Delete/i })[0]);
    fireEvent.click(screen.getByRole('button', { name: /Delete Product/i }));

    await waitFor(() => expect(mockedDeleteProduct).toHaveBeenCalled());
    await waitFor(() => expect(screen.queryByText('Base Product')).not.toBeInTheDocument());
  });

  it('shows an error message when create fails', async () => {
    mockedListProducts.mockResolvedValueOnce([baseProduct]).mockResolvedValue([baseProduct]);
    mockedCreateProduct.mockRejectedValue(new Error('fail'));

    render(
      <MemoryRouter>
        <CatalogManage />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('Base Product')).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: /New Product/i }));

    // Fill required fields so submit fires and hits the mocked error
    fireEvent.change(screen.getByLabelText(/^SKU/i), { target: { value: 'ERR-1' } });
    fireEvent.change(screen.getByLabelText(/^Name/i), { target: { value: 'Err Product' } });
    fireEvent.change(screen.getByLabelText(/Description/i), { target: { value: 'Broken' } });
    fireEvent.change(screen.getByLabelText(/Price/i), { target: { value: '5' } });
    fireEvent.change(screen.getByLabelText(/Currency/i), { target: { value: 'USD' } });
    fireEvent.change(screen.getByLabelText(/Category/i), { target: { value: 'Test' } });
    fireEvent.change(screen.getByLabelText(/Active/i), { target: { value: 'true' } });

    fireEvent.submit(screen.getByTestId('product-form'));

    await waitFor(() => expect(screen.getAllByText(/Failed to create product/i).length).toBeGreaterThan(0));
  });
});
