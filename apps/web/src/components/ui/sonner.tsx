import { Toaster as Sonner, type ToasterProps } from 'sonner';
import { useIsDark } from '@/lib/theme';

function Toaster(props: ToasterProps) {
  const dark = useIsDark();
  return (
    <Sonner
      theme={dark ? 'dark' : 'light'}
      className="toaster group"
      style={
        {
          '--normal-bg': 'var(--popover)',
          '--normal-text': 'var(--popover-foreground)',
          '--normal-border': 'var(--border)',
          '--border-radius': '16px',
        } as React.CSSProperties
      }
      {...props}
    />
  );
}

export { Toaster };
