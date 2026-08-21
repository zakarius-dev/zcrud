/// **Portée documentaire VÉRIFIABLE** d'une requête — `ZChatCorpusScope`
/// (AD-4/AD-10/AD-11).
///
/// ## Le vrai sujet n'est pas « restreindre », c'est « pouvoir le VÉRIFIER »
///
/// `ZChatSource.corpus` est un **libellé**, pas une clé. Une restriction posée
/// sur lui serait **inaudible** : on ne pourrait jamais confronter les sources
/// rendues à la portée demandée, donc jamais savoir si le fournisseur l'a
/// honorée. **Une restriction non vérifiable ne vaut rien.** La portée est donc
/// écrite en **clés stables**, et relue par la même clé.
///
/// ⇒ Ce fichier livre les DEUX moitiés du bouclage :
/// * l'**écriture** — [ZChatCorpusScope] sur la requête, en **clés stables** ;
/// * la **lecture** — [ZChatCorpusScope.audit], qui confronte des
///   [ZChatSource] à la portée et **nomme** celles qui la violent. La clé lue
///   est `ZChatSource.corpusKey`, **jamais** le libellé `corpus`.
///
/// ## Ce qui est porté de lex — et ce qui est écarté
///
/// Le mécanisme fonctionnel mesuré est celui de lex_douane (`ToolsContext` +
/// `CatalogEntry(indexed)`, `packages/lex_core/lib/domain/entities/`), le seul
/// des deux hôtes qui **atteigne le backend** (chez IFFD les six drapeaux de
/// corpus sont jetés par le repository : le mécanisme y est inerte).
///
/// | De lex | Verdict |
/// |---|---|
/// | Deux NIVEAUX : famille activée, puis filtre d'identités dans la famille | **PORTÉ** — [ZChatCorpusSelector.sourceType] puis [ZChatCorpusSelector.corpusKeys] |
/// | « filtre vide ⇒ toute la famille » | **PORTÉ** (sémantique identique) |
/// | Piloté par DONNÉES (catalogue d'entrées à `id` stable) | **PORTÉ** — la portée ne porte que des clés opaques |
/// | Familles **codées en dur** (`enableCodesDouanes`, `enableTec`, `enableValuation`) | **ÉCARTÉ** — imposerait la douane à IFFD et à DODLP. La famille est ici `ZChatSource.sourceType`, discriminant **ouvert** qui existait déjà. |
/// | Un booléen `enable*` **par** famille | **ÉCARTÉ** — non extensible : une famille de plus = un champ de plus, donc un changement de contrat. |
/// | `@JsonSerializable` / codegen | **ÉCARTÉ** — D1 : aucun codegen dans le kernel. |
/// | *(absent de lex)* confrontation des sources rendues à la portée | **AJOUTÉ** — c'est la propriété centrale du lot. |
///
/// ## Le socle ne porte AUCUNE valeur métier
///
/// Aucun code douanier, aucune famille nommée, aucun libellé : les **valeurs**
/// appartiennent aux hôtes (FR-26). Ce fichier ne porte que le **mécanisme**.
library;

import 'package:zcrud_core/domain.dart';

import '../z_chat_source.dart';

/// Clé persistée de la portée sur une requête sérialisée par un hôte.
const String kZChatCorpusScopeSelectorsKey = 'selectors';

/// Un **sélecteur** de portée : une famille, et facultativement les seules
/// clés de corpus admises dans cette famille.
///
/// Les deux niveaux sont ceux de lex, rendus génériques :
///
/// | Niveau | Champ | `null`/vide signifie |
/// |---|---|---|
/// | 1 — famille | [sourceType] | **toute** famille |
/// | 2 — corpus | [corpusKeys] | **tout** corpus de la famille |
///
/// Un sélecteur totalement vide (`sourceType == null`, `corpusKeys` vide)
/// n'admet donc **aucune restriction** : il vaut « tout ». C'est voulu — la
/// portée par défaut d'un hôte qui n'a rien réglé ne doit rien interdire.
class ZChatCorpusSelector {
  /// Construit un sélecteur. [corpusKeys] est **normalisée** : éléments
  /// rognés, vides écartés, doublons fusionnés, ordre canonique (l'ordre de
  /// saisie d'une portée n'est pas une information).
  ZChatCorpusSelector({String? sourceType, Iterable<String> corpusKeys = const <String>[]})
      : sourceType = _normalizeKey(sourceType),
        corpusKeys = List<String>.unmodifiable(_normalizeKeys(corpusKeys));

