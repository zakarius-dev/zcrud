/// **La NATURE d'un outil, et son ÉTAT COURANT** — `ZChatToolState`.
///
/// Domaine PUR (aucun Flutter, aucun `BuildContext`, aucun libellé, aucune
/// icône, aucune couleur). Ce fichier décrit **ce qu'un outil est capable
/// d'exprimer** et **où il en est**, jamais comment il se dessine.
///
/// ## La règle que ce contrat rend structurelle
///
/// > **UNE FEUILLE D'OUTILS EST UNE DONNÉE, PAS UN `switch`.**
///
/// Une feuille écrite en code — une liste à compteur fixe et un aiguillage sur
/// des index — se paie deux fois : ajouter un outil demande d'éditer à la fois
/// l'aiguillage et le compteur, et un hôte ne peut **rien** ajouter du tout.
/// Le vocabulaire ci-dessous rend la feuille énumérable : les surfaces de rendu
/// n'ont plus qu'à projeter une liste.
///
/// ## Patron `sealed` interne + variant ouvert (invariant AD-4)
///
/// Décalqué de `ZChatAction` : `sealed` donne l'**exhaustivité au socle** (une
/// nature non traitée par une projection **ne compile pas**), et l'extension
/// inter-package passe par le variant ouvert [ZChatCustomToolState] — **jamais**
/// par l'héritage externe.
///
/// ## Le jeton d'état, et pourquoi le socle n'écrit aucun sous-titre
///
/// Chaque état sait produire un [ZChatToolState.stateToken] : une chaîne
/// **opaque, déterministe et documentée** qui identifie *où l'on en est*
/// (`'on'`, `'step.3'`, `'mark.2'`, `'all'`…). C'est la moitié socle du
/// sous-titre qui décrit **l'état** plutôt que la fonction. L'autre moitié —
/// le texte — appartient à l'hôte, qui l'associe au jeton
/// (`ZChatToolEntry.stateLabels`). Le socle ne nomme rien à la place de
/// personne (FR-26).
///
/// ## Aucun parse ne lève (invariant AD-10)
///
/// [ZChatToolState.fromJson] est total : `null` sur une entrée non-`Map`, et
/// une nature inconnue retombe sur [ZChatCustomToolState] portant le payload
/// **verbatim** — un outil venu d'un schéma futur traverse le socle sans être
/// perdu ni inventé.
library;

import 'package:zcrud_core/domain.dart';

// ── Natures que le socle sait décrire (constantes ouvertes, jamais un enum) ──

/// Nature « bascule booléenne ».
const String kZChatToolKindToggle = 'toggle';

/// Nature « cycle 0..N » — un seul point de contact règle N+1 crans.
const String kZChatToolKindCycle = 'cycle';

/// Nature « choix parmi des options » (non ordonné).
const String kZChatToolKindChoice = 'choice';

/// Nature « échelle continue à repères » (ordonnée).
const String kZChatToolKindScale = 'scale';

/// Nature « catalogue filtrable » — sélection vide ⇒ **tout**.
const String kZChatToolKindCatalog = 'catalog';

/// Nature « action ponctuelle » — sans état, donc jamais active.
const String kZChatToolKindCommand = 'command';

/// Jeton d'état d'une bascule active.
const String kZChatToolTokenOn = 'on';

/// Jeton d'état d'une bascule inactive.
const String kZChatToolTokenOff = 'off';

/// Jeton d'état « rien de choisi » (choix, échelle sans valeur).
const String kZChatToolTokenNone = 'none';

/// Jeton d'état d'un catalogue **non filtré** (sélection vide ⇒ tout).
const String kZChatToolTokenAll = 'all';

/// Jeton d'état d'un catalogue filtré.
const String kZChatToolTokenSelected = 'selected';

/// Jeton d'état d'une action ponctuelle (elle n'a pas d'autre état).
const String kZChatToolTokenIdle = 'idle';

/// Jeton d'état d'une échelle valuée **sans repère** déclaré.
const String kZChatToolTokenValue = 'value';

/// L'état courant d'un outil, et ce qu'il sait faire de lui-même.
///
/// Famille **scellée au socle** ; un hôte étend par [ZChatCustomToolState],
/// jamais par héritage (invariant AD-4).
sealed class ZChatToolState {
  /// Construit un état.
  const ZChatToolState();

  /// Discriminant persisté de la nature (camelCase — convention du dépôt).
  String get kind;

