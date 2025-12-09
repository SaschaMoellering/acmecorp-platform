import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import Orders from '../views/Orders';
import { createOrder, deleteOrder, listOrders, updateOrder } from '../api/client';

vi.mock('../api/client', () => ({
  listOrders: vi.fn(),
  createOrder: vi.fn(),
  updateOrder: vi.fn(),
  deleteOrder: vi.fn()
}));

const mockedListOrders = vi.mocked(listOrders);
const mockedCreateOrder = vi.mocked(createOrder);
const mockedUpdateOrder = vi.mocked(updateOrder);
const mockedDeleteOrder = vi.mocked(deleteOrder);

const baseOrder = {
  id: 10,
  orderNumber: 'ORD-10',
  customerEmail: 'orders@example.com',
  status: 'NEW',
  totalAmount: 99,
  currency: 'USD',
  createdAt: '2025-01-01T00:00:00Z',
  updatedAt: '2025-01-01T00:00:00Z',
  items: [
    {
      id: 1,
      productId: 'p-1',
      productName: 'Performance Laptop',
      unitPrice: 99,
      quantity: 1,
      lineTotal: 99
    }
  ]
};

describe('Orders CRUD view', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  it('creates, updates, and deletes orders with feedback', async () => {
    const createdOrder = { ...baseOrder, id: 11, orderNumber: 'ORD-11', customerEmail: 'new@example.com' };
    const updatedOrder = { ...createdOrder, customerEmail: 'updated@example.com', status: 'CONFIRMED' };

    // listOrders is called on mount, after create, and after update
    mockedListOrders
      .mockResolvedValueOnce([baseOrder]) // initial load
      .mockResolvedValueOnce([baseOrder, createdOrder]) // after create
      .mockResolvedValueOnce([baseOrder, updatedOrder]); // after update

    mockedCreateOrder.mockResolvedValue(createdOrder);
    mockedUpdateOrder.mockResolvedValue(updatedOrder);
    mockedDeleteOrder.mockResolvedValue();

    render(
      <MemoryRouter>
        <Orders />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('ORD-10')).toBeInTheDocument());

    // Create
    fireEvent.change(screen.getByLabelText(/Customer Email/i), { target: { value: 'new@example.com' } });
    fireEvent.change(screen.getByLabelText(/^Product ID/i), { target: { value: 'p-2' } });
    fireEvent.change(screen.getByLabelText(/Quantity/i), { target: { value: '2' } });
    fireEvent.change(screen.getByLabelText(/Status/i), { target: { value: 'NEW' } });
    fireEvent.click(screen.getByRole('button', { name: /Create Order/i }));

    await waitFor(() => expect(mockedCreateOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('ORD-11')).toBeInTheDocument());

    // Update
    fireEvent.click(screen.getAllByRole('button', { name: /Edit/i })[0]);

    const emailInputs = screen.getAllByLabelText(/Customer Email/i);
    const statusSelects = screen.getAllByLabelText(/Status/i);

    fireEvent.change(emailInputs[emailInputs.length - 1], { target: { value: 'updated@example.com' } });
    fireEvent.change(statusSelects[statusSelects.length - 1], { target: { value: 'CONFIRMED' } });
    fireEvent.click(screen.getByRole('button', { name: /Update Order/i }));

    await waitFor(() => expect(mockedUpdateOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/updated@example.com/i)).toBeInTheDocument());

    // Delete
    const confirmSpy = vi.spyOn(window, 'confirm').mockReturnValue(true);
    fireEvent.click(screen.getAllByRole('button', { name: /Delete/i })[0]);

    await waitFor(() => expect(mockedDeleteOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.queryByText('ORD-10')).not.toBeInTheDocument());

    confirmSpy.mockRestore();
  });

  it('shows an error message when create fails', async () => {
    mockedListOrders.mockResolvedValueOnce([baseOrder]).mockResolvedValue([baseOrder]);
    mockedCreateOrder.mockRejectedValue(new Error('fail'));

    render(
      <MemoryRouter>
        <Orders />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('ORD-10')).toBeInTheDocument());

    fireEvent.change(screen.getByLabelText(/Customer Email/i), { target: { value: 'err@example.com' } });
    fireEvent.change(screen.getByLabelText(/^Product ID/i), { target: { value: 'p-x' } });
    fireEvent.change(screen.getByLabelText(/Quantity/i), { target: { value: '1' } });
    fireEvent.change(screen.getByLabelText(/Status/i), { target: { value: 'NEW' } });

    fireEvent.click(screen.getByRole('button', { name: /Create Order/i }));

    await waitFor(() => expect(screen.getByText(/Failed to save order/i)).toBeInTheDocument());
  });
});