  /// Famille de provenance visée — la valeur de [ZChatSource.sourceType]
  /// (`'tec'`, `'article'`, `'web'`…), **ouverte** et propre à l'hôte.
  /// `null` ⇒ le sélecteur ne discrimine pas la famille.
  final String? sourceType;

  /// Clés de corpus admises **dans** cette famille, ordonnées et dédupliquées.
  ///
  /// Ce sont des **clés stables**, jamais des libellés : elles se comparent
  /// à `ZChatSource.corpusKey`, et jamais à `ZChatSource.corpus` (qui est un
  /// texte d'affichage, traduisible, donc incomparable).
  final List<String> corpusKeys;

  /// `true` si ce sélecteur restreint au niveau 2 (des clés sont listées).
  bool get restrictsCorpus => corpusKeys.isNotEmpty;

  /// `true` si le sélecteur n'exprime **aucune** restriction.
  bool get isUnrestricted => sourceType == null && corpusKeys.isEmpty;

  /// `true` si [source] est admise par **ce** sélecteur.
  ///
  /// **Fail-safe, décalqué de `ZChatSource.isVerified`** : quand le
  /// sélecteur restreint au niveau 2 et que la source ne porte **aucune clé**,
  /// la réponse est `false`. En l'absence de signal on ne présume **jamais**
  /// « dans la portée » — sans quoi il suffirait à un fournisseur d'omettre la
  /// clé pour rendre n'importe quelle source indétectable.
  bool admits(ZChatSource source) {
    if (sourceType != null && source.sourceType != sourceType) return false;
    if (!restrictsCorpus) return true;
    final String? key = _normalizeKey(source.corpusKey);
    if (key == null) return false;
    return corpusKeys.contains(key);
  }

  /// Décode **défensivement** (AD-10) — ne lève jamais ; `raw` non-`Map` ⇒
  /// `null`, champs illisibles ⇒ défauts sûrs.
  static ZChatCorpusSelector? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatCorpusSelector(
      sourceType: zJsonStringOrNull(map['source_type']),
      corpusKeys: zJsonStringList(map['corpus_keys']) ?? const <String>[],
    );
  }

  /// Sérialise en clés snake_case ; les champs absents sont **omis**.
  Map<String, dynamic> toJson() => <String, dynamic>{
        if (sourceType != null) 'source_type': sourceType,
        if (corpusKeys.isNotEmpty) 'corpus_keys': corpusKeys,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCorpusSelector &&
          sourceType == other.sourceType &&
          zListEquals(corpusKeys, other.corpusKeys);

  @override
  int get hashCode => Object.hash(sourceType, zListHash(corpusKeys));

  @override
  String toString() =>
      'ZChatCorpusSelector(sourceType: $sourceType, keys: ${corpusKeys.length})';
}

/// **Portée documentaire** demandée par une requête — une disjonction de
/// [ZChatCorpusSelector] (« l'un OU l'autre »).
///
/// Vide ⇒ [isUnrestricted] : c'est le comportement d'AVANT ce lot, et le
/// défaut de `ZChatGenerationRequest.corpusScope` (`null`). Une requête sans
/// portée n'interdit rien et [audit] la déclare satisfaite quoi qu'il arrive.
class ZChatCorpusScope {
  /// Construit une portée. Les sélecteurs sont **normalisés** : dédoublonnés
  /// et remis en ordre canonique — deux portées bâties avec les mêmes
  /// sélecteurs dans un ordre différent sont **égales** (même invariant que
  /// `ZChatContextFragment.ordered` sur le contexte).
  ZChatCorpusScope(Iterable<ZChatCorpusSelector> selectors)
      : selectors =
            List<ZChatCorpusSelector>.unmodifiable(_normalize(selectors));

