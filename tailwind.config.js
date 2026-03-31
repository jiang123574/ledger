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
        income: {
          DEFAULT: 'var(--color-income, #ef4444)',
          soft: 'rgba(var(--color-income-rgb, 239, 68, 68), 0.1)',
          light: 'rgba(var(--color-income-rgb, 239, 68, 68), 0.2)'
        },
        expense: {
          DEFAULT: 'var(--color-expense, #22c55e)',
          soft: 'rgba(var(--color-expense-rgb, 34, 197, 94), 0.1)',
          light: 'rgba(var(--color-expense-rgb, 34, 197, 94), 0.2)'
        },
        transfer: '#3b82f6',
        gray: {
          25: '#fafafa',
          50: '#f7f7f7',
          100: '#f0f0f0',
          200: '#e7e7e7',
          300: '#cfcfcf',
          400: '#9e9e9e',
          500: '#737373',
          600: '#5c5c5c',
          700: '#363636',
          800: '#242424',
          900: '#171717'
        },
        red: {
          25: '#fffbfb',
          50: '#fff1f0',
          100: '#ffdedb',
          200: '#feb9b3',
          300: '#f88c86',
          400: '#ed4e4e',
          500: '#f13636',
          600: '#ec2222',
          700: '#c91313',
          800: '#a40e0e',
          900: '#7e0707'
        },
        green: {
          25: '#f6fef9',
          50: '#ecfdf3',
          100: '#d1fadf',
          200: '#a6f4c5',
          300: '#6ce9a6',
          400: '#32d583',
          500: '#12b76a',
          600: '#10a861',
          700: '#078c52',
          800: '#05603a',
          900: '#054f31'
        },
        yellow: {
          25: '#fffcf5',
          50: '#fffaeb',
          100: '#fef0c7',
          200: '#fedf89',
          300: '#fec84b',
          400: '#fdb022',
          500: '#f79009',
          600: '#dc6803',
          700: '#b54708',
          800: '#93370d',
          900: '#7a2e0e'
        },
        blue: {
          25: '#f5faff',
          50: '#eff8ff',
          100: '#d1e9ff',
          200: '#b2ddff',
          300: '#84caff',
          400: '#53b1fd',
          500: '#2e90fa',
          600: '#1570ef',
          700: '#175cd3',
          800: '#1849a9',
          900: '#194185'
        },
        indigo: {
          25: '#f5f8ff',
          50: '#eff4ff',
          100: '#e0eaff',
          200: '#c7d7fe',
          300: '#a4bcfd',
          400: '#8098f9',
          500: '#6172f3',
          600: '#444ce7',
          700: '#3538cd',
          800: '#2d31a6',
          900: '#2d3282'
        },
        violet: {
          25: '#fbfaff',
          50: '#f5f3ff',
          100: '#ece9fe',
          200: '#ddd6fe',
          300: '#c3b5fd',
          400: '#a48afb',
          500: '#875bf7',
          600: '#7839ee',
          700: '#6927da',
          800: '#5d1cc5',
          900: '#4a1b9a'
        },
        fuchsia: {
          25: '#fefaff',
          50: '#fdf4ff',
          100: '#fbe8ff',
          200: '#f6d0fe',
          300: '#eeaafd',
          400: '#e478fa',
          500: '#d444f1',
          600: '#ba24d5',
          700: '#9f1ab1',
          800: '#821890',
          900: '#6f1877'
        },
        pink: {
          25: '#fffafc',
          50: '#fef0f7',
          100: '#ffd1e2',
          200: '#ffb1ce',
          300: '#fd8fba',
          400: '#f86ba7',
          500: '#f23e94',
          600: '#d5327f',
          700: '#ba256b',
          800: '#9e1958',
          900: '#840b45'
        },
        orange: {
          25: '#fff9f5',
          50: '#fff4ed',
          100: '#ffe6d5',
          200: '#ffd6ae',
          300: '#ff9c66',
          400: '#ff692e',
          500: '#ff4405',
          600: '#e62e05',
          700: '#bc1b06',
          800: '#97180c',
          900: '#771a0d'
        },
        cyan: {
          25: '#f5feff',
          50: '#ecfdff',
          100: '#cff9fe',
          200: '#a5f0fc',
          300: '#67e3f9',
          400: '#22ccee',
          500: '#06aed4',
          600: '#088ab2',
          700: '#0e7090',
          800: '#155b75',
          900: '#155b75'
        },
        success: {
          DEFAULT: '#10a861',
          hover: '#12b76a'
        },
        warning: {
          DEFAULT: '#dc6803',
          hover: '#f79009'
        },
        destructive: {
          DEFAULT: '#ec2222',
          hover: '#f13636'
        }
      },
      fontFamily: {
        sans: ['Geist', ...defaultTheme.fontFamily.sans],
        mono: ['Geist Mono', ...defaultTheme.fontFamily.mono]
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
        'dark-border-lg': '0 10px 15px -3px rgba(0, 0, 0, 0.4)',
        'shadow-xs': '0px 1px 2px 0px rgba(11, 11, 11, 0.06)',
        'shadow-sm': '0px 1px 6px 0px rgba(11, 11, 11, 0.06)',
        'shadow-md': '0px 4px 8px -2px rgba(11, 11, 11, 0.06)',
        'shadow-lg': '0px 12px 16px -4px rgba(11, 11, 11, 0.06)',
        'shadow-xl': '0px 20px 24px -4px rgba(11, 11, 11, 0.06)'
      },
      keyframes: {
        'stroke-fill': {
          '0%': { strokeDashoffset: '43.9822971503' },
          '100%': { strokeDashoffset: '0' }
        }
      },
      animation: {
        'stroke-fill': 'stroke-fill 3s 300ms forwards'
      }
    }
  },
  plugins: []
}
