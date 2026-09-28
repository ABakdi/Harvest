// The root configuration, plus what React needs on top: the rules of
// hooks, which the type checker cannot see.
import reactHooks from 'eslint-plugin-react-hooks';
import root from '../../eslint.config.js';

export default [
  ...root,
  { ignores: ['dev-dist/**', 'public/**'] },
  {
    files: ['**/*.{ts,tsx}'],
    ...reactHooks.configs.flat['recommended-latest'],
  },
  {
    // A promise nobody handles is an action that fails in silence: user
    // actions go through runAction, background work through background
    // (src/lib/actions.ts), and a bare `void` no longer passes.
    files: ['src/**/*.{ts,tsx}'],
    rules: { '@typescript-eslint/no-floating-promises': ['error', { ignoreVoid: false }] },
  },
];
