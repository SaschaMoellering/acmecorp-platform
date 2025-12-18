import { useEffect, useState } from 'react';
import { listNotifications, type Notification } from '../api/client';
import Card from '../components/ui/Card';
import '../components/ui/table.css';
import '../components/ui/badge.css';

function Notifications() {
  const [notifications, setNotifications] = useState<Notification[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listNotifications()
      .then((response) => {
        setNotifications(response.content);
        setError(null);
      })
      .catch((err) => {
        console.error('Failed to load notifications:', err);
        setError('Failed to load notifications');
      })
      .finally(() => setLoading(false));
  }, []);

  const getStatusBadge = (status: string) => {
    const className = status === 'SENT' ? 'badge badge-success' : 'badge badge-warning';
    return <span className={className}>{status}</span>;
  };

  const getTypeBadge = (type: string) => {
    return <span className="badge badge-info">{type}</span>;
  };

  return (
    <div className="page">
      <Card title="Notifications">
        {loading && <p>Loading notifications...</p>}
        {error && <p style={{color: '#dc3545'}}>{error}</p>}
        {!loading && !error && (
          <>
            <p>Recent notifications sent by the system.</p>
            {notifications.length === 0 ? (
              <p>No notifications found. Create some orders to see notifications.</p>
            ) : (
              <div className="table-wrap">
                <table className="table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Recipient</th>
                      <th>Message</th>
                      <th>Type</th>
                      <th>Status</th>
                      <th>Created</th>
                    </tr>
                  </thead>
                  <tbody>
                    {notifications.map((notification) => (
                      <tr key={notification.id}>
                        <td>{notification.id}</td>
                        <td>{notification.recipient}</td>
                        <td style={{maxWidth: '300px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap'}}>
                          {notification.message}
                        </td>
                        <td>{getTypeBadge(notification.type)}</td>
                        <td>{getStatusBadge(notification.status)}</td>
                        <td>{new Date(notification.createdAt).toLocaleString()}</td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </Card>
    </div>
  );
}

export default Notifications;