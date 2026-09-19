import { zodResolver } from '@hookform/resolvers/zod';
import { registerBodySchema } from '@harvest/contracts';
import { MailCheckIcon } from 'lucide-react';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Link } from 'react-router';
import type { z } from 'zod';
import { FormField } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { apiMessage, fieldMessage } from '@/lib/errors';
import { AuthCard, FormError } from './auth-card';

const schema = registerBodySchema.pick({ email: true, password: true, displayName: true });

export function RegisterPage() {
  const { t } = useTranslation();
  const [failure, setFailure] = useState<string | null>(null);
  const [sentTo, setSentTo] = useState<string | null>(null);
  const form = useForm<z.input<typeof schema>, unknown, z.output<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: { email: '', password: '' },
  });
  const { errors, isSubmitting } = form.formState;

  const submit = form.handleSubmit(async (values) => {
    setFailure(null);
    try {
      const result = await api.register({
        email: values.email,
        password: values.password,
        ...(values.displayName ? { displayName: values.displayName } : {}),
      });
      setSentTo(result.user.email);
    } catch (error) {
      setFailure(apiMessage(t, error));
    }
  });

  if (sentTo) {
    return (
      <AuthCard title={t('auth.checkEmailTitle')}>
        <div className="flex flex-col items-center gap-4 text-center">
          <MailCheckIcon className="size-10 text-success" aria-hidden />
          <p>{t('auth.checkEmailBody', { email: sentTo })}</p>
          <p className="text-sm text-muted-foreground">{t('auth.unverifiedNote')}</p>
          <Button asChild size="lg" className="w-full">
            <Link to="/app">{t('site.openApp')}</Link>
          </Button>
        </div>
      </AuthCard>
    );
  }

  return (
    <AuthCard title={t('auth.registerTitle')} lead={t('auth.registerLead')}>
      <form noValidate onSubmit={(event) => void submit(event)} className="flex flex-col gap-4">
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
          autoComplete="new-password"
          hint={t('auth.passwordHint')}
          error={fieldMessage(t, errors.password)}
          {...form.register('password')}
        />
        <FormField
          label={t('auth.displayName')}
          autoComplete="nickname"
          error={fieldMessage(t, errors.displayName)}
          {...form.register('displayName', { setValueAs: (value: string) => (value.trim() === '' ? undefined : value) })}
        />
        <FormError message={failure} />
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {isSubmitting ? t('auth.creating') : t('auth.createAccount')}
        </Button>
        <p className="text-sm text-muted-foreground">{t('auth.accountOptional')}</p>
        <Link to="/login" className="text-sm font-bold text-primary hover:underline">
          {t('auth.haveAccount')}
        </Link>
      </form>
    </AuthCard>
  );
}
