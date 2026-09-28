import { MongoMemoryServer } from 'mongodb-memory-server';
import type { TestProject } from 'vitest/node';

declare module 'vitest' {
  export interface ProvidedContext {
    mongoUrl: string;
  }
}

/**
 * One real mongod for the whole run; the files share it, each in its own
 * database. `HARVEST_TEST_MONGO_URL` runs them against another server
 * instead, such as a `mongo:4.4` container: the version a server
 * without AVX runs, which the bundled binary is newer than.
 */
export default async function setup(project: TestProject) {
  const external = process.env.HARVEST_TEST_MONGO_URL;
  if (external) {
    project.provide('mongoUrl', external);
    return async () => {};
  }
  const mongod = await MongoMemoryServer.create();
  project.provide('mongoUrl', mongod.getUri());
  return async () => {
    await mongod.stop();
  };
}
