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
];
