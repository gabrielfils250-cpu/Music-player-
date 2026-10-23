# G&F Music Player

Flutter source for a local/offline music player for Android and iOS.

## Features
- Import audio files selected through the phone's file picker; copies them into app-private storage for offline use
- Background playback and media notification/controls via `just_audio_background`
- Search songs and artists
- Create playlists and add tracks to playlists
- Shuffle, repeat off/all/one, seek bar, previous/next
- Edit song title/artist and remove imported tracks
- Equalizer preset selector (see limitations below)

## Setup
1. Install Flutter stable and Android Studio. For iPhone builds, you also need a Mac with Xcode.
2. Extract this ZIP and open a terminal in the `gf_music_player` folder.
3. Generate platform scaffolding:
   ```bash
   flutter create --platforms=android,ios .
   ```
   If prompted about overwriting, allow Flutter to generate the standard platform folders. Keep `lib/main.dart` and `pubspec.yaml`.
4. Install dependencies:
   ```bash
   flutter pub get
   ```
5. Connect an Android phone with USB debugging enabled, or launch an Android emulator:
   ```bash
   flutter run
   ```
6. Tap **Import music** and choose audio files.

## Build an Android APK
```bash
flutter build apk --release
```
The APK is usually at `build/app/outputs/flutter-apk/app-release.apk`.

## iPhone
iOS apps must be built and signed on a Mac using Xcode. After `flutter create --platforms=android,ios .`, run `flutter pub get`, open `ios/Runner.xcworkspace`, configure your signing team and bundle identifier, then run on your iPhone.

## Important limitations
- The music library is local to this app/device. It does not sync between phones and does not stream internet music.
- The preset selector is currently a UI placeholder; app-controlled equalizer processing is not implemented in this starter. Equalizer implementation differs across Android devices and iOS and needs platform-specific audio processing.
- Codec support depends on the operating system. Test the formats you use on your target phone.
- Background playback should be tested on target OS versions and device battery settings.
- This is source code, not a signed APK or iOS IPA.
