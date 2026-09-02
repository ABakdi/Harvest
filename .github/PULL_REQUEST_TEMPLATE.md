## What

<!-- one or two lines: what does this change grow in the field? -->

## Checklist

- [ ] `flutter analyze` clean, `flutter test` green
- [ ] New strings live in **both** `app_en.arb` and `app_ar.arb` — no hardcoded UI text
- [ ] RTL audit: only `EdgeInsetsDirectional` / `AlignmentDirectional` / `start`/`end`; screens checked in Arabic
- [ ] Both themes checked (light & dark); golden tests updated if a signature component changed
- [ ] New tables/columns carry `uuid`, `updatedAt`, soft-delete where applicable, and writes append to the outbox
- [ ] Schema change? version bumped + schema dumped + migration test added
- [ ] Times/dates respect the 3 AM Harvest Day boundary
