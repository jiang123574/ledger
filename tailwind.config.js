const defaultTheme = require('tailwindcss/defaultTheme')

module.exports = {
  content: [
    './public/**/*.html',
    './app/helpers/**/*.rb',
    './app/javascript/**/*.js',
    './app/views/**/*.{erb,haml,html}',
    './app/components/**/*.{erb,haml,html}'
  ],
  darkMode: 'class',
  theme: {
    extend: {
      colors: {
        surface: {
          DEFAULT: '#f8f9fa',
          hover: '#f1f3f5',
          inset: '#e9ecef',
          dark: '#1a1a1a',
          'dark-hover': '#262626',
          'dark-inset': '#262626'
        },
        container: {
          DEFAULT: '#ffffff',
          inset: '#f8f9fa',
          dark: '#262626',
          'dark-inset': '#1a1a1a'
        },
        primary: {
          DEFAULT: '#1a1a1a',
          hover: '#333333',
          dark: '#f8f9fa',
          'dark-hover': '#e9ecef'
        },
        secondary: {
          DEFAULT: '#6c757d',
          hover: '#495057',
          dark: '#9ca3af',
          'dark-hover': '#d1d5db'
        },
        border: {
          DEFAULT: '#dee2e6',
          secondary: '#e9ecef',
          dark: '#404040',
          'dark-secondary': '#333333'
        },
        inverse: {
          DEFAULT: '#1a1a1a',
          hover: '#333333',
          dark: '#f8f9fa',
          'dark-hover': '#e9ecef'
        },
        destructive: {
          DEFAULT: '#dc3545',
          hover: '#c82333',
          dark: '#ef4444',
          'dark-hover': '#dc2626'
        },
        success: {
          DEFAULT: '#28a745',
          hover: '#218838',
          dark: '#22c55e',
          'dark-hover': '#16a34a'
        },
        warning: {
          DEFAULT: '#ffc107',
          hover: '#e0a800',
          dark: '#eab308',
          'dark-hover': '#ca8a04'
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
        'border-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.1)',
        'dark-border-xs': '0 0 0 1px rgba(255, 255, 255, 0.05)',
        'dark-border-sm': '0 1px 2px rgba(255, 255, 255, 0.05)',
        'dark-border-md': '0 4px 6px -1px rgba(0, 0, 0, 0.3)',
        'dark-border-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.4)'
      }
    }
  },
  plugins: []
}
