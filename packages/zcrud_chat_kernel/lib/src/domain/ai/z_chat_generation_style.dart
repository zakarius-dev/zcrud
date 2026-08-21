/// Style de génération **ouvert** — `ZChatGenerationStyle` (invariant AD-4).
///
/// ## Le défaut que ce type ferme
///
/// Une application de chat qui grandit organiquement tend à écrire chaque
/// variante de reformulation (résumé, développement, exemples, styles plus
/// ludiques…) comme une fonction et un point d'entrée distincts, doublés d'un
/// enum fermé qui porte en plus un libellé et une icône — de la présentation
/// dans le domaine. Ces chemins ne diffèrent souvent QUE par le prompt : ils
/// recopient à l'identique routeur, streaming, annulation et gestion
/// d'erreur, et finissent par diverger entre eux.
///
/// ⇒ **Un seul contrat**, `ZChatGenerationPort.generate(request)`, dont le style
/// est une **donnée** portée par ce value object.
///
/// ## Pourquoi une valeur ouverte et pas un `enum`
///
/// Des styles ludiques (poème, histoire, humour, séance de cours…) relèvent
/// d'une **gamification propre à un hôte donné**, pas du socle — un
/// catalogue d'intégration observé déclare ainsi jusqu'à huit styles de
/// reformulation applicatifs, tous hors du périmètre partagé. Un `enum` fermé
/// obligerait
/// tout autre hôte à forker zcrud pour déclarer le sien, et lui imposerait un
/// vocabulaire qui n'est pas le sien. Le patron retenu est
/// celui, déjà en production dans ce package, de [ZCustomContentBlock] et de
/// `ZChatSource.sourceType` : **discriminant `String` + charge utile,
/// round-trip par [ZTypeRegistry]** (invariant AD-4, extension par registre
/// ouvert).
///
/// **Aucun second registre n'est créé.** [ZTypeRegistry] existe déjà et sert
/// exactement cet axe (« type/valeur ouverte ») ; `ZSourceRegistry` sert
/// l'axe provenance. Poser un registre dédié aux styles serait un doublon
/// plus pauvre qu'un mécanisme déjà existant.
library;

import 'package:zcrud_core/domain.dart';

/// Clé persistée du discriminant de style.
const String kZChatGenerationStyleKindKey = 'style';

/// Clé persistée de la charge utile de style.
const String kZChatGenerationStyleParamsKey = 'style_params';

/// Style de génération, **immuable** et **ouvert**.
///
/// [kind] est un discriminant **technique** (jamais un libellé d'affichage :
/// le libellé et l'icône appartiennent à l'hôte — invariant AD-13). [params]
/// porte les paramètres propres au style de l'hôte, verbatim ou reconstruits
/// par le codec que l'hôte a enregistré dans un [ZTypeRegistry].
class ZChatGenerationStyle {
  // Le catalogue applicatif observé qui motive l'ouverture de ce type :
  // `iffd/lib/src/domain/models/ai/ai_models.dart:9-19` — un enum FERMÉ de huit
  // styles (poème, histoire, humour, séance de cours…) portant en plus un
  // libellé français et une icône Material. Aucun de ces styles n'entre au
  // socle : un hôte les déclare par `ZChatGenerationStyle('poem')`.

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
  // Ne contient QUE ce qui est neutre pour l'ensemble des hôtes. Les styles
  // de gamification propres à un hôte (poème, histoire fantastique, humour,
  // séance de cours) sont DÉLIBÉRÉMENT absents : ils se déclarent côté hôte
  // par `ZChatGenerationStyle('poem')`, sans toucher au socle.
  // ───────────────────────────────────────────────────────────────────────────

  /// Tour de conversation nu (aucune transformation stylistique demandée).
  static ZChatGenerationStyle get converse => ZChatGenerationStyle('converse');

  /// Résumé de la matière source.
  static ZChatGenerationStyle get summarize =>
      ZChatGenerationStyle('summarize');

  /// Développement/approfondissement.
  static ZChatGenerationStyle get elaborate =>
      ZChatGenerationStyle('elaborate');

  /// Illustration par des exemples concrets.
  static ZChatGenerationStyle get examples => ZChatGenerationStyle('examples');

  /// Décode **défensivement** un style (invariant AD-10) — ne lève jamais.
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