  /// `true` quand cet état **compte** comme « outil activé ».
  ///
  /// C'est la seule définition de l'activité : le comptage agrégé et la liste
  /// des actifs s'y adossent, jamais à une heuristique de surface.
  bool get isActive;

  /// Jeton **opaque et déterministe** décrivant l'état courant.
  ///
  /// Il n'est pas destiné à l'affichage : c'est la clé que l'hôte associe à
  /// son propre texte.
  String get stateToken;

  /// La forme **inactive** de ce même état — sans changer sa nature.
  ///
  /// Utilisée par l'exclusion mutuelle (activer A éteint B) et par la remise à
  /// zéro d'un outil qui ne déclare pas d'état par défaut.
  ZChatToolState get cleared;

  /// Sérialise en clés `snake_case` ; les champs absents sont **omis**.
  Map<String, dynamic> toJson();

  /// Décode **défensivement** (invariant AD-10) — ne lève jamais.
  ///
  /// Une nature inconnue n'est pas une perte : elle devient un
  /// [ZChatCustomToolState] portant le payload verbatim.
  static ZChatToolState? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String kind = zJsonString(map['kind']);
    switch (kind) {
      case kZChatToolKindToggle:
        return ZChatToggleState(value: zJsonBool(map['value'], false));
      case kZChatToolKindCycle:
        return ZChatCycleState(
          step: zJsonInt(map['step'], 0),
          stepCount: zJsonInt(map['step_count'], 1),
        );
      case kZChatToolKindChoice:
        return ZChatChoiceState(
          optionKeys: zJsonStringList(map['option_keys']) ?? const <String>[],
          selectedKey: zJsonStringOrNull(map['selected_key']),
        );
      case kZChatToolKindScale:
        return ZChatScaleState(
          min: zJsonDouble(map['min'], 0),
          max: zJsonDouble(map['max'], 1),
          value: zJsonDoubleOrNull(map['value']),
          marks: _readDoubles(map['marks']),
        );
      case kZChatToolKindCatalog:
        return ZChatCatalogState(
          itemKeys: zJsonStringList(map['item_keys']) ?? const <String>[],
          selectedKeys:
              zJsonStringList(map['selected_keys']) ?? const <String>[],
          unavailableKeys:
              zJsonStringList(map['unavailable_keys']) ?? const <String>[],
          unavailableReasonToken:
              zJsonStringOrNull(map['unavailable_reason_token']),
        );
      case kZChatToolKindCommand:
        return const ZChatCommandState();
      default:
        // Nature inconnue : préservation opaque plutôt que destruction.
        return ZChatCustomToolState(
          kind: kind.isEmpty ? 'unknown' : kind,
          active: zJsonBool(map['active'], false),
          explicitStateToken: zJsonStringOrNull(map['state_token']),
          data: zJsonMap(map['data']) ?? const <String, dynamic>{},
        );
    }
  }
}

/// **Bascule booléenne** — la nature la plus simple.
class ZChatToggleState extends ZChatToolState {
  /// Construit une bascule.
  const ZChatToggleState({this.value = false});

  /// Position courante.
  final bool value;

  /// Bascule vers l'autre position.
  ZChatToggleState toggled() => ZChatToggleState(value: !value);

  @override
  String get kind => kZChatToolKindToggle;

  @override
  bool get isActive => value;

  @override
  String get stateToken => value ? kZChatToolTokenOn : kZChatToolTokenOff;

  @override
  ZChatToolState get cleared => const ZChatToggleState();

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': kind, 'value': value};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZChatToggleState && value == other.value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'ZChatToggleState($value)';
}

/// **Cycle 0..N** — un tap avance d'un cran, et le dernier cran **revient à 0**.
///
/// C'est la forme qu'un point de contact unique doit prendre quand il doit
/// couvrir plusieurs crans sans ouvrir de panneau. Le cran `0` est le cran
/// **inactif** : un cycle n'est actif que strictement au-dessus.
class ZChatCycleState extends ZChatToolState {
  /// Construit un cycle. [stepCount] est ramené à `1` minimum et [step] est
  /// **ramené dans** `0..stepCount-1` — un état persisté hors bornes ne lève
  /// jamais (invariant AD-10).
  ZChatCycleState({int step = 0, int stepCount = 1})
      : stepCount = stepCount < 1 ? 1 : stepCount,
        step = _wrap(step, stepCount < 1 ? 1 : stepCount);

  /// Cran courant, dans `0..stepCount-1`.
  final int step;

