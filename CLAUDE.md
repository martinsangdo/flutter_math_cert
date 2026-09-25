# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

MathPathway Junior: a Flutter (Android/iOS, plus web for testing) math-olympiad practice app. The client talks **directly** to Supabase (no server in between); Row Level Security is the only authorization layer. Targets low-end phones (2GB RAM), so keep memory and rebuild cost small.

## Commands

Supabase config is compile-time only. Copy `env/example.json` to `env/dev.json` / `env/prod.json` (gitignored) and pass it in; without it the app shows a "Missing Supabase config" screen.

```bash
flutter run -d chrome --dart-define-from-file=env/dev.json     # web (ads are disabled there)
flutter run --dart-define-from-file=env/dev.json               # device/emulator
flutter build appbundle --release --dart-define-from-file=env/prod.json
flutter analyze
flutter test
flutter test test/logic_test.dart --plain-name "streak counts"  # single test
dart run flutter_launcher_icons                                 # regenerate launcher/web icons from assets/icon/
```

Compile-only smoke check (no real project needed): `flutter build apk --debug --dart-define=SUPABASE_URL=https://x.supabase.co --dart-define=SUPABASE_ANON_KEY=x`.

## Database schema (PostgreSQL / Supabase)

The schema belongs to the project owner and is the source of truth: `supabase/schema.sql` (a copy lives in the MathPathway backend project at `/Users/sangdo/Documents/PROJECTS/MobileApps/MathPathway/supabase/schema.sql`). Do not alter it to fit the app; app-side access rules are in `supabase/app_access.sql`. This section only describes the tables; read those files for the definitions.

| Table | Purpose and key columns |
|---|---|
| `certifications` | One row per exam. `id` is a string (`IKMC`, `AMC8`, `SASMO`). `full_name`, `organizing_body`, `min_grade`/`max_grade`, `default_time_minutes`, `default_question_type` (`MCQ_5`, `MCQ_4`, `INTEGER`, `PROOF`), `has_negative_marking`, `prompt_philosophy` (AI question-generation config, never fetch it in the app). |
| `exam_levels` | Divisions inside an exam (`ECOLIER`, `BENJAMIN`, `MIDDLE_PRIMARY`). Serial int `id`, `certification_id`, `level_code`, `target_grade_min`/`target_grade_max`, `total_questions`, `max_score`. |
| `topics` | Global taxonomy, **not** per certification. Serial int `id`, `domain_code` (`GEOMETRY`, `NUMBER_THEORY`, `COMBINATORICS`, `LOGIC`), `title`, `description`, `difficulty_tier` (1-10). |
| `questions` | The question bank. Bigserial `id`, `certification_id`, nullable `level_id`, `topic_id`, `question_type` (`MCQ_5_OPTION`, `INTEGER_FILL`, `PROOF`), `stem_text`, `latex_content`, `image_url`, `options_json` (`{"A": "...", "B": "...", ...}`), `correct_answer` (option letter or integer as text), `points`, `penalty_points`, `difficulty_rating` (1-10), `detailed_solution_latex`, `kid_friendly_hint`, `is_ai_generated`. Indexed on (`certification_id`, `level_id`) and (`topic_id`, `difficulty_rating`). |
| `user_mastery` | Per student per topic, unique on (`user_id`, `topic_id`). `mastery_score` (0-100), `questions_attempted`, `questions_correct`, `last_practiced_at`. `user_id` has no FK and no default. Written only through `update_user_mastery()`. |
| `exam_sessions` | One row per finished mock exam. UUID `id` and `user_id` have **no defaults** (the client supplies both). `certification_id`, `level_id`, `score`, `total_time_seconds`, `passed_threshold`, `completed_at` (zone-less timestamp, treated as UTC). |

Relationships: `certifications` 1-N `exam_levels` and `questions`; `exam_levels` 1-N `questions` (nullable `level_id`); `topics` 1-N `questions` and `user_mastery`; `certifications`/`exam_levels` 1-N `exam_sessions`. Columns the app never reads: `prompt_philosophy`, `default_question_type`, `max_score`, `difficulty_rating`, `is_ai_generated`, `description`.

## Architecture

