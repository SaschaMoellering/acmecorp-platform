const configuredApiBase = (import.meta.env.VITE_API_BASE_URL ?? '').trim();

export const API_BASE_URL = configuredApiBase.replace(/\/+$/, '');

export function buildApiUrl(path: string): string {
  return `${API_BASE_URL}${path}`;
}