  /// Nombre de crans, cran `0` (inactif) compris. Toujours ≥ 1.
  final int stepCount;

  /// Cran suivant — **et `0` après le dernier**. C'est la boucle, et elle est
  /// la seule voie d'avancement : il n'existe pas de cran hors bornes.
  ZChatCycleState next() =>
      ZChatCycleState(step: step + 1 >= stepCount ? 0 : step + 1, stepCount: stepCount);

  /// Va directement au cran demandé (ramené dans les bornes).
  ZChatCycleState at(int target) =>
      ZChatCycleState(step: target, stepCount: stepCount);

  @override
  String get kind => kZChatToolKindCycle;

  @override
  bool get isActive => step > 0;

  @override
  String get stateToken => 'step.$step';

  @override
  ZChatToolState get cleared => ZChatCycleState(stepCount: stepCount);

  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'kind': kind, 'step': step, 'step_count': stepCount};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCycleState &&
          step == other.step &&
          stepCount == other.stepCount;

  @override
  int get hashCode => Object.hash(kind, step, stepCount);

  @override
  String toString() => 'ZChatCycleState($step/$stepCount)';
}

/// **Choix parmi des options** — non ordonné, `null` signifie « rien de choisi ».
///
/// Une sélection qui ne figure pas dans [optionKeys] est **écartée** au lieu
/// d'être conservée : une valeur inatteignable ne doit pas rester dans l'état.
class ZChatChoiceState extends ZChatToolState {
  /// Construit un choix.
  ZChatChoiceState({
    required Iterable<String> optionKeys,
    String? selectedKey,
  })  : optionKeys = List<String>.unmodifiable(_normalizeKeys(optionKeys)),
        selectedKey = _normalizeKeys(optionKeys).contains(selectedKey?.trim())
            ? selectedKey!.trim()
            : null;

  /// Options possibles — clés opaques d'hôte, dédupliquées, ordre conservé.
  final List<String> optionKeys;

  /// Option retenue, ou `null`.
  final String? selectedKey;

  /// Retient [key] (ou rien si `null` / clé inconnue).
  ZChatChoiceState select(String? key) =>
      ZChatChoiceState(optionKeys: optionKeys, selectedKey: key);

  @override
  String get kind => kZChatToolKindChoice;

  @override
  bool get isActive => selectedKey != null;

  @override
  String get stateToken => selectedKey ?? kZChatToolTokenNone;

  @override
  ZChatToolState get cleared => ZChatChoiceState(optionKeys: optionKeys);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'option_keys': optionKeys,
        if (selectedKey != null) 'selected_key': selectedKey,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatChoiceState &&
          selectedKey == other.selectedKey &&
          zListEquals(optionKeys, other.optionKeys);

  @override
  int get hashCode => Object.hash(kind, selectedKey, zListHash(optionKeys));

  @override
  String toString() => 'ZChatChoiceState($selectedKey)';
}

/// **Échelle continue à repères** — `value == null` signifie « non réglée ».
///
/// Les repères ne sont pas des libellés : ce sont des **positions**. Le jeton
/// d'état d'une valeur posée est celui du repère le plus proche
/// (`'mark.<index>'`), ce qui permet à l'hôte de nommer trois paliers sans que
/// le socle connaisse leurs noms.
class ZChatScaleState extends ZChatToolState {
  /// Construit une échelle. Des bornes inversées sont **remises à l'endroit**
  /// et [value] est écrêtée — jamais un `throw` (invariant AD-10).
  factory ZChatScaleState({
    required double min,
    required double max,
    double? value,
    Iterable<double> marks = const <double>[],
  }) {
    // Bornes inversées : on les remet à l'endroit plutôt que de lever.
    final double lo = min <= max ? min : max;
    final double hi = min <= max ? max : min;
    return ZChatScaleState._(
      lo,
      hi,
      value == null ? null : _clampDouble(value, lo, hi),
      List<double>.unmodifiable(marks),
    );
  }

  const ZChatScaleState._(this.min, this.max, this.value, this.marks);

  /// Borne basse, incluse.
  final double min;

  /// Borne haute, incluse.
  final double max;

  /// Valeur courante dans `[min, max]`, ou `null` si non réglée.
  final double? value;

  /// Repères déclarés par l'hôte, dans l'ordre de l'échelle.
  final List<double> marks;

