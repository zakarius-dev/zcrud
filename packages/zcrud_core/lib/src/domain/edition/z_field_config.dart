/// Configuration spécialisée par type de champ, portée par
/// `@ZcrudField.config` (authoring) et projetée dans `ZFieldSpec.config`
/// (runtime).
///
/// Le cœur livre la **base d'extension abstraite** (invariant AD-4) + les
/// configs **triviales pur-cœur** (texte/nombre/date). Les configs **lourdes**
/// (géographie → `zcrud_geo`, fichier → ce fichier même, texte riche →
/// `zcrud_markdown`, assistant multi-étapes → moteur d'édition) sont
/// **additives** et appartiennent à leurs paquets respectifs — jamais tirées
/// dans le cœur.
///
/// **Point d'extension (invariant AD-4)** : base `abstract` (jamais `sealed`
/// — extension inter-package) ; toute config concrète est `const` et
/// pur-données.
library;

/// Base abstraite `const` d'une configuration de champ (point d'extension,
/// invariant AD-4). Les apps/satellites déclarent leurs sous-classes
/// concrètes sans forker le cœur.
abstract class ZFieldConfig {
  /// Constructeur `const` (sous-classes immuables).
  const ZFieldConfig();
}

/// Capitalisation **déclarative** d'un champ texte — pur-données, aucun type
/// Flutter (le mapping vers `TextCapitalization` + un `TextInputFormatter`
/// déterministe vit en présentation, invariants AD-2/AD-15).
///
/// **Déterministe, pas seulement indicatif.** `TextCapitalization` de Flutter
/// n'est qu'un **indice de clavier logiciel** : il ne s'applique ni au collage,
/// ni à la saisie programmatique, ni aux claviers physiques. Cette énumération
/// pilote EN PLUS un formateur qui garantit la casse à chaque frappe, quelle
/// que soit la source ([sentences] sur une saisie mono-phrase reproduit un
/// « majuscule en début de phrase » déterministe).
enum ZTextCapitalization {
  /// Aucune transformation (défaut — rétro-compatible, rendu antérieur inchangé).
  none,

  /// Première lettre de chaque phrase en majuscule (début de champ + après
  /// `.`/`!`/`?`).
  sentences,

  /// Première lettre de chaque mot en majuscule.
  words,

  /// Toutes les lettres en majuscule.
  characters,

  /// Toutes les lettres en minuscule.
  ///
  /// Comme les autres modes, la garantie est portée par le **formateur
  /// déterministe** (collage, saisie programmatique et clavier physique
  /// compris) ; `TextCapitalization` de Flutter n'ayant pas d'équivalent,
  /// l'indice de clavier logiciel reste `none`.
  lowercase,
}

/// Config triviale pur-cœur des champs **texte** (`text`/`multiline`).
class ZTextConfig extends ZFieldConfig {
  /// Construit une config texte `const`.
  const ZTextConfig({
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.capitalization = ZTextCapitalization.none,
    this.textTransform,
  });

  /// Nombre minimal de lignes affichées.
  final int? minLines;

  /// Nombre maximal de lignes affichées.
  final int? maxLines;

  /// Indice de clavier **neutre** (`String`, jamais un `TextInputType` — le
  /// mapping vit dans le moteur d'édition).
  ///
  /// ## Table de correspondance (FERMÉE)
  ///
  /// | valeur | clavier |
  /// |---|---|
  /// | `'text'` | alphabétique standard |
  /// | `'multiline'` | multi-ligne (touche retour) |
  /// | `'email'` | e-mail (`@`, `.`) |
  /// | `'url'` | URL (`/`, `.`) |
  /// | `'phone'` | téléphone |
  /// | `'number'` | numérique signé |
  /// | `'decimal'` | numérique signé + séparateur décimal |
  /// | `'name'` | nom de personne |
  /// | `'address'` | adresse postale |
  /// | `'datetime'` | date/heure |
  /// | `'none'` | aucun clavier logiciel |
  ///
  /// ## Contrat de repli et de précédence
  ///
  /// * `null` ou **chaîne hors table** ⇒ le clavier est dérivé du rendu
  ///   (multi-ligne ⇒ multi-ligne, sinon texte) — jamais une exception.
  /// * **Un champ rendu multi-ligne garde le clavier multi-ligne**, même si
  ///   une autre valeur est déclarée ici : la touche retour est nécessaire à
  ///   la saisie, la déclaration ne s'applique qu'aux champs mono-ligne.
  final String? keyboardType;

  /// Capitalisation appliquée à la saisie. Défaut [ZTextCapitalization.none]
  /// (aucun formateur — le champ texte conserve son rendu par défaut).
  final ZTextCapitalization capitalization;

