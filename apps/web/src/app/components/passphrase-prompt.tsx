import { syncPinMaxLength, syncSecretProblem, type SyncKeyResult } from '@harvest/contracts';
import { westernDigits } from '@harvest/core';
import { KeyRoundIcon } from 'lucide-react';
import { useEffect, useId, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ApiError } from '@/lib/api';
import { useHarvest, useSyncStatus } from '../context';
import { WrongPassphraseError } from '../sync/keyring';

/**
 * A PIN as typed: digits from any keyboard read as the ASCII digits the
 * key is made from, since an Arabic keypad types ٠–٩ ([[Accounts]] AC7),
 * and anything that is not a digit is left out.
 */
export function pinDigits(typed: string): string {
  return westernDigits(typed).replace(/[^0-9]/g, '').slice(0, syncPinMaxLength);
}

/**
 * The sync PIN, entered once per browser ([[Accounts]], Sync PIN): a PIN
 * of 4 to 6 digits by default, or a passphrase of 8 characters or more
 * for whoever wants more, by the contract's rule (`syncSecretProblem`).
 *
 * Whether it is chosen or entered is the server's answer, never a guess
 * from what this browser has pulled ([[Accounts]]): while the account
 * has no key check, it is chosen and typed twice (a PIN too easy to
 * guess is refused); once it has one, it is entered once, and a PIN
 * that does not open the check is refused on the spot. Entering, a
 * forgotten PIN can be started over.
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
  const [share, setShare] = useState<SyncKeyResult | null>(null);
  const [unreachable, setUnreachable] = useState(false);
  const [asked, setAsked] = useState(0);
  const [startingOver, setStartingOver] = useState(false);
  const status = useSyncStatus();
  const pin = mode === 'pin';
  const choosing = share !== null && share.check === null;

  useEffect(() => {
    let live = true;
    keyring.share().then(
      (answer) => {
        if (live) setShare(answer);
      },
      () => {
        if (live) setUnreachable(true);
      },
    );
    return () => {
      live = false;
    };
  }, [keyring, asked]);

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
    // Entering, the PIN is the one already chosen: the check judges it.
    if (problem && !(problem === 'pinTooSimple' && !choosing)) {
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
      if (failure instanceof WrongPassphraseError) {
        setError(failure.chosenElsewhere ? t('syncPin.chosenElsewhere') : t('syncPin.wrong'));
        setSecret('');
        setConfirm('');
        if (failure.chosenElsewhere) setAsked((n) => n + 1);
      } else if (failure instanceof ApiError && (failure.isNetwork || failure.status >= 500)) {
        setError(t('syncPin.unreachable'));
      } else {
        setError(t('common.somethingWrong'));
      }
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
          <h2 className="font-extrabold">
            {/* Choose or enter is the server's answer; until it comes, neither. */}
            {share === null ? t('syncPin.title') : choosing ? t('syncPin.chooseTitle') : t('syncPin.enterTitle')}
          </h2>
          {status.pinChanged && <p className="text-sm font-semibold">{t('syncPin.changedElsewhere')}</p>}
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
          <p className="text-xs text-muted-foreground">{pin ? t('syncPin.sixDigits') : t('syncPin.firstTime')}</p>
        </div>
      )}
      <div className="flex flex-col items-start gap-1">
        <p className="text-xs text-muted-foreground">{t('syncPin.tradeOff')}</p>
        <Button type="button" variant="link" size="sm" className="h-auto px-0" onClick={switchMode}>
          {pin ? t('syncPin.usePassphrase') : t('syncPin.usePin')}
        </Button>
      </div>
      <p className="rounded-lg bg-muted p-3 text-xs">{t('syncPin.warning')}</p>
      {unreachable && (
        <div role="alert" className="flex flex-col items-start gap-2 text-sm">
          <p>{t('syncPin.unreachable')}</p>
          <Button
            type="button"
            variant="outline"
            size="sm"
            onClick={() => {
              setUnreachable(false);
              setAsked((n) => n + 1);
            }}
          >
            {t('common.tryAgain')}
          </Button>
        </div>
      )}
      {error && (
        <p role="alert" className="text-sm font-semibold text-destructive">
          {error}
        </p>
      )}
      <Button type="submit" disabled={busy || share === null}>
        {busy ? t('syncPin.opening') : choosing ? t('syncPin.choose') : t('syncPin.unlock')}
      </Button>
      {share !== null && !choosing && (
        <Button type="button" variant="link" size="sm" className="h-auto self-start px-0" onClick={() => setStartingOver(true)}>
          {t('syncPin.forgot')}
        </Button>
      )}
      {startingOver && (
        <StartOverDialog
          onClose={() => setStartingOver(false)}
          onDone={() => {
            setStartingOver(false);
            setError(null);
            setAsked((n) => n + 1);
          }}
        />
      )}
    </form>
  );
}

/**
 * Starts the sync PIN over ([[Accounts]]: start over): says plainly what
 * goes, asks for the account's password, and then drops the key check,
 * the key share and everything private on the server. The next PIN is
 * chosen, and what this browser holds goes up again under it. [changing]
 * is the same, asked for as *Change PIN* by someone who still has it.
 */
export function StartOverDialog({
  onClose,
  onDone,
  changing = false,
}: {
  onClose: () => void;
  onDone: () => void;
  changing?: boolean;
}) {
  const { t } = useTranslation();
  const { keyring } = useHarvest();
  const id = useId();
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit(event: FormEvent) {
    event.preventDefault();
    event.stopPropagation();
    if (password === '') return;
    setBusy(true);
    setError(null);
    try {
      await keyring.startOver(password);
      onDone();
    } catch (failure) {
      const status = (failure as { status?: number }).status;
      setError(status === 403 || status === 401 ? t('syncPin.wrongPassword') : t('common.somethingWrong'));
    } finally {
      setBusy(false);
    }
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>{changing ? t('syncPin.change') : t('syncPin.startOver')}</DialogTitle>
          <DialogDescription>{t('syncPin.startOverBody')}</DialogDescription>
        </DialogHeader>
        <form onSubmit={(event) => void submit(event)} className="flex flex-col gap-3" noValidate>
          <Label htmlFor={`${id}-password`}>{t('syncPin.password')}</Label>
          <Input
            id={`${id}-password`}
            type="password"
            autoComplete="current-password"
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />
          {error && (
            <p role="alert" className="text-sm font-semibold text-destructive">
              {error}
            </p>
          )}
          <div className="flex justify-end gap-2">
            <Button type="button" variant="outline" onClick={onClose}>
              {t('common.cancel')}
            </Button>
            <Button type="submit" variant="destructive" disabled={busy || password === ''}>
              {t('syncPin.startOverConfirm')}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
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
