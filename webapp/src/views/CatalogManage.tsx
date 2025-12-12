import { useCallback, useEffect, useState } from 'react';
import Card from '../components/ui/Card';
import Table from '../components/ui/Table';
import Badge from '../components/ui/Badge';
import Dialog from '../components/ui/Dialog';
import ProductFormDialog from '../components/forms/ProductFormDialog';
import { Product, createProduct, deleteProduct, listProducts, updateProduct } from '../api/client';
import { dedupeByKey } from '../utils/dedupe';

function CatalogManage() {
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const [formError, setFormError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [editTarget, setEditTarget] = useState<Product | null>(null);
  const [deleteTarget, setDeleteTarget] = useState<Product | null>(null);
  const [saving, setSaving] = useState(false);

  const loadProducts = useCallback(async () => {
    setLoading(true);
    setError(null);
    try {
      const data = await listProducts();
      setProducts(dedupeByKey(data, (p) => p.sku ?? p.id));
    } catch (err) {
      console.error(err);
      setError('Unable to load catalog');
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    loadProducts();
  }, [loadProducts]);

  const handleCreate = async (values: Parameters<typeof createProduct>[0]) => {
    setSaving(true);
    setFormError(null);
    setToast(null);
    try {
      await createProduct({ ...values, price: Number(values.price) });
      setToast('Product created');
      setCreateOpen(false);
      await loadProducts();
    } catch (err) {
      console.error(err);
      setFormError('Failed to create product');
    } finally {
      setSaving(false);
    }
  };

  const handleUpdate = async (values: Parameters<typeof createProduct>[0]) => {
    if (!editTarget) return;
    setSaving(true);
    setFormError(null);
    setToast(null);
    try {
      const updated = await updateProduct(editTarget.id, { ...values, price: Number(values.price) });
      setProducts((prev) => prev.map((p) => (p.id === updated.id ? updated : p)));
      setToast('Product updated');
      setEditTarget(null);
    } catch (err) {
      console.error(err);
      setFormError('Failed to update product');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async () => {
    if (!deleteTarget) return;
    setSaving(true);
    setToast(null);
    setFormError(null);
    try {
      await deleteProduct(deleteTarget.id);
      setProducts((prev) => prev.filter((p) => p.id !== deleteTarget.id));
      setToast('Product deleted');
      setDeleteTarget(null);
    } catch (err) {
      console.error(err);
      setFormError('Failed to delete product');
    } finally {
      setSaving(false);
    }
  };

  const headers = ['Name', 'SKU', 'Category', 'Price', 'Status', 'Actions'];
  const rows = products.map((product) => [
    product.name,
    product.sku,
    product.category,
    `${product.currency} ${product.price?.toFixed?.(2) ?? product.price}`,
    <Badge tone={product.active ? 'success' : 'warning'} key={`${product.id}-badge`}>
      {product.active ? 'Active' : 'Inactive'}
    </Badge>,
    <div key={`${product.id}-actions`} style={{ display: 'flex', gap: '8px' }}>
      <button type="button" className="btn btn-ghost" onClick={() => setEditTarget(product)}>
        Edit
      </button>
      <button type="button" className="btn btn-ghost" onClick={() => setDeleteTarget(product)}>
        Delete
      </button>
    </div>
  ]);

  return (
    <div className="page">
      <div className="section-title">
        <h2>Manage Catalog</h2>
        <span className="chip">Quarkus + soft-delete</span>
      </div>
      <Card
        title="Products"
        actions={
          <div style={{ display: 'flex', gap: '8px' }}>
            <button type="button" className="btn btn-primary" onClick={() => setCreateOpen(true)}>
              New Product
            </button>
            <button type="button" className="btn btn-ghost" onClick={loadProducts} disabled={loading}>
              Refresh
            </button>
          </div>
        }
      >
        {loading && <p>Loading products...</p>}
        {error && <p>{error}</p>}
        {!loading && !error && products.length === 0 && <p>No products yet.</p>}
        {!loading && !error && products.length > 0 && <Table headers={headers} rows={rows} />}
        {toast && <p style={{ marginTop: '12px' }}>{toast}</p>}
        {formError && <p style={{ marginTop: '12px', color: 'var(--color-danger, #b42318)' }}>{formError}</p>}
      </Card>

      <ProductFormDialog
        title="Create Product"
        open={createOpen}
        mode="create"
        loading={saving}
        error={formError}
        onClose={() => setCreateOpen(false)}
        onSubmit={handleCreate}
      />

      <ProductFormDialog
        title="Edit Product"
        open={!!editTarget}
        mode="edit"
        initialValues={editTarget ?? undefined}
        loading={saving}
        error={formError}
        onClose={() => setEditTarget(null)}
        onSubmit={handleUpdate}
      />

      <Dialog
        title="Delete Product"
        open={!!deleteTarget}
        onClose={() => setDeleteTarget(null)}
        footer={
          <>
            <button type="button" className="btn btn-ghost" onClick={() => setDeleteTarget(null)}>
              Cancel
            </button>
            <button type="button" className="btn btn-primary" onClick={handleDelete} disabled={saving}>
              {saving ? 'Deleting...' : 'Delete Product'}
            </button>
          </>
        }
      >
        <p>
          Delete <strong>{deleteTarget?.name}</strong>? This marks it inactive in the catalog service.
        </p>
      </Dialog>
    </div>
  );
}

export default CatalogManage;
