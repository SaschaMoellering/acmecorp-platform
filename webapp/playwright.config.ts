import { defineConfig, devices } from '@playwright/test';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));

const port = process.env.PORT ?? '4173';
// bindHost is where the dev server listens; accessHost is what Playwright hits.
const bindHost = process.env.HOST ?? '0.0.0.0';
const accessHost = process.env.BASE_HOST ?? '127.0.0.1';
const baseURL = process.env.BASE_URL ?? `http://${accessHost}:${port}/`;

export default defineConfig({
  testDir: './tests-e2e',
  fullyParallel: true,
  timeout: 60_000,
  use: {
    baseURL,
    trace: 'retain-on-failure',
  },
  // Vite dev server is started programmatically in playwright.setup.ts to avoid sandbox port-binding limits on spawned processes.
  globalSetup: './playwright.setup.ts',
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
