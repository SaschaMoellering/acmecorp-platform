import { FormEvent, useCallback, useEffect, useMemo, useState } from 'react';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import { Product, createProduct, deleteProduct, listProducts, updateProduct } from '../api/client';

type ProductFormState = {
  sku: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  category: string;
  active: boolean;
};

function Catalog() {
  const [products, setProducts] = useState<Product[]>([]);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('all');
  const [error, setError] = useState<string | null>(null);
  const [lastAdded, setLastAdded] = useState<string | null>(null);
  const [message, setMessage] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [creating, setCreating] = useState(false);
  const [savingEdit, setSavingEdit] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [createForm, setCreateForm] = useState<ProductFormState>({
    sku: '',
    name: '',
    description: '',
    price: 0,
    currency: 'USD',
    category: '',
    active: true
  });
  const [editForm, setEditForm] = useState<ProductFormState>({
    sku: '',
    name: '',
    description: '',
    price: 0,
    currency: 'USD',
    category: '',
    active: true
  });

  const resetMessages = () => {
    setMessage(null);
    setActionError(null);
  };

  const loadProducts = useCallback(async () => {
    try {
      const data = await listProducts();
      setProducts(data);
      setError(null);
    } catch (err) {
      console.error(err);
      setProducts([]);
      setError('Failed to load catalog');
    }
  }, []);

  useEffect(() => {
    loadProducts();
  }, [loadProducts]);

  const categories = useMemo(() => Array.from(new Set(products.map((p) => p.category))), [products]);

  const filtered = useMemo(() => {
    return products.filter((p) => {
      const matchesCategory = category === 'all' || p.category === category;
      const q = query.toLowerCase();
      const matchesQuery = p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q);
      return matchesCategory && matchesQuery;
    });
  }, [products, query, category]);

  const handleCreate = async (e: FormEvent) => {
    e.preventDefault();
    resetMessages();
    setCreating(true);
    try {
      await createProduct({ ...createForm, price: Number(createForm.price) });
      setMessage('Product saved');
      setCreateForm({
        sku: '',
        name: '',
        description: '',
        price: 0,
        currency: 'USD',
        category: '',
        active: true
      });
      await loadProducts();
    } catch (err) {
      console.error(err);
      setActionError('Failed to save product');
    } finally {
      setCreating(false);
    }
  };

  const handleUpdate = async (e: FormEvent) => {
    e.preventDefault();
    if (!editingId) return;
    resetMessages();
    setSavingEdit(true);
    try {
      await updateProduct(editingId, { ...editForm, price: Number(editForm.price) });
      setMessage('Product updated');
      setEditingId(null);
      await loadProducts();
    } catch (err) {
      console.error(err);
      setActionError('Failed to update product');
    } finally {
      setSavingEdit(false);
    }
  };

  const handleDelete = async (id: string) => {
    resetMessages();
    const confirmed = window.confirm('Delete this product?');
    if (!confirmed) return;

    try {
      await deleteProduct(id);
      setProducts((prev) => prev.filter((p) => p.id !== id));
      setMessage('Product deleted');
      if (editingId === id) {
        setEditingId(null);
      }
    } catch (err) {
      console.error(err);
      setActionError('Failed to delete product');
    }
  };

  const startEdit = (product: Product) => {
    setEditingId(product.id);
    setEditForm({
      sku: product.sku,
      name: product.name,
      description: product.description,
      price: product.price,
      currency: product.currency,
      category: product.category,
      active: product.active
    });
  };

  return (
    <div className="page">
      <div className="grid two">
        <Card
          title="Catalog"
          actions={
            <div className="filter-row">
              <input
                placeholder="Search products..."
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                className="input"
              />
              <select value={category} onChange={(e) => setCategory(e.target.value)} className="input">
                <option value="all">All categories</option>
                {categories.map((c) => (
                  <option key={c} value={c}>
                    {c}
                  </option>
                ))}
              </select>
            </div>
          }
        >
          <div className="grid two">
            {filtered.map((p) => (
              <div key={p.id} className="catalog-card">
                <div className="catalog-head">
                  <div>
                    <div className="catalog-name">{p.name}</div>
                    <div className="catalog-sku">{p.sku}</div>
                  </div>
                  <Badge tone={p.active ? 'success' : 'warning'}>{p.active ? 'Active' : 'Inactive'}</Badge>
                </div>
                <p>{p.description}</p>
                <div className="catalog-foot">
                  <span className="price">
                    {p.currency} {p.price.toFixed?.(2) ?? p.price}
                  </span>
                  <span className="category-pill">{p.category}</span>
                  <div style={{ display: 'flex', gap: '8px' }}>
                    <button
                      type="button"
                      className="btn"
                      aria-label={`Add ${p.name} to order`}
                      onClick={() => setLastAdded(p.name)}
                    >
                      Add to Order
                    </button>
                    <button type="button" className="btn btn-ghost" onClick={() => startEdit(p)}>
                      Edit
                    </button>
                    <button type="button" className="btn btn-ghost" onClick={() => handleDelete(p.id)}>
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            ))}
            {filtered.length === 0 && <p>No products match the filters.</p>}
            {error && <p>{error}</p>}
          </div>
          {lastAdded && <p style={{ marginTop: '12px' }}>Added to order: {lastAdded}</p>}
          {(message || actionError) && <p>{message ?? actionError}</p>}
        </Card>

        <div className="grid">
          <Card title="Add Product">
            <form className="grid" onSubmit={handleCreate}>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>SKU</span>
                <input
                  required
                  className="input"
                  value={createForm.sku}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, sku: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Name</span>
                <input
                  required
                  className="input"
                  value={createForm.name}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, name: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Description</span>
                <textarea
                  required
                  className="input"
                  value={createForm.description}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, description: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Price</span>
                <input
                  required
                  min={0}
                  type="number"
                  className="input"
                  value={createForm.price}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, price: Number(e.target.value) }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Currency</span>
                <input
                  required
                  className="input"
                  value={createForm.currency}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, currency: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Category</span>
                <input
                  required
                  className="input"
                  value={createForm.category}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, category: e.target.value }))}
                />
              </label>
              <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                <span>Active</span>
                <select
                  className="input"
                  value={createForm.active ? 'true' : 'false'}
                  onChange={(e) => setCreateForm((prev) => ({ ...prev, active: e.target.value === 'true' }))}
                >
                  <option value="true">Active</option>
                  <option value="false">Inactive</option>
                </select>
              </label>
              <button type="submit" className="btn btn-primary" disabled={creating}>
                {creating ? 'Saving...' : 'Create Product'}
              </button>
            </form>
          </Card>

          {editingId && (
            <Card title={`Edit Product #${editingId}`}>
              <form className="grid" onSubmit={handleUpdate}>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>SKU</span>
                  <input
                    required
                    className="input"
                    value={editForm.sku}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, sku: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Name</span>
                  <input
                    required
                    className="input"
                    value={editForm.name}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, name: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Description</span>
                  <textarea
                    required
                    className="input"
                    value={editForm.description}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, description: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Price</span>
                  <input
                    required
                    min={0}
                    type="number"
                    className="input"
                    value={editForm.price}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, price: Number(e.target.value) }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Currency</span>
                  <input
                    required
                    className="input"
                    value={editForm.currency}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, currency: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Category</span>
                  <input
                    required
                    className="input"
                    value={editForm.category}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, category: e.target.value }))}
                  />
                </label>
                <label style={{ display: 'flex', flexDirection: 'column', gap: '6px' }}>
                  <span>Active</span>
                  <select
                    className="input"
                    value={editForm.active ? 'true' : 'false'}
                    onChange={(e) => setEditForm((prev) => ({ ...prev, active: e.target.value === 'true' }))}
                  >
                    <option value="true">Active</option>
                    <option value="false">Inactive</option>
                  </select>
                </label>
                <div style={{ display: 'flex', gap: '8px' }}>
                  <button type="submit" className="btn btn-primary" disabled={savingEdit}>
                    {savingEdit ? 'Saving...' : 'Update Product'}
                  </button>
                  <button type="button" className="btn btn-ghost" onClick={() => setEditingId(null)}>
                    Cancel
                  </button>
                </div>
              </form>
            </Card>
          )}
        </div>
      </div>
    </div>
  );
}

export default Catalog;
