/* global self, clients */
// Web Push for Harvest ([[Admin]]), loaded into the app's service worker
// by workbox's importScripts. The server sends {id, title, body, link};
// the browser's push service carries it encrypted to this browser. A
// push is shown as it came; a tap opens its link, or the app.

self.addEventListener('push', (event) => {
  let news = {};
  try {
    news = event.data ? event.data.json() : {};
  } catch {
    news = { body: event.data ? event.data.text() : '' };
  }
  const title = typeof news.title === 'string' && news.title ? news.title : 'Harvest';
  const options = {
    body: typeof news.body === 'string' ? news.body : '',
    icon: '/icons/icon-192.png',
    badge: '/icons/icon-192.png',
    tag: typeof news.id === 'string' ? `news-${news.id}` : undefined,
    data: { link: typeof news.link === 'string' && news.link.startsWith('https://') ? news.link : null },
  };
  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const link = event.notification.data && event.notification.data.link;
  const target = link || new URL('/app', self.location.origin).href;
  event.waitUntil(
    (async () => {
      if (!link) {
        // The app already open in a tab: that one comes forward.
        const open = await clients.matchAll({ type: 'window', includeUncontrolled: true });
        const app = open.find((client) => new URL(client.url).pathname.startsWith('/app'));
        if (app) return app.focus();
      }
      return clients.openWindow(target);
    })(),
  );
});
