/// **Porteur de réglages** neutre — `ZChatGenerationSettings` (lot β,
/// AD-4/AD-10).
///
/// ## Le manque mesuré : le porteur, pas le widget
///
/// L'étude CR-IFFD-72 (§ 4.3) a établi que les réglages du chat sont **déjà
/// modélisés** dans ce paquet mais atteignables par **un seul canal étroit** —
/// la capture de closure de l'hôte, `send()` n'ayant aucun paramètre. Et un
/// défaut structurel : `ZChatRegenerateAction` ne portait que `{messageId}`
/// alors que [ZChatLengthBias] est défini comme « biais d'une **régénération** »
/// — donc **inatteignable sur son propre cas d'usage**.
///
/// Ce porteur regroupe les réglages en **une valeur transportable**, la même
/// sur la requête et sur la régénération. C'est ce qui ferme le défaut ③.
///
/// ## 🔴 Aucun enum réinventé — RÉFÉRENCE, jamais redéclaration
///
/// | Réglage | Type porté | Déclaré où |
/// |---|---|---|
/// | Verbosité | `ZChatResponseLength` | `z_chat_enums.dart` (CHAT-0) |
/// | Biais de régénération | `ZChatLengthBias` | `z_chat_enums.dart` (CHAT-0) |
/// | Budget de calcul `1..5` | `ZChatComputeEffort` | `z_chat_compute_effort.dart` (CHAT-1) |
/// | Étapes de raisonnement | `bool?` [revealThinkingSteps] | pendant, côté DEMANDE, de `ZChatThinkingStep` (côté réponse) |
///
/// Le risque n°1 nommé par la revue était « reconstruire la moitié du kernel » :
/// ce fichier ne déclare **aucun** type de réglage, il les compose.
///
/// ## Pourquoi une PROJECTION, et non un second jeu de champs
///
/// `ZChatGenerationRequest` porte **déjà** `responseLength`, `lengthBias` et
/// `computeEffort` en champs de premier niveau — et la garde **G16/CHAT-1b**
/// exige qu'ils y restent, littéralement, pour que les deux axes (verbosité vs
/// calcul) demeurent non confondables sur la requête. Y ajouter un porteur
/// **redondant** aurait créé deux sources de vérité et « deux lectures
/// conformes mais incompatibles » — exactement ce que la lentille adversariale
/// traque.
///
/// ⇒ Sur la requête, le porteur est une **vue** : `request.settings` le
/// projette, `request.withSettings(…)` l'injecte, et le tour est une
/// **bijection** (garde du lot). Sur `ZChatRegenerateAction`, où il n'existait
/// rien, il est **stocké**.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_enums.dart';
import 'z_chat_compute_effort.dart';

/// Réglages de génération transportables — immuable, `==`/`hashCode` par
/// valeur.
///
/// **Tout est nullable, et `null` signifie « l'hôte décide »** — jamais un
/// défaut inventé par le socle. Un porteur entièrement nul ([isEmpty]) laisse
/// le comportement strictement inchangé.
class ZChatGenerationSettings {
  /// Construit un porteur de réglages (immuable, `const`).
  const ZChatGenerationSettings({
    this.responseLength,
    this.lengthBias,
    this.computeEffort,
    this.revealThinkingSteps,
  });

  /// Longueur attendue — enum **EXISTANT** `ZChatResponseLength`.
  final ZChatResponseLength? responseLength;

  /// Biais de longueur d'une régénération — enum **EXISTANT**
  /// `ZChatLengthBias`.
  final ZChatLengthBias? lengthBias;

  /// Budget de calcul `1..5` — type **EXISTANT** `ZChatComputeEffort`. Axe
  /// ORTHOGONAL à [responseLength] : les deux ne se substituent jamais.
  final ZChatComputeEffort? computeEffort;

  /// Demande d'**exposer les étapes de raisonnement** (`ZChatThinkingStep`) au
  /// fil de la réponse. `null` ⇒ l'hôte décide ; c'est le pendant, côté
  /// demande, d'un type qui n'existait jusqu'ici que côté réponse.
  final bool? revealThinkingSteps;

