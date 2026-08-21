/// `ZPhoneFieldWidget` — **champ d'édition téléphone international**
/// (`phoneNumber`), servi via `ZWidgetRegistry` (invariants AD-2, AD-4,
/// AD-13, AD-10).
///
/// **Rendu natif + valeur `String`.**
///
/// Le dispatcher du cœur route `phoneNumber` vers le `ZWidgetRegistry`
/// injecté et appelle le builder **dans** la frontière de rebuild de la
/// tranche. Le rendu (sélecteur pays drapeau/indicatif recherchable +
/// formatage « as-you-type » libphonenumber) provient d'un paquet de rendu
/// tiers, **absorbé par `zcrud_intl`** : l'hôte n'a rien à importer ni à
/// ré-implémenter. Le paquet est confiné à
/// `z_intl_phone_input_bridge.dart` (invariant AD-1) — aucun de ses types
/// n'apparaît ici.
///
/// **Contrat de valeur** : la valeur de tranche est une **`String`**.
/// Contenu exact et invariant : cf. `ZPhoneCodec.toInternationalString` —
/// **forme internationale complète** (`^\+[0-9]+$`), E.164 canonique dès
/// que le numéro est valide. `null` quand aucun chiffre n'est saisi. La
/// lecture reste **défensive** : une valeur d'un ancien schéma
/// [ZPhoneNumber] (ou sa map sérialisée) est encore **ingérée** à
/// l'amorçage (invariant AD-10, migration sans réécriture), simplement
/// ré-émise en `String`.
///
/// **Décoration thémée du cœur.** Le champ ne construit pas
/// d'`InputDecoration` nue : il passe par
/// `zFieldDecoration(context, field, bare:)`, **le helper du cœur** — donc
/// par `ZcrudTheme.inputDecoration`. Conséquences visibles pour tout hôte :
///  * cadre/fond/rayon/padding interne pilotés par les jetons **existants**
///    (`fieldFillColor`, `fieldBorderColor`, `fieldFocusedBorderColor`,
///    `inputRadius`, `inputContentPadding`) — repli `ColorScheme` inchangé ;
///  * **un seul libellé** : le libellé flottant enrichi (`ZFieldLabel`,
///    avec l'astérisque « requis ») remplace un doublon `Text` externe +
///    `labelText` interne qui annoncerait sinon le libellé du champ deux
///    fois ;
///  * le `Padding(ZcrudTheme.fieldPadding)` propre au champ **disparaît** :
///    le champ s'aligne ainsi sur la largeur de ses voisins du cœur ;
///    l'aération entre champs reste celle de `DynamicEdition`
///    (`interFieldGap`/`fieldGap`) ;
///  * mode **`bare`** (`fieldSize == large`) : bordures `none`, aucun
///    libellé propre (porté par `ZLargeFieldCard`) — **parité exacte** avec
///    le champ `text` du cœur.
///
/// **Invariant AD-2** : `TextEditingController`/`FocusNode` créés **1×**
/// (`initState`), disposés, jamais recréés ; la **graine** d'amorçage du
/// paquet est elle aussi créée 1× (sans quoi le paquet réinitialiserait le
/// texte à chaque frappe — cf. `ZPhoneInputSeed`). Sync guardée hors focus.
///
/// ## Pays d'amorçage — chaîne de priorité
///
/// **Aucune donnée fabriquée.** Le pays présélectionné n'est JAMAIS inventé
/// par `zcrud_intl`: il est **dérivé** d'une source réelle, dans cet ordre —
/// **configuration de l'hôte > information réelle du contexte > repli défini**:
///
/// | # | Source | Nature |
/// |---|---|---|
/// | 1 | pays **de la valeur déjà saisie** (`ZPhoneCodec.isoOfInternational`) | donnée de l'utilisateur |
/// | 2 | `ZIntlFieldConfig.defaultCountryIso` | configuration de l'hôte |
/// | 3 | [ZPhoneFieldWidget.defaultIsoCode] | configuration de l'hôte |
/// | 4 | pays de la **locale ambiante** (`Localizations.maybeLocaleOf(context)?.countryCode`) | information réelle du contexte |
/// | 5 | pays de la ou des **locales de l'appareil** (`PlatformDispatcher.locales`, puis `.locale`) | information réelle du contexte |
/// | 6 | **repli défini: AUCUN pays transmis** | cf. ci-dessous |
///
/// Chaque candidat est **assaini** (`ZIntlPhoneInputBridge.sanitizeIso`) contre
/// le catalogue RÉEL du paquet de rendu: un code pays inconnu (`'ZZ'`), un code
/// malformé, un code de macro-région (`es_419` → `'419'`) ou une locale sans
/// pays (`fr` seul, cas courant) **ne lève jamais** (AD-10) — il est simplement
/// ignoré et l'on passe au candidat suivant. La chaîne est parcourue **une seule
/// fois**, au premier `didChangeDependencies`: un changement de locale ULTÉRIEUR
/// ne redéplace donc **jamais** le pays d'un champ déjà monté, et ne peut donc
/// jamais réécrire une valeur déjà saisie.
///
/// **Étape 6 — la règle, écrite et assumée.** Quand aucune de ces sources
/// ne porte de pays, il ne reste **aucune source honnête** : tout indicatif
/// affiché serait une invention. `zcrud_intl` **n'en choisit donc aucun** —
/// il transmet `null` au paquet de rendu, qui applique alors *son* défaut :
/// le **premier pays de son catalogue par ordre alphabétique**
/// (Afghanistan, `+93`). C'est un **artefact de tri du tiers**, jamais un
/// choix de `zcrud_intl` : le paquet ne contient aucun code pays en dur
/// (prouvé par garde de source). Un hôte qui veut un défaut le **pose**
/// (étape 2 ou 3) ; c'est la seule façon d'obtenir un pays qui soit un
/// choix.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_country_catalog.dart';
import '../domain/z_intl_field_config.dart';
import '../domain/z_phone_number.dart';
import 'z_intl_phone_input_bridge.dart';
import 'z_national_phone_message.dart';
import 'z_phone_codec.dart';

