import { useEffect, useState } from 'react';
import Card from '../components/ui/Card';
import KpiTile from '../components/ui/KpiTile';
import Table from '../components/ui/Table';
import { Order, fetchCatalog, fetchOrders } from '../api/client';
import iconOrders from '../assets/icon-orders.svg';
import iconCatalog from '../assets/icon-catalog.svg';
import iconAnalytics from '../assets/icon-analytics.svg';

function Dashboard() {
  const [orders, setOrders] = useState<Order[]>([]);
  const [productCount, setProductCount] = useState(0);

  useEffect(() => {
    fetchOrders().then(setOrders).catch(() => setOrders([]));
    fetchCatalog().then((p) => setProductCount(p.length)).catch(() => setProductCount(0));
  }, []);

  const recent = orders.slice(0, 5);

  return (
    <div className="page">
      <div className="grid three" style={{ marginBottom: '24px' }}>
        <KpiTile label="Active Products" value={productCount} trend="+ curated" icon={iconCatalog} />
        <KpiTile label="Recent Orders" value={orders.length} trend="Live via gateway" icon={iconOrders} />
        <KpiTile label="Platform Health" value="Nominal" trend="All services reachable" icon={iconAnalytics} />
      </div>

      <div className="grid two">
        <Card title="Recent Orders">
          <Table
            headers={['Order', 'Customer', 'Status', 'Total', 'Created']}
            rows={recent.map((o) => [
              o.orderNumber,
              o.customerEmail,
              o.status,
              `${o.currency} ${o.totalAmount?.toFixed?.(2) ?? o.totalAmount}`,
              new Date(o.createdAt).toLocaleString()
            ])}
          />
        </Card>

        <Card title="Platform Notes">
          <ul style={{ color: 'var(--color-muted)', lineHeight: '1.6' }}>
            <li>Gateway aggregates Orders, Catalog, Billing for the UI.</li>
            <li>Use the System view to verify service health before demos.</li>
            <li>Analytics counters can be wired to the Metrics view later.</li>
            <li>Styling driven by theme tokens for quick customization.</li>
          </ul>
        </Card>
      </div>
    </div>
  );
}

export default Dashboard;
