import { useState } from 'react';
import Card from '../components/ui/Card';
import { seedCatalogDemoData, seedOrdersDemoData } from '../api/client';

function TestData() {
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [seedingCatalog, setSeedingCatalog] = useState(false);
  const [seedingOrders, setSeedingOrders] = useState(false);

  const reset = () => {
    setMessage(null);
    setError(null);
  };

  const handleSeedCatalog = async () => {
    reset();
    setSeedingCatalog(true);
    try {
      await seedCatalogDemoData();
      setMessage('Catalog demo data seeded');
    } catch (err) {
      console.error(err);
      setError('Failed to seed catalog data');
    } finally {
      setSeedingCatalog(false);
    }
  };

  const handleSeedOrders = async () => {
    reset();
    setSeedingOrders(true);
    try {
      await seedOrdersDemoData();
      setMessage('Orders demo data seeded');
    } catch (err) {
      console.error(err);
      setError('Failed to seed orders data');
    } finally {
      setSeedingOrders(false);
    }
  };

  return (
    <div className="page">
      <Card title="Test Data">
        <p>Seed the demo catalog and orders to try the platform quickly.</p>
        <div style={{ display: 'flex', gap: '12px', marginTop: '12px', flexWrap: 'wrap' }}>
          <button className="btn btn-primary" type="button" onClick={handleSeedCatalog} disabled={seedingCatalog}>
            {seedingCatalog ? 'Seeding Catalog...' : 'Seed Catalog Demo Data'}
          </button>
          <button className="btn btn-primary" type="button" onClick={handleSeedOrders} disabled={seedingOrders}>
            {seedingOrders ? 'Seeding Orders...' : 'Seed Orders Demo Data'}
          </button>
        </div>
        {message && <p style={{ marginTop: '12px' }}>{message}</p>}
        {error && <p style={{ marginTop: '12px' }}>{error}</p>}
      </Card>
    </div>
  );
}

export default TestData;