  /// Transformation de saisie **injectable par l'hôte**.
  ///
  /// ## Pourquoi une fonction, et non un mode de plus dans [ZTextCapitalization]
  ///
  /// Un mode figé (« première lettre seule », « code pays en majuscules »,
  /// « référence normalisée »…) ne couvrirait jamais qu'un besoin à la fois.
  /// Une transformation injectable couvre tout le reste — **y compris les
  /// besoins qu'aucune app n'a encore exprimés** — et la règle vit là où elle
  /// appartient : dans l'application qui la possède.
  ///
  /// ## Pourquoi `String Function(String)` et non des `inputFormatters`
  ///
  /// `TextInputFormatter` est un type **Flutter**, et cette configuration est du
  /// **domaine pur** : c'est la raison pour laquelle [keyboardType] est une
  /// `String` opaque et non un `TextInputType`. Une fonction pure porte la même
  /// capacité sans faire fuiter Flutter dans le domaine (invariant AD-15) ;
  /// la présentation l'enveloppe dans un `TextInputFormatter`.
  ///
  /// ## Contrat
  ///
  /// **PURE et TOTALE** : même entrée ⇒ même sortie, jamais d'exception, aucun
  /// effet de bord. Appliquée **APRÈS** [capitalization] si les deux sont
  /// fournies — l'hôte a le dernier mot.
  ///
  /// **S'applique à la SAISIE, pas à la valeur soumise.** Une valeur
  /// préremplie et jamais touchée ressort **inchangée** — c'est le comportement
  /// d'un `TextInputFormatter`, et il est délibéré : transformer en sortie
  /// modifierait des données que l'utilisateur n'a pas éditées.
  ///
  /// Une transformation qui **change la longueur** du texte déplace
  /// nécessairement le curseur ; il est alors ramené dans les bornes. Une
  /// transformation qui préserve la longueur (casse) préserve la position exacte.
  ///
  /// ```dart
  /// // « première lettre seule », exprimé par l'hôte :
  /// ZTextConfig(
  ///   textTransform: (s) =>
  ///       s.isEmpty ? s : s[0].toUpperCase() + s.substring(1),
  /// )
  /// ```
  final String Function(String value)? textTransform;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZTextConfig &&
          runtimeType == other.runtimeType &&
          minLines == other.minLines &&
          maxLines == other.maxLines &&
          keyboardType == other.keyboardType &&
          capitalization == other.capitalization &&
          textTransform == other.textTransform;

  @override
  int get hashCode =>
      Object.hash(runtimeType, minLines, maxLines, keyboardType, capitalization,
          textTransform);
}

/// Config triviale pur-cœur des champs **numériques**
/// (`number`/`integer`/`float`).
class ZNumberConfig extends ZFieldConfig {
  /// Construit une config numérique `const`.
  const ZNumberConfig({
    this.minValueKey,
    this.maxValueKey,
    this.isCurrency = false,
    this.isPercentage = false,
    this.currencySymbol,
  });

  /// Clé d'un autre champ fixant la **borne minimale** dynamique.
  ///
  /// Même mécanique cross-champ que `ZDateConfig.firstDateKey` : la borne est
  /// lue dans la tranche du champ référencé **à la validation**, et le champ
  /// borné est re-validé quand le champ référencé change (abonnement ciblé,
  /// jamais un rebuild du formulaire). Une référence absente ou non numérique
  /// est **non bloquante** — jamais une exception.
  final String? minValueKey;

  /// Clé d'un autre champ fixant la **borne maximale** dynamique (même
  /// contrat que [minValueKey]).
  final String? maxValueKey;

  /// Formatage monétaire.
  final bool isCurrency;

  /// Formatage en pourcentage.
  final bool isPercentage;

  /// **Symbole monétaire NEUTRE** (donnée, pas un style) affiché en
  /// suffixe/préfixe quand [isCurrency] est `true`. `null` (défaut) ⇒ repli
  /// sur le libellé l10n `currencySuffix` (générique) : le symbole exact
  /// (€/$/FCFA…) est **fourni par l'app** (jamais codé en dur dans le cœur —
  /// invariant AD-1). Sans effet si [isCurrency] est `false`.
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

/// Config additive `const` du champ **couleur** (`color`).
///
/// Le cœur reste **NEUTRE** (couleur = `int` ARGB 32 bits — donnée, jamais un
/// style) et n'impose **aucune** dépendance de picker tierce lourde (invariant
/// AD-1) : la richesse (roue HSV/hex/opacité) est fournie soit par le
/// **picker built-in neutre** (sliders pur-Flutter), soit par un **seam
/// injecté** (`ZcrudScope.colorPicker`). Rétro-compat : un `color` **sans**
/// cette config conserve exactement les swatches par défaut.
///
/// **Variante `multiple` native (additive)** : le drapeau [multiple] (défaut
/// **`false`** ⇒ rétro-compat stricte : un `color` sans config, ou avec
/// `ZColorConfig()`, reste **mono** — valeur `int` ARGB, `ZColorFieldWidget`
/// intact) commute le champ en **multi-sélection** (valeur `List<int>` ARGB,
/// `ZColorMultiFieldWidget`). Le constructeur nommé `const
/// ZColorConfig.multiple({…})` pose `multiple = true` sans retirer ni
/// renommer aucun champ existant.
class ZColorConfig extends ZFieldConfig {
  /// Construit une config couleur `const` **mono** (défaut historique :
  /// `multiple = false` ⇒ valeur `int` ARGB, rétro-compat stricte).
  const ZColorConfig({
    this.enableAlpha = false,
    this.showPalette = true,
    this.showRecent = true,
    this.recentColors = const <int>[],
  }) : multiple = false;

