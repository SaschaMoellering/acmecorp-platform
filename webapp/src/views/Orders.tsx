import { FormEvent, MouseEvent, useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Link } from 'react-router-dom';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Table from '../components/ui/Table';
import {
  Order,
  OrderStatus,
  createOrder,
  deleteOrder,
  listOrders,
  updateOrder
} from '../api/client';

type OrderFormState = {
  customerEmail: string;
  productId: string;
  quantity: number;
  status: OrderStatus;
};

function statusTone(status: OrderStatus) {
  switch (status) {
    case 'CONFIRMED':
    case 'FULFILLED':
      return 'success';
    case 'CANCELLED':
      return 'danger';
    case 'NEW':
    default:
      return 'info';
  }
}

function Orders() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [createFeedback, setCreateFeedback] = useState<string | null>(null);
  const createKeyRef = useRef<string | null>(null);
  const [savingEdit, setSavingEdit] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [editFeedback, setEditFeedback] = useState<string | null>(null);
  const [editingId, setEditingId] = useState<number | null>(null);
  const editCardRef = useRef<HTMLDivElement | null>(null);
  const [createForm, setCreateForm] = useState<OrderFormState>({
    customerEmail: '',
    productId: '',
    quantity: 1,
    status: 'NEW'
  });
  const [editForm, setEditForm] = useState<OrderFormState>({
    customerEmail: '',
    productId: '',
    quantity: 1,
    status: 'NEW'
  });

  const statusOptions = useMemo<OrderStatus[]>(() => ['NEW', 'CONFIRMED', 'FULFILLED', 'CANCELLED'], []);

  const loadOrders = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await listOrders();
      setOrders(data);
    } catch (err) {
      console.error(err);
      setOrders([]);
      setError('Unable to load orders');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  useEffect(() => {
    if (editingId !== null) {
      editCardRef.current?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    }
  }, [editingId]);

  const updateEditForm = (order: Order) => {
    const firstItem = order.items?.[0];
    setEditForm({
      customerEmail: order.customerEmail,
      productId: firstItem?.productId ?? '',
      quantity: firstItem?.quantity ?? 1,
      status: order.status
    });
    setEditingId(order.id);
  };

  const resetMessages = () => {
    setMessage(null);
    setActionError(null);
    setCreateFeedback(null);
    setEditFeedback(null);
  };

  const validateCreateForm = () => {
    const customerEmail = createForm.customerEmail.trim();
    const productId = createForm.productId.trim();
    const quantity = Number(createForm.quantity);
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!customerEmail) return 'Customer email is required';
    if (!emailRegex.test(customerEmail)) return 'Enter a valid customer email';
    if (!productId) return 'Product ID is required';
    if (!Number.isFinite(quantity) || quantity < 1) return 'Quantity must be at least 1';
    return null;
  };

  const handleCreate = async (e: FormEvent) => {
    e.preventDefault();
    resetMessages();
    const validationError = validateCreateForm();
    if (validationError) {
      setCreateFeedback(validationError);
      return;
    }
    setCreating(true);
    try {
      if (!createKeyRef.current && globalThis.crypto?.randomUUID) {
        createKeyRef.current = globalThis.crypto.randomUUID();
      }
      await createOrder({
        customerEmail: createForm.customerEmail.trim(),
        status: createForm.status,
        items: [{ productId: createForm.productId.trim(), quantity: Number(createForm.quantity) }]
      }, createKeyRef.current ?? undefined);
      createKeyRef.current = null;
      setMessage('Order saved');
      setCreateFeedback('Order saved');
      setCreateForm({ customerEmail: '', productId: '', quantity: 1, status: 'NEW' });
      await loadOrders();
    } catch (err) {
      console.error(err);
      setActionError('Failed to save order');
      setCreateFeedback('Failed to save order');
    } finally {
      setCreating(false);
    }
  };

  const handleUpdate = async (e: FormEvent) => {
    e.preventDefault();
    if (editingId === null) {
      return;
    }
    resetMessages();
    const customerEmail = editForm.customerEmail.trim();
    const productId = editForm.productId.trim();
    const quantity = Number(editForm.quantity);
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!customerEmail) {
      setEditFeedback('Customer email is required');
      return;
    }
    if (!emailRegex.test(customerEmail)) {
      setEditFeedback('Enter a valid customer email');
      return;
    }
    if (!productId) {
      setEditFeedback('Product ID is required');
      return;
    }
    if (!Number.isFinite(quantity) || quantity < 1) {
      setEditFeedback('Quantity must be at least 1');
      return;
    }
    setSavingEdit(true);
    try {
      await updateOrder(String(editingId), {
        customerEmail: customerEmail,
        status: editForm.status,
        items: [{ productId: productId, quantity }]
      });
      setMessage('Order updated');
      setEditFeedback('Order updated');
      setEditingId(null);
      await loadOrders();
    } catch (err) {
      console.error(err);
      setActionError('Failed to update order');
      setEditFeedback('Failed to update order');
    } finally {
      setSavingEdit(false);
    }
  };

  const handleDelete = async (id: number) => {
    resetMessages();
    const confirmed = window.confirm('Delete this order?');
    if (!confirmed) return;

    setDeletingId(id);
    try {
      await deleteOrder(String(id));
      setOrders((prev) => prev.filter((o) => o.id !== id));
      setMessage('Order deleted');
      if (editingId === id) {
        setEditingId(null);
      }
    } catch (err) {
      console.error(err);
      setActionError('Failed to delete order');
    } finally {
      setDeletingId((current) => (current === id ? null : current));
    }
  };

  const handleEditClick = (e: MouseEvent<HTMLButtonElement>, order: Order) => {
    e.preventDefault();
    e.stopPropagation();
    console.debug('[Orders] Edit clicked', { orderId: order.id });
    setMessage(`Editing order #${order.id}`);
    updateEditForm(order);
  };

  const handleDeleteClick = (e: MouseEvent<HTMLButtonElement>, id: number) => {
    e.preventDefault();
    e.stopPropagation();
    void handleDelete(id);
  };

  const headers = ['Order', 'Customer', 'Status', 'Total', 'Created', 'Actions'];
  const rows = orders.map((o) => [
    <Link to={`/orders/${o.id}`} className="link" key={o.id}>
      {o.orderNumber}
    </Link>,
    o.customerEmail,
    <Badge tone={statusTone(o.status)}>{o.status}</Badge>,
    `${o.currency} ${o.totalAmount?.toFixed?.(2) ?? o.totalAmount}`,
    new Date(o.createdAt).toLocaleString(),
    <div style={{ display: 'flex', gap: '8px' }} key={`${o.id}-actions`}>
      <button type="button" className="btn btn-ghost" onClick={(e) => handleEditClick(e, o)}>
        Edit
      </button>
      <button type="button" className="btn btn-ghost" onClick={(e) => handleDeleteClick(e, o.id)} disabled={deletingId === o.id}>
        {deletingId === o.id ? 'Deleting...' : 'Delete'}
      </button>
    </div>
  ]);

  return (
    <div className="page">
      <div className="grid two">
        <Card title="Orders">
          {loading && <p>Loading orders...</p>}
          {error && <p>{error}</p>}
          {!loading && !error && orders.length === 0 && <p>No orders available.</p>}
          {!loading && !error && orders.length > 0 && <Table headers={headers} rows={rows} />}
          {(message || actionError) && <p>{message ?? actionError}</p>}
        </Card>

        <div className="grid">
          <Card title="Create Order">
            <form className="grid" onSubmit={handleCreate} noValidate>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Customer Email</span>
                <input
                  required
                  className="input"
                  type="email"
                  value={createForm.customerEmail}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, customerEmail: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Product ID</span>
                <input
                  required
                  className="input"
                  value={createForm.productId}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, productId: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Quantity</span>
                <input
                  required
                  min={1}
                  type="number"
                  className="input"
                  value={createForm.quantity}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, quantity: Number(e.target.value) }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Status</span>
                <select
                  className="input"
                  value={createForm.status}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, status: e.target.value as OrderStatus }))}
                >
                  {statusOptions.map((s) => (
                    <option key={s} value={s}>
                      {s}
                    </option>
                  ))}
                </select>
              </label>
              <button type="submit" className="btn btn-primary" disabled={creating}>
                {creating ? 'Saving...' : 'Create Order'}
              </button>
              {createFeedback && (
                <p style={{ margin: 0, color: createFeedback === 'Order saved' ? undefined : 'var(--color-danger, #b42318)' }}>
                  {createFeedback}
                </p>
              )}
            </form>
          </Card>

          {editingId !== null && (
            <div ref={editCardRef}>
              <Card title={`Edit Order #${editingId}`}>
                <form className="grid" onSubmit={handleUpdate} noValidate>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Customer Email</span>
                  <input
                    required
                    className="input"
                    type="email"
                    value={editForm.customerEmail}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, customerEmail: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Product ID</span>
                  <input
                    required
                    className="input"
                    value={editForm.productId}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, productId: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Quantity</span>
                  <input
                    required
                    min={1}
                    type="number"
                    className="input"
                    value={editForm.quantity}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, quantity: Number(e.target.value) }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Status</span>
                  <select
                    className="input"
                    value={editForm.status}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, status: e.target.value as OrderStatus }))}
                  >
                    {statusOptions.map((s) => (
                      <option key={s} value={s}>
                        {s}
                      </option>
                    ))}
                  </select>
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button type="submit" className="btn btn-primary" disabled={savingEdit}>
                    {savingEdit ? 'Saving...' : 'Update Order'}
                  </button>
                  <button type="button" className="btn btn-ghost" onClick={() => setEditingId(null)}>
                    Cancel
                  </button>
                </div>
                {editFeedback && (
                  <p style={{ margin: 0, color: editFeedback === 'Order updated' ? undefined : 'var(--color-danger, #b42318)' }}>
                    {editFeedback}
                  </p>
                )}
                </form>
              </Card>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default Orders;
