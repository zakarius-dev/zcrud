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

/// Config triviale pur-cœur du champ **curseur** (`slider`, E3-3b).
///
/// origine: bornes/pas d'un `Slider` DODLP. Pur-données `const` : le mapping vers
/// le widget `Slider` est E3-3b (`ZSliderFieldWidget`). Défauts sûrs (`0..1`,
/// pas continu) si la config est absente.
class ZSliderConfig extends ZFieldConfig {
  /// Construit une config de curseur `const`.
  const ZSliderConfig({this.min = 0, this.max = 1, this.divisions});

  /// Borne minimale du curseur.
  final double min;

  /// Borne maximale du curseur.
  final double max;

  /// Nombre de crans discrets (`null` = continu).
  final int? divisions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSliderConfig &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max &&
          divisions == other.divisions;

  @override
  int get hashCode => Object.hash(runtimeType, min, max, divisions);
}

/// Config triviale pur-cœur du champ **note** (`rating`, E3-3b).
///
/// origine: nombre d'étoiles/segments d'un contrôle de notation. Pur-données
/// `const` ; le rendu (étoiles) est E3-3b (`ZRatingFieldWidget`). Défaut `5`.
class ZRatingConfig extends ZFieldConfig {
  /// Construit une config de note `const`.
  const ZRatingConfig({this.max = 5});

  /// Note maximale (nombre de segments/étoiles).
  final int max;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRatingConfig &&
          runtimeType == other.runtimeType &&
          max == other.max;

  @override
  int get hashCode => Object.hash(runtimeType, max);
}

/// Source d'acquisition d'un fichier (E3-3c) — valeurs **camelCase** (canonique
/// §5). L'impl concrète (scan/caméra/galerie/sélecteur) vit dans le picker
/// injecté (`ZFilePicker`, E7) ; le cœur ne fait qu'énumérer les sources
/// **autorisées** par la config.
enum ZFileSource {
  /// Numérisation de document (caméra + recadrage) — impl E7.
  scan,

  /// Capture caméra directe — impl E7.
  camera,

  /// Sélection depuis la galerie/photothèque — impl E7.
  gallery,

  /// Sélecteur de fichier générique (documents) — impl E7.
  filePicker,
}

/// Toutes les sources d'acquisition (défaut sûr si `config == null`).
const List<ZFileSource> _allFileSources = <ZFileSource>[
  ZFileSource.scan,
  ZFileSource.camera,
  ZFileSource.gallery,
  ZFileSource.filePicker,
];

/// Config du champ **fichier/image/document** (`file`/`image`/`document`,
/// E3-3c). Pur-données `const` (parité `FileFieldConfig` DODLP) : le rendu
/// (boutons/préviz) est E3-3c (`ZAppFileField`) ; l'acquisition/stockage sont
/// des **seams injectés** (`ZFilePicker`/`CloudStorageRepository`) — jamais des
/// dépendances lourdes du cœur (AD-1).
///
/// La **multiplicité** single/multiple s'appuie sur `ZFieldSpec.multiple`
/// (source unique) ; [maxFiles] en fixe seulement la **borne**.
class FileFieldConfig extends ZFieldConfig {
  /// Construit une config fichier `const`. [allowedSources] par défaut = toutes
  /// les sources ([ZFileSource.values]) — défaut sûr, aucun crash si absente.
  const FileFieldConfig({
    this.acceptedExtensions = const <String>[],
    this.acceptedMimeTypes = const <String>[],
    this.maxFiles,
    this.maxSizeBytes,
    this.allowedSources = _allFileSources,
  });

  /// Extensions acceptées (`['pdf', 'png']`) — vide = aucune contrainte.
  final List<String> acceptedExtensions;

  /// Types MIME acceptés (`['image/png']`) — vide = aucune contrainte.
  final List<String> acceptedMimeTypes;

  /// Nombre maximal de fichiers en mode multiple (`null` = illimité).
  final int? maxFiles;

  /// Taille maximale par fichier en octets (`null` = aucune borne).
  final int? maxSizeBytes;

  /// Sources d'acquisition autorisées (défaut : toutes).
  final List<ZFileSource> allowedSources;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileFieldConfig &&
          runtimeType == other.runtimeType &&
          maxFiles == other.maxFiles &&
          maxSizeBytes == other.maxSizeBytes &&
          _listEquals(acceptedExtensions, other.acceptedExtensions) &&
          _listEquals(acceptedMimeTypes, other.acceptedMimeTypes) &&
          _listEquals(allowedSources, other.allowedSources);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        maxFiles,
        maxSizeBytes,
        Object.hashAll(acceptedExtensions),
        Object.hashAll(acceptedMimeTypes),
        Object.hashAll(allowedSources),
      );
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// AD-1 out-degree 0).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
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
