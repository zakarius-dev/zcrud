/// Nœud canonique de carte mentale `ZMindmapNode` (Story E10-1, FR-19).
///
/// origine: lex_core (module « Étude ») — `MindmapNode`
/// (`lexia_mindmap.dart:22-41`). Arbre récursif par **NESTING** (jamais par
/// adjacency) + cache de profondeur dénormalisé `level`. Immuable par
/// convention : **aucun `copyWith` public**, la mutation passe EXCLUSIVEMENT
/// par `ZMindmapTreeOps` (canonique §2.2).
///
/// Réutilise les contrats du cœur (AD-1) : étend `ZNode` (clé `id` non-null de
/// réconciliation) et mixe `ZExtensible` (slots AD-4 : `extension`/`extra`).
library;

import 'package:zcrud_core/domain.dart';

/// Décodeur défensif OPTIONNEL d'une `ZExtension` concrète depuis sa map JSON.
///
/// Les sous-classes concrètes de [ZExtension] vivent dans l'app hôte / les
/// stories ultérieures (audio/sources/RAG/confiance), **jamais** dans le cœur.
/// L'appelant qui sait les reconstruire fournit ce décodeur ; l'absence de
/// décodeur laisse `extension` à `null`. Toute exception du décodeur est
/// absorbée (`ZExtension.guard`, AD-10).
typedef ZExtensionDecoder = ZExtension? Function(Map<String, dynamic> json);

/// Nœud d'arbre de carte mentale, **immuable par convention**.
///
/// - topologie par [children] imbriqués (nesting) ;
/// - [level] = cache de profondeur dénormalisé (racine = 0), **recalculé
///   systématiquement** par `ZMindmapTreeOps` à chaque reparentage (ne jamais
///   faire confiance au `level` d'un nœud déplacé) ;
/// - [content] = texte **brut** multiligne (PAS markdown — le rendu riche est
///   une extension pluggable, hors E10-1) ;
/// - slots d'extension AD-4 via `ZExtensible` ([extension] versionnée + [extra]
///   échappatoire non typée, round-trip des clés inconnues du cœur).
class ZMindmapNode extends ZNode with ZExtensible {
  /// Construit un nœud immuable. [children] est **copié défensivement** en liste
  /// non-modifiable : aucune mutation externe ne peut affecter le nœud.
  ZMindmapNode({
    required this.id,
    this.label = '',
    this.content,
    this.level = 0,
    List<ZMindmapNode> children = const <ZMindmapNode>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  })  : children = List<ZMindmapNode>.unmodifiable(children),
        // 🔴 DW-ES22-3 (ES-2.2b) : la garde partagée, dès la CONSTRUCTION
        // (constructeur **non-`const`** ⇒ il PEUT filtrer). Dépouillement
        // SILENCIEUX, jamais un `assert` (AD-10).
        extra = _sanitizeExtra(extra);

  /// Clé de réconciliation opaque (non-null, contrat `ZNode`).
  @override
  final String id;

  /// Titre court mono-ligne ; vide → défaut UI.
  final String label;

  /// Contenu long multiligne en **texte brut** (`null` = absent).
  final String? content;

  /// Enfants imbriqués (topologie par nesting). Liste non-modifiable.
  final List<ZMindmapNode> children;

  /// Cache de profondeur dénormalisé (racine = 0).
  final int level;

  /// Slot type additif versionné (AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4), défaut `const {}`, jamais `null`. Préserve
  /// les clés inconnues du cœur au round-trip.
  @override
  final Map<String, dynamic> extra;

  /// Ensemble des clés **connues** du cœur (le reste alimente [extra]).
  static const Set<String> _knownKeys = <String>{
    'id',
    'label',
    'content',
    'level',
    'children',
    'extension',
  };

  /// Clés de sync **réservées** (`ZSyncMeta`, hors-entité) : JAMAIS capturées
  /// dans [extra] ni ré-émises par [toJson]. Garantit l'invariant AD-16 sur le
  /// chemin `fromJson→toJson`, même si une map d'entrée mêle des métadonnées de
  /// sync (le store est seul responsable de ces clés, hors périmètre E10-1).
  ///
  /// **AD-19 (ES-1.3)** — alias de la **définition machine unique**
  /// `ZSyncMeta.reservedKeys` (`zcrud_core`) : plus aucun littéral redéclaré ici
  /// (solde la dette DW-ES13-1).
  static const Set<String> _reservedSyncKeys = ZSyncMeta.reservedKeys;

  /// Ensemble **RÉSERVÉ** complet de l'entité = clés **connues** ∪ clés de
  /// **sync** — l'argument de la garde partagée [_sanitizeExtra].
  ///
  /// ⚠️ Cette entité n'a **ni `$Z…FieldSpecs`** (pas de `@ZcrudModel`) **ni**
  /// `_reservedKeys` : son ensemble réservé se **compose** de [_knownKeys] et de
  /// [_reservedSyncKeys]. Patron **adapté**, pas recopié.
  static const Set<String> _reservedKeys = <String>{
    ..._knownKeys,
    ..._reservedSyncKeys,
  };

