import { useState } from 'react';
import Card from '../components/ui/Card';
import { seedDemoData, SeedResult } from '../api/client';

function SeedTools() {
  const [message, setMessage] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<SeedResult | null>(null);

  const handleSeed = async () => {
    setLoading(true);
    setMessage(null);
    setError(null);
    setResult(null);
    try {
      const seeded = await seedDemoData();
      setResult(seeded);
      setMessage('Demo data loaded via gateway seed');
    } catch (err: unknown) {
      console.error('Seed failed:', err);
      const msg =
        err instanceof Error ? err.message : 'Unknown error while seeding';
      setError(`Failed to seed demo data: ${msg}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="page">
      <div className="section-title">
        <h2>Seed Data</h2>
        <span className="chip">Gateway orchestrates catalog + orders</span>
      </div>
      <Card title="Load Demo Data">
        <p>Trigger deterministic demo data across catalog and orders services through the gateway.</p>
        <div style={{ display: 'flex', gap: '12px', marginTop: '12px', flexWrap: 'wrap' }}>
          <button className="btn btn-primary" type="button" onClick={handleSeed} disabled={loading}>
            {loading ? 'Seeding...' : 'Load Demo Data'}
          </button>
        </div>
        {message && <p style={{ marginTop: '12px' }}>{message}</p>}
        {error && <p style={{ marginTop: '12px', color: 'var(--color-danger, #b42318)' }}>{error}</p>}
        {result && (
          <div style={{ marginTop: '12px', color: 'var(--color-muted)' }}>
            <div>Catalog products created: {result.productsCreated}</div>
            <div>Orders created: {result.ordersCreated}</div>
            <div>{result.message}</div>
          </div>
        )}
      </Card>
    </div>
  );
}

export default SeedTools;
