import { isSyncPin, syncPinMaxLength, syncSecretProblem, syncSecretStrength, type SyncKeyState, type SyncSecretLevel } from '@harvest/contracts';
import { westernDigits } from '@harvest/core';
import { EyeIcon, EyeOffIcon, KeyRoundIcon } from 'lucide-react';
import { useEffect, useId, useRef, useState, type FormEvent } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '@/components/ui/dialog';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { ApiError } from '@/lib/api';
import { useHarvest, useSyncStatus } from '../context';
import { PinLimitedError, PinStartedOverError, WrongPassphraseError } from '../sync/keyring';
import { background } from '@/lib/actions';

/**
 * A PIN as typed: digits from any keyboard read as the ASCII digits the
 * key is made from, since an Arabic keypad types ٠–٩ ([[Accounts]] AC7),
 * and anything that is not a digit is left out.
 */
export function pinDigits(typed: string): string {
  return westernDigits(typed).replace(/[^0-9]/g, '').slice(0, syncPinMaxLength);
}

/**
 * How long a secret would stand against someone trying every one of its
 * kind with the server's database and its keys in hand, as words: the
 * contract's estimate (`syncSecretStrength`) in the largest unit that
 * fits, and past a thousand years only its order.
 */
export function howLongItStands(seconds: number): { key: string; count?: number } {
  const minute = 60;
  const hour = 60 * minute;
  const day = 24 * hour;
  const year = 365 * day;
  if (seconds < 1) return { key: 'instantly' };
  if (seconds < minute) return { key: 'seconds', count: Math.round(seconds) };
  if (seconds < hour) return { key: 'minutes', count: Math.round(seconds / minute) };
  if (seconds < day) return { key: 'hours', count: Math.round(seconds / hour) };
  if (seconds < year) return { key: 'days', count: Math.round(seconds / day) };
  if (seconds < 1000 * year) return { key: 'years', count: Math.round(seconds / year) };
  if (seconds < 1_000_000 * year) return { key: 'thousandsOfYears' };
  return { key: 'millionsOfYears' };
}

const meterFill: Record<SyncSecretLevel, { bars: number; colour: string }> = {
  pin: { bars: 1, colour: 'bg-destructive' },
  weak: { bars: 1, colour: 'bg-destructive' },
  fair: { bars: 2, colour: 'bg-amber-500' },
  strong: { bars: 3, colour: 'bg-emerald-500' },
};

/** The meter under a secret being chosen: how strong, and how long it would stand, in words. */
export function StrengthMeter({ secret, id }: { secret: string; id: string }) {
  const { t } = useTranslation();
  const strength = syncSecretStrength(secret);
  const { bars, colour } = meterFill[strength.level];
  const time = howLongItStands(strength.seconds);
  return (
    <div id={id} className="flex flex-col gap-1" aria-live="polite">
      <div className="flex gap-1" aria-hidden>
        {[0, 1, 2].map((bar) => (
          <span key={bar} className={`h-1.5 flex-1 rounded-full ${bar < bars ? colour : 'bg-muted'}`} />
        ))}
      </div>
      <p className="text-xs text-muted-foreground" data-level={strength.level}>
        <span className="font-semibold text-foreground">{t(`syncPin.strength.level.${strength.level}`)}</span>{' '}
        {t('syncPin.strength.stands', {
          time: t(`syncPin.strength.time.${time.key}`, time.count === undefined ? {} : { count: time.count }),
        })}
      </p>
    </div>
  );
}

/**
 * The sync secret, entered once per browser ([[Accounts]], Sync PIN): a
 * passphrase by default, since Phase 7 (M7.5), shown or hidden, with a
 * meter of how long it would stand; or, one tap away and with the
 * trade-off said beside it, a PIN of 4 to 6 digits. Both by the
 * contract's rule (`syncSecretProblem`). Entering, either is taken as
 * typed: a secret of digits alone is read as the PIN it is.
 *
 * Whether it is chosen or entered is the server's answer, never a guess
 * from what this browser has pulled ([[Accounts]]): while the account
 * has no key check, it is chosen and typed twice (a PIN too easy to
 * guess is refused); once it has one, it is entered once, and a PIN
 * that does not open the check is refused on the spot. Entering, a
 * forgotten PIN can be started over.
 */
