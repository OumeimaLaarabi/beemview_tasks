# BeemView Tasks

A small Flutter app for the BeemView API. A signed-in user can browse their
projects, open a project's tasks, view task details, and change a task's
status, optionally with a note that is posted as a comment.

**Core flow:** Login → Projects → Project Tasks → Task Details → Update Status

## Requirements

| Tool | Version used |
|---|---|
| Flutter | 3.47.6 (stable) |
| Dart | 3.13.5 |
| Android | emulator or device (min/target SDK from Flutter defaults) |

The code uses Dart 3.13 language features, such as private named
constructor parameters (`required this._api`). Use Flutter 3.47 or newer.

## Setup and run

1. Install dependencies:

   ```sh
   flutter pub get
   ```

2. Create the local config file from the example. The file is gitignored,
   so credentials and the tenant never reach source control.

   ```sh
   cp config.example.json config.json       # macOS / Linux
   copy config.example.json config.json     # Windows
   ```

3. Fill in `config.json` with the values supplied by the hiring team:

   ```json
   {
     "API_ORIGIN": "https://beemview.com",
     "TENANT_SUBDOMAIN": "<supplied tenant subdomain>",
     "DEV_LOGIN_EMAIL": "",
     "DEV_LOGIN_PASSWORD": ""
   }
   ```

4. Run the app with the config:

   ```sh
   flutter run --dart-define-from-file=config.json
   ```

Other commands:

```sh
flutter test                                                   # unit + widget tests
flutter analyze                                                # static analysis
flutter build apk --release --dart-define-from-file=config.json
```

## Configuration

Settings are read at build time with `--dart-define-from-file` (see
`lib/core/config/app_config.dart`). Nothing tenant-specific is hard-coded.

| Key | Purpose |
|---|---|
| `API_ORIGIN` | Scheme + host, e.g. `https://beemview.com`. The app adds `/api` to every route. Defaults to `https://beemview.com`. |
| `TENANT_SUBDOMAIN` | Sent with every login request. It is not a form field. If it is missing, the login screen shows "App not configured" and sign-in is disabled. |
| `DEV_LOGIN_EMAIL`, `DEV_LOGIN_PASSWORD` | Optional. They pre-fill the login form in **debug builds only**. Release builds drop them, because the check uses the `kDebugMode` constant. |

The same values can be passed one by one:

```sh
flutter run --dart-define=API_ORIGIN=https://beemview.com --dart-define=TENANT_SUBDOMAIN=<subdomain>
```

## Features

| Screen | Behaviour |
|---|---|
| **Login** | Email and password validation (valid email, password of 6+ characters). The tenant subdomain comes from config. Loading state, and inline errors that tell invalid credentials (400) apart from an inactive account (403). "Keep me signed in" is on by default. |
| **Session** | The token is stored with `flutter_secure_storage` (Keychain / Keystore). On startup it is checked with `GET /api/users/me/profile`. Any 401 clears the session and returns to login. If the app is offline at startup, it keeps the token and offers Retry or Sign out. Sign out is local only, because the contract has no logout route. |
| **Projects** | `GET /api/projects?limit=10&offset=N` with a "Load more" button until everything is loaded, plus pull-to-refresh. It accepts both the `data` envelope and the empty `{"result": [], "count": 0}` shape. |
| **Project Tasks** | `GET /api/tasks/project/:id` loads every task at once. Each card shows name, status, priority, due date (overdue in red) and assignees. Search by task name and filter by status, both clearly labelled as filtering the **loaded** tasks. Separate empty states for "no tasks" and "no matches". |
| **Task Details** | `GET /api/tasks/:id`. Shows description, project, assignees, start/due/created/updated dates, status, priority and the latest returned comment, with placeholders when a value is missing. |
| **Update Status** | A sheet with every API status and an optional note. It saves the status first (`PUT /api/tasks/:id` with only `{"status"}`), then posts a non-empty note (`POST /api/tasks/comment`). After a save it re-fetches the details and reloads the task list. |

Every read screen has loading, empty, error-with-retry and pull-to-refresh
states.

### Status update and partial failure

Status and comment are two separate requests, and they are not atomic. The
update flow is a small state machine in `UpdateStatusCubit`:

- **No duplicate submissions.** The Save button shows a spinner and ignores
  taps, and the sheet cannot be dismissed mid-request. The cubit also
  ignores a second submit on its own.
- **The status fails:** nothing else is sent. The selection and note are
  kept, and the user can save again.
- **The status is saved but the comment fails:** the sheet says the status
  was saved and keeps the note. It offers **Retry comment** (the status is
  never sent again) or closing without the note.
- **Ambiguous failure** (timeout after the request was sent): the user is
  warned the note may already be posted. Nothing is retried automatically,
  so a comment is never duplicated by the app.

## Architecture

