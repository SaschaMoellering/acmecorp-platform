export const PRICE_REQUIRED = 'Price is required.';
export const PRICE_INVALID_FORMAT = 'Enter a valid price with up to two decimals.';
export const PRICE_PRECISION = 'Price can have up to two decimal places.';
export const PRICE_NEGATIVE = 'Price must be zero or higher.';

export type PriceParseResult =
  | { ok: true; value: number }
  | { ok: false; error: string };

export function parsePrice(input: string): PriceParseResult {
  const trimmed = input.trim();
  if (!trimmed) {
    return { ok: false, error: PRICE_REQUIRED };
  }

  const normalized = trimmed.replace(/,/g, '.');
  if ((normalized.match(/\./g) ?? []).length > 1) {
    return { ok: false, error: PRICE_INVALID_FORMAT };
  }

  const isNegative = normalized.startsWith('-');
  const magnitude = isNegative ? normalized.slice(1) : normalized;

  if (!/^\d+(\.\d+)?$/.test(magnitude)) {
    return { ok: false, error: PRICE_INVALID_FORMAT };
  }

  const [, fraction = ''] = magnitude.split('.');
  if (fraction.length > 2) {
    return { ok: false, error: PRICE_PRECISION };
  }

  const value = Number(normalized);
  if (Number.isNaN(value)) {
    return { ok: false, error: PRICE_INVALID_FORMAT };
  }

  if (value < 0) {
    return { ok: false, error: PRICE_NEGATIVE };
  }

  return { ok: true, value };
}
