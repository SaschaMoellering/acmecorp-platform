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

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

async function handle<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init
  });
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`);
  }
  return res.json();
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
