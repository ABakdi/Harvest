import type { Db } from 'mongodb';
import { collections, ensureIndexes } from './collections.js';
import { FilesRepository } from './files.js';
import { OneTimeTokensRepository } from './one-time-tokens.js';
import { RecordsRepository } from './records.js';
import { SessionsRepository } from './sessions.js';
import { UsersRepository } from './users.js';

export interface Repositories {
  users: UsersRepository;
  sessions: SessionsRepository;
  oneTimeTokens: OneTimeTokensRepository;
  records: RecordsRepository;
  files: FilesRepository;
}

export async function createRepositories(db: Db): Promise<Repositories> {
  const c = collections(db);
  await ensureIndexes(c);
  return {
    users: new UsersRepository(c.users),
    sessions: new SessionsRepository(c.sessions, c.refreshTokens),
    oneTimeTokens: new OneTimeTokensRepository(c.oneTimeTokens),
    records: new RecordsRepository(c.records, c.counters),
    files: new FilesRepository(c.files),
  };
}

export { isDuplicateKey } from './records.js';
export type * from './types.js';
