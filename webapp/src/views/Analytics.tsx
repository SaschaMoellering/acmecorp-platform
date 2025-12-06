import { useEffect, useMemo, useState } from 'react';
import Card from '../components/ui/Card';
import KpiTile from '../components/ui/KpiTile';
import iconAnalytics from '../assets/icon-analytics.svg';
import iconOrders from '../assets/icon-orders.svg';
import iconNotifications from '../assets/icon-notifications.svg';
import { fetchAnalyticsCounters } from '../api/client';

const mockCounters = {
  'orders.created': 128,
  'orders.confirmed': 117,
  'orders.cancelled': 11,
  'billing.invoice.created': 117,
  'billing.invoice.paid': 92,
  'notification.sent': 210
};

function Analytics() {
  const [counters, setCounters] = useState<Record<string, number>>(mockCounters);
  const [loading, setLoading] = useState(true);
  const [usingDemo, setUsingDemo] = useState(false);

  useEffect(() => {
    fetchAnalyticsCounters()
      .then((data) => {
        if (Object.keys(data).length === 0) {
          setUsingDemo(true);
          setCounters(mockCounters);
        } else {
          setCounters(data);
        }
      })
      .catch(() => {
        setUsingDemo(true);
        setCounters(mockCounters);
      })
      .finally(() => setLoading(false));
  }, []);

  const tiles = useMemo(
    () => [
      { label: 'Orders Created', value: counters['orders.created'] ?? 0, icon: iconOrders },
      { label: 'Orders Confirmed', value: counters['orders.confirmed'] ?? 0, icon: iconOrders },
      { label: 'Invoices Paid', value: counters['billing.invoice.paid'] ?? 0, icon: iconAnalytics },
      { label: 'Notifications', value: counters['notification.sent'] ?? 0, icon: iconNotifications }
    ],
    [counters]
  );

  return (
    <div className="page">
      <div className="grid two" style={{ marginBottom: '24px' }}>
        {tiles.map((t) => (
          <KpiTile key={t.label} label={t.label} value={t.value} icon={t.icon} />
        ))}
      </div>
      <Card title="Analytics Integration">
        {loading && <p>Loading counters…</p>}
        {!loading && (
          <p>
            Showing {usingDemo ? 'demo' : 'live'} data from analytics-service. Extend this view with charts
            once additional metrics are available.
          </p>
        )}
      </Card>
    </div>
  );
}

export default Analytics;
