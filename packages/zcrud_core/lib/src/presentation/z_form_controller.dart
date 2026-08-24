/// Contrôleur de formulaire **Flutter-natif** — brique de réactivité granulaire
/// (AD-2, objectif produit n°1).
///
/// Corrige par construction le bug de rafraîchissement GLOBAL du formulaire à
/// chaque frappe (jank, perte de focus, saut de curseur). `ZFormController` pose
/// la mécanique réactive sur laquelle `DynamicEdition` bâtit ses widgets
/// d'édition.
library;

import 'package:flutter/foundation.dart';

/// Contrôleur d'un formulaire d'édition, réactif **par tranche de champ**.
///
/// Invariants (AD-2 — NON-NÉGOCIABLES) :
/// - **Une tranche = un [ValueNotifier] mémoïsé** : [fieldListenable] renvoie
///   TOUJOURS la même instance pour un `name` donné (créée une fois, jamais
///   recréée). C'est ce qui évite la recréation d'état au rebuild — cause racine
///   du bug historique.
/// - **[setValue] ne provoque JAMAIS de rebuild global** : écrire la valeur d'un
///   champ ne notifie QUE les listeners de la tranche de ce champ. Le
///   [ChangeNotifier] global (`notifyListeners()`) est réservé aux changements
///   **structurels** (ensemble/visibilité de champs — canal [visibleFields]).
/// - **Pas de ré-injection** : le contrôleur DÉTIENT la valeur ; il n'écrit
///   jamais dans un `TextEditingController` (`.text=`). La synchronisation
///   valeur↔`TextField` et la stabilité du `TextEditingController` relèvent du
///   widget de champ texte. Ici la saisie est à sens unique (`onChanged →
///   setValue`).
///
/// Aucun gestionnaire d'état n'est importé (AD-15) : seules les primitives
/// `package:flutter/foundation.dart` (`ChangeNotifier`/`ValueListenable`) sont
/// utilisées. Le branchement injection/cycle de vie passe par `ZcrudScope` / un
/// binding, jamais par une référence directe à un manager.
class ZFormController extends ChangeNotifier {
  /// Construit un contrôleur.
  ///
  /// [initialValues] pré-remplit des tranches (identité stable dès la
  /// construction). [visibleFields] fixe l'ensemble structurel initial ; à
  /// défaut il reprend les clés de [initialValues] (ou vide) — **amorçage de
  /// repli**, remplacé par l'ordre canonique du schéma dès qu'un
  /// `DynamicEdition` est monté (voir [hasExplicitVisibleFields]). Les tranches
  /// demandées ultérieurement via [fieldListenable] sont créées paresseusement
  /// et mémoïsées (voir [fieldListenable]).
  ZFormController({
    Map<String, Object?>? initialValues,
    List<String>? visibleFields,
  }) : hasExplicitVisibleFields = visibleFields != null {
    if (initialValues != null) {
      initialValues.forEach((name, value) {
        _slices[name] = ValueNotifier<Object?>(value);
        _baseline[name] = value;
      });
    }
    final initial =
        visibleFields ?? initialValues?.keys.toList(growable: false) ?? const <String>[];
    _visibleFields = ValueNotifier<List<String>>(
      List<String>.unmodifiable(initial),
    );
  }

  /// `true` ssi l'hôte a fourni `visibleFields` **à la construction**.
  /// C'est la SEULE information qui distingue un ensemble structurel
  /// **voulu par l'hôte** d'un amorçage de repli dérivé des clés de
  /// `initialValues` — le constructeur la perdait, ce qui rendait l'ordre
  /// d'affichage tributaire de l'ordre de la Map de persistance,
  /// **silencieusement**.
  ///
  /// `DynamicEdition` la lit pour décider s'il doit AMORCER `visibleFields` sur
  /// l'ordre canonique de son schéma (`fields`) : `false` ⇒ le schéma fait foi ;
  /// `true` ⇒ l'hôte est autoritaire, rien n'est réamorcé.
  ///
  /// Fixée une fois pour toutes : un [setVisibleFields] ultérieur (par l'hôte ou
  /// par le formulaire lui-même) ne la modifie PAS — sinon la première écriture
  /// du formulaire s'auto-déclarerait « explicite » et neutraliserait tout
  /// réamorçage sur changement de schéma.
  final bool hasExplicitVisibleFields;

