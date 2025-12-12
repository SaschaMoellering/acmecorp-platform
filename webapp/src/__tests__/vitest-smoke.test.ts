import { describe, it, expect, vi } from 'vitest';

describe('vitest smoke', () => {
  it('has working globals', () => {
    expect(typeof describe).toBe('function');
    expect(typeof it).toBe('function');
    expect(typeof vi).toBe('object');
    expect(typeof vi.fn).toBe('function');
  });

  it('can use vi.fn', () => {
    const fn = vi.fn().mockReturnValue(42);
    expect(fn()).toBe(42);
    expect(fn).toHaveBeenCalledTimes(1);
  });
});
