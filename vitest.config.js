import path from 'node:path'
import { defineConfig } from 'vitest/config'

const appModule = (name) => path.resolve(process.cwd(), 'app/javascript', name)

export default defineConfig({
  // 用 importmap 里的裸模块名导入应用内模块（与浏览器一致），否则 controller 无法被单测引用
  resolve: {
    alias: {
      controllers: appModule('controllers'),
      utils: appModule('utils'),
      amount_expression: appModule('amount_expression.js'),
      bill_formatters: appModule('bill_formatters.js'),
      entry_card_renderer: appModule('entry_card_renderer.js'),
      selectors: appModule('selectors.js')
    }
  },
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
