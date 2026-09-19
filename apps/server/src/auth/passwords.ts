import argon2 from 'argon2';

/**
 * argon2id at the OWASP Password Storage Cheat Sheet's first
 * recommendation: 19 MiB of memory, two passes, one lane. The
 * parameters are encoded in each hash, so raising them later only
 * affects new hashes.
 */
const options = {
  type: argon2.argon2id,
  memoryCost: 19_456,
  timeCost: 2,
  parallelism: 1,
} as const;

export function hashPassword(password: string): Promise<string> {
  return argon2.hash(password, options);
}

/**
 * A hash of nothing in particular, verified against when the email is
 * unknown, so "no such account" takes as long as "wrong password" and
 * the timing cannot tell them apart (AC3).
 */
let decoy: Promise<string> | undefined;

export async function verifyPassword(hash: string | null, password: string): Promise<boolean> {
  if (hash === null) {
    decoy ??= argon2.hash('harvest-decoy-password', options);
    await argon2.verify(await decoy, password);
    return false;
  }
  try {
    return await argon2.verify(hash, password);
  } catch {
    return false;
  }
}
