import { XIcon } from 'lucide-react';
import { Dialog as DialogPrimitive } from 'radix-ui';
import * as React from 'react';
import { useTranslation } from 'react-i18next';
import { settleFocus } from '@/lib/focus';
import { cn } from '@/lib/utils';

function Dialog(props: React.ComponentProps<typeof DialogPrimitive.Root>) {
  return <DialogPrimitive.Root data-slot="dialog" {...props} />;
}

function DialogTrigger(props: React.ComponentProps<typeof DialogPrimitive.Trigger>) {
  return <DialogPrimitive.Trigger data-slot="dialog-trigger" {...props} />;
}

function DialogClose(props: React.ComponentProps<typeof DialogPrimitive.Close>) {
  return <DialogPrimitive.Close data-slot="dialog-close" {...props} />;
}

function DialogOverlay({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Overlay>) {
  return (
    <DialogPrimitive.Overlay
      data-slot="dialog-overlay"
      className={cn(
        'fixed inset-0 z-50 bg-black/50 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0',
        className,
      )}
      {...props}
    />
  );
}

/**
 * On a phone-width window a dialog is the phone's bottom sheet: the
 * full width, rising from the foot, with a grab handle and clear of the
 * home indicator. `sheet={false}` keeps a dialog as it is drawn for
 * those that are not forms: the full-screen viewers, and search, which
 * wants the top of the screen while the keyboard is up.
 */
const sheetClasses =
  'max-md:inset-x-0 max-md:top-auto max-md:bottom-0 max-md:left-0 max-md:w-full max-md:max-w-none max-md:translate-x-0 max-md:translate-y-0 max-md:max-h-[92dvh] max-md:rounded-b-none max-md:rounded-t-[28px] max-md:border-x-0 max-md:border-b-0 max-md:px-5 max-md:pt-9 max-md:pb-[calc(1.5rem+env(safe-area-inset-bottom))] max-md:data-[state=open]:zoom-in-100 max-md:data-[state=closed]:zoom-out-100 max-md:data-[state=open]:slide-in-from-bottom max-md:data-[state=closed]:slide-out-to-bottom';

function DialogContent({
  className,
  children,
  showCloseButton = true,
  sheet = true,
  onCloseAutoFocus,
  ...props
}: React.ComponentProps<typeof DialogPrimitive.Content> & { showCloseButton?: boolean; sheet?: boolean }) {
  const { t } = useTranslation();
  return (
    <DialogPrimitive.Portal>
      <DialogOverlay />
      <DialogPrimitive.Content
        data-slot="dialog-content"
        className={cn(
          'fixed top-1/2 left-1/2 z-50 grid max-h-[calc(100dvh-2rem)] w-[calc(100%-2rem)] max-w-lg -translate-x-1/2 -translate-y-1/2 gap-4 overflow-y-auto rounded-2xl border bg-popover p-6 text-popover-foreground shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95',
          className,
          sheet && sheetClasses,
        )}
        onCloseAutoFocus={(event) => {
          onCloseAutoFocus?.(event);
          if (!event.defaultPrevented) settleFocus();
        }}
        {...props}
      >
        {sheet && <SheetHandle />}
        {children}
        {showCloseButton && (
          <DialogPrimitive.Close
            className="absolute top-4 end-4 rounded-md p-1 opacity-70 transition-opacity hover:opacity-100 focus-visible:ring-2 focus-visible:ring-ring max-md:top-2 max-md:end-2 max-md:flex max-md:size-11 max-md:items-center max-md:justify-center [&_svg]:size-4 max-md:[&_svg]:size-5"
            aria-label={t('common.close')}
          >
            <XIcon />
          </DialogPrimitive.Close>
        )}
      </DialogPrimitive.Content>
    </DialogPrimitive.Portal>
  );
}

/**
 * The sheet's grab handle: dragged down past a third of the way, or
 * flicked, the sheet goes, as the phone's does; let go short of that
 * and it settles back.
 */
function SheetHandle() {
  const close = React.useRef<HTMLButtonElement>(null);
  const drag = React.useRef<{ id: number; y: number; at: number; sheet: HTMLElement } | null>(null);

  const move = (event: React.PointerEvent<HTMLDivElement>) => {
    const current = drag.current;
    if (!current || current.id !== event.pointerId) return;
    const dy = Math.max(0, event.clientY - current.y);
    current.sheet.style.transform = `translateY(${dy}px)`;
  };
  const end = (event: React.PointerEvent<HTMLDivElement>) => {
    const current = drag.current;
    if (!current || current.id !== event.pointerId) return;
    drag.current = null;
    const dy = Math.max(0, event.clientY - current.y);
    const speed = dy / Math.max(1, event.timeStamp - current.at);
    const { sheet } = current;
    sheet.style.transition = '';
    if (dy > sheet.offsetHeight / 3 || (dy > 24 && speed > 0.6)) {
      close.current?.click();
    } else {
      sheet.style.transform = '';
    }
  };

  return (
    <>
      <div
        aria-hidden
        data-sheet-handle
        className="absolute inset-x-0 top-0 flex h-8 touch-none cursor-grab justify-center pt-3 md:hidden"
        onPointerDown={(event) => {
          const sheet = event.currentTarget.parentElement;
          if (!sheet) return;
          event.currentTarget.setPointerCapture(event.pointerId);
          sheet.style.transition = 'none';
          drag.current = { id: event.pointerId, y: event.clientY, at: event.timeStamp, sheet };
        }}
        onPointerMove={move}
        onPointerUp={end}
        onPointerCancel={end}
      >
        <span className="h-1 w-8 rounded-full bg-muted-foreground/40" />
      </div>
      <DialogPrimitive.Close ref={close} tabIndex={-1} aria-hidden className="hidden" />
    </>
  );
}

function DialogHeader({ className, ...props }: React.ComponentProps<'div'>) {
  return <div data-slot="dialog-header" className={cn('flex flex-col gap-2 text-start', className)} {...props} />;
}

function DialogFooter({ className, ...props }: React.ComponentProps<'div'>) {
  return (
    <div
      data-slot="dialog-footer"
      className={cn('flex flex-col-reverse gap-2 sm:flex-row sm:justify-end', className)}
      {...props}
    />
  );
}

function DialogTitle({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Title>) {
  return (
    <DialogPrimitive.Title
      data-slot="dialog-title"
      className={cn('text-xl font-extrabold leading-tight', className)}
      {...props}
    />
  );
}

function DialogDescription({ className, ...props }: React.ComponentProps<typeof DialogPrimitive.Description>) {
  return (
    <DialogPrimitive.Description
      data-slot="dialog-description"
      className={cn('text-sm text-muted-foreground', className)}
      {...props}
    />
  );
}

export {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogOverlay,
  DialogTitle,
  DialogTrigger,
};
