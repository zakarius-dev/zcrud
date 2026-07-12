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
    this.currencySymbol,
  });

  /// Clé d'un autre champ fixant la borne minimale.
  final String? minValueKey;

  /// Clé d'un autre champ fixant la borne maximale.
  final String? maxValueKey;

  /// Formatage monétaire.
  final bool isCurrency;

  /// Formatage en pourcentage.
  final bool isPercentage;

  /// DP-17 (M17) — **symbole monétaire NEUTRE** (donnée, pas un style — FR-26)
  /// affiché en suffixe/préfixe quand [isCurrency] est `true`. `null` (défaut) ⇒
  /// repli sur le libellé l10n `currencySuffix` (générique) : le symbole exact
  /// (€/$/FCFA…) est **fourni par l'app** (jamais codé en dur dans le cœur —
  /// AD-1/FR-26). Sans effet si [isCurrency] est `false`.
  final String? currencySymbol;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZNumberConfig &&
          runtimeType == other.runtimeType &&
          minValueKey == other.minValueKey &&
          maxValueKey == other.maxValueKey &&
          isCurrency == other.isCurrency &&
          isPercentage == other.isPercentage &&
          currencySymbol == other.currencySymbol;

  @override
  int get hashCode => Object.hash(runtimeType, minValueKey, maxValueKey,
      isCurrency, isPercentage, currencySymbol);
}

/// DP-17 (M14) — Config additive `const` du champ **couleur** (`color`).
///
/// origine: `ColorFieldConfig`/`recentColors` DODLP (`flex_color_picker`). Le cœur
/// reste **NEUTRE** (couleur = `int` ARGB 32 bits — donnée, jamais un style
/// FR-26) et n'impose **aucune** dépendance de picker tierce lourde (AD-1) : la
/// richesse (roue HSV/hex/opacité) est fournie soit par le **picker built-in
/// neutre** (sliders pur-Flutter), soit par un **seam injecté**
/// (`ZcrudScope.colorPicker`). Rétro-compat : un `color` **sans** cette config
/// conserve exactement les 15 swatches E3-3b-1.
class ZColorConfig extends ZFieldConfig {
  /// Construit une config couleur `const`.
  const ZColorConfig({
    this.enableAlpha = false,
    this.showPalette = true,
    this.showRecent = true,
    this.recentColors = const <int>[],
  });

  /// Autorise le réglage du canal **alpha/opacité** dans le picker (défaut
  /// `false` ⇒ alpha plein, parité swatches historiques).
  final bool enableAlpha;

  /// Affiche la **palette de swatches** dérivée (défaut `true`, rétro-compat).
  final bool showPalette;

  /// Affiche la ligne des **couleurs récentes** [recentColors] (défaut `true`).
  final bool showRecent;

  /// Couleurs récentes **pré-remplies** (ARGB `int`) — pur-données `const`
  /// (parité `recentColors` DODLP). Vide (défaut) ⇒ aucune ligne récente.
  final List<int> recentColors;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColorConfig &&
          runtimeType == other.runtimeType &&
          enableAlpha == other.enableAlpha &&
          showPalette == other.showPalette &&
          showRecent == other.showRecent &&
          _listEquals(recentColors, other.recentColors);

  @override
  int get hashCode => Object.hash(runtimeType, enableAlpha, showPalette,
      showRecent, Object.hashAll(recentColors));
}

/// Config triviale pur-cœur du champ **curseur** (`slider`, E3-3b).
///
/// origine: bornes/pas d'un `Slider` DODLP. Pur-données `const` : le mapping vers
/// le widget `Slider` est E3-3b (`ZSliderFieldWidget`).
///
/// **MIN-2 (slider défauts, parité DODLP)** : la plage par défaut est **`0..100`**
/// (alignée sur DODLP), et non plus `0..1`. C'est un **changement de défaut borné
/// et entièrement paramétrable** — toute config qui déclare explicitement
/// `min`/`max` conserve exactement ses bornes (aucune régression pour les specs
/// authored). Seul un `slider` **sans** `ZSliderConfig` (ou avec un `ZSliderConfig`
/// aux `min`/`max` omis) voit sa plage passer de `0..1` à `0..100`. Note de
/// migration : un usage historique s'appuyant sur le défaut `0..1` implicite doit
/// désormais déclarer `ZSliderConfig(max: 1)`.
class ZSliderConfig extends ZFieldConfig {
  /// Construit une config de curseur `const`. Défauts **`0..100`** continu
  /// (parité DODLP, MIN-2) — paramétrables champ par champ.
  const ZSliderConfig({this.min = 0, this.max = 100, this.divisions});

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
    this.allowedDocumentTypes = const <String, List<String>>{},
    this.imageFallback = false,
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

