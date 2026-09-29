import { MapPinIcon } from 'lucide-react';
import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Textarea } from '@/components/ui/textarea';
import { cn } from '@/lib/utils';
import type { SavedPlaceRow } from '../../data/places';
import { savedColor, useDistance } from './bits';

/** How far a saved place reaches, in metres: a room, a street, a village. */
const minRadiusM = 10;
const maxRadiusM = 5000;

/** Name, note and reach behind saving a place, and editing one. */
export function PlaceForm({
  initial,
  onCancel,
  onSave,
}: {
  initial: SavedPlaceRow | null;
  onCancel: () => void;
  onSave: (name: string, notes: string, radiusM: number) => void;
}) {
  const { t } = useTranslation();
  const [name, setName] = useState(initial?.name ?? '');
  const [notes, setNotes] = useState(initial?.notes ?? '');
  const [radius, setRadius] = useState(String(initial?.radiusM ?? 100));
  const [tried, setTried] = useState(false);
  const radiusM = Number(radius);
  const radiusOk = Number.isFinite(radiusM) && radiusM >= minRadiusM && radiusM <= maxRadiusM;
  const submit = () => {
    if (!name.trim() || !radiusOk) {
      setTried(true);
      return;
    }
    onSave(name.trim(), notes.trim(), Math.round(radiusM));
  };
  return (
    // Beside the map, not over it: a card laid on the map hid most of it
    // and the very point being saved. The point stays marked above.
    <div className="rounded-2xl border bg-card p-3 shadow-sm">
      <form
        onSubmit={(event) => {
          event.preventDefault();
          submit();
        }}
        aria-label={initial ? t('places.editPlace') : t('places.savePlace')}
        className="flex flex-col gap-2"
      >
        <LabelText>{initial ? t('places.editPlace') : t('places.savePlace')}</LabelText>
        <div className="grid gap-2 sm:grid-cols-2">
          <Input
            autoFocus
            value={name}
            onChange={(event) => setName(event.target.value)}
            placeholder={t('places.placeNameHint')}
            aria-label={t('places.placeName')}
            aria-invalid={tried && !name.trim()}
            className={cn(tried && !name.trim() && 'ring-2 ring-destructive')}
          />
          <Textarea
            value={notes}
            onChange={(event) => setNotes(event.target.value)}
            placeholder={t('places.placeNotesHint')}
            aria-label={t('places.placeNotes')}
            rows={1}
            className="min-h-9 resize-none"
          />
        </div>
        <label className="flex flex-wrap items-center gap-2 text-sm">
          <span className="font-bold">{t('places.radius')}</span>
          <Input
            type="number"
            inputMode="numeric"
            min={minRadiusM}
            max={maxRadiusM}
            step={10}
            value={radius}
            onChange={(event) => setRadius(event.target.value)}
            aria-invalid={tried && !radiusOk}
            className={cn('w-28', tried && !radiusOk && 'ring-2 ring-destructive')}
          />
          <span className="text-xs text-muted-foreground">{t('places.radiusHint', { min: minRadiusM, max: maxRadiusM })}</span>
        </label>
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" size="sm" onClick={onCancel}>
            {t('common.cancel')}
          </Button>
          <Button type="submit" size="sm">
            {initial ? t('common.save') : t('places.savePlace')}
          </Button>
        </div>
      </form>
    </div>
  );
}

function LabelText({ children }: { children: ReactNode }) {
  return <p className="text-sm font-extrabold">{children}</p>;
}

/** One saved place, on a card: its name, its note, and what to do with it. */
export function PlaceCard({
  place,
  onClose,
  onEdit,
  onForget,
}: {
  place: SavedPlaceRow;
  onClose: () => void;
  onEdit: () => void;
  onForget: () => void;
}) {
  const { t } = useTranslation();
  const distance = useDistance();
  return (
    <div
      role="dialog"
      aria-label={place.name}
      className="absolute inset-x-3 bottom-3 z-10 flex flex-col gap-2 rounded-2xl border bg-card p-4 shadow-lg"
    >
      <div className="flex items-center gap-2">
        <MapPinIcon className="size-5 shrink-0" style={{ color: savedColor }} aria-hidden />
        <h3 className="min-w-0 flex-1 truncate text-lg font-extrabold">{place.name}</h3>
      </div>
      {place.notes && <p className="text-sm">{place.notes}</p>}
      <p className="text-xs text-muted-foreground tabular">
        <span dir="ltr">
          {place.latitude.toFixed(4)}, {place.longitude.toFixed(4)}
        </span>{' '}
        · {t('places.reach', { distance: distance(place.radiusM) })}
      </p>
      <div className="flex justify-end gap-2">
        <Button variant="ghost" size="sm" onClick={onClose}>
          {t('common.close')}
        </Button>
        <Button variant="ghost" size="sm" onClick={onForget}>
          {t('places.forgetPlace')}
        </Button>
        <Button size="sm" onClick={onEdit}>
          {t('places.editPlace')}
        </Button>
      </div>
    </div>
  );
}
