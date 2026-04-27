import { defineConfig } from 'vitest/config'

export default defineConfig({
  test: {
    // Test environment
    environment: 'jsdom',

    // Global test setup
    globals: true,

    // Include test files
    include: ['test/javascript/**/*.test.js'],

    // Exclude patterns
    exclude: ['**/node_modules/**', '**/vendor/**'],

    // Setup files
    setupFiles: ['test/javascript/setup.js'],

    // Coverage configuration
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['app/javascript/controllers/**/*.js'],
      exclude: ['app/javascript/controllers/index.js', 'app/javascript/controllers/application.js']
    }
  },

  // Resolve paths for importmap compatibility
  resolve: {
    alias: {
      '@hotwired/stimulus': './vendor/assets/javascripts/@hotwired--stimulus.js'
    }
  }
})