# BeatCraft

**Craft sound. Share the vibe.**

BeatCraft is a mobile app concept that brings together a remix editor, a music player and a creator community in one place.

This repository contains a working demo built with Flutter as an individual academic project for ITS Academy ICT Piemonte.

> 🚧 **Work in progress.**  
> The project is under active development.  
> Features are marked below as done or planned.

## Features

### Remix editor

The Create screen is a timeline editor where you remix a Jamendo track.

- [x] Load a track and show its waveform on a timeline
- [x] Play the timeline with a moving playhead
- [x] Split a clip at the playhead
- [x] Drag clips along the timeline: a clip dropped on another one goes before or after it, and the following clips move right only as much as needed, keeping the gaps between them
- [x] Copy a clip and paste it at the playhead, with the same rule as dragging
- [x] Delete clips and close the gaps between them
- [x] Undo and redo clip edits
- [x] Zoom and scroll the timeline, down to one second across the screen; the view follows the playhead or a clip dragged against its edge
- [x] Save and reopen remixes as local projects, with a name and a cover of your choice, edited together from the pencil next to the name
- [ ] Volume per clip and basic effects (if time allows)

> ℹ️ **How clips play in sequence.**  
> Each clip is scheduled on the clock of the audio engine and starts from its own point in the original track.  
> The whole timeline is planned before the first sound, so the clips follow each other at the right time.

### Online features (external APIs)

- [x] Login with a demo account (DummyJSON)
- [x] Home feed and music player with real Creative Commons tracks (Jamendo)
- [x] Ready to remix: popular tracks that can be remixed (Jamendo)
- [ ] Trending artists (Jamendo)
- [ ] Playlists (Jamendo)

### Your library

- [x] Like tracks and find them among your favorites in the profile
- [x] Saved remixes in the profile, to reopen or delete

Deleting or saving a remix can be undone from the message that appears at the bottom of the screen. Remix names are unique for each user: a new remix of the same track is numbered, and a name already in use can't be chosen.

Favorites, saved remixes and the last track played are kept on the device, separately for each user who logs in.

### Mock (UI only)

Statistics and followers are static sample data. Remixes are not published anywhere: they stay in the app's local library.

## How remixing works

### Which tracks can be remixed

The Remix button is enabled only when both conditions are true:

1. The artist allows downloads: the Jamendo field `audiodownload_allowed` is `true`.
2. The license allows derivative works: the license URL in license_ccurl is present and is not a NoDerivatives (-nd) license.

Otherwise the button is disabled and its label changes to **Not allowed** (screen readers announce "Remix not allowed").

NoDerivatives tracks are excluded even though remixes are never published: the rule is simple, consistent and respects the artist's choice.

### Non-destructive editing

A remix is saved as a project, not as an audio file. The project stores:

- the Jamendo track ID
- the list of clips: for each clip, its start and end in the original track and its position on the timeline
- the remix name and the number of its cover, one of the images in the app

When a remix is opened, the app loads the original track from Jamendo into memory again and rebuilds the remix from the project. No copy of the track is saved on the device, in line with the Jamendo terms.

> ⚠️ **To be evaluated:** how long it takes to load a track before editing can start.

## Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Platforms | Android, iOS |
| State management | [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) |
| HTTP | [http](https://pub.dev/packages/http) |
| Audio engine | [flutter_soloud](https://pub.dev/packages/flutter_soloud) |
| Local storage | [shared_preferences](https://pub.dev/packages/shared_preferences) |
| Links to Jamendo | [url_launcher](https://pub.dev/packages/url_launcher) |
| UI components | [material_ui](https://pub.dev/packages/material_ui) |
| Icons | [phosphoricons_flutter](https://pub.dev/packages/phosphoricons_flutter) |
| Font | Exo |
| Design | Figma |

## External APIs

| API | Used for | Key required | Limits |
|---|---|---|---|
| [Jamendo API v3.0](https://developer.jamendo.com/v3.0/docs) | Tracks, audio streaming, artists, playlists | Yes, free app registration on the [Jamendo developer portal](https://devportal.jamendo.com) | Free for non-commercial use, request limits apply over high threshold|
| [DummyJSON](https://dummyjson.com/docs/auth) | Demo authentication | No | No |

### Jamendo terms

Jamendo is free for non-commercial use only. As required by the [Jamendo API terms of use](https://devportal.jamendo.com/api_terms_of_use), the app:

- credits the artist of each track and Jamendo as the provider
- does not store tracks for offline listening
- links each track to its page on Jamendo, from Share in the player and from the credit in Create

All tracks are published under Creative Commons licenses. This app is not affiliated with or endorsed by Jamendo.

### DummyJSON

DummyJSON is a fake REST API: login works with its predefined demo users, but new accounts cannot be registered.

| Endpoint | Method | Purpose |
|---|---|---|
| `/auth/login` | POST | Sends `username` and `password`, returns the user data with an `accessToken` and a `refreshToken` |
| `/users/{id}` | GET | Returns a user by id: at launch it brings back the user who was logged in, without asking for the password again |

The access token is kept in memory only, and the refresh token is not kept. Only the user id is saved on the device, and logout removes it.

**Demo account**

| Username | Password |
|---|---|
| `emilys` | `emilyspass` |

Any other user listed at [dummyjson.com/users](https://dummyjson.com/users) works too.

## Project structure

```
lib/
  main.dart          app entry point
  app.dart           MaterialApp, theme and routes
  theme/             design tokens from Figma: colors, text styles, spacing, effects
  models/            data classes (tracks, clips, remix projects)
  services/          audio engine, API calls and local storage
  providers/         Riverpod providers: shared state such as the login session
  screens/           one file per screen
  widgets/           reusable UI components

assets/
  images/            playlist and remix covers
  fonts/             Exo font files
```

## Getting started

Requirements: Flutter SDK, Android Studio for Android, Xcode on macOS for iOS.

```bash
git clone https://github.com/francescaoliverio/flutter_beatcraft
cd flutter_beatcraft
flutter pub get
flutter run --dart-define=JAMENDO_CLIENT_ID=your_client_id
```

API keys are not stored in this repository. Register an app on the Jamendo developer portal to get your own credentials and pass them at launch as shown above.

Alternatively, put the key in a `.env` file in the project root (it is ignored by git) and launch with `--dart-define-from-file`:

```bash
echo "JAMENDO_CLIENT_ID=your_client_id" > .env
flutter run --dart-define-from-file=.env
```

### Run on a device or emulator

1. Start an emulator (Android Studio's Device Manager, or the iOS Simulator from Xcode), or connect a phone with a USB cable (on iPhone, Developer Mode must be on).
2. List the available devices and copy the id of the one you want, the second column:

   ```bash
   flutter devices
   ```

3. Launch the app on it:

   ```bash
   flutter run -d <device-id> --dart-define-from-file=.env
   ```

   Or, to hide the engine message explained below:

   ```bash
   flutter run -d <device-id> --dart-define-from-file=.env 2>&1 | grep --line-buffered -v "Reported frame time is older"
   ```

   `2>&1` sends the error output to the same place as the normal output, and `grep -v` drops the lines with that message. `--line-buffered` prints the other lines as soon as they arrive. If the hot reload keys stop responding with the filtered output, use the first command.

#### About "Reported frame time is older than the last one; clamping"

While the app runs, the terminal may show lines like this one, especially while scrolling or dragging:

```
[ERROR:flutter/lib/ui/window/platform_configuration.cc(475)] Reported frame time is older than the last one; clamping. 523424059836 < 523424060851 ~= 1015
```

- **Where it comes from**: the Flutter engine, not the app code. For every frame the operating system tells Flutter when it will be shown on screen.
- **What it means**: the system reported a frame time earlier than the one of the previous frame, here by about 1 ms (the numbers are microseconds). Flutter's maintainers explain it in [flutter/flutter#106277](https://github.com/flutter/flutter/issues/106277): the system first asks for a frame in the future, then for one that is earlier.
- **Why it can be ignored**: the engine handles it by itself, using the time of the previous frame (that is the "clamping"), and goes on. In the same issue the maintainers state that it "is not a crashing bug". Despite the `ERROR` tag, nothing is wrong in the app, and the app can't prevent it.

## Design

The visual identity is dark mode first, with a neon green and purple palette. Colors, typography, spacing and effects are defined as tokens in Figma and mirrored in `lib/theme/`.

## Roadmap

Ideas beyond the scope of this demo:

- Step sequencer to create beats from scratch with short samples
- Real authentication and user accounts
- Own backend to publish remixes online
- Live listening sessions synced between devices
- Remix of other creators' beats
- Microphone recording to create custom samples
- Export to WAV or MP3
- Direct support for artists

## Author

Francesca Oliverio  
Student at ITS Academy ICT Piemonte, Turin, Italy.