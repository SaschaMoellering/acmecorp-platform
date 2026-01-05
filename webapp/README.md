# AcmeCorp Webapp

Vite + React + TypeScript single-page UI for the AcmeCorp demo platform.

## Run locally

```bash
cd webapp
npm install
npm run dev   # http://localhost:5173
```

The app expects the gateway-service at `http://localhost:8080` (configurable via `VITE_API_BASE_URL`).

## Structure

- `src/theme/styles` — global tokens and typography
- `src/assets` — SVG logo and icons
- `src/api` — gateway API client
- `src/components` — layout shell, UI primitives, feature widgets
- `src/views` — routed pages: Dashboard, Orders, Catalog, Analytics, System

## Testing

```bash
cd webapp
npx vitest run --config vitest.config.ts --pool=threads --poolOptions.threads.singleThread
```

Vitest does not support Jest's `--runInBand`, so CI uses a single-thread pool for deterministic runs.
