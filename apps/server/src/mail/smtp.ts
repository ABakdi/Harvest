import nodemailer from 'nodemailer';
import type { SmtpConfig } from '../config.js';
import type { MailMessage, Mailer } from './mailer.js';

export class SmtpMailer implements Mailer {
  private readonly transport: nodemailer.Transporter;

  constructor(
    config: SmtpConfig,
    private readonly from: string,
  ) {
    this.transport = nodemailer.createTransport({
      host: config.host,
      port: config.port,
      secure: config.secure,
      ...(config.user ? { auth: { user: config.user, pass: config.pass ?? '' } } : {}),
    });
  }

  async send(message: MailMessage): Promise<void> {
    await this.transport.sendMail({
      from: this.from,
      to: message.to,
      subject: message.subject,
      text: message.text,
    });
  }
}
