// Paint the right theme before React loads, so a dark-mode reader
// never sees a cream flash. Mirrors src/lib/theme.ts.
(function () {
  try {
    var mode = localStorage.getItem('harvest.themeMode') || 'system';
    var preset = localStorage.getItem('harvest.themePreset') || 'harvest';
    var dark = mode === 'dark' || (mode === 'system' && matchMedia('(prefers-color-scheme: dark)').matches);
    var root = document.documentElement;
    root.classList.toggle('dark', dark);
    root.dataset.preset = preset;
    var lang = localStorage.getItem('harvest.locale');
    if (lang === 'ar') { root.lang = 'ar'; root.dir = 'rtl'; }
  } catch (e) {}
})();
