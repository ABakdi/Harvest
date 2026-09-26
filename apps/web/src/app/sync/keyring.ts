import { deriveSyncKey, openRow } from '@harvest/contracts';
import { getMeta, metaKeys, setMeta, type HarvestDB } from '../data/db';

interface StoredKey {
  key: CryptoKey;
  /** The salt it was derived with: a key for another account is no key. */
  salt: string;
}

export class WrongPassphraseError extends Error {
  override readonly name = 'WrongPassphraseError';
}

/**
 * Where this browser keeps the private tier's key: in IndexedDB, as a
 * non-extractable CryptoKey, so the passphrase is typed once per
 * browser and the key itself can never be read back out. The scheme is
 * the contract's (`deriveSyncKey`, `sealRow`, `openRow`), the same on
 * the phone: the passphrase is never sent and never stored.
 */
export class Keyring {
  private cached: CryptoKey | null | undefined;
  private readonly listeners = new Set<() => void>();

  constructor(private readonly db: HarvestDB) {}

  async key(salt: string | null): Promise<CryptoKey | null> {
    if (this.cached !== undefined) return this.cached;
    const stored = await getMeta<StoredKey>(this.db, metaKeys.privateKey);
    this.cached = stored && (salt === null || stored.salt === salt) ? stored.key : null;
    return this.cached;
  }

  /**
   * Derives the key and keeps it. When sealed rows are waiting, one is
   * opened first: a passphrase that cannot open what the server holds
   * is refused rather than kept to seal new rows nobody can read.
   */
  async unlock(passphrase: string, salt: string, iterations?: number): Promise<void> {
    const key = await deriveSyncKey(passphrase, salt, iterations === undefined ? {} : { iterations });
    const probe = await this.db.sealed.limit(1).first();
    if (probe) {
      try {
        await openRow(key, probe.table, probe.uuid, probe.enc);
      } catch {
        throw new WrongPassphraseError('The passphrase does not open the sealed rows');
      }
    }
    await setMeta(this.db, metaKeys.privateKey, { key, salt } satisfies StoredKey);
    this.cached = key;
    for (const listener of this.listeners) listener();
  }

  /** Whether anything sealed is waiting: the passphrase can then be checked. */
  async hasSealed(): Promise<boolean> {
    return (await this.db.sealed.count()) > 0;
  }

  onUnlock(listener: () => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  forget(): void {
    this.cached = undefined;
  }
}
