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

  @override
  String ratePerSecond(String value) {
    return '+$value/s';
  }

  @override
  String buyQuantity(String count) {
    return 'Comprar ×$count';
  }

  @override
  String get buyMax => 'Comprar máximo';

  @override
  String get evolvedTitle => 'Nueva arquitectura desbloqueada';

  @override
  String offlineEvolved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tu modelo evolucionó $count veces mientras no estabas',
      one: 'Tu modelo evolucionó una vez mientras no estabas',
      zero: 'Tu modelo no evolucionó mientras no estabas',
    );
    return '$_temp0';
  }

  @override
  String get statsLifetimeTokens => 'Tokens acumulados';

  @override
  String get statsPlayTime => 'Tiempo de juego';

  @override
  String get statsManualTrainings => 'Entrenamientos manuales';

  @override
  String get statsPapers => 'Papers publicados';

  @override
  String get statsCitations => 'Citas';

  @override
  String get statsCitationBonus => 'Bonus por citas';

  @override
  String get publishPaper => 'Publicar paper';

  @override
  String get publishPaperBody =>
      'Publicar un paper reinicia tu progreso de entrenamiento. Conservás las citas, que dan un bonus permanente a todos tus entrenamientos futuros.';

  @override
  String get publishConfirm => 'Publicar y reiniciar';

  @override
  String get cancel => 'Cancelar';

  @override
  String citationsGain(String count) {
    return '+$count citas';
  }

  @override
  String get publishLocked =>
      'Llegá a Transformer para publicar tu primer paper';

  @override
  String get resetProgress => 'Reiniciar progreso';

  @override
  String get resetProgressConfirm =>
      '¿Borrar todo el progreso de entrenamiento, los papers y las citas? Esta acción no se puede deshacer.';

  @override
  String get exportSave => 'Exportar partida';

  @override
  String get importSave => 'Importar partida';

  @override
  String get importInvalid =>
      'No se pudo importar esta partida. Revisá el texto e intentá de nuevo.';

  @override
  String get copy => 'Copiar';

  @override
  String get copied => 'Copiado';

  @override
  String get about => 'Acerca de';

  @override
  String get sourceCode => 'Código fuente';

  @override
  String get builtWithFlutter => 'Hecho con Flutter';

  @override
  String networkSemanticLabel(String architecture) {
    return 'Red neuronal: $architecture';
  }

  @override
  String get trainSemanticHint => 'Entrenar el modelo una vez';

  @override
  String get buyAmount => 'Cantidad a comprar';

  @override
  String researchAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mejoras disponibles para comprar',
      one: '1 mejora disponible para comprar',
    );
    return '$_temp0';
  }

  @override
  String get currentCitations => 'Citas actuales';

  @override
  String get bonusAfter => 'Bonus después de publicar';

  @override
  String get saveData => 'Datos de la partida';

  @override
  String get importSaveHint => 'Pegá una partida exportada';

  @override
  String get importSaveBody =>
      'Importar reemplaza el progreso de tu partida actual.';

  @override
  String get exportFailed =>
      'No se pudo exportar la partida. Intentá de nuevo.';

  @override
  String get copyFailed =>
      'No se pudo copiar. Seleccioná el texto para copiarlo manualmente.';

  @override
  String versionLabel(String version) {
    return 'Versión $version';
  }

  @override
  String get widgetPreview => 'Vista previa de widgets';

  @override
  String get previewTitle => 'Vista previa de componentes';

  @override
  String get previewDescription =>
      'Datos de ejemplo. Estos controles no cambian tu partida.';

  @override
  String get previewEvolution => 'Ver evolución';

  @override
  String get hintTrain => 'Tocá Entrenar modelo para ganar tus primeros tokens';

  @override
  String hintBuyHardware(String name) {
    return 'El hardware entrena por vos: comprá $name';
  }

  @override
  String hintEvolve(String tokens, String architecture) {
    return 'Ganá $tokens tokens en esta partida y tu red evoluciona a $architecture';
  }

  @override
  String get hintResearch =>
      'La investigación multiplica todo. Mirá la pestaña Investigación';

  @override
  String publishLockedNext(String architecture) {
    return 'Volvé a llegar a $architecture para publicar tu próximo paper';
  }

  @override
  String get buyMaxShort => 'MÁX';
}
