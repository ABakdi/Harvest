import { act, render, screen } from '@testing-library/react';
import { afterEach, describe, expect, it } from 'vitest';
import { LocaleDirection } from '@/components/locale-direction';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import i18n from '@/i18n';

afterEach(async () => {
  await act(() => i18n.changeLanguage('en'));
});

describe('the reading direction reaches Radix', () => {
  it('lays tabs out right to left in Arabic, and back when the language changes', async () => {
    render(
      <LocaleDirection>
        <Tabs defaultValue="a">
          <TabsList>
            <TabsTrigger value="a">A</TabsTrigger>
            <TabsTrigger value="b">B</TabsTrigger>
          </TabsList>
          <TabsContent value="a">Inside</TabsContent>
        </Tabs>
      </LocaleDirection>,
    );
    const root = () => screen.getByRole('tablist').closest('[data-slot="tabs"]')!;
    expect(root()).toHaveAttribute('dir', 'ltr');
    await act(() => i18n.changeLanguage('ar'));
    expect(root()).toHaveAttribute('dir', 'rtl');
    expect(document.documentElement.dir).toBe('rtl');
    await act(() => i18n.changeLanguage('en'));
    expect(root()).toHaveAttribute('dir', 'ltr');
  });

  it('lets a long tab strip scroll instead of clipping', () => {
    render(
      <Tabs defaultValue="a">
        <TabsList>
          <TabsTrigger value="a">A</TabsTrigger>
        </TabsList>
      </Tabs>,
    );
    expect(screen.getByRole('tablist')).toHaveClass('overflow-x-auto', 'max-w-full');
    expect(screen.getByRole('tab')).toHaveClass('shrink-0');
  });
});
