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

import 'package:zcrud_core/zcrud_core.dart';

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
        extra = Map<String, dynamic>.unmodifiable(extra);

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
  static const Set<String> _reservedSyncKeys = <String>{
    'updated_at',
    'is_deleted',
  };

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
      extension: extensionDecoder == null
          ? null
          : ZExtension.guard<ZExtension?>(() {
              final raw = json['extension'];
              return raw is Map<String, dynamic> ? extensionDecoder(raw) : null;
            }),
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
        ...extra,
      };
}
