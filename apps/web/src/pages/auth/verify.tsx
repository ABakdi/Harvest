import { useQuery } from '@tanstack/react-query';
import { CircleCheckIcon, CircleXIcon, LoaderIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { Link, useParams } from 'react-router';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { AuthCard } from './auth-card';

export function VerifyPage() {
  const { t } = useTranslation();
  const { token = '' } = useParams();
  // A query rather than an effect, so the link is spent exactly once
  // however many times the page renders: the token is single use.
  const verify = useQuery({
    queryKey: ['verify-email', token],
    queryFn: async () => {
      await api.verifyEmail(token);
      return true;
    },
    retry: false,
    staleTime: Infinity,
    gcTime: Infinity,
    refetchOnWindowFocus: false,
  });

  return (
    <AuthCard title={t('auth.verifyTitle')}>
      <div role="status" className="flex flex-col items-center gap-4 text-center">
        {verify.isPending && (
          <>
            <LoaderIcon className="size-10 animate-spin text-muted-foreground" aria-hidden />
            <p>{t('auth.verifying')}</p>
          </>
        )}
        {verify.isSuccess && (
          <>
            <CircleCheckIcon className="size-10 text-success" aria-hidden />
            <p>{t('auth.verified')}</p>
            <Button asChild size="lg" className="w-full">
              <Link to="/app">{t('site.openApp')}</Link>
            </Button>
          </>
        )}
        {verify.isError && (
          <>
            <CircleXIcon className="size-10 text-destructive" aria-hidden />
            <p>{t('auth.linkInvalid')}</p>
            <Button asChild variant="outline" className="w-full">
              <Link to="/login">{t('auth.signIn')}</Link>
            </Button>
          </>
        )}
      </div>
    </AuthCard>
  );
}
