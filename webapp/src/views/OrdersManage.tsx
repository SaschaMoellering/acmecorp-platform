import { useCallback, useEffect, useMemo, useState } from 'react';
import Card from '../components/ui/Card';
import Table from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import Dialog from '../components/ui/Dialog';
import OrderFormDialog, { OrderFormValues } from '../components/forms/OrderFormDialog';
import {
  Order,
  OrderStatus,
  cancelOrder,
  confirmOrder,
  createOrder,
  deleteOrder,
  listOrders,
  updateOrder
} from '../api/client';

function OrdersManage() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [editTarget, setEditTarget] = useState<Order | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Order | null>(null);
  const [saving, setSaving] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);

  const loadOrders = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await listOrders();
      setOrders(data);
    } catch (err) {
      console.error(err);
      setError('Unable to load orders');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadOrders();
  }, [loadOrders]);

  const statusTone = (status: OrderStatus) => {
    switch (status) {
      case 'CONFIRMED':
      case 'FULFILLED':
        return 'success';
      case 'CANCELLED':
        return 'danger';
      default:
        return 'info';
    }
  };

  const handleCreate = async (values: OrderFormValues) => {
    setSaving(true);
    setFormError(null);
    setToast(null);
    try {
      await createOrder({
        customerEmail: values.customerEmail,
        status: values.status,
        items: [{ productId: values.productId, quantity: values.quantity }]
      });
      setCreateOpen(false);
      setToast('Order created');
      await loadOrders();
    } catch (err) {
      console.error(err);
      setFormError('Failed to create order');
    } finally {
      setSaving(false);
    }
  };

  const handleUpdate = async (values: OrderFormValues) => {
    if (!editTarget) return;
    setSaving(true);
    setFormError(null);
    setToast(null);
    try {
      const updated = await updateOrder(String(editTarget.id), {
        customerEmail: values.customerEmail,
        status: values.status,
        items: [{ productId: values.productId, quantity: values.quantity }]
      });
      setToast('Order updated');
      setEditTarget(null);
      setOrders((prev) => prev.map((o) => (o.id === updated.id ? updated : o)));
    } catch (err) {
      console.error(err);
      setFormError('Failed to update order');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setSaving(true);
    setToast(null);
    setFormError(null);
    try {
      await deleteOrder(String(deleteTarget.id));
      setOrders((prev) => prev.filter((o) => o.id !== deleteTarget.id));
      setToast('Order deleted');
      setDeleteTarget(null);
    } catch (err) {
      console.error(err);
      setFormError('Failed to delete order');
    } finally {
      setSaving(false);
    }
  };

  const mutateOrder = (updated: Order) => {
    setOrders((prev) => prev.map((o) => (o.id === updated.id ? updated : o)));
  };

  const handleConfirm = async (order: Order) => {
    try {
      const confirmed = await confirmOrder(String(order.id));
      mutateOrder(confirmed);
      setToast('Order confirmed');
    } catch (err) {
      console.error(err);
      setFormError('Failed to confirm order');
    }
  };

  const handleCancel = async (order: Order) => {
    try {
      const cancelled = await cancelOrder(String(order.id));
      mutateOrder(cancelled);
      setToast('Order cancelled');
    } catch (err) {
      console.error(err);
      setFormError('Failed to cancel order');
    }
  };

  const editInitialValues: OrderFormValues | undefined = useMemo(() => {
    if (!editTarget) return undefined;
    const item = editTarget.items?.[0];
    return {
      customerEmail: editTarget.customerEmail,
      productId: item?.productId ?? '',
      quantity: item?.quantity ?? 1,
      status: editTarget.status
    };
  }, [editTarget]);

  const headers = ['Order', 'Customer', 'Status', 'Total', 'Updated', 'Actions'];
  const rows = orders.map((order) => [
    order.orderNumber,
    order.customerEmail,
    <Badge tone={statusTone(order.status)} key={`${order.id}-status`}>
      {order.status}
    </Badge>,
    `${order.currency} ${order.totalAmount?.toFixed?.(2) ?? order.totalAmount}`,
    new Date(order.updatedAt).toLocaleString(),
    <div key={`${order.id}-actions`} style={{ display: 'flex', gap: '8px', flexWrap: 'wrap' }}>
      <button type="button" className="btn btn-ghost" onClick={() => setEditTarget(order)}>
        Edit
      </button>
      {order.status === 'NEW' && (
        <>
          <button type="button" className="btn btn-ghost" onClick={() => handleConfirm(order)}>
            Confirm
          </button>
          <button type="button" className="btn btn-ghost" onClick={() => handleCancel(order)}>
            Cancel
          </button>
        </>
      )}
      <button type="button" className="btn btn-ghost" onClick={() => setDeleteTarget(order)}>
        Delete
      </button>
    </div>
  ]);

  return (
    <div className="page">
      <div className="section-title">
        <h2>Manage Orders</h2>
        <span className="chip">Gateway proxy</span>
      </div>
      <Card
        title="Orders"
        actions={
          <div style={{ display: 'flex', gap: '8px' }}>
            <button type="button" className="btn btn-primary" onClick={() => setCreateOpen(true)}>
              New Order
            </button>
            <button type="button" className="btn btn-ghost" onClick={loadOrders} disabled={loading}>
              Refresh
            </button>
          </div>
        }
      >
        {loading && <p>Loading orders...</p>}
        {error && <p>{error}</p>}
        {!loading && !error && orders.length === 0 && <p>No orders yet. Create one to get started.</p>}
        {!loading && !error && orders.length > 0 && <Table headers={headers} rows={rows} />}
        {toast && <p style={{ marginTop: '12px' }}>{toast}</p>}
        {formError && <p style={{ marginTop: '12px', color: 'var(--color-danger, #b42318)' }}>{formError}</p>}
      </Card>

      <OrderFormDialog
        title="Create Order"
        open={createOpen}
        mode="create"
        loading={saving}
        error={formError}
        onClose={() => setCreateOpen(false)}
        onSubmit={handleCreate}
      />

      <OrderFormDialog
        title="Edit Order"
        open={!!editTarget}
        mode="edit"
        loading={saving}
        initialValues={editInitialValues}
        error={formError}
        onClose={() => setEditTarget(null)}
        onSubmit={handleUpdate}
      />

      <Dialog
        title="Delete Order"
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        footer={
          <>
            <button type="button" className="btn btn-ghost" onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button type="button" className="btn btn-primary" onClick={handleDelete} disabled={saving}>
              {saving ? 'Deleting...' : 'Delete Order'}
            </button>
          </>
        }
      >
        <p>
          Delete order <strong>{deleteTarget?.orderNumber}</strong>? This cannot be undone.
        </p>
      </Dialog>
    </div>
  );
}

export default OrdersManage;