  /// Index du repère le plus proche de [value], ou `null` (pas de valeur ou
  /// pas de repère).
  int? get nearestMarkIndex {
    final double? v = value;
    if (v == null || marks.isEmpty) return null;
    int best = 0;
    double bestDelta = (marks[0] - v).abs();
    for (int i = 1; i < marks.length; i++) {
      final double delta = (marks[i] - v).abs();
      if (delta < bestDelta) {
        best = i;
        bestDelta = delta;
      }
    }
    return best;
  }

  /// Pose une valeur (écrêtée), ou la retire avec `null`.
  ZChatScaleState withValue(double? next) =>
      ZChatScaleState(min: min, max: max, value: next, marks: marks);

  @override
  String get kind => kZChatToolKindScale;

  @override
  bool get isActive => value != null;

  @override
  String get stateToken {
    if (value == null) return kZChatToolTokenNone;
    final int? mark = nearestMarkIndex;
    return mark == null ? kZChatToolTokenValue : 'mark.$mark';
  }

  @override
  ZChatToolState get cleared =>
      ZChatScaleState(min: min, max: max, marks: marks);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'min': min,
        'max': max,
        if (value != null) 'value': value,
        if (marks.isNotEmpty) 'marks': marks,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatScaleState &&
          min == other.min &&
          max == other.max &&
          value == other.value &&
          zListEquals(marks, other.marks);

  @override
  int get hashCode => Object.hash(kind, min, max, value, zListHash(marks));

  @override
  String toString() => 'ZChatScaleState($value in [$min,$max])';
}

/// **Catalogue filtrable** — sélection vide ⇒ **tout le catalogue**.
///
/// Les entrées indisponibles ne sont **pas retirées** de [itemKeys] : elles
/// restent énumérables et sont désignées par [unavailableKeys], avec un jeton
/// de raison résolu par l'hôte. Retirer une entrée indisponible poserait à
/// l'utilisateur la question sans réponse « pourquoi la mienne n'est-elle pas
/// là ? ».
class ZChatCatalogState extends ZChatToolState {
  /// Construit un catalogue. Les clés sélectionnées absentes de [itemKeys] et
  /// les clés indisponibles sont **écartées** de la sélection.
  ZChatCatalogState({
    required Iterable<String> itemKeys,
    Iterable<String> selectedKeys = const <String>[],
    Iterable<String> unavailableKeys = const <String>[],
    this.unavailableReasonToken,
  })  : itemKeys = List<String>.unmodifiable(_normalizeKeys(itemKeys)),
        unavailableKeys =
            List<String>.unmodifiable(_normalizeKeys(unavailableKeys)),
        selectedKeys = List<String>.unmodifiable(<String>[
          for (final String k in _normalizeKeys(selectedKeys))
            if (_normalizeKeys(itemKeys).contains(k) &&
                !_normalizeKeys(unavailableKeys).contains(k))
              k,
        ]);

  /// Toutes les entrées du catalogue, indisponibles comprises.
  final List<String> itemKeys;

  /// Entrées retenues. **Vide ⇒ aucune restriction** (« Tous »).
  final List<String> selectedKeys;

  /// Entrées présentes mais non sélectionnables.
  final List<String> unavailableKeys;

  /// Jeton opaque de la raison d'indisponibilité, résolu par l'hôte.
  final String? unavailableReasonToken;

  /// `true` si [key] est sélectionnable.
  bool isAvailable(String key) => !unavailableKeys.contains(key);

  /// Remplace la sélection (les clés inconnues ou indisponibles sont écartées).
  ZChatCatalogState select(Iterable<String> keys) => ZChatCatalogState(
        itemKeys: itemKeys,
        selectedKeys: keys,
        unavailableKeys: unavailableKeys,
        unavailableReasonToken: unavailableReasonToken,
      );

  @override
  String get kind => kZChatToolKindCatalog;

  @override
  bool get isActive => selectedKeys.isNotEmpty;

  @override
  String get stateToken =>
      selectedKeys.isEmpty ? kZChatToolTokenAll : kZChatToolTokenSelected;

