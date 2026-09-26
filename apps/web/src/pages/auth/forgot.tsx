import { zodResolver } from '@hookform/resolvers/zod';
import { forgotPasswordBodySchema } from '@harvest/contracts';
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

export function ForgotPage() {
  const { t } = useTranslation();
  const [failure, setFailure] = useState<string | null>(null);
  const [sent, setSent] = useState(false);
  const form = useForm<z.input<typeof forgotPasswordBodySchema>, unknown, z.output<typeof forgotPasswordBodySchema>>({
    resolver: zodResolver(forgotPasswordBodySchema),
    defaultValues: { email: '' },
  });

  const submit = form.handleSubmit(async (values) => {
    setFailure(null);
    try {
      await api.forgotPassword(values);
      setSent(true);
    } catch (error) {
      setFailure(apiMessage(t, error));
    }
  });

  return (
    <AuthCard title={t('auth.forgotTitle')} lead={sent ? undefined : t('auth.forgotLead')}>
      {sent ? (
        // The same words whether or not the address has an account (AC3).
        <div role="status" className="flex flex-col gap-4">
          <p>{t('auth.forgotSent')}</p>
          <Link to="/login" className="text-sm font-bold text-primary hover:underline">
            {t('auth.backToSignIn')}
          </Link>
        </div>
      ) : (
        <form
          noValidate
          // A server's answer is about the values it was sent: an edit or
          // a new try clears it, even one the form itself then refuses.
          onChange={() => setFailure(null)}
          onSubmit={(event) => {
            setFailure(null);
            void submit(event);
          }}
          className="flex flex-col gap-4"
        >
          <FormField
            label={t('auth.email')}
            type="email"
            autoComplete="email"
            error={fieldMessage(t, form.formState.errors.email)}
            {...form.register('email')}
          />
          <FormError message={failure} />
          <Button type="submit" size="lg" disabled={form.formState.isSubmitting}>
            {t('auth.sendLink')}
          </Button>
          <Link to="/login" className="text-sm font-bold text-primary hover:underline">
            {t('auth.backToSignIn')}
          </Link>
        </form>
      )}
    </AuthCard>
  );
}
