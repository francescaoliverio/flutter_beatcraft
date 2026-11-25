import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/track.dart';

/// Track opened in Create with the Remix button: null until one is chosen.
class RemixTrackNotifier extends Notifier<Track?> {
  @override
  Track? build() => null;

  void select(Track track) => state = track;
}

final remixTrackProvider = NotifierProvider<RemixTrackNotifier, Track?>(RemixTrackNotifier.new);
