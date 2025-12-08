import { defineConfig, devices } from '@playwright/test';

const port = process.env.PORT ?? '5173';
const baseURL = process.env.BASE_URL ?? `http://127.0.0.1:${port}/`;

export default defineConfig({
  testDir: './tests-e2e',
  fullyParallel: true,
  timeout: 60_000,
  use: {
    baseURL,
    trace: 'retain-on-failure',
  },
  webServer: {
    command: `npm run dev -- --host --port ${port}`,
    url: baseURL,
    reuseExistingServer: !process.env.CI,
    timeout: 120_000,
  },
  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],
});
