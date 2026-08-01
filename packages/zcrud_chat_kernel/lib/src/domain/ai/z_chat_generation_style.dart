/// Style de génération **OUVERT** — `ZChatGenerationStyle` (CHAT-1, AD-4).
///
/// ## Le défaut que ce type ferme
///
/// IFFD écrit **sept** variantes de reformulation comme **sept fonctions et
/// sept endpoints distincts** (`ai_repository.dart:36-47` :
/// `summarizeExplanation`, `elaborateExplanation`, `explain_with_examples`,
/// `explain_as_poem`, `explain_as_story`, `explain_with_humor`,
/// `explain_as_classroom`), doublées d'un `enum ExplainStyle` à dix valeurs
/// (`lib/src/domain/models/ai/ai_models.dart:9-19`) qui porte en plus **un
/// libellé français et une icône Material** — de la présentation dans le
/// domaine. Ces sept chemins ne diffèrent QUE par le prompt : ils recopient à
/// l'identique routeur, streaming, annulation et gestion d'erreur, et ont
/// divergé (`explainSubjectWithStyle` existe ET les endpoints séparés existent).
///
/// ⇒ **Un seul contrat**, `ZChatGenerationPort.generate(request)`, dont le style
/// est une **donnée** portée par ce value object.
///
/// ## Pourquoi une valeur ouverte et pas un `enum`
///
/// « poème / humour / histoire / séance de cours » sont de la **gamification
/// propre à IFFD**, pas du socle : un `enum` fermé obligerait tout hôte à
/// forker zcrud pour déclarer le sien, et imposerait le vocabulaire d'IFFD à
/// lex et à DODLP. Le patron retenu est celui, déjà en production dans ce
/// package, de [ZCustomContentBlock] et de `ZChatSource.sourceType` :
/// **discriminant `String` + charge utile, round-trip par [ZTypeRegistry]**
/// (AD-4 pt.3).
///
/// 🔴 **Aucun second registre n'est créé.** [ZTypeRegistry] existe déjà et sert
/// exactement cet axe (« type/valeur ouverte ») ; `ZSourceRegistry` sert
/// l'axe provenance. Poser un `ZChatStyleRegistry` serait le motif CR-LEX-78
/// (un doublon plus pauvre qu'un existant).
library;

import 'package:zcrud_core/domain.dart';

/// Clé persistée du discriminant de style.
const String kZChatGenerationStyleKindKey = 'style';

/// Clé persistée de la charge utile de style.
const String kZChatGenerationStyleParamsKey = 'style_params';

/// Style de génération, **immuable** et **ouvert**.
///
/// [kind] est un discriminant **technique** (jamais un libellé d'affichage :
/// le libellé et l'icône appartiennent à l'hôte — AD-13/FR-26). [params] porte
/// les paramètres propres au style de l'hôte, verbatim ou reconstruits par le
/// codec que l'hôte a enregistré dans un [ZTypeRegistry].
class ZChatGenerationStyle {
  /// Construit un style pour [kind], avec des [params] optionnels.
  ZChatGenerationStyle(
    this.kind, [
    Map<String, dynamic> params = const <String, dynamic>{},
  ]) : params = Map<String, dynamic>.unmodifiable(params);

  /// Discriminant **ouvert** du style (`'summarize'`, `'poem'`, `'classroom'`…).
  final String kind;

  /// Paramètres propres au style — **verbatim** par défaut.
  final Map<String, dynamic> params;

  // ───────────────────────────────────────────────────────────────────────────
  // Catalogue MINIMAL du socle.
  //
  // 🔴 Ne contient QUE ce qui est neutre pour les trois consommateurs (DODLP,
  // IFFD, lex). Les styles de gamification d'IFFD (poème, histoire fantastique,
  // humour, séance de cours) sont DÉLIBÉRÉMENT absents : ils se déclarent
  // côté hôte par `ZChatGenerationStyle('poem')`, sans toucher au socle.
  // Garde G-C5 : leur réintroduction ici fait rougir la suite.
  // ───────────────────────────────────────────────────────────────────────────

  /// Tour de conversation nu (aucune transformation stylistique demandée).
  static ZChatGenerationStyle get converse => ZChatGenerationStyle('converse');

  /// Résumé de la matière source (IFFD `summarize_explanation`).
  static ZChatGenerationStyle get summarize =>
      ZChatGenerationStyle('summarize');

  /// Développement/approfondissement (IFFD `elaborate_explanation`).
  static ZChatGenerationStyle get elaborate =>
      ZChatGenerationStyle('elaborate');

  /// Illustration par des exemples concrets (IFFD `explain_with_examples`).
  static ZChatGenerationStyle get examples => ZChatGenerationStyle('examples');

  /// Décode **défensivement** un style (AD-10) — ne lève jamais.
  ///
  /// - [raw] non-`Map` ou [kind] absent/vide ⇒ `null` (le parent décide) ;
  /// - [kind] **enregistré** dans [typeRegistry] ⇒ [params] reconstruits par le
  ///   codec de l'hôte (un codec qui lève est absorbé : repli verbatim) ;
  /// - [kind] inconnu ⇒ [params] verbatim.
  static ZChatGenerationStyle? fromJson(
    Object? raw, {
    ZTypeRegistry? typeRegistry,
  }) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    final String kind = zJsonString(map[kZChatGenerationStyleKindKey]);
    if (kind.isEmpty) return null;
    final Map<String, dynamic> verbatim =
        zJsonMap(map[kZChatGenerationStyleParamsKey]) ??
        const <String, dynamic>{};
    final ZValueCodec? codec = typeRegistry?.tryCodecFor(kind);
    final Map<String, dynamic> params = codec == null
        ? verbatim
        : (zJsonMap(zJsonGuard(() => codec.fromJson(verbatim))) ?? verbatim);
    return ZChatGenerationStyle(kind, params);
  }

  /// Sérialise en clés snake_case ; [params] omis s'il est vide.
  Map<String, dynamic> toJson({ZTypeRegistry? typeRegistry}) {
    final ZValueCodec? codec = typeRegistry?.tryCodecFor(kind);
    final Map<String, dynamic> body = codec == null
        ? params
        : (zJsonGuard(() => codec.toJson(params)) ?? params);
    return <String, dynamic>{
      kZChatGenerationStyleKindKey: kind,
      if (body.isNotEmpty) kZChatGenerationStyleParamsKey: body,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatGenerationStyle &&
          kind == other.kind &&
          zJsonEquals(params, other.params);

  @override
  int get hashCode => Object.hash(kind, zJsonHash(params));

  @override
  String toString() => 'ZChatGenerationStyle(kind: $kind)';
}