  /// MIN-2 (parité DODLP `allowedDocumentTypes`) — extensions **groupées par
  /// catégorie** (`{'images': ['png','jpg'], 'docs': ['pdf','docx']}`). Pur-données
  /// `const` : permet de déclarer la granularité par **type de document** que
  /// [acceptedExtensions] (liste plate) n'exprime pas. Le picker injecté
  /// (`ZFilePicker`, seam E7) consomme [effectiveExtensions] (union de
  /// [acceptedExtensions] et de toutes les valeurs de cette map). Vide (défaut) ⇒
  /// **rétro-compat stricte** : [effectiveExtensions] == [acceptedExtensions].
  final Map<String, List<String>> allowedDocumentTypes;

  /// MIN-2 (parité DODLP « fallback image ») — quand `true`, un champ `image` dont
  /// la valeur acquise **n'est pas** une image affiche malgré tout la
  /// prévisualisation/l'icône **image** (repli visuel), au lieu de l'icône
  /// document générique. Pur-données ; consommé par `ZAppFileField._iconFor`.
  /// Défaut `false` ⇒ rendu E3-3c inchangé (icône dérivée du mime).
  final bool imageFallback;

  /// Extensions **effectives** acceptées (MIN-2) : union de [acceptedExtensions]
  /// et de toutes les extensions déclarées par catégorie dans
  /// [allowedDocumentTypes] (dédupliquées, ordre stable — plates d'abord). Sans
  /// [allowedDocumentTypes] ⇒ exactement [acceptedExtensions] (rétro-compat).
  List<String> get effectiveExtensions {
    if (allowedDocumentTypes.isEmpty) return acceptedExtensions;
    final seen = <String>{};
    final out = <String>[];
    for (final e in acceptedExtensions) {
      if (seen.add(e)) out.add(e);
    }
    for (final list in allowedDocumentTypes.values) {
      for (final e in list) {
        if (seen.add(e)) out.add(e);
      }
    }
    return List<String>.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FileFieldConfig &&
          runtimeType == other.runtimeType &&
          maxFiles == other.maxFiles &&
          maxSizeBytes == other.maxSizeBytes &&
          imageFallback == other.imageFallback &&
          _listEquals(acceptedExtensions, other.acceptedExtensions) &&
          _listEquals(acceptedMimeTypes, other.acceptedMimeTypes) &&
          _listEquals(allowedSources, other.allowedSources) &&
          _docTypesEquals(allowedDocumentTypes, other.allowedDocumentTypes);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        maxFiles,
        maxSizeBytes,
        imageFallback,
        Object.hashAll(acceptedExtensions),
        Object.hashAll(acceptedMimeTypes),
        Object.hashAll(allowedSources),
        Object.hashAllUnordered(
          allowedDocumentTypes.entries
              .map((e) => Object.hash(e.key, Object.hashAll(e.value))),
        ),
      );
}

/// Égalité **profonde** de deux maps `catégorie → extensions` (pur-Dart, MIN-2).
bool _docTypesEquals(
    Map<String, List<String>> a, Map<String, List<String>> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final entry in a.entries) {
    final other = b[entry.key];
    if (other == null || !_listEquals(entry.value, other)) return false;
  }
  return true;
}

/// Config du champ **select** (`select`/`radio`/`checkbox`, DP-15/M8+M22).
/// Pur-données `const` : elle active le **modal de recherche** ([searchable] ou
/// seuil [modalThreshold]) et déclare les **choix dynamiques cross-champ**
/// ([choicesFromKey] = lecture directe d'une tranche portant les options, parité
/// `stateChoiceItems` DODLP ; [choicesSourceKey] = source **calculée** résolue au
/// runtime dans `ZChoicesSourceRegistry`, filtrée par [filterKeys]).
///
/// **const-safe (AD-3)** : aucune closure/`Function` (non émissibles par
/// `ConstantReader`) — le calcul réel des choix vit hors du cœur (binding/app),
/// résolu par [choicesSourceKey] au runtime. La **multiplicité** single/multiple
/// s'appuie sur `ZFieldSpec.multiple` (source unique — **jamais** dupliquée ici).
///
/// Rétro-compat : un `select`/`radio`/`checkbox` **sans** cette config conserve
/// exactement le dropdown/radio/checkbox statique E3-3a sur `choices`.
class ZSelectConfig extends ZFieldConfig {
  /// Construit une config select `const`.
  const ZSelectConfig({
    this.searchable = false,
    this.modalThreshold,
    this.choicesFromKey,
    this.choicesSourceKey,
    this.filterKeys = const <String>[],
    this.radioAsModal = false,
  });

