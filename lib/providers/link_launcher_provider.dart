import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/link_launcher.dart';

final linkLauncherProvider = Provider<LinkLauncher>((ref) => const LinkLauncher());
