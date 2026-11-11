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

- [ ] Load a track and show its waveform on a timeline
- [ ] Play the timeline with a moving playhead
- [ ] Split a clip at the playhead
- [ ] Drag clips along the timeline
- [ ] Delete clips
- [ ] Save and reopen remixes as local projects
- [ ] Volume per clip and basic effects (if time allows)

> ⚠️ **Feasibility under test.**  
> Playing clips in sequence requires starting each part of the track from a precise point at a precise time.  
> This is being tested with the audio engine before building the full editor.

### Online features (external APIs)

- [ ] Login with a demo account (DummyJSON)
- [ ] Home feed and music player with real Creative Commons tracks (Jamendo)
- [ ] Playlists (Jamendo)
- [ ] Artist and user profiles with generated names and pictures (Random User Generator)

### Mock (UI only)

Statistics, followers and likes are static sample data. Remixes are not published anywhere: they stay in the app's local library.

## How remixing works

### Which tracks can be remixed

The Remix button is enabled only when both conditions are true:

1. The artist allows downloads: the Jamendo field `audiodownload_allowed` is `true`.
2. The license allows derivative works: the license URL in `license_ccurl` is not a NoDerivatives (`-nd`) license.

Otherwise the button is disabled and its label changes to **Remix not allowed**.

NoDerivatives tracks are excluded even though remixes are never published: the rule is simple, consistent and respects the artist's choice.

### Non-destructive editing

A remix is saved as a project, not as an audio file. The project stores:

- the Jamendo track ID
- the list of clips: for each clip, its start and end in the original track and its position on the timeline

When a remix is opened, the app loads the original track from Jamendo into memory again and rebuilds the remix from the project. No copy of the track is saved on the device, in line with the Jamendo terms.

> ⚠️ **To be evaluated:** how long it takes to load a track before editing can start.

## Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Platforms | Android, iOS |
| Audio engine | [flutter_soloud](https://pub.dev/packages/flutter_soloud) |
| Icons | [phosphor_flutter](https://pub.dev/packages/phosphor_flutter) |
| Font | Exo |
| Design | Figma |

## External APIs

| API | Used for | Key required | Limits |
|---|---|---|---|
| [Jamendo API v3.0](https://developer.jamendo.com/v3.0/docs) | Tracks, audio streaming, playlists | Yes, free app registration on the [Jamendo developer portal](https://devportal.jamendo.com) | Free for non-commercial use, request limits apply over high threshold|
| [Random User Generator](https://randomuser.me/documentation) | Artist and user names and pictures | No | No |
| [DummyJSON](https://dummyjson.com/docs/auth) | Demo authentication | No | No |

### Jamendo terms

Jamendo is free for non-commercial use only. As required by the [Jamendo API terms of use](https://devportal.jamendo.com/api_terms_of_use), the app:

- credits the artist of each track and Jamendo as the provider
- does not store tracks for offline listening
- links each track to its page on Jamendo

All tracks are published under Creative Commons licenses. This app is not affiliated with or endorsed by Jamendo.

### Random User Generator

Users are requested with a fixed `seed` parameter, so the same profiles are returned on every launch.

### DummyJSON

DummyJSON is a fake REST API: login works with its predefined demo users, but new accounts cannot be registered.

| Endpoint | Method | Purpose |
|---|---|---|
| `/auth/login` | POST | Sends `username` and `password`, returns the user data with an `accessToken` and a `refreshToken` |
| `/auth/me` | GET | Returns the current user, with the access token in the `Authorization: Bearer <token>` header |
| `/auth/refresh` | POST | Sends the `refreshToken`, returns a new pair of tokens |

The access token lasts 60 minutes by default. The optional `expiresInMins` field changes its duration.

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
  screens/           one file per screen
  widgets/           reusable UI components

assets/
  audio/             local audio files, if needed
  images/            app images
  data/              mock JSON data
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