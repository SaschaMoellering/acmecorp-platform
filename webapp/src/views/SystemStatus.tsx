import { useEffect, useState } from 'react';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';

// Import only the type, not a runtime value
import type { SystemStatus as SystemStatusDto } from '../api/client';
import { fetchSystemStatus } from '../api/client';

function SystemStatus() {
  const [statuses, setStatuses] = useState<SystemStatusDto[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetchSystemStatus()
      .then(setStatuses)
      .finally(() => setLoading(false));
  }, []);

  return (
    <div className="page">
      <Card title="Service Status">
        {loading && <p>Checking services...</p>}
        {!loading && (
          <div className="grid two">
            {statuses.map((s) => (
              <div
                key={s.service}
                className="catalog-card"
                style={{ gap: '8px' }}
              >
                <div
                  style={{
                    display: 'flex',
                    justifyContent: 'space-between',
                    alignItems: 'center'
                  }}
                >
                  <div style={{ fontWeight: 700 }}>{s.service}</div>
                  <Badge
                    tone={
                      s.status === 'OK'
                        ? 'success'
                        : s.status === 'DOWN'
                        ? 'danger'
                        : 'warning'
                    }
                  >
                    {s.status}
                  </Badge>
                </div>
                <p>Health via /status</p>
              </div>
            ))}
          </div>
        )}
      </Card>
    </div>
  );
}

export default SystemStatus;