  /// Registre `name → tranche` (identité stable ; jamais recréé pour un `name`).
  final Map<String, ValueNotifier<Object?>> _slices =
      <String, ValueNotifier<Object?>>{};

  /// Canal **structurel** : ensemble/ordre des champs visibles. C'est le SEUL
  /// signal qui déclenche `notifyListeners()` du contrôleur (voir
  /// [setVisibleFields]). Un [setValue] ne le modifie jamais.
  late final ValueNotifier<List<String>> _visibleFields;

  /// Empreinte de l'**état initial** (baseline) servant à dériver [isDirty].
  /// Capturée à la construction depuis `initialValues`, re-capturée
  /// par [markPristine]/[reseed], restaurée par [reset]. Pur-données (jamais un
  /// callback/Widget — AD-3).
  final Map<String, Object?> _baseline = <String, Object?>{};

  /// Ensemble des champs dont la valeur **s'écarte** de la baseline. [isDirty]
  /// en est dérivé (`isNotEmpty`) — permet un toggle au **flip** uniquement.
  final Set<String> _dirtyFields = <String>{};

  /// Canal *dirty* **dédié** : ne notifie JAMAIS les tranches ni
  /// le `notifyListeners()` global — un widget « bannière dirty » / « bouton
  /// enregistrer » n'écoute QUE ce `ValueListenable<bool>` (rebuild ciblé).
  final ValueNotifier<bool> _isDirty = ValueNotifier<bool>(false);

  /// Canal de **révélation d'erreurs** : époque incrémentée par la
  /// soumission agrégée en échec de validation pour révéler les messages de
  /// TOUTES les familles (y compris non-texte) SANS `Form`/`FormBuilder` global
  /// (AD-2). N'est PAS le canal structurel `visibleFields` (aucun
  /// `notifyListeners()` global). Remis à `0` par [reset].
  final ValueNotifier<int> _reveal = ValueNotifier<int>(0);

  /// Canal de **write-back externe** : révision incrémentée par
  /// [reset]/[reseed] pour signaler aux widgets à buffer d'édition interne
  /// (texte/signature/mini-CRUD/select bufferisé) de re-lire `valueOf` dans leur
  /// buffer — **uniquement hors focus** (jamais pendant un geste/frappe).
  final ValueNotifier<int> _reseedRevision = ValueNotifier<int>(0);

  /// Retourne la **tranche réactive** du champ [name].
  ///
  /// Renvoie TOUJOURS la même instance de [ValueListenable] pour un `name`
  /// donné (tranche stable). **`name` inconnu** : la tranche est créée
  /// paresseusement (valeur initiale `null`) puis mémoïsée : un formulaire
  /// dynamique ne connaît pas toujours ses champs à l'avance ; la création
  /// paresseuse évite un couplage d'ordre et un `throw` fragile. La
  /// composition structurelle (visibilité) reste gouvernée par
  /// [visibleFields], pas par la simple existence d'une tranche.
  ValueListenable<Object?> fieldListenable(String name) => _slice(name);

  ValueNotifier<Object?> _slice(String name) =>
      _slices.putIfAbsent(name, () => ValueNotifier<Object?>(null));

  /// Lit la valeur courante de la tranche [name] (`null` si jamais écrite).
  Object? valueOf(String name) => _slices[name]?.value;