```
lib/
  main.dart                 wires config, ApiClient and repositories
  app.dart                  MaterialApp; picks the screen from AuthState
  core/
    config/                 AppConfig (dart-define values)
    network/                ApiClient (Dio wrapper), ApiException
    storage/                SessionStorage (secure token storage)
    theme/                  colours and ThemeData
  data/
    models/                 typed, normalised models (Task, Project, ...)
    repositories/           AuthRepository, ProjectRepository, TaskRepository
  features/
    auth/                   AuthCubit, LoginCubit, login and session screens
    projects/               ProjectsCubit, projects screen
    tasks/                  task list, details, update-status cubits and UI
  widgets/                  reusable UI (buttons, fields, banners, empty/error views)
```

Each layer has one job:

- **`ApiClient`** is the only class that talks to Dio. It sets the base URL,
  JSON headers, `Accept-Language: en` and the Bearer token. It turns every
  failure into an `ApiException` with a type (400, 401, 403, 404, 429, 5xx,
  timeout, network) and a message read from `error` or `message`, including
  validation `details`. A 401 on a protected request clears the session and
  notifies `AuthCubit`. A 403 is shown as "no access", never as an expired
  session.
- **Models** normalise the two task shapes. They handle `dueDate`/`due_date`
  and `startedDate`/`start_date`, priority `"High"`/`"high"`,
  `Project`/`project_id`, and `Assignees`/`assignedTo`. They tolerate
  missing or unexpected values and never throw. Unknown statuses keep their
  raw value. The list route's `progress` field is ignored on purpose.
- **Repositories** expose typed methods per endpoint. The UI never sees raw
  JSON or Dio types.

### State management: Cubit (flutter_bloc)

Each screen has its own Cubit with an immutable, `Equatable` state. Session
state lives in one app-wide `AuthCubit`.

Why Cubit:

- **Simple:** plain method calls (`load()`, `submit()`) without the event
  classes a full Bloc needs. That suits a small app.
- **Explicit states:** loading, success, failure and the update phases are
  values the UI switches on. That makes edge cases visible and hard to miss.
- **Easy to test:** `bloc_test` checks the exact sequence of states, which
  is how the update flow and pagination are tested.
- **Scoped:** a screen's cubit is created with the screen and closed when it
  leaves.

Two rules apply to every cubit that loads data:

1. A **generation counter** drops stale responses. A slow first load can't
   overwrite a newer refresh, and a pull-to-refresh can't mix with an
   in-flight "load more".
2. A failed **refresh** keeps the data already on screen and shows a
   snackbar instead of replacing the screen with an error.

## Packages

| Package | Why |
|---|---|
| `dio` | HTTP client: interceptors for the token, timeouts, typed errors |
| `flutter_bloc` | Cubit state management |
| `equatable` | Value equality for states and models |
| `flutter_secure_storage` | Session token in Keychain / Keystore |
| `intl` | Date formatting |
| `bloc_test`, `mocktail` *(dev)* | Cubit and widget tests with mocked repositories |
| `flutter_lints` *(dev)* | Lint rules |

The UI uses the Manrope font (SIL Open Font License), bundled in
`assets/fonts/`.

## Tests

`flutter test` runs 96 tests in `test/`. The most relevant ones are:

- `data/response_mapping_test.dart`: both task shapes, priority casing,
  envelopes, calendar dates, latest comment, overdue rules.
- `features/tasks/update_status_cubit_test.dart`: update state transitions
  (status first, then comment, partial failure, retry the comment only, no
  duplicate submits).
- `features/tasks/task_details_screen_test.dart`: the full change-status
  flow in the UI, including retrying a failed note.
- `features/projects/projects_cubit_test.dart`: pagination, stale responses,
  failed load-more and refresh.
- `core/api_client_test.dart`, `features/auth/*`: login, session restore,
  401 handling, the login form.

## Assumptions

- Due and start dates are calendar days sent as UTC midnight
  (`2026-10-10T00:00:00Z`). The app shows the day as written, so it doesn't
  shift to the day before for users west of UTC.
- A task is **overdue** when its due day is before today and its status is
  not `done` or `canceled`.
- Tasks are shown in the order the API returns them.
- Statuses outside the 8 documented values are shown with their raw name
  and only appear under the "All" filter.
- The note can only be posted together with a status change, as described
  in the assignment. Saving requires a status different from the current
  one.
- Write requests may return an empty body (e.g. 204), which is treated as
  success.
- There is no password-reset route, so "Forgot password?" tells the user to
  contact their workspace administrator.
- "Keep me signed in" (on by default) persists the session. When unchecked,
  the token is kept in memory only, and the next launch starts at login.

## Known limitations

- **No full comment history.** Only the latest returned comment is shown,
  as the assignment allows. Comments can't be posted without a status
  change.
- **Not included:** priority filter, offline caching, dark theme and
  translations. The UI is English and light theme only.
- **Late 401 edge case:** a 401 from a request sent with an *old* token,
  arriving after the user has signed in again, would also clear the new
  session. Fixing it means comparing the token the request used with the
  current one.
- **Dates with a non-UTC offset:** a due date sent with an offset other than
  `Z` (e.g. `+05:00`) could show one day off. The documented format uses
  `Z`.
- **Platforms:** developed and tested on Android only. The iOS project has
  not been built.
- **Release setup is not done:** the Android application ID is still the
  template `com.yourname.beemview_tasks`, and release builds are signed with
  the debug key.
