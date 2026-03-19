const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/**/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html}',
    './app/components/**/*.{erb,haml,html}'
  ],
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#f8f9fa',
          hover: '#f1f3f5',
          inset: '#e9ecef'
        },
        container: {
          DEFAULT: '#ffffff',
          inset: '#f8f9fa'
        },
        primary: {
          DEFAULT: '#1a1a1a',
          hover: '#333333'
        },
        secondary: {
          DEFAULT: '#6c757d',
          hover: '#495057'
        },
        border: {
          DEFAULT: '#dee2e6',
          secondary: '#e9ecef'
        },
        inverse: {
          DEFAULT: '#1a1a1a',
          hover: '#333333'
        },
        destructive: {
          DEFAULT: '#dc3545',
          hover: '#c82333'
        },
        success: {
          DEFAULT: '#28a745',
          hover: '#218838'
        },
        warning: {
          DEFAULT: '#ffc107',
          hover: '#e0a800'
        },
        income: '#ef4444',
        expense: '#22c55e',
        transfer: '#3b82f6'
      },
      fontFamily: {
        sans: ['Inter', ...defaultTheme.fontFamily.sans]
      },
      borderRadius: {
        DEFAULT: '8px',
        sm: '6px',
        lg: '12px',
        xl: '16px'
      },
      boxShadow: {
        'border-xs': '0 0 0 1px rgba(0, 0, 0, 0.05)',
        'border-sm': '0 1px 2px rgba(0, 0, 0, 0.05)',
        'border-md': '0 4px 6px -1px rgba(0, 0, 0, 0.1)',
        'border-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.1)'
      }
    }
  },
  plugins: []
}
