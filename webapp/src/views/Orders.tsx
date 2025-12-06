import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import Table from '../components/ui/Table';
import { Order, OrderStatus, fetchOrders } from '../api/client';

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

  useEffect(() => {
    fetchOrders()
      .then((data) => setOrders(data))
      .catch(() => setError('Unable to load orders'))
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="page">
      <Card title="Orders">
        {loading && <p>Loading orders...</p>}
        {error && <p>{error}</p>}
        {!loading && !error && (
          <Table
            headers={['Order', 'Customer', 'Status', 'Total', 'Created']}
            rows={orders.map((o) => [
              <Link to={`/orders/${o.id}`} className="link" key={o.id}>
                {o.orderNumber}
              </Link>,
              o.customerEmail,
              <Badge tone={statusTone(o.status)}>{o.status}</Badge>,
              `${o.currency} ${o.totalAmount?.toFixed?.(2) ?? o.totalAmount}`,
              new Date(o.createdAt).toLocaleString()
            ])}
          />
        )}
      </Card>
    </div>
  );
}

export default Orders;
