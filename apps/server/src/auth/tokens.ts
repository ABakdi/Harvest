import { createHash, randomBytes } from 'node:crypto';
import { SignJWT, jwtVerify, type CryptoKey } from 'jose';
import { ObjectId } from 'mongodb';

// ------------------------------------------------------- access tokens

const issuer = 'harvest';
const audience = 'harvest';
export const accessTokenSeconds = 15 * 60;

export interface AccessClaims {
  userId: ObjectId;
  sessionId: ObjectId;
}

/** A short EdDSA JWT: who (`sub`) and which signed-in device (`sid`). */
export function signAccessToken(key: CryptoKey, claims: AccessClaims): Promise<string> {
  return new SignJWT({ sid: claims.sessionId.toHexString() })
    .setProtectedHeader({ alg: 'EdDSA', typ: 'JWT' })
    .setSubject(claims.userId.toHexString())
    .setIssuer(issuer)
    .setAudience(audience)
    .setIssuedAt()
    .setExpirationTime(`${accessTokenSeconds}s`)
    .sign(key);
}

/** The claims of a valid, unexpired token, or null for anything else. */
export async function verifyAccessToken(key: CryptoKey, token: string): Promise<AccessClaims | null> {
  try {
    const { payload } = await jwtVerify(token, key, { issuer, audience, algorithms: ['EdDSA'] });
    const sub = payload.sub;
    const sid = payload.sid;
    if (typeof sub !== 'string' || typeof sid !== 'string') return null;
    if (!ObjectId.isValid(sub) || !ObjectId.isValid(sid)) return null;
    return { userId: new ObjectId(sub), sessionId: new ObjectId(sid) };
  } catch {
    return null;
  }
}

// ------------------------------------------------------ opaque tokens

/**
 * Refresh tokens and emailed links are opaque: `<user id>.<32 random
 * bytes>`. The user id in front is not a secret; it is there so the
 * lookup can be scoped to one user like every other query (ADR-011
 * rule 2). Only the SHA-256 of the whole token is stored, so a copy of
 * the database is not a copy of anyone's session.
 */
export interface OpaqueToken {
  token: string;
  hash: string;
}

export function hashToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function createOpaqueToken(userId: ObjectId): OpaqueToken {
  const token = `${userId.toHexString()}.${randomBytes(32).toString('base64url')}`;
  return { token, hash: hashToken(token) };
}

export function readOpaqueToken(token: string): { userId: ObjectId; hash: string } | null {
  const match = /^([0-9a-f]{24})\.([A-Za-z0-9_-]{43})$/.exec(token);
  if (!match) return null;
  return { userId: new ObjectId(match[1]), hash: hashToken(token) };
}