  /// 🔴 **LA GARDE PARTAGÉE DE `extra`** (DW-ES22-3, ES-2.2b) — appelée par
  /// [fromJson] (via l'initializer du constructeur) **ET** par [toJson].
  ///
  /// ⚠️ **DEUX sites, et pas de `copyWith`** : cette entité n'expose **aucun**
  /// `copyWith` public (la mutation passe EXCLUSIVEMENT par `ZMindmapTreeOps`).
  /// Sa voie d'écriture publique de `extra` est donc le **CONSTRUCTEUR NOMINAL**
  /// — qui, lui, est **non-`const`** et **PEUT** filtrer dans son initializer.
  ///
  /// ⛔ Mais l'initializer **ne suffit pas** à porter la promesse : c'est [toJson],
  /// **frontière de SORTIE**, qui la rend **INCONDITIONNELLE**. **MESURÉ** avant
  /// correctif : `ZMindmap(…, extra: {updated_at: …, is_deleted: true}).toJson()`
  /// réémettait les DEUX clés — en **contradiction directe** avec sa propre
  /// dartdoc (« INVARIANT AD-16 : n'écrit NI `updated_at` NI `is_deleted` »).
  ///
  /// 🔴 **Aggravant, propre à cette entité** : son [toJson] étale `...extra` **EN
  /// DERNIER** (l'inverse des entités codegen) ⇒ un `extra` pollué **ÉCRASAIT**
  /// jusqu'aux clés connues. La garde couvre les deux (`_knownKeys` ∪ sync).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  /// Désérialisation **défensive** (AD-10) : ne **throw JAMAIS**.
  ///
  /// - `id` absent/non-`String` → `''` (nœud non invalidé) ;
  /// - `label` absent/non-`String` → `''` (défaut UI) ;
  /// - `content` absent/non-`String` → `null` ;
  /// - `level` absent/non-`int` → `0` (normalisé au niveau forêt par
  ///   `ZMindmapTreeOps.normalizeLevels`) ;
  /// - `children` absent/non-liste → `[]` ; enfants corrompus ignorés
  ///   défensivement ;
  /// - `extension` parsée via [extensionDecoder] sous `ZExtension.guard`
  ///   (`formatVersion` non gérée/corrompue → `null` sans invalider le nœud) ;
  /// - toute clé résiduelle inconnue du cœur → préservée dans [extra].
  factory ZMindmapNode.fromJson(
    Map<String, dynamic> json, {
    ZExtensionDecoder? extensionDecoder,
  }) {
    final rawChildren = json['children'];
    final children = <ZMindmapNode>[];
    if (rawChildren is List) {
      for (final child in rawChildren) {
        if (child is Map<String, dynamic>) {
          children.add(
            ZMindmapNode.fromJson(child, extensionDecoder: extensionDecoder),
          );
        }
      }
    }

    final extra = <String, dynamic>{};
    for (final entry in json.entries) {
      if (!_knownKeys.contains(entry.key) &&
          !_reservedSyncKeys.contains(entry.key)) {
        extra[entry.key] = entry.value;
      }
    }

    return ZMindmapNode(
      id: json['id'] is String ? json['id'] as String : '',
      label: json['label'] is String ? json['label'] as String : '',
      content: json['content'] is String ? json['content'] as String : null,
      level: json['level'] is int ? json['level'] as int : 0,
      children: children,
      // CR-LEX-33 : ce ternaire rendait `null` dès qu'aucun décodeur n'était
      // fourni. Comme `extension` est une clé CONNUE (donc exclue d'`extra`),
      // le payload d'un AUTRE hôte était DÉTRUIT au décodage. Le cœur préserve
      // désormais verbatim ce que personne n'a su typer.
      extension: zDecodeExtension(json['extension'], extensionDecoder),
      extra: extra,
    );
  }

  /// Sérialise en clés **snake_case** (uniformisation canonique §5). `content`
  /// omis si `null` ; [extra] réinjecté tel quel (round-trip des clés inconnues).
  ///
  /// **INVARIANT AD-16** : n'écrit NI `updated_at` NI `is_deleted` (sync
  /// hors-entité `ZSyncMeta`, hors périmètre E10-1).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'label': label,
        if (content != null) 'content': content,
        'level': level,
        'children': children.map((c) => c.toJson()).toList(),
        if (extension != null) 'extension': extension!.toJson(),
        // 🔴 ES-2.2b (remédiation HIGH-1) — étale [extra] **tel quel** : le
        // constructeur (NON-`const`) l'a déjà dépouillé, et c'est la SEULE voie
        // d'écriture publique de cette entité (aucun `copyWith` : la mutation
        // passe par TreeOps). Un `_sanitizeExtra(extra)` ICI serait **DÉCORATIF**
        // — MESURÉ (code-review ES-2.2b, INJ-B) : le retirer laissait le gate
        // **VERT**. La garde vit dans l'initializer du constructeur ; l'en retirer
        // rend (i.1a)/(i.1c) ROUGES.
        ...extra,
      };
}
