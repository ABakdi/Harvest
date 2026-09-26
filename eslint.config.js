// One lint configuration for every TypeScript workspace. The Flutter
// app has its own analyzer and is not this file's business.
import js from '@eslint/js';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: [
      '**/dist/**',
      '**/node_modules/**',
      '**/coverage/**',
      '**/fixtures/**',
      'apps/mobile/**',
      'docs/**',
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommendedTypeChecked,
  {
    languageOptions: {
      parserOptions: {
        projectService: true,
        tsconfigRootDir: import.meta.dirname,
      },
    },
    rules: {
      '@typescript-eslint/no-unused-vars': [
        'error',
        { argsIgnorePattern: '^_', varsIgnorePattern: '^_' },
      ],
      '@typescript-eslint/consistent-type-imports': 'error',
      eqeqeq: ['error', 'always'],
    },
  },
  {
    // Config files sit outside every tsconfig; they get the plain rules.
    files: ['**/*.config.{js,ts}', 'eslint.config.js'],
    extends: [tseslint.configs.disableTypeChecked],
  },
);
