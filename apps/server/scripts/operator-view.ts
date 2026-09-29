/**
 * Reads a Harvest database the way its operator could, and says what in
 * it is still readable: Phase 7's exit check ([[Phase-7-Privacy-and-Currencies]]).
 *
 *   MONGO_URL=mongodb://… pnpm --filter @harvest/server operator-view [--db harvest]
 *
 * It has no key and asks for none. It reports:
 * - rows still in the clear (`data`), by table, and rows of retired tables;
 * - accounts whose address or name is still stored as itself;
 * - anything, in any collection, that looks like an email address, an
 *   IP address or a coordinate pair;
 * and exits 1 when it found any of it, 0 when the store is blind.
 */
import { MongoClient } from 'mongodb';
import { retiredTables } from '@harvest/contracts';

const url = process.env.MONGO_URL;
if (!url) {
  console.error('MONGO_URL is required');
  process.exit(2);
}
const dbFlag = process.argv.indexOf('--db');
const dbName = dbFlag > 0 ? process.argv[dbFlag + 1] : undefined;

const patterns: Record<string, RegExp> = {
  email: /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/,
  ipv4: /\b(?:25[0-5]|2[0-4]\d|1?\d?\d)(?:\.(?:25[0-5]|2[0-4]\d|1?\d?\d)){3}\b/,
  coordinates: /"(?:latitude|lat)"\s*:\s*-?\d/,
};

const client = await MongoClient.connect(url);
let findings = 0;
const say = (line: string) => {
  findings += 1;
  console.log(`  ✗ ${line}`);
};

try {
  const db = client.db(dbName);
  console.log(`Reading ${db.databaseName} as its operator would.\n`);

  const records = db.collection('records');
  const plain = await records
    .aggregate<{ _id: string; n: number }>([
      { $match: { data: { $exists: true } } },
      { $group: { _id: '$table', n: { $sum: 1 } } },
    ])
    .toArray();
  console.log('Rows');
  for (const { _id, n } of plain) say(`${n} ${_id} row(s) in the clear`);
  const retired = await records.countDocuments({ table: { $in: [...retiredTables] }, purged: { $ne: true } });
  if (retired > 0) say(`${retired} row(s) of a retired table (${retiredTables.join(', ')})`);
  const sealed = await records.countDocuments({ enc: { $exists: true } });
  console.log(`  ${sealed} sealed row(s)`);

  console.log('\nAccounts');
  const users = db.collection('users');
  const bare = await users.countDocuments({ $or: [{ email: { $exists: true } }, { displayName: { $exists: true } }] });
  if (bare > 0) say(`${bare} account(s) with the address or name as itself`);
  console.log(`  ${await users.countDocuments({})} account(s)`);

  console.log('\nEverything else, by pattern');
  for (const { name } of await db.listCollections().toArray()) {
    // The bytes of files are ciphertext; their chunks are not text.
    if (name.endsWith('.chunks')) continue;
    for await (const doc of db.collection(name).find()) {
      const text = JSON.stringify(doc);
      for (const [what, pattern] of Object.entries(patterns)) {
        const match = pattern.exec(text);
        if (match) say(`${name}: something like ${what} (${match[0].slice(0, 12)}…)`);
      }
    }
  }
} finally {
  await client.close();
}

console.log(findings === 0 ? '\nNothing readable found.' : `\n${findings} finding(s).`);
process.exit(findings === 0 ? 0 : 1);