  /// Portée à un seul niveau : uniquement des clés de corpus, toutes familles
  /// confondues. C'est la forme la plus courante côté hôte.
  factory ZChatCorpusScope.ofKeys(Iterable<String> corpusKeys) =>
      ZChatCorpusScope(<ZChatCorpusSelector>[
        ZChatCorpusSelector(corpusKeys: corpusKeys),
      ]);

  /// Sélecteurs, ordonnés et dédupliqués. Une source est admise si **au
  /// moins un** sélecteur l'admet.
  final List<ZChatCorpusSelector> selectors;

  /// `true` si la portée n'interdit rien (aucun sélecteur, ou uniquement des
  /// sélecteurs sans restriction).
  bool get isUnrestricted =>
      selectors.isEmpty ||
      selectors.every((ZChatCorpusSelector s) => s.isUnrestricted);

  /// `true` si au moins un sélecteur restreint au niveau **corpus** — donc si
  /// une source sans clé devient **invérifiable** (cf. [audit]).
  bool get requiresCorpusKey =>
      selectors.any((ZChatCorpusSelector s) => s.restrictsCorpus);

  /// Toutes les clés de corpus citées par la portée, à plat (ordre canonique).
  List<String> get corpusKeys => List<String>.unmodifiable(
        _normalizeKeys(
          selectors.expand((ZChatCorpusSelector s) => s.corpusKeys),
        ),
      );

  /// `true` si [source] est dans la portée.
  bool admits(ZChatSource source) =>
      isUnrestricted ||
      selectors.any((ZChatCorpusSelector s) => s.admits(source));

  /// **Le bouclage** : confronte les sources RENDUES à la portée DEMANDÉE.
  ///
  /// C'est le membre qui rend la restriction vérifiable — sans lui, la portée
  /// ne serait qu'un vœu écrit sur la requête. Un hôte l'appelle sur les
  /// sources de la réponse pour décider s'il affiche un avertissement, filtre,
  /// ou rejette le tour ; une garde l'appelle pour **prouver** qu'une source
  /// hors portée est détectée.
  ZChatCorpusAudit audit(Iterable<ZChatSource> sources) {
    final List<ZChatSource> admitted = <ZChatSource>[];
    final List<ZChatSource> outOfScope = <ZChatSource>[];
    final List<ZChatSource> unattributed = <ZChatSource>[];
    for (final ZChatSource source in sources) {
      if (admits(source)) {
        admitted.add(source);
        continue;
      }
      // Distinguer « hors portée » (clé connue, non demandée) de
      // « invérifiable » (aucune clé) : les deux échouent, mais l'hôte ne les
      // traite pas pareil — l'un accuse le fournisseur, l'autre son schéma.
      if (_normalizeKey(source.corpusKey) == null && requiresCorpusKey) {
        unattributed.add(source);
      } else {
        outOfScope.add(source);
      }
    }
    return ZChatCorpusAudit(
      scope: this,
      admitted: admitted,
      outOfScope: outOfScope,
      unattributed: unattributed,
    );
  }

  /// Décode **défensivement** (AD-10) — `raw` non-`Map` ⇒ `null` ; un
  /// sélecteur illisible est **sauté**, il n'annule pas les autres.
  static ZChatCorpusScope? fromJson(Object? raw) {
    final Map<String, dynamic>? map = zJsonMap(raw);
    if (map == null) return null;
    return ZChatCorpusScope(
      zJsonDecodeList<ZChatCorpusSelector>(
            map[kZChatCorpusScopeSelectorsKey],
            ZChatCorpusSelector.fromJson,
          ) ??
          const <ZChatCorpusSelector>[],
    );
  }

