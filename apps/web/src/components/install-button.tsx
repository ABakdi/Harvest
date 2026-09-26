import { DownloadIcon, GlobeIcon, PlusSquareIcon, ShareIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import { Button } from '@/components/ui/button';
import { isIosSafari, promptInstall, useInstallState } from '@/lib/pwa';

/**
 * "Open Harvest in the browser", which becomes "Install Harvest" where
 * the browser offered to install it. iOS Safari never offers, so there
 * the button explains the two steps instead ([[Web]]).
 */
export function InstallButton({ size = 'lg' }: { size?: 'lg' | 'default' }) {
  const { t } = useTranslation();
  const { canPrompt, installed } = useInstallState();
  const [showSteps, setShowSteps] = useState(false);
  const ios = isIosSafari();

  if (canPrompt && !installed) {
    return (
      <Button variant="brand" size={size} onClick={() => void promptInstall()}>
        <DownloadIcon />
        {t('site.install')}
      </Button>
    );
  }

  return (
    <div className="flex flex-col items-center gap-2 sm:items-start">
      <Button asChild variant="brand" size={size}>
        <Link to="/app">
          <GlobeIcon />
          {t('site.openInBrowser')}
        </Link>
      </Button>
      {ios && !installed && (
        <>
          <Button variant="link" size="sm" aria-expanded={showSteps} onClick={() => setShowSteps((v) => !v)}>
            {t('site.iosHow')}
          </Button>
          {showSteps && (
            <ol className="flex flex-col gap-2 rounded-lg bg-card p-3 text-sm">
              <li className="flex items-center gap-2">
                <ShareIcon className="size-4" aria-hidden />
                {t('site.iosStep1')}
              </li>
              <li className="flex items-center gap-2">
                <PlusSquareIcon className="size-4" aria-hidden />
                {t('site.iosStep2')}
              </li>
            </ol>
          )}
        </>
      )}
    </div>
  );
}
