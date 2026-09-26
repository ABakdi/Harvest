import { syncPinMaxLength, syncSecretProblem } from '@harvest/contracts';
import { KeyRoundIcon } from 'lucide-react';
import { useEffect, useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { useHarvest } from '../context';
import { WrongPassphraseError } from '../sync/keyring';

/**
 * A PIN as typed: digits from any keyboard read as the ASCII digits the
 * key is made from, since an Arabic keypad types ٠–٩ ([[Accounts]] AC7),
 * and anything that is not a digit is left out.
 */
export function pinDigits(typed: string): string {
  return typed
    .replace(/[٠-٩]/g, (digit) => String(digit.charCodeAt(0) - 0x0660))
    .replace(/[۰-۹]/g, (digit) => String(digit.charCodeAt(0) - 0x06f0))
    .replace(/[^0-9]/g, '')
    .slice(0, syncPinMaxLength);
}

/**
 * The sync PIN, entered once per browser ([[Accounts]], Sync PIN): a PIN
 * of 4 to 6 digits by default, or a passphrase of 8 characters or more
 * for whoever wants more, by the contract's rule (`syncSecretProblem`).
 *
 * When sealed rows are already waiting, it is checked against one of
 * them; when nothing is sealed yet (this may be the first device to use
 * it), it is chosen and typed twice instead, because a typo here would
 * seal rows nobody can open.
 */
export function PassphrasePrompt({ onUnlocked }: { onUnlocked?: () => void }) {
  const { t } = useTranslation();
  const { keyring, engine, user } = useHarvest();
  const id = useId();
  const [mode, setMode] = useState<'pin' | 'passphrase'>('pin');
  const [secret, setSecret] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [checkable, setCheckable] = useState<boolean | null>(null);
  const pin = mode === 'pin';
  const choosing = checkable === false;

  useEffect(() => {
    let live = true;
    void keyring.hasSealed().then((sealed) => {
      if (live) setCheckable(sealed);
    });
    return () => {
      live = false;
    };
  }, [keyring]);

  const switchMode = () => {
    setMode(pin ? 'passphrase' : 'pin');
    setSecret('');
    setConfirm('');
    setError(null);
  };

  async function submit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    const problem = syncSecretProblem(secret);
    if (problem) {
      setError(t(`syncPin.problem.${problem}`));
      return;
    }
    if (choosing && secret !== confirm) {
      setError(t('syncPin.mismatch'));
      return;
    }
    setBusy(true);
    try {
      await keyring.unlock(secret, user.syncSalt);
      await engine.openSealed();
      void engine.sync();
      onUnlocked?.();
    } catch (failure) {
      setError(failure instanceof WrongPassphraseError ? t('syncPin.wrong') : t('common.somethingWrong'));
    } finally {
      setBusy(false);
    }
  }

  // The PIN keypad on a phone, never a saved password.
  const field = pin
    ? { inputMode: 'numeric' as const, maxLength: syncPinMaxLength, className: 'tracking-[0.4em] tabular' }
    : {};
  const typed = (value: string) => (pin ? pinDigits(value) : value);

  return (
    <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-4" noValidate>
      <div className="flex items-start gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
          <KeyRoundIcon className="size-5" aria-hidden />
        </span>
        <div className="flex flex-col gap-1">
          <h2 className="font-extrabold">{choosing ? t('syncPin.chooseTitle') : t('syncPin.enterTitle')}</h2>
          <p className="text-sm text-muted-foreground">{t('syncPin.lead')}</p>
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor={`${id}-secret`}>{pin ? t('syncPin.pinLabel') : t('syncPin.passphraseLabel')}</Label>
        <Input
          id={`${id}-secret`}
          type="password"
          autoComplete="off"
          dir="ltr"
          {...field}
          value={secret}
          onChange={(event) => setSecret(typed(event.target.value))}
        />
      </div>
      {choosing && (
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-confirm`}>{pin ? t('syncPin.confirmPin') : t('syncPin.confirmPassphrase')}</Label>
          <Input
            id={`${id}-confirm`}
            type="password"
            autoComplete="off"
            dir="ltr"
            {...field}
            value={confirm}
            onChange={(event) => setConfirm(typed(event.target.value))}
          />
          <p className="text-xs text-muted-foreground">{t('syncPin.firstTime')}</p>
        </div>
      )}
      <div className="flex flex-col items-start gap-1">
        <p className="text-xs text-muted-foreground">{t('syncPin.tradeOff')}</p>
        <Button type="button" variant="link" size="sm" className="h-auto px-0" onClick={switchMode}>
          {pin ? t('syncPin.usePassphrase') : t('syncPin.usePin')}
        </Button>
      </div>
      <p className="rounded-lg bg-muted p-3 text-xs">{t('syncPin.warning')}</p>
      {error && (
        <p role="alert" className="text-sm font-semibold text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" disabled={busy || checkable === null}>
        {busy ? t('syncPin.opening') : choosing ? t('syncPin.choose') : t('syncPin.unlock')}
      </Button>
    </form>
  );
}

/** The sync PIN prompt in a dialog, from wherever it is asked for. */
export function SyncPinDialog({ onClose }: { onClose: () => void }) {
  const { t } = useTranslation();
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{t('syncPin.title')}</DialogTitle>
          <DialogDescription className="sr-only">{t('syncPin.lead')}</DialogDescription>
        </DialogHeader>
        <PassphrasePrompt onUnlocked={onClose} />
      </DialogContent>
    </Dialog>
  );
}
