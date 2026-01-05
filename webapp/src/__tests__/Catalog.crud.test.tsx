import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
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

    const [newProductButton] = screen.getAllByRole('button', { name: /New Product/i });
    // Use the toolbar action in case multiple "New Product" buttons are present.
    fireEvent.click(newProductButton);

    // Create
    const createDialog = await screen.findByRole('dialog');
    const createForm = within(createDialog);

    fireEvent.change(createForm.getByLabelText(/^SKU/i), { target: { value: 'SKU-2' } });
    fireEvent.change(createForm.getByLabelText(/^Name/i), { target: { value: 'New Product' } });
    fireEvent.change(createForm.getByLabelText(/Description/i), { target: { value: 'Brand new' } });
    fireEvent.change(createForm.getByLabelText(/Price/i), { target: { value: '20' } });
    fireEvent.change(createForm.getByLabelText(/Currency/i), { target: { value: 'USD' } });
    fireEvent.change(createForm.getByLabelText(/Category/i), { target: { value: 'General' } });
    fireEvent.change(createForm.getByLabelText(/Active/i), { target: { value: 'true' } });
    fireEvent.submit(createForm.getByTestId('product-form'));

    await waitFor(() => expect(mockedCreateProduct).toHaveBeenCalled());
    await waitFor(() => expect(screen.getAllByText('New Product').length).toBeGreaterThan(0));

    // Update
    fireEvent.click(screen.getAllByRole('button', { name: /Edit/i })[0]);

    const editDialog = await screen.findByRole('dialog');
    const editForm = within(editDialog);

    fireEvent.change(editForm.getByLabelText(/^Name/i), { target: { value: 'Updated Product' } });
    fireEvent.change(editForm.getByLabelText(/Price/i), { target: { value: '42' } });
    fireEvent.submit(editForm.getByTestId('product-form'));

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
    mockedCreateProduct.mockRejectedValueOnce(new Error('fail'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      render(
        <MemoryRouter>
          <CatalogManage />
        </MemoryRouter>
      );

      await screen.findByText('Base Product');

      const [newProductButton] = screen.getAllByRole('button', { name: /New Product/i });
      // Use the toolbar action in case multiple "New Product" buttons are present.
      fireEvent.click(newProductButton);

      // Fill required fields so submit fires and hits the mocked error
      const dialog = await screen.findByRole('dialog');
      const dialogQueries = within(dialog);

      fireEvent.change(dialogQueries.getByLabelText(/^SKU/i), { target: { value: 'ERR-1' } });
      fireEvent.change(dialogQueries.getByLabelText(/^Name/i), { target: { value: 'Err Product' } });
      fireEvent.change(dialogQueries.getByLabelText(/Description/i), { target: { value: 'Broken' } });
      fireEvent.change(dialogQueries.getByLabelText(/Price/i), { target: { value: '5' } });
      fireEvent.change(dialogQueries.getByLabelText(/Currency/i), { target: { value: 'USD' } });
      fireEvent.change(dialogQueries.getByLabelText(/Category/i), { target: { value: 'Test' } });
      fireEvent.change(dialogQueries.getByLabelText(/Active/i), { target: { value: 'true' } });

      fireEvent.submit(dialogQueries.getByTestId('product-form'));

      await dialogQueries.findByText(/Failed to create product/i);
    } finally {
      // Silence intentional error logging from the rejected mock.
      consoleError.mockRestore();
    }
  });
});