  /// Active le **modal de recherche** (filtrage client sur les libellés). `false`
  /// (défaut) ⇒ dropdown natif (sauf si [modalThreshold] atteint).
  final bool searchable;

  /// Seuil de bascule automatique en modal : si `choices.length >=
  /// modalThreshold`, le `select` passe en modal même si [searchable] est `false`.
  /// `null` (défaut) ⇒ pas de seuil.
  final int? modalThreshold;

  /// Clé d'un **autre champ** dont la tranche porte une `List<ZFieldChoice>` qui
  /// **remplace** `field.choices` (parité `stateChoiceItems` DODLP — recalcul
  /// déclaratif pur-cœur). `null` ⇒ aucune lecture cross-champ. L'abonnement à
  /// cette clé est **ciblé** (SM-1) — jamais un canal global.
  final String? choicesFromKey;

  /// Clé de résolution d'une `ZChoicesSource` **calculée** dans
  /// `ZChoicesSourceRegistry` (choix arbitraires côté binding). `null` ⇒ pas de
  /// source calculée. Priorité : [choicesSourceKey] > [choicesFromKey] >
  /// `field.choices`.
  final String? choicesSourceKey;

  /// Clés des champs formant le `filterContext` cross-champ passé à
  /// `ZChoicesSource.options(...)`. Vide ⇒ aucun filtre. L'abonnement à ces
  /// tranches est **ciblé** (SM-1).
  final List<String> filterKeys;

  /// MIN-2 (parité DODLP « radio = en réalité modal S2 ») — quand `true`, un champ
  /// `radio` est rendu comme un **déclencheur ouvrant un modal** de choix unique
  /// (au lieu des `RadioListTile` inline). Sans effet sur `select`/`checkbox`.
  /// Défaut `false` ⇒ rendu `RadioListTile` inline E3-3a inchangé (rétro-compat).
  final bool radioAsModal;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSelectConfig &&
          runtimeType == other.runtimeType &&
          searchable == other.searchable &&
          modalThreshold == other.modalThreshold &&
          choicesFromKey == other.choicesFromKey &&
          choicesSourceKey == other.choicesSourceKey &&
          radioAsModal == other.radioAsModal &&
          _listEquals(filterKeys, other.filterKeys);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        searchable,
        modalThreshold,
        choicesFromKey,
        choicesSourceKey,
        radioAsModal,
        Object.hashAll(filterKeys),
      );
}

/// Config du champ **relation** (`relation`, ex-`crudDataSelect` DODLP — gap
/// B7, DP-5). Pur-données `const` : elle porte SEULEMENT la **clé de source**
/// dynamique (résolue au runtime dans `ZRelationSourceRegistry`), les **clés de
/// champ** formant le filtre cross-champ, l'activation du modal de recherche, et
/// (DP-15/M8) la **clé de handler CRUD inline** ([crudKey], résolue dans
/// `ZRelationCrudRegistry`).
///
/// **const-safe (AD-3)** : aucune closure/`Stream`/`Function` (non émissibles
/// par `ConstantReader`) — la source réelle (repository/flux + filtre métier)
/// vit hors du cœur (binding/app), résolue par [sourceKey] au runtime. La
/// **multiplicité** single/multiple s'appuie sur `ZFieldSpec.multiple` (source
/// unique — jamais dupliquée ici).
///
/// Rétro-compat : un `ZFieldSpec(type: relation)` **sans** cette config (ou avec
/// [sourceKey] `null`) conserve exactement le dropdown statique sur `choices`.
class ZRelationConfig extends ZFieldConfig {
  /// Construit une config relation `const`.
  const ZRelationConfig({
    this.sourceKey,
    this.filterKeys = const <String>[],
    this.searchable = false,
    this.crudKey,
  });