  /// Construit une config couleur `const` **multiple**
  /// (`multiple = true` ⇒ valeur `List<int>` ARGB, `ZColorMultiFieldWidget`).
  /// Additif : aucun champ retiré/renommé par rapport au constructeur par défaut.
  const ZColorConfig.multiple({
    this.enableAlpha = false,
    this.showPalette = true,
    this.showRecent = true,
    this.recentColors = const <int>[],
  }) : multiple = true;

  /// Autorise le réglage du canal **alpha/opacité** dans le picker (défaut
  /// `false` ⇒ alpha plein, parité swatches historiques).
  final bool enableAlpha;

  /// Affiche la **palette de swatches** dérivée (défaut `true`, rétro-compat).
  final bool showPalette;

  /// Affiche la ligne des **couleurs récentes** [recentColors] (défaut `true`).
  final bool showRecent;

  /// Couleurs récentes **pré-remplies** (ARGB `int`) — pur-données `const`.
  /// Vide (défaut) ⇒ aucune ligne récente.
  final List<int> recentColors;

  /// Mode **multi-sélection** : `false` (défaut) ⇒ champ mono (`int` ARGB) ;
  /// `true` (via `ZColorConfig.multiple`) ⇒ champ multiple (`List<int>`
  /// ARGB). Rétro-compat : le défaut `false` préserve le comportement mono par
  /// défaut.
  final bool multiple;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZColorConfig &&
          runtimeType == other.runtimeType &&
          enableAlpha == other.enableAlpha &&
          showPalette == other.showPalette &&
          showRecent == other.showRecent &&
          multiple == other.multiple &&
          _listEquals(recentColors, other.recentColors);

  @override
  int get hashCode => Object.hash(runtimeType, enableAlpha, showPalette,
      showRecent, multiple, Object.hashAll(recentColors));
}

/// Config triviale pur-cœur du champ **curseur** (`slider`). Pur-données
/// `const` : le mapping vers le widget `Slider` vit dans `ZSliderFieldWidget`.
///
/// La plage par défaut est **`0..100`**. Toute config qui déclare
/// explicitement `min`/`max` conserve exactement ses bornes ; seul un
/// `slider` **sans** `ZSliderConfig` (ou avec un `ZSliderConfig` aux
/// `min`/`max` omis) utilise `0..100`. Pour un curseur `0..1`, déclarer
/// explicitement `ZSliderConfig(max: 1)`.
class ZSliderConfig extends ZFieldConfig {
  /// Construit une config de curseur `const`. Défauts **`0..100`** continu —
  /// paramétrables champ par champ.
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

/// Config triviale pur-cœur du champ **note** (`rating`) — nombre
/// d'étoiles/segments d'un contrôle de notation. Pur-données `const` ; le
/// rendu (étoiles) vit dans `ZRatingFieldWidget`. Défaut `5`.
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

/// Config triviale pur-cœur du champ **booléen** (`boolean`). Pur-données
/// `const` : elle active le **texte d'état** rendu à côté du `Switch` et
/// permet d'en surcharger les libellés.
///
/// ## Activation EXPLICITE, défauts localisés ENSUITE
///
/// Poser des défauts Oui/Non localisés inconditionnellement ferait apparaître
/// un texte chez **tous** les hôtes — un déplacement visible pour qui n'a rien
/// demandé. L'affichage s'active donc explicitement ([showStateLabel] ou la
/// fourniture d'un libellé) ; **une fois activé**, les libellés retombent sur
/// les clés l10n `yes`/`no` (déjà traduites en/fr) si l'hôte n'en fournit pas.
///
/// ⇒ **Hôte passif** (pas de config, ou `ZBooleanConfig()`) : [showsStateLabel]
/// est `false` et `ZBooleanFieldWidget` emprunte le chemin de rendu par défaut
/// (`title: Text(label)`) — rendu et arbre sémantique inchangés.
///
/// ## Pourquoi [showStateLabel] ET les libellés activent tous deux
///
/// Sans cela, `ZBooleanConfig(trueLabel: 'Actif')` serait **silencieusement
/// ignoré** faute d'avoir aussi posé le drapeau — un piège. [showsStateLabel]
/// est le prédicat unique consommé par la présentation.
///
/// ## Le rendu « pilule »
///
/// [style] ajoute la **forme d'affichage** : [ZBooleanStyle.switchTile]
/// (défaut, rendu par défaut inchangé) ou [ZBooleanStyle.pill] (piste
/// arrondie, texte d'état **à l'intérieur**). L'activation passe donc par le
/// **même canal** que le texte d'état : la config du champ. Un hôte qui ne
/// pose pas `style` ne voit **aucun** déplacement.
///
/// [boxed] ajoute l'**encart de champ** : le conteneur décoré du thème, celui
/// des voisins `text`/`number`/`select`. Opt-in, valable pour les deux formes,
/// défaut `false` ⇒ rendu inchangé.
class ZBooleanConfig extends ZFieldConfig {
  /// Construit une config booléenne `const`. Défauts ⇒ **rétro-compat stricte**
  /// (aucun texte d'état, aucune pilule, rendu par défaut inchangé).
  const ZBooleanConfig({
    this.showStateLabel = false,
    this.trueLabel,
    this.falseLabel,
    this.style = ZBooleanStyle.switchTile,
    this.activeColorKey,
    this.inactiveColorKey,
    this.boxed = false,
  });

