import { useEffect, useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Table from '../components/ui/Table';
import { Order, OrderStatus, fetchOrderById } from '../api/client';

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
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!id) return;
    fetchOrderById(id)
      .then(setOrder)
      .catch(() => setError('Order not found'));
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
    </div>
  );
}

export default OrderDetails;
