import { useEffect, useMemo, useState } from 'react';
import Card from '../components/ui/Card';
import Badge from '../components/ui/Badge';
import { Product, fetchCatalog } from '../api/client';

function Catalog() {
  const [products, setProducts] = useState<Product[]>([]);
  const [query, setQuery] = useState('');
  const [category, setCategory] = useState('all');

  useEffect(() => {
    fetchCatalog().then(setProducts).catch(() => setProducts([]));
  }, []);

  const categories = useMemo(() => Array.from(new Set(products.map((p) => p.category))), [products]);

  const filtered = useMemo(() => {
    return products.filter((p) => {
      const matchesCategory = category === 'all' || p.category === category;
      const q = query.toLowerCase();
      const matchesQuery = p.name.toLowerCase().includes(q) || p.description.toLowerCase().includes(q);
      return matchesCategory && matchesQuery;
    });
  }, [products, query, category]);

  return (
    <div className="page">
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
              </div>
            </div>
          ))}
          {filtered.length === 0 && <p>No products match the filters.</p>}
        </div>
      </Card>
    </div>
  );
}

export default Catalog;
