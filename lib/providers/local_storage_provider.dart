import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/local_storage.dart';

final localStorageProvider = Provider<LocalStorage>((ref) => LocalStorage(SharedPreferencesAsync()));