export function PassphrasePrompt({
  onUnlocked,
  Title = 'h2',
  leadId,
}: {
  onUnlocked?: () => void;
  /** What draws the heading; a dialog passes its own title, so there is one heading, not two. */
  Title?: 'h2' | typeof DialogTitle;
  /** The lead's id, for a dialog to be described by it. */
  leadId?: string;
}) {
  const { t } = useTranslation();
  const secretField = useRef<HTMLInputElement>(null);
  const { keyring, engine, user } = useHarvest();
  const id = useId();
  const [mode, setMode] = useState<'pin' | 'passphrase'>('passphrase');
  const [shown, setShown] = useState(false);
  const [secret, setSecret] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [share, setShare] = useState<SyncKeyState | null>(null);
  const [unreachable, setUnreachable] = useState(false);
  const [asked, setAsked] = useState(0);
  const [startingOver, setStartingOver] = useState(false);
  const status = useSyncStatus();
  const pin = mode === 'pin';
  const choosing = share !== null && share.state === 'none';

  useEffect(() => {
    let live = true;
    keyring.state().then(
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
    // Entering, a PIN typed in the passphrase field is still the PIN,
    // whatever keyboard's digits it came in.
    const asPin = pinDigits(secret);
    const secretNow = !choosing && !pin && isSyncPin(asPin) && westernDigits(secret).trim() === asPin ? asPin : secret;
    const problem = syncSecretProblem(secretNow);
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
      await keyring.unlock(secretNow, user.syncSalt);
      await engine.openSealed();
      background(engine.sync());
      onUnlocked?.();
    } catch (failure) {
      if (failure instanceof WrongPassphraseError) {
        const left = failure.triesLeft;
        setError(
          [
            failure.chosenElsewhere ? t('syncPin.chosenElsewhere') : t('syncPin.wrong'),
            // Said once it matters: three tries or fewer before the pause.
            left !== null && left <= 3 ? t('syncPin.triesLeft', { count: left }) : null,
          ]
            .filter(Boolean)
            .join(' '),
        );
        setConfirm('');
        if (failure.chosenElsewhere) {
          setSecret('');
          setAsked((n) => n + 1);
        }
        // The field keeps the try, selected, so the next one types over it.
        requestAnimationFrame(() => secretField.current?.select());
      } else if (failure instanceof PinLimitedError) {
        const minutes = failure.retryAfter === null ? null : Math.max(1, Math.ceil(failure.retryAfter / 60));
        setError(minutes === null ? t('syncPin.tooManySoon') : t('syncPin.tooMany', { count: minutes }));
      } else if (failure instanceof PinStartedOverError) {
        // Started over elsewhere a moment ago: this browser chooses now.
        setError(t('syncPin.startedOver'));
        setAsked((n) => n + 1);
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
    <form onSubmit={(event) => background(submit(event))} className="flex flex-col gap-4" noValidate>
      <div className="flex items-start gap-3">
        <span className="flex size-10 shrink-0 items-center justify-center rounded-lg bg-secondary">
          <KeyRoundIcon className="size-5" aria-hidden />
        </span>
        <div className="flex flex-col gap-1">
          <Title className="text-base font-extrabold">
            {/* Choose or enter is the server's answer; until it comes, neither. */}
            {share === null ? t('syncPin.title') : choosing ? t('syncPin.chooseTitle') : t('syncPin.enterTitle')}
          </Title>
          {status.pinChanged && <p className="text-sm font-semibold">{t('syncPin.changedElsewhere')}</p>}
          <p id={leadId} className="text-sm text-muted-foreground">
            {t('syncPin.lead')}
          </p>
        </div>
      </div>
      <div className="flex flex-col gap-2">
        <Label htmlFor={`${id}-secret`}>
          {pin ? t('syncPin.pinLabel') : choosing ? t('syncPin.passphraseLabel') : t('syncPin.secretLabel')}
        </Label>
        <div className="flex gap-2">
          <Input
            ref={secretField}
            id={`${id}-secret`}
            type={shown && !pin ? 'text' : 'password'}
            autoComplete="off"
            autoCapitalize="off"
            spellCheck={false}
            dir="ltr"
            aria-invalid={error ? true : undefined}
            aria-describedby={[error ? `${id}-error` : null, choosing && secret !== '' ? `${id}-strength` : null].filter(Boolean).join(' ') || undefined}
            {...field}
            value={secret}
            onChange={(event) => setSecret(typed(event.target.value))}
          />
          {!pin && (
            <Button
              type="button"
              variant="outline"
              size="icon"
              aria-pressed={shown}
              aria-label={shown ? t('syncPin.hide') : t('syncPin.show')}
              title={shown ? t('syncPin.hide') : t('syncPin.show')}
              onClick={() => setShown((now) => !now)}
            >
              {shown ? <EyeOffIcon /> : <EyeIcon />}
            </Button>
          )}
        </div>
        {choosing && secret !== '' && <StrengthMeter secret={secret} id={`${id}-strength`} />}
      </div>
      {choosing && (
        <div className="flex flex-col gap-2">
          <Label htmlFor={`${id}-confirm`}>{pin ? t('syncPin.confirmPin') : t('syncPin.confirmPassphrase')}</Label>
          <Input
            id={`${id}-confirm`}
            type={shown && !pin ? 'text' : 'password'}
            autoComplete="off"
            dir="ltr"
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? `${id}-error` : undefined}
            {...field}
            value={confirm}
            onChange={(event) => setConfirm(typed(event.target.value))}
          />
          <p className="text-xs text-muted-foreground">{pin ? t('syncPin.sixDigits') : t('syncPin.firstTime')}</p>
        </div>
      )}
      {/* Choosing, the trade-off and the warning help; entering one set elsewhere, only which kind it was does. */}
      <div className="flex flex-col items-start gap-1">
        {choosing && <p className="text-xs text-muted-foreground">{pin ? t('syncPin.tradeOffPin') : t('syncPin.tradeOff')}</p>}
        <Button type="button" variant="link" size="sm" className="h-auto px-0" onClick={switchMode}>
          {choosing ? (pin ? t('syncPin.usePassphrase') : t('syncPin.usePin')) : pin ? t('syncPin.setPassphraseInstead') : t('syncPin.setPinInstead')}
        </Button>
      </div>
      {choosing && <p className="rounded-lg bg-muted p-3 text-xs">{t('syncPin.warning')}</p>}
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
        <p id={`${id}-error`} role="alert" className="text-sm font-semibold text-destructive">
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
          {changing && <p className="text-sm font-semibold">{t('syncPin.changeNext')}</p>}
        </DialogHeader>
        <form onSubmit={(event) => background(submit(event))} className="flex flex-col gap-3" noValidate>
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
              {changing ? t('syncPin.changeConfirm') : t('syncPin.startOverConfirm')}
            </Button>
          </div>
        </form>
      </DialogContent>
    </Dialog>
  );
}

/** The sync PIN prompt in a dialog, from wherever it is asked for. */
export function SyncPinDialog({ onClose }: { onClose: () => void }) {
  const id = useId();
  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent aria-describedby={`${id}-lead`}>
        <PassphrasePrompt onUnlocked={onClose} Title={DialogTitle} leadId={`${id}-lead`} />
      </DialogContent>
    </Dialog>
  );
}
