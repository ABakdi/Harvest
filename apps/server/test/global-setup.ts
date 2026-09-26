import { MongoMemoryServer } from 'mongodb-memory-server';
import type { TestProject } from 'vitest/node';

declare module 'vitest' {
  export interface ProvidedContext {
    mongoUrl: string;
  }
}

/** One real mongod for the whole run; the files share it, each in its own database. */
export default async function setup(project: TestProject) {
  const mongod = await MongoMemoryServer.create();
  project.provide('mongoUrl', mongod.getUri());
  return async () => {
    await mongod.stop();
  };
}
