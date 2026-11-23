import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tabs of the bottom navigation, in display order.
enum ShellTab { home, create, profile }

/// Selected tab. In a provider so any screen can switch tab, e.g. Profile to Create.
class ShellTabNotifier extends Notifier<ShellTab> {
  @override
  ShellTab build() => ShellTab.home;

  void select(ShellTab tab) => state = tab;
}

final shellTabProvider = NotifierProvider<ShellTabNotifier, ShellTab>(ShellTabNotifier.new);
