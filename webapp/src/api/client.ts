export type OrderStatus = 'NEW' | 'CONFIRMED' | 'CANCELLED' | 'FULFILLED';

export type OrderItem = {
  id?: number;
  productId: string;
  productName: string;
  unitPrice: number;
  quantity: number;
  lineTotal: number;
};

export type Order = {
  id: number;
  orderNumber: string;
  customerEmail: string;
  status: OrderStatus;
  totalAmount: number;
  currency: string;
  createdAt: string;
  updatedAt: string;
  items?: OrderItem[];
};

export type Product = {
  id: string;
  sku: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  category: string;
  active: boolean;
};

export type OrderItemPayload = {
  productId: string;
  quantity: number;
};

export type NewOrderPayload = {
  customerEmail: string;
  status: OrderStatus;
  items: OrderItemPayload[];
  currency?: string;
};

export type UpdateOrderPayload = Partial<NewOrderPayload>;

export type NewProductPayload = {
  sku: string;
  name: string;
  description: string;
  price: number;
  currency: string;
  category: string;
  active: boolean;
};

export type UpdateProductPayload = Partial<Omit<Product, 'id'>>;

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

async function handle<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init
  });
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`);
  }

  const text = await res.text();
  if (!text) {
    return undefined as T;
  }

  return JSON.parse(text);
}

export function fetchOrders(): Promise<Order[]> {
  return handle<Order[]>('/api/gateway/orders/latest');
}

export function fetchOrderById(id: string | number): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}`);
}

export function fetchCatalog(): Promise<Product[]> {
  return handle<Product[]>('/api/gateway/catalog');
}

export type SystemStatus = {
  service: string;
  status: string;
};

export async function fetchSystemStatus(): Promise<SystemStatus[]> {
  return handle<SystemStatus[]>('/api/gateway/system/status');
}

export async function fetchAnalyticsCounters(): Promise<Record<string, number>> {
  return handle<Record<string, number>>('/api/gateway/analytics/counters');
}

export function listOrders(): Promise<Order[]> {
  return handle<Order[]>('/api/gateway/orders');
}

export function getOrder(id: string): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}`);
}

export function createOrder(payload: NewOrderPayload): Promise<Order> {
  return handle<Order>('/api/gateway/orders', {
    method: 'POST',
    body: JSON.stringify(payload)
  });
}

export function updateOrder(id: string, payload: UpdateOrderPayload): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload)
  });
}

export async function deleteOrder(id: string): Promise<void> {
  await handle<void>(`/api/gateway/orders/${id}`, {
    method: 'DELETE'
  });
}

export function listProducts(): Promise<Product[]> {
  return handle<Product[]>('/api/gateway/catalog');
}

export function getProduct(id: string): Promise<Product> {
  return handle<Product>(`/api/gateway/catalog/${id}`);
}

export function createProduct(payload: NewProductPayload): Promise<Product> {
  return handle<Product>('/api/gateway/catalog', {
    method: 'POST',
    body: JSON.stringify(payload)
  });
}

export function updateProduct(id: string, payload: UpdateProductPayload): Promise<Product> {
  return handle<Product>(`/api/gateway/catalog/${id}`, {
    method: 'PUT',
    body: JSON.stringify(payload)
  });
}

export async function deleteProduct(id: string): Promise<void> {
  await handle<void>(`/api/gateway/catalog/${id}`, {
    method: 'DELETE'
  });
}

export async function seedCatalogDemoData(): Promise<void> {
  await handle<void>('/api/gateway/seed/catalog', {
    method: 'POST'
  });
}

export async function seedOrdersDemoData(): Promise<void> {
  await handle<void>('/api/gateway/seed/orders', {
    method: 'POST'
  });
}