  /// Amorce la tranche [name] avec [value] **uniquement si elle est ABSENTE**.
  ///
  /// C'est la voie par laquelle le moteur d'édition applique les
  /// `ZFieldSpec.defaultValue` déclarés : toute tranche que `initialValues` n'a
  /// **pas** fournie est amorcée avec le défaut de sa spec.
  ///
  /// ## Absent ≠ nul explicite
  ///
  /// Le discriminant est la **présence de la clé** dans `initialValues` (ou
  /// dans un [reseed]), jamais la valeur : une clé fournie avec `null`
  /// **explicite** est autoritaire et n'est PAS remplacée par le défaut — c'est
  /// la même distinction omis/`null` que le `copyWith` généré. Sont également
  /// préservées : une tranche déjà **saisie** ([isTouched]) et une tranche déjà
  /// **écrite** à une valeur non nulle (écriture programmatique de l'hôte).
  ///
  /// L'amorçage écrit la tranche **et** la baseline (le champ reste
  /// *pristine* : un défaut appliqué n'est pas une modification). Seuls les
  /// listeners de la tranche amorcée sont notifiés — jamais le canal global.
  /// Idempotent : une fois la baseline posée, les appels suivants sont no-op.
  void seedDefaultValue(String name, Object? value) {
    if (_baseline.containsKey(name)) return;
    if (_touched.contains(name)) return;
    final existing = _slices[name];
    if (existing != null && existing.value != null) return;
    _slice(name).value = value;
    _baseline[name] = value;
    _updateDirty(name, value);
  }

  /// Lit la valeur **baseline** (item d'origine persisté) de [name] — `null` si
  /// absente. Lecture seule **pure** de [_baseline] : aucune
  /// mutation, aucun canal réactif, aucun `notifyListeners()` (rebuild ciblé
  /// intact).
  ///
  /// C'est la source de `persistedValueOf` pour `evaluateZCondition` : une
  /// condition `source: ZValueSource.persisted` lit l'état **d'origine**,
  /// indépendamment d'une saisie en cours sur le champ homonyme (l'état
  /// persisté à l'ouverture du formulaire, distinct de l'état édité en cours).
  Object? baselineValueOf(String name) => _baseline[name];

  /// Champs **touchés par l'utilisateur** : tout [setValue] dont `derived` vaut
  /// `false`. *Touché* ≠ *dirty* : revenir manuellement à la valeur
  /// d'origine efface le *dirty* mais PAS le *touché* (le champ a bien été
  /// saisi). Remis à zéro par [reset]/[reseed]/[markPristine].
  final Set<String> _touched = <String>{};

  /// `true` si l'utilisateur a écrit dans la tranche [name] depuis la dernière
  /// remise à zéro ([reset]/[reseed]/[markPristine]).
  ///
  /// Lecture **pure** (aucun canal réactif, rebuild ciblé intact). C'est le prédicat de
  /// `ZDerivationOverwrite.ifPristine` : le moteur de dérivation sait quelles
  /// écritures viennent de LUI (`derived: true`) ; tout le reste est une saisie.
  bool isTouched(String name) => _touched.contains(name);

  /// Registre des **retraits** de la famille fichier : `nom du champ → entrées
  /// que l'utilisateur a détachées du champ depuis l'ouverture du formulaire`.
  ///
  /// Vidé par [reset] / [reseed] / [markPristine], comme la baseline dont il
  /// est le pendant : ce qui n'est plus en cours d'édition n'a plus de retrait
  /// en attente.
  final Map<String, List<Object>> _removedFiles = <String, List<Object>>{};

  /// Consigne que [entry] a été **retirée** du champ [name].
  ///
  /// [entry] est ce que le champ tenait au moment du retrait : l'objet fichier
  /// (`AppFile`) quand il est connu — y compris pour une référence que le
  /// résolveur avait résolue —, sinon la **référence opaque** telle qu'elle
  /// était persistée. C'est cette forme-là qui est utile à l'appelant : elle
  /// désigne le fichier à effacer réellement.
  ///
  /// Écriture **pure** : aucun canal réactif n'est notifié (ni tranche, ni
  /// `notifyListeners()` global — invariant AD-2). Un retrait déjà consigné
  /// n'est pas dupliqué.
  ///
  /// Appelé par le champ fichier du moteur d'édition ; un hôte n'a normalement
  /// pas à l'appeler lui-même.
  void recordRemovedFile(String name, Object entry) {
    final list = _removedFiles.putIfAbsent(name, () => <Object>[]);
    if (list.contains(entry)) return;
    list.add(entry);
  }

