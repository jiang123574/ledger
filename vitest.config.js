import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    environment: 'jsdom',
    globals: true,
    include: ['test/javascript/**/*.test.js'],
    exclude: ['**/node_modules/**', '**/vendor/**'],
    setupFiles: ['test/javascript/setup.js'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['app/javascript/controllers/**/*.js'],
      exclude: ['app/javascript/controllers/index.js', 'app/javascript/controllers/application.js']
    }
  }
})
