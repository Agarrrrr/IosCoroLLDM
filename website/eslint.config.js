import js from '@eslint/js'
import reactHooks from 'eslint-plugin-react-hooks'
import reactRefresh from 'eslint-plugin-react-refresh'

export default [
  {
    ignores: [
      'dist/**',
      'node_modules/**',
      '.preview-output/**',
      '.preview-tmp/**',
      'public/catalogo*.json',
      'public/roadmap-pending.json',
    ],
  },
  js.configs.recommended,
  {
    files: ['src/**/*.{js,jsx}', 'scripts/**/*.mjs'],
    languageOptions: {
      globals: {
        Audio: 'readonly',
        Buffer: 'readonly',
        Headers: 'readonly',
        Response: 'readonly',
        URL: 'readonly',
        URLSearchParams: 'readonly',
        console: 'readonly',
        document: 'readonly',
        fetch: 'readonly',
        import: 'readonly',
        IntersectionObserver: 'readonly',
        localStorage: 'readonly',
        process: 'readonly',
        window: 'readonly',
      },
      parserOptions: { ecmaFeatures: { jsx: true } },
    },
    plugins: { 'react-hooks': reactHooks, 'react-refresh': reactRefresh },
    rules: {
      'no-unused-vars': ['error', { argsIgnorePattern: '^_', caughtErrorsIgnorePattern: '^_' }],
      'react-hooks/rules-of-hooks': 'error',
      'react-hooks/exhaustive-deps': 'warn',
      'react-refresh/only-export-components': 'warn',
    },
  },
  {
    files: ['src/main.jsx', 'src/App.jsx', 'src/pages.jsx', 'src/components/**/*.jsx'],
    rules: { 'no-unused-vars': 'off', 'react-refresh/only-export-components': 'off' },
  },
  {
    files: ['preview-worker/**/*.js'],
    languageOptions: { globals: { Headers: 'readonly', Response: 'readonly', URL: 'readonly', console: 'readonly' } },
  },
]
