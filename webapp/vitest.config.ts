/// <reference types="vitest/config" />

import { defineConfig, mergeConfig } from 'vitest/config'
import { resolve } from 'node:path'
import viteConfig from './vite.config.ts'

// Vitest will use *this* file instead of any root-level config
export default mergeConfig(
  viteConfig,
  defineConfig({
    resolve: {
      alias: {
        vitest: resolve('node_modules/vitest/dist/index.js'),
      },
    },
    test: {
      environment: 'jsdom',
      globals: true,
      setupFiles: './src/setupTests.ts',
      include: ['src/__tests__/**/*.test.{ts,tsx}'],
      exclude: [
        'node_modules/**',
        'dist/**',
        'cypress/**',
        '.{idea,git,cache,output,temp}/**'
      ],
      // Avoid any Tinypool worker shenanigans
      pool: 'forks',
    },
  }),
)
