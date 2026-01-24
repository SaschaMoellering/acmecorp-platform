import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Table from '../components/ui/Table';
import { Order, OrderStatus, OrderStatusHistory, fetchOrderById, fetchOrderHistory } from '../api/client';

function statusTone(status: OrderStatus) {
  switch (status) {
    case 'CONFIRMED':
    case 'FULFILLED':
      return 'success';
    case 'CANCELLED':
      return 'danger';
    default:
      return 'info';
  }
}

function OrderDetails() {
  const { id } = useParams();
  const [order, setOrder] = useState<Order | null>(null);
  const [history, setHistory] = useState<OrderStatusHistory[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    fetchOrderById(id)
      .then(setOrder)
      .catch(() => setError('Order not found'));
  }, [id]);

  useEffect(() => {
    if (!id) return;
    fetchOrderHistory(id)
      .then(setHistory)
      .catch(() => setHistory([]));
  }, [id]);

  if (error) return <div className="page"><p>{error}</p></div>;
  if (!order) return <div className="page"><p>Loading...</p></div>;

  return (
    <div className="page">
      <Card
        title={
          <div style={{ display: 'flex', gap: '12px', alignItems: 'center' }}>
            <Link to="/orders" className="link">← Back</Link>
            <span>Order {order.orderNumber}</span>
            <Badge tone={statusTone(order.status)}>{order.status}</Badge>
          </div>
        }
      >
        <div className="grid two" style={{ marginBottom: '24px' }}>
          <div>
            <p><strong>Customer:</strong> {order.customerEmail}</p>
            <p><strong>Total:</strong> {order.currency} {order.totalAmount?.toFixed?.(2) ?? order.totalAmount}</p>
          </div>
          <div>
            <p><strong>Created:</strong> {new Date(order.createdAt).toLocaleString()}</p>
            <p><strong>Updated:</strong> {new Date(order.updatedAt).toLocaleString()}</p>
          </div>
        </div>
        <Table
          headers={['Product', 'Unit Price', 'Qty', 'Line Total']}
          rows={(order.items ?? []).map((item) => [
            item.productName,
            `${order.currency} ${item.unitPrice.toFixed?.(2) ?? item.unitPrice}`,
            item.quantity,
            `${order.currency} ${item.lineTotal.toFixed?.(2) ?? item.lineTotal}`
          ])}
        />
      </Card>
      <Card title="Status history">
        {history.length === 0 ? (
          <p>No history recorded yet.</p>
        ) : (
          <div className="timeline">
            {history.map((entry) => (
              <div key={entry.id} className="timeline-row" style={{ display: 'flex', justifyContent: 'space-between', gap: '16px', padding: '8px 0', borderBottom: '1px solid rgba(148, 163, 184, 0.2)' }}>
                <div>
                  <strong>{entry.newStatus}</strong>{' '}
                  <span style={{ color: '#64748b' }}>
                    {entry.oldStatus ? `${entry.oldStatus} → ${entry.newStatus}` : `created as ${entry.newStatus}`}
                  </span>
                  {entry.reason && <div style={{ color: '#94a3b8', fontSize: '0.9rem' }}>{entry.reason}</div>}
                </div>
                <div style={{ color: '#94a3b8', whiteSpace: 'nowrap' }}>
                  {new Date(entry.changedAt).toLocaleString()}
                </div>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

export default OrderDetails;
