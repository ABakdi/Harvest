import { PlusIcon } from 'lucide-react';
import { useSyncExternalStore } from 'react';
import type * as React from 'react';
import { Button } from '@/components/ui/button';
import { cn } from '@/lib/utils';

/**
 * A screen's primary action. On a phone-width window it floats in the
 * bottom corner above the tab bar, the gradient pill the phone draws
 * (`HarvestFab`); on a wide window it is an ordinary button where the
 * screen puts it, or nothing at all when [wide] is false because the
 * wide layout already offers it elsewhere.
 */
export function Fab({
  label,
  icon = <PlusIcon />,
  wide = true,
  className,
  ...props
}: Omit<React.ComponentProps<typeof Button>, 'children'> & { label: string; icon?: React.ReactNode; wide?: boolean }) {
  return (
    <Button
      data-fab
      className={cn(
        'max-md:fixed max-md:end-4 max-md:bottom-[calc(6rem+env(safe-area-inset-bottom))] max-md:z-30 max-md:h-14 max-md:rounded-2xl max-md:bg-harvest-gradient max-md:px-5 max-md:text-base max-md:text-white max-md:shadow-lg max-md:shadow-primary/40 max-md:[text-shadow:0_1px_1px_rgb(0_0_0/0.25)] max-md:has-[>svg]:px-5 max-md:[&_svg:not([class*=size-])]:size-5',
        !wide && 'md:hidden',
        className,
      )}
      {...props}
    >
      {icon}
      {label}
    </Button>
  );
}

const phoneQuery = '(width < 48rem)';

function subscribe(onChange: () => void) {
  if (typeof window.matchMedia !== 'function') return () => {};
  const query = window.matchMedia(phoneQuery);
  query.addEventListener('change', onChange);
  return () => query.removeEventListener('change', onChange);
}

/**
 * Whether the window is phone-width, where the layout is the phone's.
 * For the few places that must choose one control rather than restyle
 * it, such as a floating action that stands in for a card's button.
 */
export function usePhoneWidth(): boolean {
  return useSyncExternalStore(
    subscribe,
    () => typeof window.matchMedia === 'function' && window.matchMedia(phoneQuery).matches,
    () => false,
  );
}
