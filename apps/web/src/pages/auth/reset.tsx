import { zodResolver } from '@hookform/resolvers/zod';
import { passwordSchema } from '@harvest/contracts';
import { useState } from 'react';
import { useForm } from 'react-hook-form';
import { useTranslation } from 'react-i18next';
import { Link, useParams } from 'react-router';
import { z } from 'zod';
import { FormField } from '@/components/form-field';
import { Button } from '@/components/ui/button';
import { api } from '@/lib/api';
import { apiMessage, fieldMessage } from '@/lib/errors';
import { AuthCard, FormError } from './auth-card';

const schema = z
  .object({ password: passwordSchema, confirm: z.string() })
  .refine((values) => values.password === values.confirm, { path: ['confirm'], message: 'mismatch' });

export function ResetPage() {
  const { t } = useTranslation();
  const { token = '' } = useParams();
  const [failure, setFailure] = useState<string | null>(null);
  const [done, setDone] = useState(false);
  const form = useForm<z.input<typeof schema>, unknown, z.output<typeof schema>>({
    resolver: zodResolver(schema),
    defaultValues: { password: '', confirm: '' },
  });
  const { errors, isSubmitting } = form.formState;

  const submit = form.handleSubmit(async (values) => {
    setFailure(null);
    try {
      await api.resetPassword({ token, password: values.password });
      setDone(true);
    } catch (error) {
      setFailure(apiMessage(t, error) === t('auth.error.invalid') ? t('auth.linkInvalid') : apiMessage(t, error));
    }
  });

  if (done) {
    return (
      <AuthCard title={t('auth.resetDoneTitle')}>
        <div role="status" className="flex flex-col gap-4">
          <p>{t('auth.resetDoneBody')}</p>
          <Button asChild size="lg">
            <Link to="/login">{t('auth.signIn')}</Link>
          </Button>
        </div>
      </AuthCard>
    );
  }

  return (
    <AuthCard title={t('auth.resetTitle')} lead={t('auth.resetLead')}>
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
          label={t('auth.newPassword')}
          type="password"
          autoComplete="new-password"
          hint={t('auth.passwordHint')}
          error={fieldMessage(t, errors.password)}
          {...form.register('password')}
        />
        <FormField
          label={t('auth.confirmPassword')}
          type="password"
          autoComplete="new-password"
          error={errors.confirm ? t('form.error.mismatch') : undefined}
          {...form.register('confirm')}
        />
        <FormError message={failure} />
        <Button type="submit" size="lg" disabled={isSubmitting}>
          {t('auth.setPassword')}
        </Button>
      </form>
    </AuthCard>
  );
}
