# BeatCraft

Individual ITS project: a Flutter app that combines a remix editor, a music player and a creator community. Features, APIs and remix rules are described in `@README.md`.

## Stack

- Flutter 3.50, Dart. Targets: Android and iOS only.
- `material_ui` instead of `package:flutter/material.dart` (Flutter 3.50).
- Icons: `phosphoricons_flutter`. Do not use `phosphor_flutter`: it extends `IconData`, which is `final` since Flutter 3.44, so it doesn't compile.
- State: `flutter_riverpod`. Code generation: not decided yet, ask before choosing.
- HTTP: `http`.

## Structure

```
lib/
  main.dart, app.dart
  theme/      design tokens
  models/     data classes
  services/   API calls, audio engine, local storage
  providers/  Riverpod providers
  screens/    one file per screen
  widgets/    reusable components
```

## Code style

- Formatter page width 120 (`analysis_options.yaml`). Single quotes.
- Naming: theme classes have the `App` prefix (`AppColors`), widgets don't (`Button`, `Heading`), screens end with `Screen`.
- Comments: a short `///` summary per class; inline comments only where the code isn't obvious. No usage examples in comments.
- Always use the theme tokens, never hardcoded colors, sizes or text styles.
- Use the `Heading` widget for headings (it sets screen reader semantics) and `Button` for buttons.
- Take into account accessibility.
- Value scalable architecture.

## Design rules

- White text only on `AppColors.bgDark` (#0E0E0E). On brand colors (primary, secondary, tertiary) text is always dark.
- `greyDark` and `greyDarker` are not readable as text on the background: use them for borders, dividers and surfaces.
- No Material ripple: the design uses pressed colors instead.

## APIs

- Jamendo: `client_id` passed with `--dart-define=JAMENDO_CLIENT_ID=...`, read with `String.fromEnvironment`. Never write it in the code or in committed files.
- Jamendo `/playlists` fails with `Internal Error` without a filter: always pass one (e.g. `namesearch`).
- Jamendo playlists: `user_name` can contain an email address. Never read or show it.
- Jamendo tracks: `waveform` (when present) is a JSON string inside the JSON and needs a second decode.
- Jamendo errors come with HTTP 200: check `headers.code` (0 = success).
- Jamendo sometimes returns empty `results` with `code` 0: retry before showing an error.
- Jamendo `headers.next` contains the full URL with `client_id`: never log or show it.
- Remix allowed only if `audiodownload_allowed` is true and `license_ccurl` is present and not NoDerivatives (`-nd`).
- Remixes are non-destructive: saved as a project (track id + clips), never as an audio copy of the track.
- DummyJSON: demo login, token kept in memory only.

## Known issues

- Android emulator: black screen with the app built correctly is fixed by setting the AVD graphics acceleration to Hardware and doing a cold boot.
