/// Player-facing text in every supported language.
///
/// Game content (hardware, research, architectures, AI lines) lives in this
/// package together with its translations, so adding an item never requires
/// touching the app's ARB files.
class LocalizedText {
  const LocalizedText({required this.en, required this.es});

  final String en;
  final String es;

  /// Returns the text for [languageCode], falling back to English.
  String resolve(String languageCode) => switch (languageCode) {
        'es' => es,
        _ => en,
      };

  @override
  bool operator ==(Object other) =>
      other is LocalizedText && other.en == en && other.es == es;

  @override
  int get hashCode => Object.hash(en, es);

  @override
  String toString() => en;
}
