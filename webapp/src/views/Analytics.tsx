import { useMemo } from 'react';
import Card from '../components/ui/Card';
import KpiTile from '../components/ui/KpiTile';
import iconAnalytics from '../assets/icon-analytics.svg';
import iconOrders from '../assets/icon-orders.svg';
import iconNotifications from '../assets/icon-notifications.svg';

const mockCounters = {
  'orders.created': 128,
  'orders.confirmed': 117,
  'orders.cancelled': 11,
  'billing.invoice.created': 117,
  'billing.invoice.paid': 92,
  'notification.sent': 210
};

function Analytics() {
  const tiles = useMemo(
    () => [
      { label: 'Orders Created', value: mockCounters['orders.created'], icon: iconOrders },
      { label: 'Orders Confirmed', value: mockCounters['orders.confirmed'], icon: iconOrders },
      { label: 'Invoices Paid', value: mockCounters['billing.invoice.paid'], icon: iconAnalytics },
      { label: 'Notifications', value: mockCounters['notification.sent'], icon: iconNotifications }
    ],
    []
  );

  return (
    <div className="page">
      <div className="grid two" style={{ marginBottom: '24px' }}>
        {tiles.map((t) => (
          <KpiTile key={t.label} label={t.label} value={t.value} icon={t.icon} />
        ))}
      </div>
      <Card title="Analytics Integration">
        <p>
          This view is wired for counters from the analytics-service. Connect the API client to
          `/api/analytics/counters` and map keys like `orders.created` to these KPI tiles for live demos.
          Charts can be added later using the same theme tokens.
        </p>
      </Card>
    </div>
  );
}

export default Analytics;