  /// `true` si aucun réglage n'est exprimé — le porteur est alors **sans
  /// effet** et une requête qui le reçoit est identique à une requête sans.
  bool get isEmpty =>
      responseLength == null &&
      lengthBias == null &&
      computeEffort == null &&
      revealThinkingSteps == null;

  /// `true` si au moins un réglage est exprimé.
  bool get isNotEmpty => !isEmpty;

  /// Copie modifiée — les paramètres omis sont **conservés** (même forme que
  /// `ZChatThinkingStep.copyWith`).
  ///
  /// ⚠️ **Ce membre ne peut pas RETIRER un réglage** : passer `null` est
  /// indistinguable d'un paramètre omis. Pour revenir à « l'hôte décide », on
  /// **construit** la valeur — les quatre champs sont optionnels, donc
  /// `ZChatGenerationSettings(responseLength: s.responseLength)` suffit.
  ///
  /// 🔴 Les drapeaux `clear*` de lex (`ToolsContext.copyWith`) ne sont pas
  /// portés : `clearComputeEffort` heurterait la garde **G16**, qui n'autorise
  /// pour `Effort` que les deux orthographes exactes `ZChatComputeEffort` et
  /// `computeEffort` — précisément pour qu'aucune famille d'orthographes
  /// voisines ne se glisse à côté de l'axe qu'elle protège. Le contournement
  /// aurait été de la renommer ; on préfère un membre plus étroit.
  ZChatGenerationSettings copyWith({
    ZChatResponseLength? responseLength,
    ZChatLengthBias? lengthBias,
    ZChatComputeEffort? computeEffort,
    bool? revealThinkingSteps,
  }) =>
      ZChatGenerationSettings(
        responseLength: responseLength ?? this.responseLength,
        lengthBias: lengthBias ?? this.lengthBias,
        computeEffort: computeEffort ?? this.computeEffort,
        revealThinkingSteps: revealThinkingSteps ?? this.revealThinkingSteps,
      );

  /// Décode **défensivement** (AD-10) — ne lève jamais ; `raw` non-`Map` ⇒
  /// `null`, valeur illisible ⇒ réglage absent (« l'hôte décide »), **jamais**
  /// un palier inventé.
  ///
  /// ⚠️ [responseLength] et [lengthBias] ont des `fromJson` **totaux** (repli
  /// `standard` / `asIs`) : appliquer ce repli à une clé **absente**
  /// transformerait « non réglé » en « réglé au défaut ». La clé est donc
  /// testée avant d'être décodée.
  static ZChatGenerationSettings? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatGenerationSettings(
      responseLength: map.containsKey('response_length')
          ? ZChatResponseLength.fromJson(map['response_length'])
          : null,
      lengthBias: map.containsKey('length_bias')
          ? ZChatLengthBias.fromJson(map['length_bias'])
          : null,
      computeEffort: ZChatComputeEffort.fromJson(map['compute_effort']),
      revealThinkingSteps: zJsonBoolOrNull(map['reveal_thinking_steps']),
    );
  }

  /// Sérialise en clés snake_case ; un réglage non exprimé est **omis** (et
  /// non écrit `null`), pour qu'un round-trip conserve « l'hôte décide ».
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (responseLength != null) 'response_length': responseLength!.jsonValue,
        if (lengthBias != null) 'length_bias': lengthBias!.jsonValue,
        if (computeEffort != null) 'compute_effort': computeEffort!.toJson(),
        if (revealThinkingSteps != null)
          'reveal_thinking_steps': revealThinkingSteps,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatGenerationSettings &&
          responseLength == other.responseLength &&
          lengthBias == other.lengthBias &&
          computeEffort == other.computeEffort &&
          revealThinkingSteps == other.revealThinkingSteps;

  @override
  int get hashCode => Object.hash(
        responseLength,
        lengthBias,
        computeEffort,
        revealThinkingSteps,
      );

  @override
  String toString() => 'ZChatGenerationSettings(responseLength: '
      '$responseLength, lengthBias: $lengthBias, '
      'computeEffort: $computeEffort, '
      'revealThinkingSteps: $revealThinkingSteps)';
}
