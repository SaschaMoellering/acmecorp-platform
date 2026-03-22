# AcmeCorp Webapp

Vite + React + TypeScript single-page UI for the AcmeCorp demo platform.

## Run locally

```bash
cd webapp
npm install
npm run dev   # http://localhost:5173
```

The app reads the gateway base URL from Vite env files:

- `.env.development` -> `http://localhost:8080`
- `.env.production` -> `https://api.acmecorp.autoscaling.io`

You can override either with `VITE_API_BASE_URL=... npm run dev` or `VITE_API_BASE_URL=... npm run build`.

## Structure

- `src/theme/styles` — global tokens and typography
- `src/assets` — SVG logo and icons
- `src/api` — gateway API client
- `src/components` — layout shell, UI primitives, feature widgets
- `src/views` — routed pages: Dashboard, Orders, Catalog, Analytics, System

## CI note: `dist` worker shim

In CI we create a temporary `dist/worker.js` symlink to keep Vitest/Tinypool happy in clean checkouts.
`dist/` is intentionally not tracked in git.
