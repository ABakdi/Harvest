import type * as React from 'react';
import { cn } from '@/lib/utils';

function Input({ className, type, ...props }: React.ComponentProps<'input'>) {
  return (
    <input
      type={type}
      data-slot="input"
      className={cn(
        'flex h-11 w-full min-w-0 rounded-lg bg-input px-4 py-2 text-base outline-none transition-[box-shadow] placeholder:text-muted-foreground file:border-0 file:bg-transparent file:text-sm file:font-medium disabled:cursor-not-allowed disabled:opacity-50 md:text-sm',
        'focus-visible:ring-2 focus-visible:ring-ring',
        'aria-invalid:ring-2 aria-invalid:ring-destructive',
        className,
      )}
      {...props}
    />
  );
}

export { Input };