/// Champ d'édition téléphone (patron AD-2: contrôleur stable, rebuild ciblé).
class ZPhoneFieldWidget extends StatefulWidget {
  /// Construit le champ pour [ctx]. [defaultIsoCode] (surchargeable, jamais codé
  /// en dur non surchargeable — AD-12) amorce le pays quand la valeur initiale
  /// n'en fournit pas.
  const ZPhoneFieldWidget({
    required this.ctx,
    required this.catalog,
    this.defaultIsoCode,
    this.selectorLeadingPadding,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contexte du champ (`ctx.value` = `String` internationale courante,
  /// `ctx.onChanged` = écriture de la tranche).
  final ZFieldWidgetContext ctx;

  /// Catalogue pays de `zcrud_intl`.
  ///
  /// **Plus lu pour le rendu** du téléphone — le sélecteur pays vient du
  /// paquet de rendu natif, qui embarque son propre catalogue et ses
  /// drapeaux. Le paramètre est CONSERVÉ pour ne pas casser les sites
  /// d'appel `ZPhoneFieldWidget.builder(catalog: …)` (les champs `country`
  /// et `address`, eux, continuent de s'en servir).
  final ZCountryCatalog catalog;

  /// Pays d'amorçage optionnel (code ISO alpha-2), **surchargeable** ;
  /// `null` par défaut (aucun défaut national imposé, invariant AD-12).
  ///
  /// Étape **3** de la chaîne de priorité (cf. doc de bibliothèque) : il
  /// cède le pas à la valeur déjà saisie et à
  /// `ZIntlFieldConfig.defaultCountryIso`, et prime sur la locale ambiante
  /// et sur les locales de l'appareil.
  final String? defaultIsoCode;

  /// Retrait de **tête** (dp) du contenu « drapeau + indicatif », par
  /// registre.
  ///
  /// Maillon « paramètre » de la priorité paramètre > jeton, **sous** la
  /// config par champ ([ZIntlFieldConfig.selectorLeadingPadding]) et
  /// **au-dessus** du jeton. `null` (défaut) ⇒ retrait dérivé du thème
  /// (cf. `_selectorLeadingIndent`).
  final double? selectorLeadingPadding;

  /// Hook de test: appelé UNE FOIS en `initState`.
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook de test: appelé à chaque (re)build (compteur ciblé).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Fabrique un [ZFieldWidgetBuilder] enregistrable sous le `kind`
  /// `"phoneNumber"`. Exemple:
  /// `registry.register('phoneNumber', ZPhoneFieldWidget.builder())`.
  static ZFieldWidgetBuilder builder({
    ZCountryCatalog? catalog,
    String? defaultIsoCode,
    double? selectorLeadingPadding,
    VoidCallback? onInit,
    VoidCallback? onBuild,
  }) {
    final cat = catalog ?? sharedDefaultCountryCatalog();
    return (BuildContext context, ZFieldWidgetContext ctx) => ZPhoneFieldWidget(
          ctx: ctx,
          catalog: cat,
          defaultIsoCode: defaultIsoCode,
          selectorLeadingPadding: selectorLeadingPadding,
          onInit: onInit,
          onBuild: onBuild,
        );
  }

  @override
  State<ZPhoneFieldWidget> createState() => _ZPhoneFieldWidgetState();
}

class _ZPhoneFieldWidgetState extends State<ZPhoneFieldWidget> {
  /// Contrôleur du numéro — créé 1× (`initState`), jamais recréé (AD-2).
  late final TextEditingController _numberController;

  /// Focus du numéro — oracle de la sync guardée.
  late final FocusNode _numberFocus;

  /// Graine d'amorçage du paquet — créée 1×, JAMAIS reconstruite (AD-2: la
  /// reconstruire relancerait `initialiseWidget()` du paquet à chaque frappe).
  late final ZPhoneInputSeed _seed;

  /// `true` dès que l'amorçage (pays + graine + pré-remplissage) a eu lieu.
  /// Garantit qu'il n'a lieu **qu'une fois**, malgré les rappels répétés de
  /// `didChangeDependencies` (changement de locale, de thème, de média).
  bool _bootstrapped = false;

  /// Pays courant (code ISO alpha-2), tenu par le sélecteur du paquet.
  String? _iso;

  /// Dernière valeur ÉMISE — évite les écritures redondantes de la tranche et
  /// sert d'oracle à la sync guardée.
  String? _lastEmitted;

  bool get _hasNumberFocus => _numberFocus.hasFocus;

  /// Config additive intl du champ (`null` → chemin historique inchangé).
  ZIntlFieldConfig? get _config {
    final c = widget.ctx.field.config;
    return c is ZIntlFieldConfig ? c : null;
  }

  @override
  void initState() {
    super.initState();
    _numberController = TextEditingController();
    _numberFocus = FocusNode();
    widget.onInit?.call();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // AMORÇAGE UNIQUE (AD-2). Il vit ici et non dans `initState` parce que
    // l'étape 4 de la chaîne lit la locale ambiante, ce qu'`initState` n'a pas
    // le droit de faire (`dependOnInheritedWidgetOfExactType`).
    //
    // Ce drapeau porte AUSSI l'invariant de valeur: la chaîne n'est
    // parcourue QU'UNE fois, donc un changement de locale postérieur au montage
    // ne redéplace pas le pays et ne peut PAS réécrire une valeur déjà saisie.
    if (_bootstrapped) return;
    _bootstrapped = true;

    final stored = _storedOf(widget.ctx.value);
    _iso = _resolveInitialIso(stored);
    _lastEmitted = stored;

    // Deux chemins d'amorçage, tous deux SÛRS (cf. cas 1 de AD-10 documenté au
    // pont): le numéro n'est confié au paquet QUE s'il est valide ET que le
    // pays est résolu; sinon on pré-remplit nous-mêmes la partie nationale,
    // que le paquet laisse alors intacte.
    final valid = _iso != null && ZPhoneCodec.isValidInternational(stored, iso: _iso);
    _seed = ZPhoneInputSeed.of(isoCode: _iso, e164: valid ? stored : null);
    if (!valid) {
      final national = ZPhoneCodec.nationalDigitsOf(stored, iso: _iso);
      if (national.isNotEmpty) _numberController.text = national;
    }
  }

  /// Résout le pays d'amorçage — **chaîne de priorité documentée en tête de
  /// bibliothèque**: configuration de l'hôte > information réelle du contexte >
  /// repli défini.
  ///
  /// Retourne `null` quand **aucune source honnête** ne porte de pays: c'est
  /// l'étape 6, et elle signifie « `zcrud_intl` n'en choisit aucun », pas
  /// « Afghanistan ». Ne lève jamais (AD-10).
  String? _resolveInitialIso(String? stored) {
    for (final candidate in _isoCandidates(stored)) {
      // Assainissement PAR CANDIDAT (et non sur le seul premier non nul):
      // un code inconnu/malformé n'annule pas la chaîne, il passe la main.
      final iso = ZIntlPhoneInputBridge.sanitizeIso(candidate);
      if (iso != null) return iso;
    }
    return null;
  }

  /// Candidats bruts, dans l'ordre de priorité. Aucun n'est un littéral de
  /// ce paquet : tous sont lus sur la valeur, la config ou le contexte.
  Iterable<String?> _isoCandidates(String? stored) sync* {
    yield ZPhoneCodec.isoOfInternational(stored); // 1 — donnée de l'utilisateur
    yield _config?.defaultCountryIso; // 2 — config de l'hôte
    yield widget.defaultIsoCode; // 3 — config de l'hôte
    yield Localizations.maybeLocaleOf(context)?.countryCode; // 4 — contexte réel
    yield* _platformCountryCodes(); // 5 — locales de l'appareil
  }

  /// Codes pays portés par les locales de l'APPAREIL (information réelle, pas
  /// une invention). Sert quand la locale ambiante n'a pas de pays — le cas
  /// courant d'une app qui force `Locale('fr')`.
  ///
  /// AD-10: tout échec de lecture de la plateforme rend une liste vide (on
  /// rattrape `Object`, donc AUSSI les `Error`), jamais une exception.
  static Iterable<String> _platformCountryCodes() {
    try {
      final dispatcher = WidgetsBinding.instance.platformDispatcher;
      return <String>[
        for (final locale in <Locale>[...dispatcher.locales, dispatcher.locale])
          if (locale.countryCode case final String c when c.isNotEmpty) c,
      ];
    } on Object {
      return const <String>[];
    }
  }

  @override
  void didUpdateWidget(covariant ZPhoneFieldWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // SYNC GUARDÉE (AD-2): refléter une valeur EXTERNE UNIQUEMENT hors focus.
    // Pendant la frappe, priorité absolue au curseur.
    if (_hasNumberFocus) return;
    final stored = _storedOf(widget.ctx.value);
    if (stored == _lastEmitted) return;
    _lastEmitted = stored;
    final national = ZPhoneCodec.nationalDigitsOf(stored, iso: _iso);
    if (_numberController.text != national) _numberController.text = national;
  }

  @override
  void dispose() {
    // Anti-fuite (learning E5).
    _numberController.dispose();
    _numberFocus.dispose();
    super.dispose();
  }

  /// Lecture défensive (AD-10) de la valeur de tranche. Accepte:
  ///  - la `String` internationale (contrat courant);
  ///  - un [ZPhoneNumber] legacy ou sa map sérialisée (ingestion sans
  ///    réécriture — la valeur sera ré-émise en `String` à la première frappe);
  ///  - tout autre type ⇒ `null` (jamais d'exception).
  static String? _storedOf(Object? value) {
    if (value is String) return value.trim().isEmpty ? null : value.trim();
    final legacy = value is ZPhoneNumber ? value : ZPhoneNumber.fromMapSafe(value);
    if (legacy == null) return null;
    final e164 = legacy.e164;
    if (e164 != null && e164.isNotEmpty) return e164;
    return ZPhoneCodec.toInternationalString(
      legacy.nationalNumber,
      dialCode: legacy.dialCode,
      iso: legacy.isoCode,
    );
  }

  /// Voie UNIQUE d'écriture (AD-2): canonise ce que le paquet produit et
  /// n'écrit la tranche que si la valeur a **réellement** changé.
  void _onInputChanged(ZPhoneInputChange change) {
    if (!mounted) return;
    _iso = change.isoCode ?? _iso;
    final next = ZPhoneCodec.toInternationalString(
      change.number,
      dialCode: change.dialCode,
      iso: change.isoCode ?? _iso,
    );
    if (next == _lastEmitted) return;
    _lastEmitted = next;
    widget.ctx.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    widget.onBuild?.call();
    final field = widget.ctx.field;
    // Erreur nationale **dérivée** (opt-in). `nationalPhone == null` →
    // `null` → chemin antérieur identique. Recalcul en `build` seulement.
    final validator = _config?.nationalPhone;
    final String? nationalErrorText = validator == null
        ? null
        : nationalPhoneErrorText(context, validator.validate(_numberController.text));
    // Décoration thémée du cœur — la MÊME chaîne que `text`/`number`/
    // `select`/`date` (`zFieldDecoration` → `ZcrudTheme.inputDecoration`) :
    // `fieldFillColor`, `fieldBorderColor`, `inputRadius`,
    // `inputContentPadding`, libellé flottant enrichi (astérisque requis),
    // hint/helper l10n et ornements déclaratifs. Aucun jeton nouveau.
    //
    // Le préfixe « drapeau + indicatif » du paquet natif reste posé : le
    // paquet le pose lui-même en `prefixIcon` (`getInputDecoration` ⇒
    // `copyWith(prefixIcon: SelectorButton(...))`), donc **dans** ce cadre
    // thémé. Corollaire : un ornement `ZFieldSpec.prefix` de kind `icon`
    // est ÉCRASÉ par ce `copyWith` du tiers — c'est le seul slot de la
    // décoration que le champ téléphone ne peut pas honorer.
    final decoration = zFieldDecoration(
      context,
      field,
      bare: _bare,
      errorText: nationalErrorText,
    );
    // Invariant AD-13 : la cible tactile est portée par la contrainte
    // liante (`minHeight`), pas par une taille rendue constatée après
    // coup.
    return ConstrainedBox(
      // Clé nommée : sans elle, une garde de cible tactile mesurerait le
      // maximum des `ConstrainedBox` descendants et se satisferait du
      // 48×48 posé par le bouton sélecteur du paquet tiers — elle
      // mesurerait le plancher du tiers, pas le nôtre.
      key: const Key('z-phone-tap-target'),
      constraints: const BoxConstraints(minHeight: 48),
      child: ZIntlPhoneInputBridge.build(
        fieldKey: const Key('z-phone-number'),
        seed: _seed,
        controller: _numberController,
        focusNode: _numberFocus,
        enabled: !field.readOnly,
        searchable: _config?.searchable ?? true,
        // Jamais de code pays en dur ; la restriction vient de la config
        // du champ, et elle est assainie contre le catalogue réel du
        // paquet (invariant AD-10).
        countries: ZIntlPhoneInputBridge.sanitizeCountries(
          _config?.allowedCountryIsos ?? const <String>[],
        ),
        // La langue des noms de pays est une donnée de locale lue sur
        // l'ambiance, jamais un littéral de ce paquet.
        locale: Localizations.maybeLocaleOf(context)?.languageCode,
        // Invariant AD-13 : le message d'erreur est annoncé par la
        // sémantique native du champ (il transite par
        // `InputDecoration.errorText`).
        decoration: decoration,
        // Rétablit le retrait de TÊTE perdu par le slot `prefixIcon` (cf.
        // `_selectorLeadingIndent`).
        selectorLeadingPadding: _selectorLeadingIndent(context, decoration),
        onChanged: _onInputChanged,
      ),
    );
  }

  /// Retrait de **tête** du contenu « drapeau + indicatif » du sélecteur.
  ///
  /// **Défaut mesuré, cause vérifiée.**
  ///
  /// Le bouton sélecteur du paquet tiers occupe le slot `prefixIcon` de la
  /// décoration (`getInputDecoration` ⇒
  /// `copyWith(prefixIcon: SelectorButton(…))`). Or `InputDecorator`
  /// **substitue** la largeur du `prefixIcon` au retrait de tête du
  /// contenu — cf. `input_decorator.dart` :
  /// `start: … + (prefixIcon == null ? contentPadding.start + inputGap: …)`.
  /// L'`inputContentPadding.start` du thème est donc **perdu côté tête**,
  /// et le `prefixIcon` est posé au ras du cadre.
  ///
  /// Mesuré (formulaire de 2 champs, `inputContentPadding` = 16, bordure
  /// `OutlineInputBorder` par défaut) : contenu du champ `text` voisin à
  /// **x = 32** depuis le bord de page, drapeau à **x = 12**, c'est-à-dire
  /// **exactement le bord de la carte** — 20 dp d'écart, pas 16 : le
  /// retrait réel des voisins vaut `contentPadding.start` (16) **+**
  /// `inputGap` (le `gapPadding` de la bordure, 4).
  ///
  /// Priorité **paramètre > jeton** : config par champ, puis paramètre de
  /// registre, puis valeur **dérivée du thème**. Aucune constante de style
  /// n'est écrite ici : la valeur dérivée est recalculée à partir de la
  /// décoration déjà construite par le helper du cœur, avec la **formule
  /// du SDK**.
  double _selectorLeadingIndent(
    BuildContext context,
    InputDecoration decoration,
  ) {
    final explicit =
        _config?.selectorLeadingPadding ?? widget.selectorLeadingPadding;
    if (explicit != null) return explicit;
    // Retrait qu'`InputDecorator` applique au contenu d'un champ SANS
    // `prefixIcon` — donc celui des champs voisins, dans le MÊME thème.
    final padding = decoration.contentPadding;
    // AD-13: composante de **TÊTE**. `resolve(ltr).left` la lit sans supposer
    // le sens du texte (pour un `EdgeInsetsDirectional`, `left` en LTR **est**
    // `start`); c'est ensuite le `Row` du sélecteur qui la place du bon côté
    // selon la `Directionality` ambiante — jamais un `left` rendu.
    final start = padding == null ? 0.0 : padding.resolve(TextDirection.ltr).left;
    return start + _inputGap(context, decoration);
  }

  /// `inputGap` réellement appliqué par `InputDecorator` (Material 3: le
  /// `gapPadding` de la bordure). Défensif (AD-10) et **jamais inventé**: toute
  /// bordure qui n'est pas une `OutlineInputBorder` rend `0` — sous-estimer le
  /// retrait est le repli sûr, plutôt que de recopier une constante privée du
  /// SDK. En mode `bare` la bordure est `InputBorder.none` et le
  /// `contentPadding` nul: le retrait dérivé vaut alors **0**, ce qui est
  /// exactement le retrait des voisins `bare` (décor porté par la Card).
  static double _inputGap(BuildContext context, InputDecoration decoration) {
    if (!Theme.of(context).useMaterial3) return 0;
    final border = decoration.enabledBorder ?? decoration.border;
    return border is OutlineInputBorder ? border.gapPadding : 0;
  }

  /// Rendu `bare` (le décor est porté par `ZLargeFieldCard`) — dérivé de la
  /// spec **exactement comme le dispatcher du cœur** et comme
  /// `ZDecoratedFieldTrigger` (`fieldSize == large`). Aucune convention nouvelle.
  bool get _bare => widget.ctx.field.fieldSize == ZFieldSize.large;
}