  /// Entrées **retirées** du champ [name] depuis l'ouverture du formulaire,
  /// dans l'ordre des retraits. Liste **vide** quand rien n'a été retiré —
  /// jamais `null`.
  ///
  /// Lecture **pure** (aucun canal réactif, rebuild ciblé intact). La liste
  /// rendue est immuable.
  List<Object> removedFilesOf(String name) =>
      List<Object>.unmodifiable(_removedFiles[name] ?? const <Object>[]);

  /// Snapshot **immuable** de tous les retraits en attente
  /// (`nom du champ → entrées retirées`). Les champs sans retrait en sont
  /// absents.
  Map<String, List<Object>> get removedFiles =>
      Map<String, List<Object>>.unmodifiable(<String, List<Object>>{
        for (final e in _removedFiles.entries)
          if (e.value.isNotEmpty) e.key: List<Object>.unmodifiable(e.value),
      });

  /// Met à jour **exclusivement** la tranche du champ [name].
  ///
  /// Notifie UNIQUEMENT les listeners de `fieldListenable(name)` ; les autres
  /// tranches et le `ChangeNotifier` global ne sont PAS notifiés (aucun
  /// `notifyListeners()` global — rebuilds granulaires, AD-2). Poser la même
  /// valeur (`==`)
  /// est un no-op natif de [ValueNotifier] (pas de notification superflue).
  ///
  /// [derived] (défaut `false` ⇒ appelants existants inchangés) marque une
  /// écriture **du moteur de dérivation**, pas de l'utilisateur : elle ne rend
  /// pas le champ *touché* (voir [isTouched]). Les widgets d'édition appellent
  /// toujours la forme par défaut (`onChanged → setValue`).
  void setValue(String name, Object? value, {bool derived = false}) {
    if (!derived) _touched.add(name);
    _slice(name).value = value;
    _updateDirty(name, value);
  }

  /// Met à jour le suivi *dirty* pour le champ [name] passé à [value] et ne
  /// **toggle** [_isDirty] que si le booléen agrégé **change**. N'émet
  /// aucun `notifyListeners()` global ni notification de tranche tierce.
  void _updateDirty(String name, Object? value) {
    final differs = value != _baseline[name];
    final was = _dirtyFields.contains(name);
    if (differs && !was) {
      _dirtyFields.add(name);
    } else if (!differs && was) {
      _dirtyFields.remove(name);
    }
    final now = _dirtyFields.isNotEmpty;
    if (now != _isDirty.value) _isDirty.value = now;
  }

  /// Snapshot **immuable** des valeurs de toutes les tranches (`name → valeur`).
  ///
  /// Données **pures** (jamais un `Widget`/`callback`/`BuildContext` — AD-3) :
  /// c'est cet objet qui est transmis au seam `onSubmit` (voir
  /// `ZEditionSubmitController`), jamais le contrôleur ni une tranche.
  Map<String, Object?> get values => Map<String, Object?>.unmodifiable(
        <String, Object?>{
          for (final e in _slices.entries) e.key: e.value.value,
        },
      );

  /// `ValueListenable<bool>` *dirty* **dédié** : `true` dès qu'au moins un
  /// champ s'écarte de la baseline ; revient à `false` quand tous y reviennent
  /// (ou après [reset]/[markPristine]). Écoute CIBLÉE (jamais le canal global).
  ValueListenable<bool> get isDirty => _isDirty;

  /// Canal de révélation d'erreurs (époque). Les champs l'observent pour révéler
  /// leur message à une soumission agrégée en échec, texte comme non-texte.
  ValueListenable<int> get reveal => _reveal;

