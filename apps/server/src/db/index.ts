import { AdminStatsRepository } from './admin-stats.js';
import { AnnouncementsRepository, PushSubscriptionsRepository, ServerSettingsRepository } from './announcements.js';
import { peopleKeys } from '../auth/people-keys.js';
import type { Db } from 'mongodb';
import { collections, ensureIndexes } from './collections.js';
import { AssistUsageRepository } from './assist-usage.js';
import { FilesRepository } from './files.js';
import { LoginFailuresRepository } from './login-failures.js';
import { OneTimeTokensRepository } from './one-time-tokens.js';
import { RecordsRepository } from './records.js';
import { SessionsRepository } from './sessions.js';
import { TotalsRepository } from './totals.js';
import { WindowedCountsRepository } from './windowed-counts.js';
import { UsersRepository } from './users.js';

export interface Repositories {
  users: UsersRepository;
  sessions: SessionsRepository;
  oneTimeTokens: OneTimeTokensRepository;
  records: RecordsRepository;
  files: FilesRepository;
  assistUsage: AssistUsageRepository;
  totals: TotalsRepository;
  loginFailures: LoginFailuresRepository;
  windowedCounts: WindowedCountsRepository;
  adminStats: AdminStatsRepository;
  announcements: AnnouncementsRepository;
  pushSubscriptions: PushSubscriptionsRepository;
  serverSettings: ServerSettingsRepository;
}

/**
 * The repositories over [db]. [secret] is KEY_SHARE_KEY, from which the
 * keys that seal addresses and names are drawn (`people-keys.ts`).
 */
export async function createRepositories(db: Db, secret: Buffer): Promise<Repositories> {
  const c = collections(db);
  await ensureIndexes(c);
  const users = new UsersRepository(c.users, peopleKeys(secret));
  await users.sealLegacy();
  return {
    users,
    sessions: new SessionsRepository(c.sessions, c.refreshTokens),
    oneTimeTokens: new OneTimeTokensRepository(c.oneTimeTokens),
    records: new RecordsRepository(c.records, c.counters),
    files: new FilesRepository(c.files, db),
    assistUsage: new AssistUsageRepository(c.assistUsage, c.assistDays),
    totals: new TotalsRepository(c.counters),
    loginFailures: new LoginFailuresRepository(c.loginFailures),
    windowedCounts: new WindowedCountsRepository(c.windowedCounts),
    adminStats: new AdminStatsRepository(c.users, c.dailyStats),
    announcements: new AnnouncementsRepository(c.announcements),
    pushSubscriptions: new PushSubscriptionsRepository(c.pushSubscriptions),
    serverSettings: new ServerSettingsRepository(c.serverSettings),
  };
}

export { isDuplicateKey } from './records.js';
export type * from './types.js';
