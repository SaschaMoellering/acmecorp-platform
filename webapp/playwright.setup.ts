import type { FullConfig } from '@playwright/test';
import { createServer, type ViteDevServer } from 'vite';

/**
 * Start a Vite dev server in-process before E2E runs.
 * Using an in-process server avoids sandbox restrictions that block child
 * processes from binding to local ports.
 */
export default async function globalSetup(_config: FullConfig) {
  const port = Number(process.env.PORT ?? 4173);
  const host = process.env.HOST ?? '0.0.0.0';

  // Force the web app to call the dev server itself during E2E runs.
  process.env.VITE_API_BASE_URL = `http://127.0.0.1:${port}`;

  const server: ViteDevServer = await createServer({
    server: {
      host,
      port,
      strictPort: true
    }
  });

  await server.listen();
  // Make the URLs visible in the test logs if needed.
  server.printUrls();

  return async () => {
    await server.close();
  };
}