  /// Active le **texte d'état** à côté du switch avec les libellés localisés par
  /// défaut (clés `yes`/`no`). `false` (défaut) ⇒ aucun texte, sauf si
  /// [trueLabel]/[falseLabel] est fourni (cf. [showsStateLabel]).
  // Domaine pur : jamais lue directement par la présentation — son unique
  // consommateur est le prédicat [showsStateLabel], qui la combine aux
  // libellés fournis (cf. garde d'inertie des configs).
  final bool showStateLabel;

  /// Libellé d'état affiché quand la valeur est `true`. `null` (défaut) ⇒ repli
  /// sur la clé l10n `yes`. Fournir ce libellé **active** le texte d'état.
  final String? trueLabel;

  /// Libellé d'état affiché quand la valeur est `false`. `null` (défaut) ⇒ repli
  /// sur la clé l10n `no`. Fournir ce libellé **active** le texte d'état.
  final String? falseLabel;

  /// **Forme d'affichage** du booléen. Défaut [ZBooleanStyle.switchTile] ⇒
  /// rendu **strictement inchangé**.
  final ZBooleanStyle style;

  /// Clé sémantique de couleur de la pilule à l'état `true` — résolue par le
  /// **seam** `ZcrudScope.colorKeyResolver` (`zResolveColorKey`), jamais par
  /// une couleur littérale (le cœur ne possède ni « vert succès » ni
  /// « ambre » : ce sont des rôles que l'application enregistre par son
  /// resolver). `null` (défaut) ⇒ jeton `ZcrudTheme.booleanPillActiveColor`,
  /// puis rôle `ColorScheme.primary`.
  final String? activeColorKey;

  /// Clé sémantique de couleur de la pilule à l'état `false` (même seam).
  /// `null` (défaut) ⇒ jeton `ZcrudTheme.booleanPillInactiveColor`, puis rôle
  /// `ColorScheme.outline`.
  final String? inactiveColorKey;

  /// **Encart de champ** — enveloppe le champ booléen dans le **conteneur
  /// décoré du thème**, celui-là même que rendent `text`/`number`/`select` :
  /// `ZcrudTheme.inputDecoration` (fond `fieldFillColor`, bordure
  /// `fieldBorderColor`, rayon `inputRadius`, marge interne
  /// `inputContentPadding`). Aucun jeton nouveau, aucun cadre peint à la main :
  /// c'est **la même fabrique** que les familles décor-portantes.
  ///
  /// `false` (défaut) ⇒ **rendu strictement inchangé** : le booléen reste la
  /// ligne nue par défaut. Le drapeau est donc **opt-in**, et vaut pour les
  /// **deux** formes ([ZBooleanStyle.switchTile] et [ZBooleanStyle.pill]).
  ///
  /// Ce que ce drapeau ne fait PAS : il ne pose **aucun libellé** dans la
  /// décoration. Le libellé du champ reste le `title` du `ListTile` — y ajouter
  /// le label flottant de la décoration l'écrirait **deux fois** (visuellement
  /// et dans l'arbre sémantique). La cible tactile, l'état `switch` et le tap
  /// sur toute la ligne sont inchangés : l'encart est un pur décor.
  final bool boxed;

