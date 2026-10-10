/// Version shown in Settings → About. Release builds can pass the real one
/// with `--dart-define=APP_VERSION=x.y.z`; it defaults to pubspec's version.
const appVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
