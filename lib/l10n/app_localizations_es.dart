// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Neural Idle';

  @override
  String get tokens => 'Tokens';

  @override
  String get tokensPerSecond => 'Tokens / seg';

  @override
  String get accuracy => 'Precisión';

  @override
  String get loss => 'Pérdida';

  @override
  String get architecture => 'Arquitectura';

  @override
  String stageLabel(int stage, int total) {
    return 'Etapa $stage / $total';
  }

  @override
  String get nextArchitecture => 'Próxima arquitectura';

  @override
  String get train => 'Entrenar modelo';

  @override
  String get buy => 'Comprar';

  @override
  String get owned => 'Comprados';

  @override
  String get locked => 'Bloqueado';

  @override
  String get purchased => 'Comprada';

  @override
  String get hardware => 'Hardware';

  @override
  String get research => 'Investigación';

  @override
  String get stats => 'Estadísticas';

  @override
  String get settings => 'Ajustes';

  @override
  String get language => 'Idioma';

  @override
  String get systemLanguage => 'Usar idioma del dispositivo';

  @override
  String get offlineTitle => 'Bienvenido de nuevo';

  @override
  String offlineBody(String duration, String tokens) {
    return 'Mientras no estabas, tu IA entrenó durante $duration y ganó $tokens tokens.';
  }

  @override
  String get collect => 'Recoger tokens';

  @override
  String get trainingLab => 'LABORATORIO DE IA';

  @override
  String get modelStatus => 'Estado del modelo';

  @override
  String get modelVoice => 'SALIDA DEL MODELO';

  @override
  String get resourceOverview => 'Recursos';

  @override
  String get trainingHint => 'Cada token acerca tu modelo a su objetivo.';

  @override
  String get debugOffline => 'Ver progreso sin conexión';

  @override
  String get close => 'Cerrar';

  @override
  String progressLabel(String progress) {
    return '$progress% hacia la próxima arquitectura';
  }
}
