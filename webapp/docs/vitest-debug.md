# Vitest Debug Notes

## Root Cause
- In this repo, `import { describe, it, vi, expect } from 'vitest'` resolved to an empty module during Vitest runs.
- As a result, the imported APIs were `undefined`, causing `describe is not a function` and `vi.mock` failures, and leading to zero tests collected.
- The globals (`globalThis.describe`, `globalThis.vi`) were present, but the module import was broken.
 - CI also used Jest's `--runInBand`, which Vitest doesn't support, so the run failed before tests executed.

## Fix
- Alias `vitest` to its ESM entry (`node_modules/vitest/dist/index.js`) in `webapp/vitest.config.ts`.
- Keep `test.globals = true`, `test.environment = 'jsdom'`, and `setupFiles = './src/setupTests.ts'`.
- This restores proper `vitest` module exports without touching test files.
 - Replace `--runInBand` with a single-thread Vitest pool in CI for deterministic runs.

## Reproduce
```sh
cd webapp
npx vitest run --config vitest.config.ts --reporter verbose
```

## Validate
- Tests are discovered and executed (non-zero test count).
- `src/__tests__/vitest-smoke.test.ts` passes.
