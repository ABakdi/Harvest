import { MongoClient, type Db } from 'mongodb';

/**
 * How long one database operation may take (Q6-17). A hung one would
 * otherwise hold the account's lock, and every push, upload and delete
 * of that account behind it, until a restart. A cursor read at the
 * pace of a download sets its own, per batch.
 */
export const operationTimeoutMs = 30_000;

export interface Mongo {
  client: MongoClient;
  db: Db;
  close(): Promise<void>;
}

/**
 * Connects to [url]. The database is the one the URL names, or
 * [dbName] when given, which is how each test file gets its own.
 */
export async function connectMongo(url: string, dbName?: string): Promise<Mongo> {
  const client = new MongoClient(url, {
    // Fail fast at boot rather than hang for the driver's thirty seconds.
    serverSelectionTimeoutMS: 10_000,
    timeoutMS: operationTimeoutMs,
    appName: 'harvest-server',
  });
  await client.connect();
  const db = client.db(dbName);
  return { client, db, close: () => client.close() };
}
