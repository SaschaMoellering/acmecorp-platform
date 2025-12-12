import { FormEvent, useEffect, useState } from 'react';
import { NewProductPayload } from '../../api/client';
import Dialog from '../ui/Dialog';
import { parsePrice } from '../../utils/price';

type Props = {
  title: string;
  open: boolean;
  mode: 'create' | 'edit';
  initialValues?: NewProductPayload;
  loading?: boolean;
  error?: string | null;
  onClose: () => void;
  onSubmit: (values: NewProductPayload) => Promise<void>;
};

type FormValues = Omit<NewProductPayload, 'price'>;

const defaults: FormValues = {
  sku: '',
  name: '',
  description: '',
  currency: 'USD',
  category: '',
  active: true
};

function formValuesFromPayload(payload: NewProductPayload): FormValues {
  const { price, ...rest } = payload;
  return rest;
}

function validate(values: FormValues) {
  const errs: string[] = [];
  if (!values.sku.trim()) errs.push('SKU is required.');
  if (!values.name.trim()) errs.push('Name is required.');
  if (!values.description.trim()) errs.push('Description is required.');
  if (!values.currency.trim()) errs.push('Currency is required.');
  if (!values.category.trim()) errs.push('Category is required.');
  return errs;
}

function ProductFormDialog({ title, open, mode, initialValues, loading, error, onClose, onSubmit }: Props) {
  const [values, setValues] = useState<FormValues>(defaults);
  const [priceInput, setPriceInput] = useState('');
  const [errors, setErrors] = useState<string[]>([]);

  const priceValidation = parsePrice(priceInput);

  useEffect(() => {
    if (open) {
      setValues(initialValues ? formValuesFromPayload(initialValues) : defaults);
      setPriceInput(initialValues ? initialValues.price.toFixed(2) : '');
      setErrors([]);
    }
  }, [open, initialValues]);

  const canSubmit = priceValidation.ok && !loading;

  const handleSubmit = async (e: FormEvent) => {
    e.preventDefault();
    const validation = validate(values);
    if (validation.length || !priceValidation.ok) {
      setErrors(validation);
      return;
    }
    setErrors([]);
    await onSubmit({ ...values, price: priceValidation.value });
  };

  const handlePriceChange = (value: string) => {
    setPriceInput(value);
    if (errors.length) {
      setErrors([]);
    }
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
          <button type="submit" form="product-form" className="btn btn-primary" disabled={!canSubmit}>
            {loading ? 'Saving...' : mode === 'create' ? 'Create Product' : 'Update Product'}
          </button>
        </>
      }
    >
      <form id="product-form" data-testid="product-form" className="grid" onSubmit={handleSubmit}>
        <label className="form-field">
          <span>SKU</span>
          <input
            className="input"
            required
            value={values.sku}
            onChange={(e) => setValues((prev) => ({ ...prev, sku: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Name</span>
          <input
            className="input"
            required
            value={values.name}
            onChange={(e) => setValues((prev) => ({ ...prev, name: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Description</span>
          <textarea
            className="input"
            required
            value={values.description}
            onChange={(e) => setValues((prev) => ({ ...prev, description: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Price</span>
          <input
            className="input"
            required
            type="text"
            inputMode="decimal"
            placeholder="49.00"
            value={priceInput}
            onChange={(e) => handlePriceChange(e.target.value)}
          />
          {priceValidation.error && <span className="field-error">{priceValidation.error}</span>}
        </label>
        <label className="form-field">
          <span>Currency</span>
          <input
            className="input"
            required
            value={values.currency}
            onChange={(e) => setValues((prev) => ({ ...prev, currency: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Category</span>
          <input
            className="input"
            required
            value={values.category}
            onChange={(e) => setValues((prev) => ({ ...prev, category: e.target.value }))}
          />
        </label>
        <label className="form-field">
          <span>Active</span>
          <select
            className="input"
            value={values.active ? 'true' : 'false'}
            onChange={(e) => setValues((prev) => ({ ...prev, active: e.target.value === 'true' }))}
          >
            <option value="true">Active</option>
            <option value="false">Inactive</option>
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

export default ProductFormDialog;
