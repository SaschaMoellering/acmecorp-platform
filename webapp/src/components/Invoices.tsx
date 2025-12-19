import { useState, useEffect } from 'react';
import Card from './ui/Card';
import Table from './ui/Table';
import Badge from './ui/Badge';
import { listInvoices, payInvoice, type Invoice, type PageResponse, type PaymentRequest } from '../api/client';

function Invoices() {
  const [invoices, setInvoices] = useState<Invoice[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [payingInvoice, setPayingInvoice] = useState<number | null>(null);

  useEffect(() => {
    loadInvoices();
  }, []);

  const loadInvoices = async () => {
    setLoading(true);
    setError(null);
    try {
      const response: PageResponse<Invoice> = await listInvoices();
      setInvoices(response.content);
    } catch (err) {
      console.error(err);
      setError('Failed to load invoices');
    } finally {
      setLoading(false);
    }
  };

  const handlePayInvoice = async (invoice: Invoice) => {
    setPayingInvoice(invoice.id);
    setToast(null);
    try {
      const payment: PaymentRequest = { paymentMethod: 'DEMO' };
      await payInvoice(invoice.id.toString(), payment);
      setToast(`Invoice ${invoice.invoiceNumber} paid`);
      await loadInvoices();
    } catch (err) {
      console.error(err);
      setError('Failed to pay invoice');
    } finally {
      setPayingInvoice(null);
    }
  };

  const headers = ['Invoice #', 'Order #', 'Customer', 'Amount', 'Status', 'Created', 'Actions'];
  const rows = invoices.map((invoice) => [
    invoice.invoiceNumber,
    invoice.orderNumber,
    invoice.customerEmail,
    `${invoice.currency} ${invoice.amount.toFixed(2)}`,
    <Badge
      tone={invoice.status === 'PAID' ? 'success' : invoice.status === 'OPEN' ? 'warning' : 'danger'}
      key={`${invoice.id}-badge`}
    >
      {invoice.status}
    </Badge>,
    new Date(invoice.createdAt).toLocaleString(),
    <div key={`${invoice.id}-actions`}>
      {invoice.status === 'OPEN' && (
        <button
          type="button"
          className="btn btn-primary"
          onClick={() => handlePayInvoice(invoice)}
          disabled={payingInvoice === invoice.id}
        >
          {payingInvoice === invoice.id ? 'Paying...' : 'Pay'}
        </button>
      )}
    </div>
  ]);

  return (
    <div className="page">
      <div className="section-title">
        <h2>Invoices</h2>
        <span className="chip">Billing + RabbitMQ</span>
      </div>
      <Card
        title="Invoice List"
        actions={
          <button type="button" className="btn btn-ghost" onClick={loadInvoices} disabled={loading}>
            Refresh
          </button>
        }
      >
        {loading && <p>Loading invoices...</p>}
        {error && <p style={{ color: 'var(--color-danger, #b42318)' }}>{error}</p>}
        {!loading && !error && invoices.length === 0 && <p>No invoices yet.</p>}
        {!loading && !error && invoices.length > 0 && <Table headers={headers} rows={rows} />}
        {toast && <p style={{ marginTop: '12px' }}>{toast}</p>}
      </Card>
    </div>
  );
}

export default Invoices;