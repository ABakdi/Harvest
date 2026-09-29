import { ChartLineIcon, SettingsIcon, type LucideIcon } from 'lucide-react';
import { useTranslation } from 'react-i18next';
import { NavLink } from 'react-router';
import { cn } from '@/lib/utils';

/*
 * The tabs under a screen's title ([[Web]]). On a wide window they are
 * the segmented pill the web has always had; on a phone-width one they
 * are the phone's tab row: the full width, pinned under the app bar,
 * icon and label, and a bar under the one on show.
 */

/** The row: pill on a wide window, the phone's row under the app bar on a narrow one. */
export const screenTabsList =
  'max-md:sticky max-md:top-[calc(3.5rem+env(safe-area-inset-top))] max-md:z-20 max-md:-mx-3 max-md:-mt-4 max-md:flex max-md:w-auto max-md:max-w-none max-md:gap-0 max-md:overflow-x-auto max-md:no-scrollbar max-md:rounded-none max-md:border-b max-md:bg-background max-md:p-0';

/** One tab: for a Radix trigger (`data-state`) or a link (`aria-current`). */
export const screenTabsTrigger =
  "max-md:relative max-md:h-12 max-md:min-w-fit max-md:flex-1 max-md:shrink-0 max-md:gap-1.5 max-md:rounded-none max-md:px-2.5 max-md:text-muted-foreground max-md:shadow-none max-md:after:absolute max-md:after:inset-x-3 max-md:after:bottom-0 max-md:after:h-[3px] max-md:after:rounded-t-full max-md:after:bg-primary max-md:after:opacity-0 max-md:after:content-[''] max-md:data-[state=active]:bg-transparent max-md:data-[state=active]:text-primary max-md:data-[state=active]:shadow-none max-md:data-[state=active]:after:opacity-100 max-md:aria-[current=page]:bg-transparent max-md:aria-[current=page]:text-primary max-md:aria-[current=page]:shadow-none max-md:aria-[current=page]:after:opacity-100";

/** The icon a tab carries on the phone; a wide window shows the label alone. */
export function TabIcon({ icon: Icon }: { icon: LucideIcon }) {
  return <Icon className="size-[18px] md:hidden" aria-hidden />;
}

export interface NavTab {
  to: string;
  label: string;
  icon: LucideIcon;
  /** Lit only on this exact path, not on the paths under it. */
  end?: boolean;
  /** Extra classes, such as a tab only a wide window offers. */
  className?: string;
}

/** Tabs that are pages: each one a link, lit while its path is open. */
export function NavTabs({ label, tabs, className }: { label: string; tabs: NavTab[]; className?: string | undefined }) {
  const item = ({ isActive }: { isActive: boolean }) =>
    cn(
      'inline-flex items-center justify-center whitespace-nowrap rounded-md px-3 py-1.5 text-sm font-extrabold outline-none focus-visible:ring-2 focus-visible:ring-ring',
      isActive ? 'bg-card text-foreground shadow-sm' : 'text-muted-foreground hover:text-foreground',
      screenTabsTrigger,
    );
  return (
    <nav aria-label={label} className={cn('no-scrollbar flex w-fit max-w-full gap-1 overflow-x-auto rounded-lg bg-muted p-1', screenTabsList, className)}>
      {tabs.map((tab) => (
        <NavLink key={tab.to} to={tab.to} end={tab.end ?? false} className={(state) => cn(item(state), tab.className)}>
          <TabIcon icon={tab.icon} />
          {tab.label}
        </NavLink>
      ))}
    </nav>
  );
}

/**
 * Progress and Settings, the farmer's two halves on the phone. A wide
 * window has Settings at the foot of the rail instead, so the row is a
 * phone-width thing only.
 */
export function FarmerTabs() {
  const { t } = useTranslation();
  return (
    <NavTabs
      label={t('nav.farmerTabs')}
      className="md:hidden"
      tabs={[
        { to: '/app/farmer', label: t('nav.progress'), icon: ChartLineIcon },
        { to: '/app/settings', label: t('nav.settings'), icon: SettingsIcon },
      ]}
    />
  );
}
