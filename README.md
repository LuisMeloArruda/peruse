# peruse

Interactive English learning application


## Makefile

From the project root, run targets with [GNU Make](https://www.gnu.org/software/make/) (`make` on macOS/Linux; on Windows use Git Bash, WSL, or run the recipe commands yourself).

| Target | What it does |
|--------|----------------|
| `make fresh` | `flutter clean`, removes `ios/Pods` and `ios/Podfile.lock`, then `flutter pub get`. |
| `make build-runner` | Code generation: `dart run build_runner build --delete-conflicting-outputs`. |
| `make fix-lint` | Applies fixes: `dart fix --apply`. |
| `make format-code` | Runs `fix-lint`, then `dart format .`. |
| `make lint` | Runs `dart analyze` on the project. |
| `make build-apk` | Runs `fresh`, `build-runner`, and `format-code`, then `flutter build apk --release`. |
| `make preview` | Runs `flutter widget-preview start --web-server`. |

Examples:

```bash
make fresh
make build-runner
make format-code
make build-apk
```

## Theme and context extensions

Import the theme barrel so extensions and tokens are available:

```dart
import 'package:peruse/core/theme/theme.dart';
```

Apply the app theme once (already wired in `lib/app.dart` via `AppTheme.light()`).

### `TypographyContext` (`context.textTheme`)

`BuildContext` gets a `textTheme` getter from `typography_context_extension.dart`. It returns the same `TextTheme` as `Theme.of(context).textTheme` (Plus Jakarta Sans / Be Vietnam Pro when using `AppTheme`).

```dart
Text('Welcome', style: context.textTheme.headlineMedium);
Text('Details', style: context.textTheme.bodyMedium);
```

Ensure the widget is under a `MaterialApp` (or `CupertinoApp` with a compatible theme) so `Theme.of(context)` resolves.

### Static tokens

Use these when you are not pulling styles from `TextTheme`:

- `AppColors` — semantic colors aligned with the design system
- `AppSpacing` — spacing scale (`xxs` … `xxl`)
- `AppRadius` — corner radii (`sm` … `sheet`, `pill`)

```dart
padding: const EdgeInsets.all(AppSpacing.md),
borderRadius: BorderRadius.circular(AppRadius.lg),
color: AppColors.surfaceMuted,
```

## Widget previews (`@Preview`)

Previews live in `lib/widget_preview/peruse_widget_previews.dart` and use `@Preview` from `package:flutter/widget_previews.dart`, as described in the [Flutter Widget Previewer](https://docs.flutter.dev/tools/widget-previewer) docs.

### Run previews from the terminal

1. Use a recent **Flutter SDK** (widget previews are documented against current stable; see the docs for minimum version).
2. In the **project root** (`peruse/`), run:

```bash
flutter widget-preview start
```

3. Wait for the tool to finish starting; it should open a **widget preview** session (often in **Chrome**).
4. Pick a preview from the UI; the **Peruse** group contains the catalog of shared widgets.
5. Edit Dart files and save; use the previewer’s **hot restart** for that preview (or the global control) when the tool does not pick up a change.

## Routing

Paths for [go_router](https://pub.dev/packages/go_router) live in **`lib/core/router/routes.dart`** as **`AppRoutes`** (`home`, `login`, `register`). Use these constants everywhere (navigation, redirects, `GoRoute.path`) so URLs stay in one place.

```dart
import 'package:peruse/core/router/routes.dart';

context.push(AppRoutes.register);
```

`GoRouter` configuration is in **`lib/core/router/router.dart`** (Riverpod `routerProvider`).