  /// Prédicat unique d'affichage du texte d'état : `true` si l'hôte l'a demandé
  /// explicitement ([showStateLabel]) **ou** a fourni au moins un libellé.
  ///
  /// En [ZBooleanStyle.pill], le texte d'état vit **DANS** la pilule : le rendu
  /// n'ajoute alors **pas** de second texte en fin de titre, même quand ce
  /// prédicat est vrai — sinon le texte d'état serait écrit deux fois sur la
  /// même ligne. La lecture de ce prédicat est donc bornée au style
  /// `switchTile` (cf. `ZBooleanFieldWidget`).
  bool get showsStateLabel =>
      showStateLabel || trueLabel != null || falseLabel != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZBooleanConfig &&
          runtimeType == other.runtimeType &&
          showStateLabel == other.showStateLabel &&
          trueLabel == other.trueLabel &&
          falseLabel == other.falseLabel &&
          style == other.style &&
          activeColorKey == other.activeColorKey &&
          inactiveColorKey == other.inactiveColorKey &&
          boxed == other.boxed;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        showStateLabel,
        trueLabel,
        falseLabel,
        style,
        activeColorKey,
        inactiveColorKey,
        boxed,
      );
}

/// Forme d'affichage de la famille `boolean`.
///
/// Valeurs **camelCase** — l'enum est `const`-émissible par le générateur
/// (`ConstantReader`, invariant AD-3) au même titre que le reste de
/// [ZBooleanConfig].
enum ZBooleanStyle {
  /// `SwitchListTile` Material — **le défaut** (texte d'état optionnel en fin
  /// de titre).
  switchTile,

  /// **Pilule** : piste arrondie peinte, texte d'état à l'INTÉRIEUR, libellé
  /// du champ à gauche. Peinte nativement, **sans aucune dépendance**
  /// (invariant AD-1).
  pill,
}

/// Source d'acquisition d'un fichier — valeurs **camelCase**. L'implémentation
/// concrète (scan/caméra/galerie/sélecteur) vit dans le picker injecté
/// (`ZFilePicker`) ; le cœur ne fait qu'énumérer les sources **autorisées**
/// par la config.
enum ZFileSource {
  /// Numérisation de document (caméra + recadrage).
  scan,

  /// Capture caméra directe.
  camera,

  /// Sélection depuis la galerie/photothèque.
  gallery,

  /// Sélecteur de fichier générique (documents).
  filePicker,
}

/// Toutes les sources d'acquisition (défaut sûr si `config == null`).
const List<ZFileSource> _allFileSources = <ZFileSource>[
  ZFileSource.scan,
  ZFileSource.camera,
  ZFileSource.gallery,
  ZFileSource.filePicker,
];

/// Config du champ **fichier/image/document** (`file`/`image`/`document`).
/// Pur-données `const` : le rendu (boutons/préviz) vit dans `ZAppFileField` ;
/// l'acquisition/stockage sont des **seams injectés**
/// (`ZFilePicker`/`CloudStorageRepository`) — jamais des dépendances lourdes
/// du cœur (invariant AD-1).
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
  // Domaine pur : contrat du seam `ZFilePicker` — la config est transmise
  // intégralement au picker hôte, qui applique cette contrainte (le cœur
  // n'acquiert aucun fichier lui-même). Idem pour les trois membres suivants.
  final List<String> acceptedExtensions;

  /// Types MIME acceptés (`['image/png']`) — vide = aucune contrainte.
  // Domaine pur : contrat du seam `ZFilePicker` (cf. [acceptedExtensions]).
  final List<String> acceptedMimeTypes;

  /// Nombre maximal de fichiers en mode multiple (`null` = illimité).
  final int? maxFiles;

  /// Taille maximale par fichier en octets (`null` = aucune borne).
  // Domaine pur : contrat du seam `ZFilePicker` (cf. [acceptedExtensions]).
  final int? maxSizeBytes;

  /// Sources d'acquisition autorisées (défaut : toutes).
  final List<ZFileSource> allowedSources;

  /// Extensions **groupées par catégorie**
  /// (`{'images': ['png','jpg'], 'docs': ['pdf','docx']}`). Pur-données
  /// `const` : permet de déclarer la granularité par **type de document** que
  /// [acceptedExtensions] (liste plate) n'exprime pas. Le picker injecté
  /// (`ZFilePicker`) consomme [effectiveExtensions] (union de
  /// [acceptedExtensions] et de toutes les valeurs de cette map). Vide (défaut) ⇒
  /// **rétro-compat stricte** : [effectiveExtensions] == [acceptedExtensions].
  // Domaine pur : consommée par [effectiveExtensions], dont le résultat est
  // transmis au seam `ZFilePicker` (cf. [acceptedExtensions]).
  final Map<String, List<String>> allowedDocumentTypes;

