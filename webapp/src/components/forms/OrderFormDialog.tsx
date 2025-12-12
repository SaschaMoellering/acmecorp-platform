import { FormEvent, useEffect, useState } from 'react';
import { OrderStatus } from '../../api/client';
import Dialog from '../ui/Dialog';

export type OrderFormValues = {
  customerEmail: string;
  productId: string;
  quantity: number;
  status: OrderStatus;
};

type Props = {
  title: string;
  open: boolean;
  mode: 'create' | 'edit';
  initialValues?: OrderFormValues;
  loading?: boolean;
  error?: string | null;
  onClose: () => void;
  onSubmit: (values: OrderFormValues) => Promise<void>;
};

const defaults: OrderFormValues = {
  customerEmail: '',
  productId: '',
  quantity: 1,
  status: 'NEW'
};

function validate(values: OrderFormValues) {
  const errs: string[] = [];
  if (!values.customerEmail || !values.customerEmail.includes('@')) {
    errs.push('A valid customer email is required.');
  }
  if (!values.productId.trim()) {
    errs.push('Product ID is required.');
  }
  if (!values.quantity || values.quantity < 1) {
    errs.push('Quantity must be at least 1.');
  }
  return errs;
}

function OrderFormDialog({ title, open, mode, initialValues, loading, error, onClose, onSubmit }: Props) {
  const [values, setValues] = useState<OrderFormValues>(initialValues ?? defaults);
  const [errors, setErrors] = useState<string[]>([]);

  useEffect(() => {
    if (open) {
      setValues(initialValues ?? defaults);
      setErrors([]);
    }
  }, [open, initialValues]);

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const validation = validate(values);
    if (validation.length) {
      setErrors(validation);
      return;
    }
    setErrors([]);
    await onSubmit(values);
  };

  return (
    <Dialog
      title={title}
      open={open}
      onClose={onClose}
      footer={
        <>
          <button type="button" className="btn btn-ghost" onClick={onClose}>
            Cancel
          </button>
          <button type="submit" form="order-form" className="btn btn-primary" disabled={loading}>
            {loading ? 'Saving...' : mode === 'create' ? 'Create Order' : 'Update Order'}
          </button>
        </>
      }
    >
      <form id="order-form" data-testid="order-form" className="grid" onSubmit={handleSubmit}>
        <label className="form-field">
          <span>Customer Email</span>
          <input
            required
            type="email"
            className="input"
            value={values.customerEmail}
            onChange={(e) => setValues((prev) => ({ ...prev, customerEmail: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Product ID</span>
          <input
            required
            className="input"
            value={values.productId}
            onChange={(e) => setValues((prev) => ({ ...prev, productId: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Quantity</span>
          <input
            required
            type="number"
            min={1}
            className="input"
            value={values.quantity}
            onChange={(e) => setValues((prev) => ({ ...prev, quantity: Number(e.target.value) }))}
          />
        </label>
        <label className="form-field">
          <span>Status</span>
          <select
            className="input"
            value={values.status}
            onChange={(e) => setValues((prev) => ({ ...prev, status: e.target.value as OrderStatus }))}
          >
            <option value="NEW">NEW</option>
            <option value="CONFIRMED">CONFIRMED</option>
            <option value="CANCELLED">CANCELLED</option>
            <option value="FULFILLED">FULFILLED</option>
          </select>
        </label>
        {errors.length > 0 && (
          <div className="form-errors" role="alert">
            {errors.map((err) => (
              <p key={err}>{err}</p>
            ))}
          </div>
        )}
        {error && (
          <div className="form-errors" role="alert">
            <p>{error}</p>
          </div>
        )}
      </form>
    </Dialog>
  );
}

export default OrderFormDialog;
