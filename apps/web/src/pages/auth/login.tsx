import { zodResolver } from '@hookform/resolvers/zod';
import { loginBodySchema } from '@harvest/contracts';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Link, useNavigate, useSearchParams } from 'react-router';
import type { z } from 'zod';
import { FormField } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { apiMessage, fieldMessage } from '@/lib/errors';
import { AuthCard, FormError } from './auth-card';
import { runAction } from '@/lib/actions';

const schema = loginBodySchema.pick({ email: true, password: true });

/** Only paths inside the app; a `next` pointing elsewhere is ignored. */
export function safeNext(next: string | null): string {
  return next && next.startsWith('/app') ? next : '/app';
}

export function LoginPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const [failure, setFailure] = useState<string | null>(null);
  const form = useForm<z.input<typeof schema>, unknown, z.output<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: { email: '', password: '' },
  });
  const { errors, isSubmitting } = form.formState;

  const submit = form.handleSubmit(async (values) => {
    setFailure(null);
    try {
      await api.login(values);
      await navigate(safeNext(params.get('next')), { replace: true });
    } catch (error) {
      setFailure(apiMessage(t, error));
    }
  });

  return (
    <AuthCard title={t('auth.loginTitle')} lead={t('auth.loginLead')}>
      {/* The browser version needs an account (W5); a first visit sent here from /app learns why, and where to make one. */}
      <div className="flex flex-col gap-3 rounded-xl bg-secondary p-4 text-sm">
        <p>{t('auth.browserNeedsAccount')}</p>
        <div className="flex flex-wrap gap-2">
          <Button asChild variant="brand">
            <Link to="/register">
              {t('auth.createFree')}
            </Link>
          </Button>
          <Button asChild variant="outline">
            <Link to="/download">{t('auth.getAndroid')}</Link>
          </Button>
        </div>
      </div>
      <form
        noValidate
        // A server's answer is about the values it was sent: an edit or
        // a new try clears it, even one the form itself then refuses.
        onChange={() => setFailure(null)}
        onSubmit={(event) => {
          setFailure(null);
          runAction(() => submit(event));
        }}
        className="flex flex-col gap-4"
      >
        <FormField
          label={t('auth.email')}
          type="email"
          autoComplete="email"
          inputMode="email"
          error={fieldMessage(t, errors.email)}
          {...form.register('email')}
        />
        <FormField
          label={t('auth.password')}
          type="password"
          autoComplete="current-password"
          error={fieldMessage(t, errors.password)}
          {...form.register('password')}
        />
        <FormError message={failure} />
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {isSubmitting ? t('auth.signingIn') : t('auth.signIn')}
        </Button>
        <div className="flex flex-wrap justify-between gap-2 text-sm">
          <Link to="/forgot" className="font-bold text-primary hover:underline max-md:inline-flex max-md:min-h-11 max-md:items-center">
            {t('auth.forgotLink')}
          </Link>
          <Link to="/register" className="font-bold text-primary hover:underline max-md:inline-flex max-md:min-h-11 max-md:items-center">
            {t('auth.createAccount')}
          </Link>
        </div>
      </form>
    </AuthCard>
  );
}
