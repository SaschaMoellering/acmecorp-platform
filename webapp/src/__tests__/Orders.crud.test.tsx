import { describe, expect, it, vi, beforeEach } from 'vitest';
import { MemoryRouter } from 'react-router-dom';
import { fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import OrdersManage from '../views/OrdersManage';
import { cancelOrder, confirmOrder, createOrder, deleteOrder, listOrders, updateOrder } from '../api/client';

vi.mock('../api/client', () => ({
  listOrders: vi.fn(),
  createOrder: vi.fn(),
  updateOrder: vi.fn(),
  deleteOrder: vi.fn(),
  confirmOrder: vi.fn(),
  cancelOrder: vi.fn()
}));

const mockedListOrders = vi.mocked(listOrders);
const mockedCreateOrder = vi.mocked(createOrder);
const mockedUpdateOrder = vi.mocked(updateOrder);
const mockedDeleteOrder = vi.mocked(deleteOrder);
const mockedConfirmOrder = vi.mocked(confirmOrder);
const mockedCancelOrder = vi.mocked(cancelOrder);

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
    mockedConfirmOrder.mockResolvedValue(baseOrder as any);
    mockedCancelOrder.mockResolvedValue({ ...baseOrder, status: 'CANCELLED' } as any);
  });

  it('creates, updates, and deletes orders with feedback', async () => {
    const createdOrder = { ...baseOrder, id: 11, orderNumber: 'ORD-11', customerEmail: 'new@example.com' };
    const updatedOrder = { ...createdOrder, customerEmail: 'updated@example.com', status: 'CONFIRMED' };

    // listOrders is called on mount and after create
    mockedListOrders
      .mockResolvedValueOnce([baseOrder]) // initial load
      .mockResolvedValueOnce([baseOrder, createdOrder]) // after create
      .mockResolvedValueOnce([baseOrder, createdOrder]); // refresh after create

    mockedCreateOrder.mockResolvedValue(createdOrder);
    mockedUpdateOrder.mockResolvedValue(updatedOrder);
    mockedDeleteOrder.mockResolvedValue();

    render(
      <MemoryRouter>
        <OrdersManage />
      </MemoryRouter>
    );

    await waitFor(() => expect(screen.getByText('ORD-10')).toBeInTheDocument());

    fireEvent.click(screen.getByRole('button', { name: /New Order/i }));

    fireEvent.change(screen.getByLabelText(/Customer Email/i), { target: { value: 'new@example.com' } });
    fireEvent.change(screen.getByLabelText(/^Product ID/i), { target: { value: 'p-2' } });
    fireEvent.change(screen.getByLabelText(/Quantity/i), { target: { value: '2' } });
    fireEvent.change(screen.getByLabelText(/Status/i), { target: { value: 'NEW' } });
    fireEvent.click(screen.getByRole('button', { name: /Create Order/i }));

    await waitFor(() => expect(mockedCreateOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText('ORD-11')).toBeInTheDocument());

    // Update
    fireEvent.click(screen.getAllByRole('button', { name: /Edit/i })[0]);

    fireEvent.change(screen.getByLabelText(/Customer Email/i), { target: { value: 'updated@example.com' } });
    fireEvent.change(screen.getByLabelText(/Status/i), { target: { value: 'CONFIRMED' } });
    fireEvent.click(screen.getByRole('button', { name: /Update Order/i }));

    await waitFor(() => expect(mockedUpdateOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.getByText(/updated@example.com/i)).toBeInTheDocument());

    // Delete
    fireEvent.click(screen.getAllByRole('button', { name: /Delete/i })[0]);
    fireEvent.click(screen.getByRole('button', { name: /Delete Order/i }));

    await waitFor(() => expect(mockedDeleteOrder).toHaveBeenCalled());
    await waitFor(() => expect(screen.queryByText('ORD-10')).not.toBeInTheDocument());
  });

  it('shows an error message when create fails', async () => {
    mockedListOrders.mockResolvedValueOnce([baseOrder]).mockResolvedValue([baseOrder]);
    mockedCreateOrder.mockRejectedValueOnce(new Error('fail'));
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});

    try {
      render(
        <MemoryRouter>
          <OrdersManage />
        </MemoryRouter>
      );

      await screen.findByText('ORD-10');

      // Scope to the Orders card to avoid duplicate "New Order" buttons from stale renders.
      const ordersCard = screen.getByText('Orders').closest('.card');
      if (!ordersCard) {
        throw new Error('Orders card not found');
      }
      fireEvent.click(within(ordersCard).getByRole('button', { name: /New Order/i }));

      const dialog = await screen.findByRole('dialog');
      // Scope inputs to the create dialog to avoid leaking across forms.
      const dialogQueries = within(dialog);

      fireEvent.change(dialogQueries.getByLabelText(/Customer Email/i), { target: { value: 'err@example.com' } });
      fireEvent.change(dialogQueries.getByLabelText(/^Product ID/i), { target: { value: 'p-x' } });
      fireEvent.change(dialogQueries.getByLabelText(/Quantity/i), { target: { value: '1' } });
      fireEvent.change(dialogQueries.getByLabelText(/Status/i), { target: { value: 'NEW' } });

      fireEvent.click(dialogQueries.getByRole('button', { name: /Create Order/i }));

      await dialogQueries.findByText(/Failed to create order/i);
    } finally {
      // Silence intentional error logging from the rejected mock.
      consoleError.mockRestore();
    }
  });
});
