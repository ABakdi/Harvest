import { KeyRoundIcon } from 'lucide-react';
import { useEffect, useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useHarvest } from '../context';
import { WrongPassphraseError } from '../sync/keyring';

/**
 * The sync passphrase, typed once per browser. When sealed rows are
 * already waiting, it is checked against one of them; when nothing is
 * sealed yet (this may be the first device to use it), it is typed
 * twice instead, because a typo here would seal rows nobody can open.
 */
export function PassphrasePrompt({ onUnlocked }: { onUnlocked?: () => void }) {
  const { t } = useTranslation();
  const { keyring, engine, user } = useHarvest();
  const id = useId();
  const [passphrase, setPassphrase] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [checkable, setCheckable] = useState<boolean | null>(null);

  useEffect(() => {
    let live = true;
    void keyring.hasSealed().then((sealed) => {
      if (live) setCheckable(sealed);
    });
    return () => {
      live = false;
    };
  }, [keyring]);

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    if (passphrase.length < 12) {
      setError(t('passphrase.tooShort'));
      return;
    }
    if (!checkable && passphrase !== confirm) {
      setError(t('passphrase.mismatch'));
      return;
    }
    setBusy(true);
    try {
      await keyring.unlock(passphrase, user.syncSalt);
      await engine.openSealed();
      void engine.sync();
      onUnlocked?.();
    } catch (failure) {
      setError(failure instanceof WrongPassphraseError ? t('passphrase.wrong') : t('common.somethingWrong'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
      <div className="flex items-start gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
          <KeyRoundIcon className="size-5" aria-hidden />
        </span>
        <div className="flex flex-col gap-1">
          <h2 className="font-extrabold">{t('passphrase.title')}</h2>
          <p className="text-sm text-muted-foreground">{t('passphrase.lead')}</p>
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor={`${id}-pass`}>{t('passphrase.label')}</Label>
        <Input
          id={`${id}-pass`}
          type="password"
          autoComplete="off"
          value={passphrase}
          onChange={(event) => setPassphrase(event.target.value)}
        />
      </div>
      {checkable === false && (
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-confirm`}>{t('passphrase.confirm')}</Label>
          <Input
            id={`${id}-confirm`}
            type="password"
            autoComplete="off"
            value={confirm}
            onChange={(event) => setConfirm(event.target.value)}
          />
          <p className="text-xs text-muted-foreground">{t('passphrase.firstTime')}</p>
        </div>
      )}
      <p className="rounded-lg bg-muted p-3 text-xs">{t('passphrase.warning')}</p>
      {error && (
        <p role="alert" className="text-sm font-semibold text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" disabled={busy || checkable === null}>
        {busy ? t('passphrase.opening') : t('passphrase.unlock')}
      </Button>
    </form>
  );
}
