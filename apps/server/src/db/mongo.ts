import { MongoClient, type Db } from 'mongodb';

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
    appName: 'harvest-server',
  });
  await client.connect();
  const db = client.db(dbName);
  return { client, db, close: () => client.close() };
}
