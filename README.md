# MathPathway Junior

Flutter + Supabase math-olympiad practice app (Android/iOS). No middle server: the app talks to Supabase directly and RLS enforces access.

## Setup

1. Create a Supabase project, enable **Authentication → Providers → Allow anonymous sign-ins**, then run [`supabase/schema.sql`](supabase/schema.sql) in the SQL editor (includes sample SASMO grade 5 data).
2. Run:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=<anon key>
   ```

3. Ads use Google's test ids by default. For release, replace the app ids in `AndroidManifest.xml` / `Info.plist` and pass `--dart-define=ADMOB_BANNER_ID=...` / `ADMOB_REWARDED_ID=...`.

## Layout

- `lib/services/` Supabase queries, Hive cache (wiped near 50KB), AdMob
- `lib/logic/` Riverpod providers and the quiz controller
- `lib/models/` data types and the contest list
- `lib/views/` screens and widgets

Question text uses inline LaTeX between `$...$`.
