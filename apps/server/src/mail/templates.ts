import type { MailMessage } from './mailer.js';

/**
 * Plain text, on purpose: two short messages with one link each do not
 * need HTML, and plain text is what every client renders the same.
 */
export function verificationMail(to: string, appUrl: string, token: string): MailMessage {
  const link = `${appUrl}/verify/${encodeURIComponent(token)}`;
  return {
    to,
    purpose: 'verify',
    link,
    subject: 'Confirm your Harvest email',
    text: [
      'Someone, hopefully you, made a Harvest account with this address.',
      '',
      'Confirm it to start syncing:',
      link,
      '',
      'The link works for 24 hours. If this was not you, ignore this email; nothing will sync to an unconfirmed account.',
    ].join('\n'),
  };
}

export function resetMail(to: string, appUrl: string, token: string): MailMessage {
  const link = `${appUrl}/reset/${encodeURIComponent(token)}`;
  return {
    to,
    purpose: 'reset',
    link,
    subject: 'Reset your Harvest password',
    text: [
      'A password reset was asked for on this Harvest account.',
      '',
      'Choose a new password here:',
      link,
      '',
      'The link works once, for one hour. Resetting signs out every device.',
      'If this was not you, ignore this email; your password has not changed.',
    ].join('\n'),
  };
}
