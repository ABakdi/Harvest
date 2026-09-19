import { useQuery } from '@tanstack/react-query';
import { CheckIcon, CopyIcon, DownloadIcon, ExternalLinkIcon, ShieldCheckIcon } from 'lucide-react';
import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { api, ApiError } from '@/lib/api';
import { formatBytes, formatDate } from '@/lib/format';
import { Markdown } from '@/lib/markdown';

const releasesPage = 'https://github.com/ABakdi/Harvest/releases';

function CopyButton({ value, label }: { value: string; label: string }) {
  const { t } = useTranslation();
  const [copied, setCopied] = useState(false);
  return (
    <Button
      variant="ghost"
      size="icon-sm"
      aria-label={copied ? t('common.copied') : label}
      onClick={() => {
        void navigator.clipboard?.writeText(value).then(() => {
          setCopied(true);
          setTimeout(() => setCopied(false), 2000);
        });
      }}
    >
      {copied ? <CheckIcon /> : <CopyIcon />}
    </Button>
  );
}

export function DownloadPage() {
  const { t } = useTranslation();
  const release = useQuery({
    queryKey: ['release', 'latest'],
    queryFn: ({ signal }) => api.latestRelease(signal),
    retry: 1,
    staleTime: 5 * 60_000,
  });

  const noRelease = release.error instanceof ApiError && release.error.code === 'not_found';

  return (
    <div className="mx-auto flex max-w-3xl flex-col gap-6 px-4 py-10">
      <div className="flex flex-col gap-2">
        <h1 className="text-3xl font-extrabold">{t('download.title')}</h1>
        <p className="text-muted-foreground">{t('download.lead')}</p>
      </div>

      {release.isPending && (
        <Card aria-busy="true">
          <CardContent>
            <p className="text-muted-foreground">{t('download.loading')}</p>
          </CardContent>
        </Card>
      )}

      {release.isError && (
        <Card role="status">
          <CardHeader>
            <CardTitle>{noRelease ? t('download.noRelease') : t('download.unavailable')}</CardTitle>
          </CardHeader>
          <CardContent className="flex flex-col gap-3">
            <p className="text-sm text-muted-foreground">{t('download.unavailableBody')}</p>
            <Button asChild variant="outline" className="w-fit">
              <a href={releasesPage} target="_blank" rel="noreferrer noopener">
                <ExternalLinkIcon />
                {t('download.onGitHub')}
              </a>
            </Button>
          </CardContent>
        </Card>
      )}

      {release.data && (
        <Card>
          <CardHeader>
            <CardTitle className="text-2xl">{release.data.name ?? release.data.tag}</CardTitle>
            <dl className="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1 text-sm">
              <dt className="text-muted-foreground">{t('download.version')}</dt>
              <dd className="font-bold">{release.data.tag}</dd>
              {release.data.publishedAt && (
                <>
                  <dt className="text-muted-foreground">{t('download.date')}</dt>
                  <dd className="font-bold">{formatDate(release.data.publishedAt)}</dd>
                </>
              )}
              {release.data.apk && (
                <>
                  <dt className="text-muted-foreground">{t('download.size')}</dt>
                  <dd className="font-bold tabular">{formatBytes(release.data.apk.size)}</dd>
                </>
              )}
            </dl>
          </CardHeader>
          <CardContent className="flex flex-col gap-4">
            {release.data.apk ? (
              <>
                <Button asChild variant="brand" size="lg" className="w-full sm:w-fit">
                  <a href={release.data.apk.url} download>
                    <DownloadIcon />
                    {t('download.apk', { name: release.data.apk.name })}
                  </a>
                </Button>
                {release.data.apk.sha256 && (
                  <div className="flex flex-col gap-1">
                    <span className="flex items-center gap-1 text-sm font-bold">
                      <ShieldCheckIcon className="size-4 text-success" aria-hidden />
                      {t('download.sha256')}
                    </span>
                    <div className="flex items-center gap-2 rounded-lg bg-muted p-2">
                      <code dir="ltr" className="min-w-0 flex-1 break-all font-mono text-xs">
                        {release.data.apk.sha256}
                      </code>
                      <CopyButton value={release.data.apk.sha256} label={t('download.copySha')} />
                    </div>
                  </div>
                )}
              </>
            ) : (
              <p className="text-sm text-muted-foreground">{t('download.noApk')}</p>
            )}
            {release.data.notes && (
              <section aria-labelledby="notes" className="flex flex-col gap-2">
                <h2 id="notes" className="text-lg font-extrabold">
                  {t('download.notes')}
                </h2>
                <div className="rounded-lg bg-background p-4 text-sm" dir="auto">
                  <Markdown source={release.data.notes} />
                </div>
              </section>
            )}
            <a
              href={release.data.htmlUrl}
              target="_blank"
              rel="noreferrer noopener"
              className="flex w-fit items-center gap-1 text-sm font-bold text-primary underline-offset-4 hover:underline"
            >
              <ExternalLinkIcon className="size-4" aria-hidden />
              {t('download.onGitHub')}
            </a>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>{t('download.howTitle')}</CardTitle>
        </CardHeader>
        <CardContent>
          <ol className="flex list-decimal flex-col gap-2 ps-5 text-sm">
            <li>{t('download.how1')}</li>
            <li>{t('download.how2')}</li>
            <li>{t('download.how3')}</li>
            <li>{t('download.how4')}</li>
          </ol>
          <p className="mt-3 text-sm text-muted-foreground">{t('download.verifyHint')}</p>
        </CardContent>
      </Card>
    </div>
  );
}
