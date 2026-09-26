import type { ReactNode } from 'react';
import { HarvestMark } from '@/components/brand';

export function AuthCard({ title, lead, children }: { title: string; lead?: string | undefined; children: ReactNode }) {
  return (
    <div className="mx-auto flex w-full max-w-md flex-col gap-6 px-4 py-10">
      <div className="flex flex-col items-center gap-3 text-center">
        <HarvestMark className="size-14" />
        <h1 className="text-2xl font-extrabold">{title}</h1>
        {lead && <p className="text-muted-foreground">{lead}</p>}
      </div>
      <div className="rounded-2xl border bg-card p-6">{children}</div>
    </div>
  );
}

export function FormError({ message }: { message: string | null }) {
  if (!message) return null;
  return (
    <p role="alert" className="rounded-lg bg-destructive/10 p-3 text-sm font-semibold text-destructive">
      {message}
    </p>
  );
}