Layers: `services/` (I/O) → `logic/` (Riverpod state) → `views/` (UI), with plain data types in `models/models.dart`. `flutter_riverpod` is pinned to 2.x on purpose (3.x auto-retries failed providers); use `Notifier`/`FutureProvider`, not codegen.

**Backend contract.** The schema is the user's own (`supabase/schema.sql`, kept verbatim) and must not be changed to suit the app. Access rules the app depends on live in `supabase/app_access.sql`: RLS policies plus the `update_user_mastery(int, bool)` security-definer function, which is the *only* way `user_mastery` is written (no client write policy). Anonymous sign-in must be enabled in Supabase; `SupabaseService._uid()` signs in lazily before every call, so every query works without a login screen.

Schema facts that shape the code:
- Ids are ints (`questions.id`, `topics.id`, `exam_levels.id`); `certifications.id` is a string like `SASMO`. Contest names, grade range, time limit and negative marking all come from the `certifications` table (with embedded `exam_levels`), not from constants.
- `exam_sessions.id` and `user_id` have no defaults, so the client supplies both (`uuid` v4 + `auth.uid()`). `completed_at` is a zone-less `timestamp`; `parseTimestamp` treats it as UTC.
- There is no exam-date column: the student picks it and it is stored locally per contest (`ExamDateNotifier`, Hive `prefs` box).
- Per-topic breakdown is not stored; it exists only in the in-memory `ExamSession` shown on the results screen. `passed_threshold` uses an app-defined `ExamSession.passRatio` (50%).
- Questions are matched to a grade via an inner join on `exam_levels` (`target_grade_min/max`), `PROOF` questions are excluded, MCQ options come from `options_json` and the answer is the option letter. Text fields use inline `$...$` LaTeX (`LatexText`); `latex_content` is a bare expression (`LatexBlock`); `image_url` ending in `.svg` renders via `flutter_svg` (`QuestionImage`), otherwise as a raster image.

**Quiz flow** (`logic/quiz_controller.dart`, `views/quiz_screen.dart`). `quizProvider` is an auto-dispose notifier that loads pages of 10 (`range(offset, offset+limit-1)`) until the level's `total_questions`, and starts the exam clock when the first page lands. `finish()` scores points (minus `penalty_points` when the contest has negative marking, floored at 0), fires `updateUserMastery` per answered question (errors swallowed), submits the session, and never blocks results on network failure. The timer (`Countdown`) rebuilds only its own subtree.

**Offline.** `SupabaseService` caches certifications (Hive `prefs`) and question pages (Hive `question_cache`), falling back to them on any network error. `CacheService.writeQuestions` wipes the whole question cache when it would reach ~45KB (50KB cap).

**Ads** (`ad_service.dart`, `widgets/ad_banner.dart`). Only on Android/iOS (`AppConfig.adsSupported`); on web/desktop the banner collapses and the rewarded "hint" unlocks immediately. Rewarded ads are loaded on demand and disposed after use. Test unit ids are used unless a release build passes `ADMOB_BANNER_ID` / `ADMOB_REWARDED_ID`; real AdMob app ids still need replacing in `AndroidManifest.xml` and `Info.plist`.

**Config normalisation.** `AppConfig.supabaseUrl` reduces the URL to its origin (a pasted `/rest/v1/` suffix otherwise makes every auth call 404). `main.dart` passes the key as `anonKey` with an `ignore: deprecated_member_use` to stay compatible with `supabase_flutter: ^2.0.0`.

## UI conventions

- All styling goes through `theme/app_theme.dart` (light + dark `ColorScheme`s, Baloo 2 variable font bundled in `assets/fonts/`, headings via `AppTheme.heading`). Read colours from `Theme.of(context).colorScheme` (plus the `success`/`warning` extension), not hardcoded hex, so dark mode keeps working.
- Cards are `ClayCard` (thick border + solid lower lip, no blur). Use `ContentWidth` to cap width at 640 on tablets/web, `BottomBar` for fixed action bars (safe-area aware, hosts the banner), `MessageView` for error/empty states.
- A `Row` with `CrossAxisAlignment.stretch` inside a `ListView` needs `IntrinsicHeight` (unbounded height otherwise breaks layout).
- Errors are shown in full only in debug builds (`kDebugMode`); release shows a friendly message.
