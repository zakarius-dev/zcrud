/// Configuration spécialisée par type de champ, portée par
/// `@ZcrudField.config` (authoring) et projetée dans `ZFieldSpec.config`
/// (runtime, E2-5).
///
/// origine: `*FieldConfig` DODLP (technical-inventory §3, colonne « Config
/// specialisee »). E2-4 livre la **base d'extension abstraite** (AD-4) + les
/// configs **triviales pur-cœur** (texte/nombre/date). Les configs **lourdes**
/// (`GeoFieldConfig` → zcrud_geo/E11a, `FileFieldConfig` → E-fichier,
/// `RichTextToolbarConfig` → E6, `StepperConfig` → E3) sont **additives** et
/// appartiennent à leurs packages/stories — jamais tirées dans le cœur.
///
/// **Point d'extension AD-4** : base `abstract` (jamais `sealed` — extension
/// inter-package) ; toute config concrète est `const` et pur-données.
library;

/// Base abstraite `const` d'une configuration de champ (point d'extension
/// AD-4). Les apps/satellites déclarent leurs sous-classes concrètes sans
/// forker le cœur.
abstract class ZFieldConfig {
  /// Constructeur `const` (sous-classes immuables).
  const ZFieldConfig();
}

/// Config triviale pur-cœur des champs **texte** (`text`/`multiline`).
///
/// origine: colonne `inputType` + `minLines`/`maxLines` DODLP.
class ZTextConfig extends ZFieldConfig {
  /// Construit une config texte `const`.
  const ZTextConfig({this.minLines, this.maxLines, this.keyboardType});

  /// Nombre minimal de lignes affichées.
  final int? minLines;

  /// Nombre maximal de lignes affichées.
  final int? maxLines;

  /// Indice de clavier neutre (opaque : le mapping vers `TextInputType` est E3).
  final String? keyboardType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTextConfig &&
          runtimeType == other.runtimeType &&
          minLines == other.minLines &&
          maxLines == other.maxLines &&
          keyboardType == other.keyboardType;

  @override
  int get hashCode => Object.hash(runtimeType, minLines, maxLines, keyboardType);
}

/// Config triviale pur-cœur des champs **numériques**
/// (`number`/`integer`/`float`).
///
/// origine: `minValueKey`/`maxValueKey` + `isCurrency`/`isPercentage` DODLP.
class ZNumberConfig extends ZFieldConfig {
  /// Construit une config numérique `const`.
  const ZNumberConfig({
    this.minValueKey,
    this.maxValueKey,
    this.isCurrency = false,
    this.isPercentage = false,
  });

  /// Clé d'un autre champ fixant la borne minimale.
  final String? minValueKey;

  /// Clé d'un autre champ fixant la borne maximale.
  final String? maxValueKey;

  /// Formatage monétaire.
  final bool isCurrency;

  /// Formatage en pourcentage.
  final bool isPercentage;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNumberConfig &&
          runtimeType == other.runtimeType &&
          minValueKey == other.minValueKey &&
          maxValueKey == other.maxValueKey &&
          isCurrency == other.isCurrency &&
          isPercentage == other.isPercentage;

  @override
  int get hashCode =>
      Object.hash(runtimeType, minValueKey, maxValueKey, isCurrency, isPercentage);
}

/// Config triviale pur-cœur des champs **date/heure** (`dateTime`/`time`).
///
/// origine: `firstDateKey`/`lastDateKey` DODLP. Les bornes sont exprimées comme
/// **clés d'autres champs** (neutres) ; aucune valeur `DateTime` littérale ne
/// vit dans l'annotation `const`.
class ZDateConfig extends ZFieldConfig {
  /// Construit une config date `const`.
  const ZDateConfig({this.firstDateKey, this.lastDateKey});

  /// Clé d'un autre champ fixant la date minimale sélectionnable.
  final String? firstDateKey;

  /// Clé d'un autre champ fixant la date maximale sélectionnable.
  final String? lastDateKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDateConfig &&
          runtimeType == other.runtimeType &&
          firstDateKey == other.firstDateKey &&
          lastDateKey == other.lastDateKey;

  @override
  int get hashCode => Object.hash(runtimeType, firstDateKey, lastDateKey);
}
