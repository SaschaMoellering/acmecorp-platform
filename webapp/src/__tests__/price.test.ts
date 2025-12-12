import { describe, expect, it } from 'vitest';
import { parsePrice, PRICE_NEGATIVE, PRICE_PRECISION, PRICE_REQUIRED } from '../utils/price';

describe('parsePrice', () => {
  it('accepts valid numeric formats', () => {
    expect(parsePrice('0')).toEqual({ ok: true, value: 0 });
    expect(parsePrice('19')).toEqual({ ok: true, value: 19 });
    expect(parsePrice('19.9')).toEqual({ ok: true, value: 19.9 });
    expect(parsePrice('19,90')).toEqual({ ok: true, value: 19.9 });
  });

  it('rejects invalid inputs', () => {
    expect(parsePrice('')).toEqual({ ok: false, error: PRICE_REQUIRED });
    expect(parsePrice('-1').error).toBe(PRICE_NEGATIVE);
    expect(parsePrice('12.999').error).toBe(PRICE_PRECISION);
    expect(parsePrice('abc').ok).toBe(false);
  });
});
