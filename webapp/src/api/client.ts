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

export type OrderStatusHistory = {
  id: number;
  orderId: number;
  oldStatus: OrderStatus | null;
  newStatus: OrderStatus;
  reason: string;
  changedAt: string;
};

export type NewOrderPayload = {
  customerEmail: string;
  status?: OrderStatus;
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

export type PageResponse<T> = {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
};

export type ApiErrorResponse = {
  timestamp: string;
  traceId: string | null;
  status: number;
  error: string;
  message: string;
  path: string;
  fields?: Record<string, string>;
};

export type ApiError = Error & {
  status: number;
  error?: string;
  fields?: Record<string, string>;
  traceId?: string | null;
  path?: string;
};

const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8080';

async function handle<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, {
    headers: { 'Content-Type': 'application/json' },
    ...init
  });

  const text = await res.text();
  if (!res.ok) {
    const error = toApiError(res, text, path);
    console.error('API error for', path, 'status:', res.status, 'body:', text);
    throw error;
  }
  if (!text) {
    return undefined as T;
  }

  return JSON.parse(text);
}

function toApiError(res: Response, text: string, path: string): ApiError {
  let parsed: ApiErrorResponse | null = null;
  if (text) {
    try {
      parsed = JSON.parse(text) as ApiErrorResponse;
    } catch {
      parsed = null;
    }
  }
  const message = parsed?.message || `Request failed: ${res.status}`;
  const error = new Error(message) as ApiError;
  error.status = res.status;
  error.error = parsed?.error;
  error.fields = parsed?.fields;
  error.traceId = parsed?.traceId ?? null;
  error.path = parsed?.path || path;
  return error;
}

export function fetchOrders(): Promise<Order[]> {
  return handle<Order[]>('/api/gateway/orders/latest');
}

export function fetchOrderById(id: string | number): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}`);
}

export function fetchOrderHistory(id: string | number): Promise<OrderStatusHistory[]> {
  return handle<OrderStatusHistory[]>(`/api/gateway/orders/${id}/history`);
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

export function listOrdersPage(page = 0, size = 20): Promise<PageResponse<Order>> {
  return handle<PageResponse<Order>>(`/api/gateway/orders?page=${page}&size=${size}`);
}

export async function listOrders(page = 0, size = 20): Promise<Order[]> {
  const response = await listOrdersPage(page, size);
  return response.content;
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

export function confirmOrder(id: string): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}/confirm`, { method: 'POST' });
}

export function cancelOrder(id: string): Promise<Order> {
  return handle<Order>(`/api/gateway/orders/${id}/cancel`, { method: 'POST' });
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

export type SeedResult = {
  ordersCreated: number;
  productsCreated: number;
  message: string;
};

export async function seedDemoData(): Promise<SeedResult> {
  return handle<SeedResult>('/api/gateway/tools/seed', {
    method: 'POST'
  });
}
