import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/remix_project.dart';
import '../models/track.dart';
import 'local_storage_provider.dart';

/// What Create opens: a new remix of [track], or a saved [project].
class RemixRequest {
  const RemixRequest.newRemix(Track this.track) : project = null;

  const RemixRequest.open(RemixProject this.project) : track = null;

  final Track? track;
  final RemixProject? project;
}

/// Set by the Remix button in the player and by the saved remixes in the profile. Null until one is chosen.
class RemixNotifier extends Notifier<RemixRequest?> {
  @override
  RemixRequest? build() => null;

  void newRemix(Track track) => state = RemixRequest.newRemix(track);

  void open(RemixProject project) => state = RemixRequest.open(project);
}

final remixProvider = NotifierProvider<RemixNotifier, RemixRequest?>(RemixNotifier.new);

/// Saved remixes, last modified first.
class RemixProjectsNotifier extends AsyncNotifier<List<RemixProject>> {
  @override
  Future<List<RemixProject>> build() async {
    final List<RemixProject> projects = await ref.read(localStorageProvider).readRemixProjects();
    return projects..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  /// Adds [project], or replaces the saved one with the same id, and moves it first.
  Future<void> save(RemixProject project) async {
    final List<RemixProject> projects = state.value ?? await future;
    await _update([project, ...projects.where((p) => p.id != project.id)]);
  }

  Future<void> delete(String projectId) async {
    final List<RemixProject> projects = state.value ?? await future;
    await _update(projects.where((p) => p.id != projectId).toList());
  }

  Future<void> _update(List<RemixProject> projects) async {
    state = AsyncData(projects);
    await ref.read(localStorageProvider).saveRemixProjects(projects);
  }
}

final remixProjectsProvider = AsyncNotifierProvider<RemixProjectsNotifier, List<RemixProject>>(
  RemixProjectsNotifier.new,
);
