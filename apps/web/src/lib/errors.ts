import type { TFunction } from 'i18next';
import type { FieldError } from 'react-hook-form';
import { ApiError } from '@/lib/api';

/**
 * The contract's validation messages are English sentences written for
 * a log; the screen shows its own words for the ones it knows.
 */
const contractMessages: Record<string, string> = {
  'Not an email address': 'form.error.email',
  'At least 10 characters': 'form.error.passwordShort',
  'At most 256 characters': 'form.error.tooLong',
  'Too common; pick something less guessable': 'form.error.passwordCommon',
};

export function fieldMessage(t: TFunction, error: FieldError | undefined): string | undefined {
  if (!error) return undefined;
  const key = error.message ? contractMessages[error.message] : undefined;
  if (key) return t(key);
  if (error.type === 'too_small') return t('form.error.required');
  if (error.type === 'invalid_format') return t('form.error.email');
  return error.message ?? t('form.error.invalid');
}

/** A server answer, in words for the person who caused it. */
export function apiMessage(t: TFunction, error: unknown): string {
  if (error instanceof ApiError) {
    switch (error.code) {
      case 'network':
        return t('common.offline');
      case 'unauthorized':
        return t('auth.error.wrongCredentials');
      case 'conflict':
        return t('auth.error.emailTaken');
      case 'rate_limited':
        return t('auth.error.rateLimited');
      case 'forbidden':
        return t('auth.error.forbidden');
      case 'validation_failed': {
        const detail = error.details[0]?.message;
        return detail && contractMessages[detail] ? t(contractMessages[detail]) : t('auth.error.invalid');
      }
      default:
        return t('common.somethingWrong');
    }
  }
  return t('common.somethingWrong');
}
