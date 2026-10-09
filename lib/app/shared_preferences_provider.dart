import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Initialized once in main and shared with the future game persistence layer.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw StateError(
    'SharedPreferences must be initialized before starting the app.',
  );
});