  /// Clé de résolution de la source dynamique dans `ZRelationSourceRegistry`
  /// (`null` ⇒ pas de source dynamique ⇒ repli statique sur `choices`).
  final String? sourceKey;

  /// Clés des champs formant le `filterContext` cross-champ passé à
  /// `ZRelationSource.options(...)` (équivalent `ressourceFilter`). Vide ⇒
  /// aucun filtre cross-champ (source non filtrée). L'abonnement à ces tranches
  /// est **ciblé** (SM-1) — jamais un canal global.
  final List<String> filterKeys;

  /// Active le modal de recherche (filtrage **client** sur les libellés). `false`
  /// ⇒ sélection légère (dropdown en mono).
  final bool searchable;

  /// Clé de résolution d'un `ZRelationCrudHandler` **CRUD inline** dans
  /// `ZRelationCrudRegistry` (DP-15/M8, parité `showCrudButton` DODLP). `null`
  /// (défaut) OU registre/handler absent ⇒ **aucun** bouton CRUD (rétro-compat
  /// DP-5 stricte).
  final String? crudKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZRelationConfig &&
          runtimeType == other.runtimeType &&
          sourceKey == other.sourceKey &&
          searchable == other.searchable &&
          crudKey == other.crudKey &&
          _listEquals(filterKeys, other.filterKeys);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        sourceKey,
        searchable,
        crudKey,
        Object.hashAll(filterKeys),
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

/// Mode d'édition d'un champ **date/heure** (parité du sous-type DODLP
/// `InputType.date`/`time`/`both`, orthogonal à `EditionFieldType`) — valeurs
/// **camelCase** (canonique §5). Neutre, pur-Dart, **non persisté** (porté par
/// la config `const`, jamais sérialisé) : la discipline `@JsonKey(unknownEnumValue:)`
/// ne s'applique pas ici (DP-10, D2).
enum ZDateMode {
  /// Date seule (picker de date ; valeur à minuit).
  date,

  /// Date **et** heure combinées (picker date puis heure — fix B13).
  dateTime,

  /// Heure seule (picker d'heure ; valeur `HH:mm`).
  time,
}

/// Config triviale pur-cœur des champs **date/heure** (`dateTime`/`time`).
///
/// origine: `firstDateKey`/`lastDateKey` **+ `minDate`/`maxDate`** DODLP
/// (`models.dart:643-647`). Les bornes s'expriment soit comme **clés d'autres
/// champs** ([firstDateKey]/[lastDateKey], résolution cross-champ), soit comme
/// **littéraux ISO-8601** ([minDateIso]/[maxDateIso]).
///
/// **const-safe (D1)** : les bornes littérales sont des `String?` ISO-8601 (et
/// **non** des `DateTime`, qui n'ont pas de constructeur `const`) ⇒ la config
/// reste `const` et pur-données dans une annotation `@ZcrudField.config`. Le
/// parsing est **défensif** au runtime (AD-10 : ISO invalide ⇒ borne ignorée).
class ZDateConfig extends ZFieldConfig {
  /// Construit une config date `const`.
  const ZDateConfig({
    this.firstDateKey,
    this.lastDateKey,
    this.minDateIso,
    this.maxDateIso,
    this.mode,
  });

  /// Clé d'un autre champ fixant la date minimale sélectionnable (cross-champ).
  final String? firstDateKey;

  /// Clé d'un autre champ fixant la date maximale sélectionnable (cross-champ).
  final String? lastDateKey;

  /// Borne minimale **littérale** ISO-8601 (prime sur [firstDateKey], D4).
  final String? minDateIso;

  /// Borne maximale **littérale** ISO-8601 (prime sur [lastDateKey], D4).
  final String? maxDateIso;

  /// Mode d'édition explicite (`date`/`dateTime`/`time`). `null` ⇒ dérivé du
  /// type du champ (`time` → time ; sinon → `dateTime` combiné).
  final ZDateMode? mode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDateConfig &&
          runtimeType == other.runtimeType &&
          firstDateKey == other.firstDateKey &&
          lastDateKey == other.lastDateKey &&
          minDateIso == other.minDateIso &&
          maxDateIso == other.maxDateIso &&
          mode == other.mode;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        firstDateKey,
        lastDateKey,
        minDateIso,
        maxDateIso,
        mode,
      );
}