  /// Quand `true`, un champ `image` dont la valeur acquise **n'est pas** une
  /// image affiche malgré tout la prévisualisation/l'icône **image** (repli
  /// visuel), au lieu de l'icône document générique. Pur-données ; consommé
  /// par `ZAppFileField._iconFor`. Défaut `false` ⇒ icône dérivée du mime.
  final bool imageFallback;

  /// Extensions **effectives** acceptées : union de [acceptedExtensions] et de
  /// toutes les extensions déclarées par catégorie dans
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

/// Égalité **profonde** de deux maps `catégorie → extensions` (pur-Dart).
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

/// Config du champ **select** (`select`/`radio`/`checkbox`). Pur-données
/// `const` : elle active le **modal de recherche** ([searchable] ou seuil
/// [modalThreshold]) et déclare les **choix dynamiques cross-champ**
/// ([choicesFromKey] = lecture directe d'une tranche portant les options ;
/// [choicesSourceKey] = source **calculée** résolue au runtime dans
/// `ZChoicesSourceRegistry`, filtrée par [filterKeys]).
///
/// **const-safe (invariant AD-3)** : aucune closure/`Function` (non
/// émissibles par `ConstantReader`) — le calcul réel des choix vit hors du
/// cœur (binding/app), résolu par [choicesSourceKey] au runtime. La
/// **multiplicité** single/multiple s'appuie sur `ZFieldSpec.multiple` (source
/// unique — **jamais** dupliquée ici).
///
/// Rétro-compat : un `select`/`radio`/`checkbox` **sans** cette config conserve
/// exactement le dropdown/radio/checkbox statique sur `choices`.
class ZSelectConfig extends ZFieldConfig {
  /// Construit une config select `const`.
  const ZSelectConfig({
    this.searchable = false,
    this.modalThreshold,
    this.choicesFromKey,
    this.choicesSourceKey,
    this.choiceBuilderKey,
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
  /// **remplace** `field.choices` (recalcul déclaratif pur-cœur). `null` ⇒
  /// aucune lecture cross-champ. L'abonnement à cette clé est **ciblé** —
  /// jamais un canal global.
  final String? choicesFromKey;

  /// Clé de résolution d'une `ZChoicesSource` **calculée** dans
  /// `ZChoicesSourceRegistry` (choix arbitraires côté binding). `null` ⇒ pas de
  /// source calculée. Priorité : [choicesSourceKey] > [choicesFromKey] >
  /// `field.choices`.
  final String? choicesSourceKey;

  /// Clé d'un rendu riche d'option résolu à l'exécution dans
  /// `ZSelectChoiceBuilderRegistry`. `null` conserve le rendu précédent;
  /// une clé absente du registre retombe silencieusement sur ce même rendu.
  final String? choiceBuilderKey;

  /// Clés des champs formant le `filterContext` cross-champ passé à
  /// `ZChoicesSource.options(...)`. Vide ⇒ aucun filtre. L'abonnement à ces
  /// tranches est **ciblé**.
  final List<String> filterKeys;

  /// Quand `true`, un champ `radio` est rendu comme un **déclencheur ouvrant
  /// un modal** de choix unique (au lieu des `RadioListTile` inline). Sans
  /// effet sur `select`/`checkbox`. Défaut `false` ⇒ rendu `RadioListTile`
  /// inline inchangé (rétro-compat).
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
          choiceBuilderKey == other.choiceBuilderKey &&
          radioAsModal == other.radioAsModal &&
          _listEquals(filterKeys, other.filterKeys);

  @override
  int get hashCode => Object.hash(
        runtimeType,
        searchable,
        modalThreshold,
        choicesFromKey,
        choicesSourceKey,
        choiceBuilderKey,
        radioAsModal,
        Object.hashAll(filterKeys),
      );
}

/// Config du champ **relation** (`relation`). Pur-données `const` : elle
/// porte SEULEMENT la **clé de source** dynamique (résolue au runtime dans
/// `ZRelationSourceRegistry`), les **clés de champ** formant le filtre
/// cross-champ, l'activation du modal de recherche, et la **clé de handler
/// CRUD inline** ([crudKey], résolue dans `ZRelationCrudRegistry`).
///
/// **const-safe (invariant AD-3)** : aucune closure/`Stream`/`Function` (non
/// émissibles par `ConstantReader`) — la source réelle (repository/flux +
/// filtre métier) vit hors du cœur (binding/app), résolue par [sourceKey] au
/// runtime. La **multiplicité** single/multiple s'appuie sur
/// `ZFieldSpec.multiple` (source unique — jamais dupliquée ici).
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
  /// `ZRelationSource.options(...)`. Vide ⇒ aucun filtre cross-champ (source
  /// non filtrée). L'abonnement à ces tranches est **ciblé** — jamais un canal
  /// global.
  final List<String> filterKeys;

  /// Active le modal de recherche (filtrage **client** sur les libellés). `false`
  /// ⇒ sélection légère (dropdown en mono).
  final bool searchable;

  /// Clé de résolution d'un `ZRelationCrudHandler` **CRUD inline** dans
  /// `ZRelationCrudRegistry`. `null` (défaut) OU registre/handler absent ⇒
  /// **aucun** bouton CRUD (rétro-compat stricte).
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
/// invariant AD-1).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Mode d'édition d'un champ **date/heure** (orthogonal à
/// `EditionFieldType`) — valeurs **camelCase**. Neutre, pur-Dart, **non
/// persisté** (porté par la config `const`, jamais sérialisé) : la discipline
/// `@JsonKey(unknownEnumValue:)` ne s'applique donc pas ici.
enum ZDateMode {
  /// Date seule (picker de date ; valeur à minuit).
  date,

  /// Date **et** heure combinées (picker date puis heure).
  dateTime,

  /// Heure seule (picker d'heure ; valeur `HH:mm`).
  time,
}

/// Verdict d'**amplitude** d'une plage de dates confrontée à
/// [ZDateConfig.maxDays]/[ZDateConfig.minDays].
///
/// Rendu par [ZDateConfig.checkSpanDays] ; les valeurs sont en **camelCase** et
/// ne sont **jamais persistées** (verdict calculé, pas une donnée).
enum ZDateSpanVerdict {
  /// L'amplitude est admise : la plage peut être écrite dans le champ.
  accepted,

  /// La plage couvre **plus** de jours que [ZDateConfig.maxDays] ne l'autorise.
  tooLong,

  /// La plage couvre **moins** de jours que [ZDateConfig.minDays] ne l'exige.
  tooShort,
}

/// Config triviale pur-cœur des champs **date/heure** (`dateTime`/`time`) et
/// **plage de dates** (`dateRange`).
///
/// Deux familles de contraintes, à ne pas confondre :
///
/// - **où** la plage se situe — [firstDateKey]/[lastDateKey] (clés d'autres
///   champs, résolution cross-champ) ou [minDateIso]/[maxDateIso] (littéraux
///   ISO-8601) ;
/// - **quelle largeur** elle peut avoir — [maxDays]/[minDays] (amplitude, type
///   `dateRange` uniquement).
///
/// **const-safe** : les bornes littérales sont des `String?` ISO-8601 (et
/// **non** des `DateTime`, qui n'ont pas de constructeur `const`) ⇒ la config
/// reste `const` et pur-données dans une annotation `@ZcrudField.config`. Le
/// parsing est **défensif** au runtime (invariant AD-10 : ISO invalide ⇒ borne
/// ignorée).
class ZDateConfig extends ZFieldConfig {
  /// Construit une config date `const`.
  const ZDateConfig({
    this.firstDateKey,
    this.lastDateKey,
    this.minDateIso,
    this.maxDateIso,
    this.mode,
    this.maxDays,
    this.minDays,
  });

  /// Clé d'un autre champ fixant la date minimale sélectionnable (cross-champ).
  final String? firstDateKey;

  /// Clé d'un autre champ fixant la date maximale sélectionnable (cross-champ).
  final String? lastDateKey;

  /// Borne minimale **littérale** ISO-8601 (prime sur [firstDateKey]).
  final String? minDateIso;

  /// Borne maximale **littérale** ISO-8601 (prime sur [lastDateKey]).
  final String? maxDateIso;

  /// Mode d'édition explicite (`date`/`dateTime`/`time`). `null` ⇒ dérivé du
  /// type du champ (`time` → time ; sinon → `dateTime` combiné).
  final ZDateMode? mode;

  /// **Amplitude maximale** d'une plage (`dateRange`), exprimée en **nombre de
  /// jours couverts, bornes incluses**.
  ///
  /// 🔴 **Le comptage, sans ambiguïté** : `maxDays` compte les **jours**, pas
  /// les nuits ni les intervalles. `maxDays: 7` autorise « du 1er au 7 janvier
  /// » (7 jours) et **refuse** « du 1er au 8 janvier » (8 jours). Une plage
  /// commençant et finissant le même jour compte pour **1**. C'est exactement
  /// le nombre annoncé à l'utilisateur dans le message de refus : la valeur
  /// déclarée ici et le nombre affiché sont **le même**.
  ///
  /// **Moment du refus** : à la **sélection**. Quand le sélecteur de plage rend
  /// une période trop large, elle est **rejetée** — le champ conserve sa valeur
  /// précédente et un message nomme l'amplitude autorisée. Rien n'est reporté à
  /// la validation du formulaire : l'utilisateur voit le refus au moment où il
  /// choisit, sur le champ concerné.
  ///
  /// **Composition avec les autres bornes** : l'amplitude est **indépendante**
  /// de [minDateIso]/[maxDateIso]/[firstDateKey]/[lastDateKey]. Celles-ci
  /// restreignent le calendrier proposé (aucune date hors bornes n'est
  /// sélectionnable) ; l'amplitude, elle, s'applique à la période retenue
  /// **à l'intérieur** de ce calendrier. Une plage peut donc être conforme aux
  /// bornes et refusée pour sa largeur ; les deux contraintes ne se
  /// contredisent jamais — elles se cumulent.
  ///
  /// **Défensif** (invariant AD-10) : `null` (défaut) ⇒ aucune contrainte
  /// d'amplitude, comportement strictement inchangé. Une valeur `< 1` est
  /// **ignorée** (elle interdirait toute plage), jamais une exception.
  ///
  /// Sans effet sur les types `dateTime`/`time`, qui portent une date unique.
  // Domaine pur : jamais lue brute par la présentation — consommée au travers
  // de [effectiveMaxDays]/[checkSpanDays], qui portent la règle d'ignorance
  // des valeurs invalides (cf. garde d'inertie des configs).
  final int? maxDays;

  /// **Amplitude minimale** d'une plage (`dateRange`), même comptage que
  /// [maxDays] : **nombre de jours couverts, bornes incluses**.
  ///
  /// `minDays: 2` refuse une plage d'une seule journée. `null` (défaut) ⇒
  /// aucune exigence. Refus à la **sélection**, comme [maxDays].
  ///
  /// **Défensif** (invariant AD-10) : une valeur `< 1` est **ignorée** (toute
  /// plage couvre au moins un jour). Une déclaration **contradictoire**
  /// (`minDays` supérieur à [maxDays] — aucune plage ne pourrait satisfaire les
  /// deux) est résolue en faveur de la contrainte protectrice : [maxDays]
  /// s'applique, `minDays` est **ignoré**. Le champ reste utilisable ; il ne se
  /// bloque jamais sur une déclaration incohérente.
  // Domaine pur : consommée au travers de [effectiveMinDays]/[checkSpanDays]
  // (cf. [maxDays] et la garde d'inertie des configs).
  final int? minDays;

  /// [maxDays] **retenue**, ou `null` si aucune amplitude maximale ne
  /// s'applique (non déclarée, ou valeur `< 1` ignorée — cf. [maxDays]).
  ///
  /// C'est cette valeur — et non [maxDays] brute — qu'il faut afficher à
  /// l'utilisateur : elle est celle que [checkSpanDays] applique réellement.
  int? get effectiveMaxDays {
    final int? v = maxDays;
    return (v != null && v >= 1) ? v : null;
  }

  /// [minDays] **retenue**, ou `null` si aucune amplitude minimale ne
  /// s'applique — non déclarée, valeur `< 1`, ou déclaration contradictoire
  /// avec [effectiveMaxDays] (cf. [minDays]).
  int? get effectiveMinDays {
    final int? v = minDays;
    if (v == null || v < 1) return null;
    final int? max = effectiveMaxDays;
    if (max != null && v > max) return null;
    return v;
  }

  /// Confronte une amplitude ([ZDateRange.spanDays] — **jours couverts, bornes
  /// incluses**) aux contraintes déclarées.
  ///
  /// Rend [ZDateSpanVerdict.accepted] si aucune amplitude n'est déclarée, si
  /// les valeurs déclarées sont ignorées (cf. [effectiveMaxDays] /
  /// [effectiveMinDays]), ou si la plage tombe **dans** l'intervalle admis —
  /// bornes **incluses** : une plage d'exactement [maxDays] jours est acceptée,
  /// une plage d'exactement [minDays] jours aussi.
  ///
  /// Pur-Dart, sans effet de bord : le message présenté à l'utilisateur est
  /// construit par la couche présentation à partir de ce verdict.
  ZDateSpanVerdict checkSpanDays(int spanDays) {
    final int? max = effectiveMaxDays;
    if (max != null && spanDays > max) return ZDateSpanVerdict.tooLong;
    final int? min = effectiveMinDays;
    if (min != null && spanDays < min) return ZDateSpanVerdict.tooShort;
    return ZDateSpanVerdict.accepted;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZDateConfig &&
          runtimeType == other.runtimeType &&
          firstDateKey == other.firstDateKey &&
          lastDateKey == other.lastDateKey &&
          minDateIso == other.minDateIso &&
          maxDateIso == other.maxDateIso &&
          mode == other.mode &&
          maxDays == other.maxDays &&
          minDays == other.minDays;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        firstDateKey,
        lastDateKey,
        minDateIso,
        maxDateIso,
        mode,
        maxDays,
        minDays,
      );
}
