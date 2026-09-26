import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    include: ['test/**/*.test.ts'],
    // One mongod for the whole run; each test file gets its own database.
    globalSetup: ['test/global-setup.ts'],
    // argon2 at OWASP cost, and a real engine: slower than a mock, and
    // the point.
    testTimeout: 30_000,
    hookTimeout: 120_000,
  },
});