  /// Canal de write-back externe (révision) observé par les widgets à buffer
  /// interne pour se re-amorcer **hors focus** sur [reset]/[reseed].
  ValueListenable<int> get reseedRevision => _reseedRevision;

  /// Demande la **révélation** des erreurs de validation (incrémente l'époque).
  /// Appelé par la soumission agrégée en échec de validation.
  void revealErrors() => _reveal.value = _reveal.value + 1;

  /// Re-capture la **baseline** depuis les valeurs courantes ⇒ [isDirty] repasse
  /// à `false`. Appelé après une soumission réussie (`onSubmit` → `Right`).
  /// N'affecte NI la révélation NI la révision de re-seed. Les retraits de
  /// fichiers ([removedFilesOf]) sont **oubliés** : ils ont été soumis.
  void markPristine() {
    _baseline
      ..clear()
      ..addEntries(
        _slices.entries.map((e) => MapEntry<String, Object?>(e.key, e.value.value)),
      );
    _dirtyFields.clear();
    _touched.clear();
    _removedFiles.clear();
    if (_isDirty.value) _isDirty.value = false;
  }

  /// **Réinitialise** le formulaire à sa baseline courante : restaure la
  /// valeur baseline de chaque tranche, efface l'état *dirty*, la révélation et
  /// les retraits de fichiers en attente ([removedFilesOf]),
  /// puis incrémente [reseedRevision] pour re-amorcer les widgets bufferisés
  /// **hors focus**. Une saisie en cours (champ focalisé) n'est pas écrasée : le
  /// re-amorçage est différé à la perte de focus par le widget.
  void reset() {
    for (final entry in _slices.entries) {
      entry.value.value = _baseline[entry.key];
    }
    _dirtyFields.clear();
    _touched.clear();
    _removedFiles.clear();
    if (_isDirty.value) _isDirty.value = false;
    _reveal.value = 0;
    _reseedRevision.value = _reseedRevision.value + 1;
  }

  /// **Recharge** des valeurs EXTERNES autoritaires : écrit
  /// [values] dans les tranches, **re-définit la baseline** sur ces valeurs
  /// (⇒ non-dirty), puis incrémente [reseedRevision] pour re-amorcer les widgets
  /// bufferisés hors focus. Sert le chargement asynchrone d'un enregistrement.
  /// Les retraits de fichiers en attente ([removedFilesOf]) sont effacés : ils
  /// portaient sur l'état remplacé.
  void reseed(Map<String, Object?> values) {
    values.forEach((name, value) {
      _slice(name).value = value;
      _baseline[name] = value;
    });
    _dirtyFields.clear();
    _touched.clear();
    _removedFiles.clear();
    if (_isDirty.value) _isDirty.value = false;
    _reseedRevision.value = _reseedRevision.value + 1;
  }

  /// Canal **structurel** : liste ordonnée des champs visibles.
  ///
  /// Seul canal qui déclenche `notifyListeners()` du contrôleur (sert les
  /// champs conditionnels). Un [setValue] ne le modifie jamais.
  ValueListenable<List<String>> get visibleFields => _visibleFields;

  /// Remplace l'ensemble structurel des champs visibles.
  ///
  /// No-op si l'ensemble est inchangé (comparaison de liste). Sinon met à jour
  /// [visibleFields] ET déclenche le `notifyListeners()` global — le SEUL
  /// déclencheur global (invariant AD-2).
  void setVisibleFields(List<String> names) {
    final next = List<String>.unmodifiable(names);
    if (listEquals(_visibleFields.value, next)) return;
    _visibleFields.value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final slice in _slices.values) {
      slice.dispose();
    }
    _slices.clear();
    _removedFiles.clear();
    _visibleFields.dispose();
    _isDirty.dispose();
    _reveal.dispose();
    _reseedRevision.dispose();
    super.dispose();
  }
}
