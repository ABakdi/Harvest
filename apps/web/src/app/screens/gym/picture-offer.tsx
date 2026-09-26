import { useState, type ReactNode } from 'react';
import { useTranslation } from 'react-i18next';
import { useLocation, useNavigate } from 'react-router';
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from '@/components/ui/alert-dialog';
import { CaptureDialog } from '../../components/gallery/capture-dialog';
import type { AlbumRow } from '../../data/gallery';

/**
 * What a navigation carries when the next screen should offer the
 * program's album a picture: before the first set, or on the way out
 * (`PhotoPrompt`). The album is looked up before the navigation, so a
 * trashed one is never offered.
 */
export interface PictureState {
  gymPicture: AlbumRow;
}

/**
 * The picture, asked for once (`_offerPicture`): offered rather than
 * demanded, with a "not now" that is one click, because a prompt at the
 * wrong moment gets dismissed forever. Yes opens the album's own
 * capture, the same one the gallery uses.
 */
export function PictureOffer({ album, onDone }: { album: AlbumRow; onDone: () => void }) {
  const { t } = useTranslation();
  const [capturing, setCapturing] = useState(false);
  if (capturing) return <CaptureDialog album={album} onClose={onDone} />;
  return (
    <AlertDialog open onOpenChange={(open) => !open && onDone()}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>{t('gym.pictureNow')}</AlertDialogTitle>
          <AlertDialogDescription>{t('gym.pictureNowBody')}</AlertDialogDescription>
        </AlertDialogHeader>
        <AlertDialogFooter>
          <AlertDialogCancel>{t('gym.pictureNotNow')}</AlertDialogCancel>
          <AlertDialogAction
            onClick={(event) => {
              // The capture replaces this question; closing it would end the offer.
              event.preventDefault();
              setCapturing(true);
            }}
          >
            {t('gym.pictureYes')}
          </AlertDialogAction>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  );
}

/**
 * The offer a navigation brought with it, if any. Answering it — either
 * way — clears it from the history entry, so going back or reloading
 * does not ask again.
 */
export function usePictureOffer(): ReactNode {
  const location = useLocation();
  const navigate = useNavigate();
  const album = (location.state as Partial<PictureState> | null)?.gymPicture;
  if (!album) return null;
  return (
    <PictureOffer
      key={album.uuid}
      album={album}
      onDone={() => void navigate({ pathname: location.pathname, search: location.search }, { replace: true, state: null })}
    />
  );
}