  @override
  ZChatToolState get cleared => ZChatCatalogState(
        itemKeys: itemKeys,
        unavailableKeys: unavailableKeys,
        unavailableReasonToken: unavailableReasonToken,
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'item_keys': itemKeys,
        if (selectedKeys.isNotEmpty) 'selected_keys': selectedKeys,
        if (unavailableKeys.isNotEmpty) 'unavailable_keys': unavailableKeys,
        if (unavailableReasonToken != null)
          'unavailable_reason_token': unavailableReasonToken,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCatalogState &&
          zListEquals(itemKeys, other.itemKeys) &&
          zListEquals(selectedKeys, other.selectedKeys) &&
          zListEquals(unavailableKeys, other.unavailableKeys) &&
          unavailableReasonToken == other.unavailableReasonToken;

  @override
  int get hashCode => Object.hash(kind, zListHash(itemKeys),
      zListHash(selectedKeys), zListHash(unavailableKeys), unavailableReasonToken);

  @override
  String toString() =>
      'ZChatCatalogState(${selectedKeys.length}/${itemKeys.length})';
}

/// **Action ponctuelle** — elle se déclenche, elle ne se règle pas.
///
/// Elle n'est **jamais** active : une action ne peut pas peupler le comptage
/// agrégé, sans quoi le badge annoncerait des réglages que la liste des actifs
/// ne saurait pas montrer.
class ZChatCommandState extends ZChatToolState {
  /// Construit l'action ponctuelle.
  const ZChatCommandState();

  @override
  String get kind => kZChatToolKindCommand;

  @override
  bool get isActive => false;

  @override
  String get stateToken => kZChatToolTokenIdle;

  @override
  ZChatToolState get cleared => const ZChatCommandState();

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'kind': kind};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is ZChatCommandState;

  @override
  int get hashCode => kind.hashCode;

  @override
  String toString() => 'ZChatCommandState()';
}

/// **Nature d'hôte** — l'échappatoire du vocabulaire scellé (invariant AD-4).
///
/// Un hôte déclare sa propre nature en instanciant ce variant : il fournit le
/// discriminant, l'activité et le jeton d'état, et transporte son payload dans
/// [data]. Le socle ne sait pas la rendre — c'est au rendu d'hôte de le faire —
/// mais elle traverse le catalogue, compte dans les agrégats et se sérialise.
class ZChatCustomToolState extends ZChatToolState {
  /// Construit une nature d'hôte.
  const ZChatCustomToolState({
    required this.kind,
    this.active = false,
    this.explicitStateToken,
    this.data = const <String, dynamic>{},
  });

  @override
  final String kind;

  /// Contribution au comptage, décidée par l'hôte.
  final bool active;

  /// Jeton d'état imposé par l'hôte. `null` ⇒ le jeton se déduit de [active].
  final String? explicitStateToken;

  /// Payload d'hôte, conservé verbatim.
  final Map<String, dynamic> data;

  /// Même nature, activité et jeton remplacés.
  ZChatCustomToolState copyWith({bool? active, String? explicitStateToken}) =>
      ZChatCustomToolState(
        kind: kind,
        active: active ?? this.active,
        explicitStateToken: explicitStateToken ?? this.explicitStateToken,
        data: data,
      );

  @override
  bool get isActive => active;

  @override
  String get stateToken =>
      explicitStateToken ?? (active ? kZChatToolTokenOn : kZChatToolTokenOff);

  @override
  ZChatToolState get cleared =>
      ZChatCustomToolState(kind: kind, data: data);

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'kind': kind,
        'active': active,
        if (explicitStateToken != null) 'state_token': explicitStateToken,
        if (data.isNotEmpty) 'data': data,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCustomToolState &&
          kind == other.kind &&
          active == other.active &&
          explicitStateToken == other.explicitStateToken &&
          zJsonEquals(data, other.data);

  @override
  int get hashCode =>
      Object.hash(kind, active, explicitStateToken, zJsonHash(data));

  @override
  String toString() => 'ZChatCustomToolState($kind, active: $active)';
}

// ── Normalisation partagée ───────────────────────────────────────────────────

double _clampDouble(double v, double lo, double hi) =>
    v < lo ? lo : (v > hi ? hi : v);

int _wrap(int step, int stepCount) {
  if (stepCount <= 1) return 0;
  final int m = step % stepCount;
  return m < 0 ? m + stepCount : m;
}

List<String> _normalizeKeys(Iterable<String> raw) {
  final List<String> out = <String>[];
  for (final String k in raw) {
    final String t = k.trim();
    if (t.isEmpty || out.contains(t)) continue;
    out.add(t);
  }
  return out;
}

List<double> _readDoubles(Object? raw) {
  if (raw is! List) return const <double>[];
  return <double>[
    for (final Object? e in raw)
      if (zJsonDoubleOrNull(e) != null) zJsonDoubleOrNull(e)!,
  ];
}