  /// Sérialise en clés snake_case.
  Map<String, dynamic> toJson() => <String, dynamic>{
        kZChatCorpusScopeSelectorsKey: <Map<String, dynamic>>[
          for (final ZChatCorpusSelector s in selectors) s.toJson(),
        ],
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatCorpusScope && zListEquals(selectors, other.selectors);

  @override
  int get hashCode => zListHash(selectors);

  @override
  String toString() => 'ZChatCorpusScope(selectors: ${selectors.length})';
}

/// Résultat d'une confrontation [ZChatCorpusScope.audit] — immuable.
///
/// Ne **filtre** rien et ne **lève** rien (AD-10) : il constate. Que faire
/// d'une violation (avertir, masquer, redemander) est une décision d'hôte, pas
/// de socle.
class ZChatCorpusAudit {
  /// Construit un constat.
  ZChatCorpusAudit({
    required this.scope,
    required List<ZChatSource> admitted,
    required List<ZChatSource> outOfScope,
    required List<ZChatSource> unattributed,
  })  : admitted = List<ZChatSource>.unmodifiable(admitted),
        outOfScope = List<ZChatSource>.unmodifiable(outOfScope),
        unattributed = List<ZChatSource>.unmodifiable(unattributed);

  /// Portée qui a servi de référence.
  final ZChatCorpusScope scope;

  /// Sources effectivement dans la portée.
  final List<ZChatSource> admitted;

  /// Sources dont la clé est **connue** mais **hors** de la portée demandée.
  final List<ZChatSource> outOfScope;

  /// Sources **sans clé** alors que la portée en exige une : la conformité
  /// n'est pas réfutée, elle est **invérifiable** — ce qui, fail-safe, compte
  /// comme un échec.
  final List<ZChatSource> unattributed;

  /// `true` si **aucune** source ne viole la portée et qu'aucune n'est
  /// invérifiable.
  bool get isSatisfied => outOfScope.isEmpty && unattributed.isEmpty;

  /// Toutes les sources en défaut, hors portée **et** invérifiables.
  List<ZChatSource> get violations => List<ZChatSource>.unmodifiable(
        <ZChatSource>[...outOfScope, ...unattributed],
      );

  @override
  String toString() => 'ZChatCorpusAudit(admitted: ${admitted.length}, '
      'outOfScope: ${outOfScope.length}, '
      'unattributed: ${unattributed.length})';
}

/// Rogne une clé et rend `null` si elle est vide — une chaîne blanche n'est
/// pas une clé.
String? _normalizeKey(String? raw) {
  if (raw == null) return null;
  final String trimmed = raw.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Normalise une collection de clés : rognage, retrait des vides, déduplication
/// et **ordre canonique** (l'ordre de saisie n'est pas une information).
List<String> _normalizeKeys(Iterable<String> raw) {
  final Set<String> seen = <String>{};
  for (final String key in raw) {
    final String? normalized = _normalizeKey(key);
    if (normalized != null) seen.add(normalized);
  }
  return seen.toList()..sort();
}

/// Normalise une collection de sélecteurs : retrait des doublons, ordre
/// canonique (par famille puis par clés).
List<ZChatCorpusSelector> _normalize(Iterable<ZChatCorpusSelector> raw) {
  final List<ZChatCorpusSelector> out = <ZChatCorpusSelector>[];
  for (final ZChatCorpusSelector selector in raw) {
    if (!out.contains(selector)) out.add(selector);
  }
  out.sort((ZChatCorpusSelector a, ZChatCorpusSelector b) {
    final int byType = (a.sourceType ?? '').compareTo(b.sourceType ?? '');
    if (byType != 0) return byType;
    return a.corpusKeys.join(' ').compareTo(b.corpusKeys.join(' '));
  });
  return out;
}
