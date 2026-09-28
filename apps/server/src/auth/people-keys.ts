import { createHmac, hkdfSync } from 'node:crypto';

/**
 * The server's own keys for what it knows about people
 * ([[Phase-7-Privacy-and-Currencies]], M7.7), drawn from KEY_SHARE_KEY,
 * which lives in the environment and never in the database:
 *
 * - `lookup`, an HMAC-SHA256 key: an email is found by its keyed hash,
 *   and a sign-in's failures are counted by one, so a copy of the
 *   database cannot be searched for an address, or an address and a
 *   network, by hashing guesses;
 * - `seal`, an AES-256-GCM key: the address itself, for the mail that
 *   needs it, and the display name are kept sealed with it.
 */
export interface PeopleKeys {
  lookup: Buffer;
  seal: Buffer;
}

export function peopleKeys(secret: Buffer): PeopleKeys {
  const derive = (info: string) => Buffer.from(hkdfSync('sha256', secret, Buffer.alloc(32), info, 32));
  return { lookup: derive('harvest/lookup/v1'), seal: derive('harvest/people/v1') };
}

/** The keyed hash of [text], lowercase hex. */
export function lookupOf(keys: PeopleKeys, text: string): string {
  return createHmac('sha256', keys.lookup).update(text, 'utf8').digest('hex');
}
