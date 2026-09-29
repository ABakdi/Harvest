import { createCipheriv, createDecipheriv, randomBytes } from 'node:crypto';
import type { SealedBytes } from '../db/types.js';

/**
 * AES-256-GCM, for the few things the server seals for itself: the
 * accounts' key shares and a refresh token's successor. A fresh 12-byte
 * nonce each time, the 16-byte tag after the ciphertext, and additional
 * data naming what the bytes are for, so sealed bytes moved to another
 * account or another purpose do not open.
 */
export function seal(key: Buffer, plain: Buffer, aad: string): SealedBytes {
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  cipher.setAAD(Buffer.from(aad, 'utf8'));
  const ct = Buffer.concat([cipher.update(plain), cipher.final(), cipher.getAuthTag()]);
  return { iv: iv.toString('base64'), ct: ct.toString('base64') };
}

/** The bytes [seal] sealed, or null when this key or this aad does not open them. */
export function open(key: Buffer, sealed: SealedBytes, aad: string): Buffer | null {
  try {
    const iv = Buffer.from(sealed.iv, 'base64');
    const all = Buffer.from(sealed.ct, 'base64');
    if (iv.length !== 12 || all.length < 16) return null;
    const decipher = createDecipheriv('aes-256-gcm', key, iv);
    decipher.setAAD(Buffer.from(aad, 'utf8'));
    decipher.setAuthTag(all.subarray(all.length - 16));
    return Buffer.concat([decipher.update(all.subarray(0, all.length - 16)), decipher.final()]);
  } catch {
    return null;
  }
}
