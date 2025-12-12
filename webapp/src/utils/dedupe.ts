export function dedupeByKey<T>(items: T[], keyFn: (item: T) => string | number | undefined | null): T[] {
  const seen = new Set<string>();
  const deduped: T[] = [];

  for (const item of items) {
    const rawKey = keyFn(item);
    const key = rawKey == null ? undefined : String(rawKey).trim();
    if (!key) {
      deduped.push(item);
      continue;
    }
    if (seen.has(key)) {
      continue;
    }
    seen.add(key);
    deduped.push(item);
  }

  return deduped;
}
