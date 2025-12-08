import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,                    // 👈 keep this
    setupFiles: './src/setupTests.ts',
    include: ['src/__tests__/**/*.test.{ts,tsx}'],
    exclude: [
      'node_modules/**',
      'dist/**',
      'cypress/**',
      '.{idea,git,cache,output,temp}/**'
    ]
  },
})
