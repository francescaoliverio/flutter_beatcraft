# BeatCraft

**Craft sound. Share the vibe.**

BeatCraft is a mobile app concept that brings together a beat maker, a music player and a creator community in one place. This repository contains a working demo built with Flutter as an individual academic project for ITS Academy ICT Piemonte.

> 🚧 **Work in progress.**  
> The project is under active development.

## Features

### Real (working in the demo)

- [x] Step sequencer with multiple tracks, BPM control and play/stop
- [ ] Mixer: volume, mute and solo per track
- [ ] Audio effects (e.g. reverb, delay, filter)
- [ ] Save and load projects locally
- [ ] Publish a beat to the local feed
- [ ] Music player with mini player

### Mock (UI only, with sample data)

Home feed, trending artists, playlists, user profile and statistics use local mock data. There is no backend: everything runs offline on the device.

## Tech stack

| Area | Choice |
|---|---|
| Framework | Flutter (Dart) |
| Platforms | Android, iOS |
| Audio engine | [flutter_soloud](https://pub.dev/packages/flutter_soloud) |
| Icons | [phosphor_flutter](https://pub.dev/packages/phosphor_flutter) |
| Font | Exo |
| Design | Figma |

## Project structure

```
lib/
  main.dart          app entry point
  app.dart           MaterialApp, theme and routes
  theme/             design tokens from Figma: colors, text styles, spacing, effects
  models/            data classes (tracks, beat projects)
  services/          audio engine and local storage
  screens/           one file per screen
  widgets/           reusable UI components

assets/
  audio/             samples and demo tracks
  images/            covers and avatars
  data/              mock JSON data
  fonts/             Exo font files
```

## Getting started

Requirements: Flutter SDK, Android Studio for Android, Xcode on macOS for iOS.

```bash
git clone https://github.com/francescaoliverio/flutter_beatcraft
cd flutter_beatcraft
flutter pub get
flutter run
```

## Design

The visual identity is dark mode first, with a neon green and purple palette. Colors, typography, spacing and effects are defined as tokens in Figma and mirrored in `lib/theme/`.

## Roadmap

Ideas beyond the scope of this demo:

- Real backend with user accounts and cloud storage
- Live listening sessions synced between devices
- Remix of other creators' beats
- Microphone recording to create custom samples
- Export to WAV or MP3
- Direct support for artists

## Author

Francesca Oliverio  
Student at ITS Academy ICT Piemonte, Turin, Italy.