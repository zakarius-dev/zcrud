/// Carte mentale canonique `ZMindmap` : forêt de nœuds titrée dans un
/// container/dossier, multi-racine autorisée.
///
/// **Invariant dur (invariant AD-9, offline-first)** : `ZMindmap` ne porte
/// ni `updatedAt` ni `isDeleted`/`is_deleted` dans l'entité. Les métadonnées
/// de synchronisation sont **hors-entité**, portées par `ZSyncMeta` (déjà
/// dans `zcrud_core`), gérées par le store/dépôt.
///
/// Mixe `ZExtensible` (slots d'extension au niveau carte, invariant AD-4) ;
/// réutilise le cœur (invariant AD-1).
library;

import 'package:zcrud_core/domain.dart';

import 'z_mindmap_node.dart';
import 'z_mindmap_tree_ops.dart';

/// Sentinelle de [ZMindmap.copyWithPreservingTree] : distingue « paramètre
/// non fourni » de « mets explicitement à `null` ». Pendant local du
/// marqueur d'indéfini que le générateur émet pour les entités annotées.
const Object _$undefinedMindmap = _ZUndefinedMindmap();

class _ZUndefinedMindmap {
  const _ZUndefinedMindmap();
}

/// Carte mentale immuable : forêt de [nodes] racines titrée dans un
/// container.
///
/// Étend [ZEntity] au même titre que les autres entités persistables du
/// domaine étude, ce qui la rend directement compatible avec la chaîne de
/// persistance générique bornée `T extends ZEntity` (dépôt, store local).
///
/// [id] reste `String` non-nullable : Dart autorise une sous-classe à
/// restreindre le type de retour d'un getter (`String` est un sous-type de
/// `String?`), donc aucune rupture n'est imposée au code existant.
/// [isEphemeral] est en revanche redéfini : le défaut hérité (`id == null`)
/// ne pourrait jamais être vrai ici, alors que la chaîne **vide** est
/// précisément le marqueur d'absence d'identité de cette entité (voir
/// `fromJson`).
class ZMindmap extends ZEntity with ZExtensible {
  /// Construit une carte immuable. [nodes] est copié défensivement en liste
  /// non-modifiable.
  ZMindmap({
    required this.id,
    required this.folderId,
    this.title = '',
    this.description,
    List<ZMindmapNode> nodes = const <ZMindmapNode>[],
    this.extension,
    Map<String, dynamic> extra = const <String, dynamic>{},
  })  : nodes = List<ZMindmapNode>.unmodifiable(nodes),
        // La garde partagée s'applique dès la CONSTRUCTION. Ce constructeur
        // est **non-`const`** ⇒ il PEUT filtrer. Ce n'est PAS un `assert`
        // (invariant AD-10 l'interdirait) : c'est un dépouillement SILENCIEUX
        // et TOTAL — la désérialisation d'une donnée corrompue ne throw JAMAIS.
        extra = _sanitizeExtra(extra);

  /// Identifiant opaque de la carte (non-null — cf. note de conformité).
  @override
  final String id;

  /// `true` tant que la carte n'a pas d'identité.
  ///
  /// Redéfini : le défaut hérité de [ZEntity] teste `id == null`, impossible ici
  /// puisque [id] est non-nullable. Le marqueur d'absence d'identité de cette
  /// entité est la **chaîne vide** — c'est le repli de `fromJson` sur un `id`
  /// absent ou corrompu.
  @override
  bool get isEphemeral => id.isEmpty;

  /// Dossier/container (clé de sous-collection + filtrage stream), non-null.
  final String folderId;

  /// Titre de la carte ; vide → défaut UI.
  final String title;

  /// Description longue optionnelle (`null` = absente).
  final String? description;

  /// Racines de la forêt (multi-racine autorisé). Liste non-modifiable.
  final List<ZMindmapNode> nodes;

  /// Slot type additif versionné (AD-4), `null` si absent.
  @override
  final ZExtension? extension;

  /// Échappatoire non typée (AD-4), défaut `const {}`, jamais `null`.
  @override
  final Map<String, dynamic> extra;

  /// Copie en **préservant les champs qui ne sont PAS l'arbre**.
  ///
  /// ## Pourquoi cette méthode existe, et pourquoi elle exclut `nodes`
  ///
  /// `ZMindmap` n'expose pas de `copyWith` généraliste : le motif documenté
  /// (« la mutation passe EXCLUSIVEMENT par `ZMindmapTreeOps` ») protège la
  /// cohérence de l'**arbre**, donc `nodes` n'est **pas** un paramètre ici.
  ///
  /// Mais cela ne devrait pas interdire de préserver ce qui **n'est pas
  /// l'arbre**. Un hôte qui reconstruirait la carte champ par champ sans
  /// cette méthode perdrait `description`, `extension` et `extra` à chaque
  /// sauvegarde — dont le slot d'extension (invariant AD-4), celui qui porte
  /// les données d'un **autre** hôte.
  ///
  /// **Sentinelle obligatoire** : `description` et `extension` sont
  /// nullables. Sans elle, `copyWith()` ne saurait pas distinguer « non
  /// fourni » de « mets à `null` », et effacerait ce qu'il prétend préserver —
  /// le défaut même qu'il corrige. Les entités générées utilisent la même
  /// sentinelle (`_$undefined`, émise par le codegen) ; celle-ci est déclarée
  /// à la main parce que `zcrud_mindmap` est hors codegen.
  ZMindmap copyWithPreservingTree({
    Object? id = _$undefinedMindmap,
    Object? folderId = _$undefinedMindmap,
    Object? title = _$undefinedMindmap,
    Object? description = _$undefinedMindmap,
    Object? extension = _$undefinedMindmap,
    Object? extra = _$undefinedMindmap,
  }) {
    return ZMindmap(
      id: identical(id, _$undefinedMindmap) ? this.id : id! as String,
      folderId: identical(folderId, _$undefinedMindmap)
          ? this.folderId
          : folderId! as String,
      title:
          identical(title, _$undefinedMindmap) ? this.title : title! as String,
      description: identical(description, _$undefinedMindmap)
          ? this.description
          : description as String?,
      // `nodes` est repris TEL QUEL : l'arbre ne se modifie que par TreeOps.
      nodes: nodes,
      extension: identical(extension, _$undefinedMindmap)
          ? this.extension
          : extension as ZExtension?,
      // Le constructeur re-dépouille `extra` : l'opération est idempotente.
      extra: identical(extra, _$undefinedMindmap)
          ? this.extra
          : (extra as Map<String, dynamic>?) ?? const <String, dynamic>{},
    );
  }

  /// Remplace **la forêt entière** en préservant **tous les autres champs**.
  ///
  /// C'est le dernier maillon de la chaîne d'édition de l'arbre :
  /// [ZMindmapTreeOps] rend une `List<ZMindmapNode>`, et cette méthode est ce
  /// qui la repose dans l'entité. Sans elle, un appelant qui vient de produire
  /// une nouvelle forêt n'aurait que le constructeur nominal, où il devrait
  /// réénumérer chaque champ à la main — et perdrait `description`,
  /// `extension` ou `extra` au premier oubli, puis à chaque champ ajouté
  /// ensuite au cœur.
  ///
  /// ## L'invariant de l'arbre tient par la PROVENANCE, pas par l'absence
  ///
  /// Le motif « la mutation de l'arbre passe par [ZMindmapTreeOps] » reste la
  /// règle. [nodes] doit donc être **une sortie de [ZMindmapTreeOps]** — ou une
  /// forêt que l'appelant a construite lui-même en assumant sa cohérence
  /// (`level` en cascade depuis 0, identifiants uniques). Ce contrat porte sur
  /// ce que l'appelant fournit, pas sur ce que la signature interdit.
  ///
  /// ## Ce que la méthode garantit
  ///
  /// - **Préservation par construction** de `id`, `folderId`, `title`,
  ///   `description`, `extension` et `extra` — y compris les slots nullables,
  ///   sans sentinelle nécessaire puisque rien d'autre que l'arbre ne bouge.
  /// - **Normalisation identique au constructeur nominal** : la liste rendue
  ///   par [ZMindmap.nodes] est une copie **non-modifiable**. Les `level` ne
  ///   sont **pas** renormalisés (le constructeur ne le fait pas non plus —
  ///   seule [ZMindmap.fromJson] renormalise, parce qu'elle lit une donnée
  ///   dont la cohérence n'est pas garantie).
  /// - Une liste **vide** est admise : elle vide la carte de ses racines.
  ///
  /// Pour changer autre chose que l'arbre, utiliser [copyWithPreservingTree].
  ZMindmap withNodes(List<ZMindmapNode> nodes) {
    return ZMindmap(
      id: id,
      folderId: folderId,
      title: title,
      description: description,
      nodes: nodes,
      extension: extension,
      extra: extra,
    );
  }

  /// Clés **connues** du cœur (le reste alimente [extra]).
  static const Set<String> _knownKeys = <String>{
    'id',
    'folder_id',
    'title',
    'description',
    'nodes',
    'extension',
  };

  /// Clés de sync **réservées** (`ZSyncMeta`, hors-entité) : JAMAIS capturées
  /// dans [extra] ni ré-émises par [toJson]. Garantit l'invariant AD-9 sur le
  /// chemin `fromJson→toJson`, même si la map d'entrée mêle des métadonnées de
  /// sync (le store est seul responsable de ces clés).
  ///
  /// Alias de la **définition machine unique** `ZSyncMeta.reservedKeys`
  /// (`zcrud_core`) : aucun littéral redéclaré ici. Si `ZSyncMeta` gagne une
  /// clé réservée, ce site la reprend automatiquement — plus de dérive
  /// silencieuse possible.
  static const Set<String> _reservedSyncKeys = ZSyncMeta.reservedKeys;

  /// Ensemble **RÉSERVÉ** complet de l'entité = clés **connues** ∪ clés de
  /// **sync** — l'argument de la garde partagée [_sanitizeExtra].
  ///
  /// Cette entité n'a **ni `$Z…FieldSpecs`** (pas de `@ZcrudModel`) **ni**
  /// `_reservedKeys` : son ensemble réservé se **compose** de [_knownKeys] et de
  /// [_reservedSyncKeys]. Patron **adapté**, pas recopié.
  static const Set<String> _reservedKeys = <String>{
    ..._knownKeys,
    ..._reservedSyncKeys,
  };

  /// **LA GARDE PARTAGÉE DE `extra`** — appelée par [fromJson] (via
  /// l'initializer du constructeur) **ET** par [toJson].
  ///
  /// **DEUX sites, et pas de `copyWith`** : cette entité n'expose **aucun**
  /// `copyWith` public (la mutation passe EXCLUSIVEMENT par `ZMindmapTreeOps`).
  /// Sa voie d'écriture publique de `extra` est donc le **CONSTRUCTEUR NOMINAL**
  /// — qui, lui, est **non-`const`** et **PEUT** filtrer dans son initializer.
  ///
  /// Mais l'initializer **ne suffit pas** à porter la promesse : c'est
  /// [toJson], **frontière de SORTIE**, qui la rend **INCONDITIONNELLE**. Sans
  /// cette seconde garde, `ZMindmap(…, extra: {updated_at: …, is_deleted:
  /// true}).toJson()` réémettrait les DEUX clés — en contradiction directe
  /// avec l'invariant AD-9 (« n'écrit NI `updated_at` NI `is_deleted` »).
  ///
  /// **Particularité de cette entité** : son [toJson] étale `...extra` **EN
  /// DERNIER** (l'inverse des entités codegen) ⇒ un `extra` pollué
  /// **ÉCRASERAIT** jusqu'aux clés connues sans cette garde. Elle couvre donc
  /// les deux ensembles (`_knownKeys` ∪ sync).
  static Map<String, dynamic> _sanitizeExtra(Map<String, dynamic> raw) =>
      zSanitizeExtra(raw, _reservedKeys);

  /// Désérialisation **défensive** (invariant AD-10) : ne **throw JAMAIS**.
  ///
  /// - `id`/`folder_id` absent/non-`String` → `''` ;
  /// - `title` absent/non-`String` → `''` (défaut UI) ;
  /// - `description` absent/non-`String` → `null` ;
  /// - `nodes` absent/non-liste → `[]` ; racines corrompues ignorées ;
  /// - `level` incohérent des nœuds **renormalisé** (racines → 0, cascade) via
  ///   `ZMindmapTreeOps.normalizeLevels` ;
  /// - `extension` via [extensionDecoder] sous `ZExtension.guard` ;
  /// - clés résiduelles inconnues → préservées dans [extra].
  ///
  /// Persistance en clés **snake_case** (`folder_id`), canonique §5.
  factory ZMindmap.fromJson(
    Map<String, dynamic> json, {
    ZExtensionDecoder? extensionDecoder,
  }) {
    final rawNodes = json['nodes'];
    final nodes = <ZMindmapNode>[];
    if (rawNodes is List) {
      for (final node in rawNodes) {
        if (node is Map<String, dynamic>) {
          nodes.add(
            ZMindmapNode.fromJson(node, extensionDecoder: extensionDecoder),
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

    return ZMindmap(
      id: json['id'] is String ? json['id'] as String : '',
      folderId: json['folder_id'] is String ? json['folder_id'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      description:
          json['description'] is String ? json['description'] as String : null,
      // Renormalise les `level` : ne jamais faire confiance aux valeurs
      // persistées (cache fragile), racines forcées à 0 puis cascade.
      nodes: ZMindmapTreeOps.normalizeLevels(nodes),
      // Un ternaire naïf rendrait `null` dès qu'aucun décodeur n'est fourni.
      // Comme `extension` est une clé CONNUE (donc exclue d'`extra`), le
      // payload d'un AUTRE hôte serait alors DÉTRUIT au décodage. Le cœur
      // préserve donc verbatim ce que personne n'a su typer.
      extension: zDecodeExtension(json['extension'], extensionDecoder),
      extra: extra,
    );
  }

  /// Sérialise en clés **snake_case**. `description` omise si `null` ; [extra]
  /// réinjecté tel quel.
  ///
  /// **Invariant AD-9** : n'écrit NI `updated_at` NI `is_deleted`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'folder_id': folderId,
        'title': title,
        if (description != null) 'description': description,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        if (extension != null) 'extension': extension!.toJson(),
        // Étale [extra] **tel quel** : le constructeur (NON-`const`) l'a déjà
        // dépouillé, et c'est la SEULE voie d'écriture publique de cette
        // entité (aucun `copyWith` : la mutation passe par TreeOps). Un
        // second `_sanitizeExtra(extra)` ICI serait redondant avec la garde
        // de l'initializer du constructeur, mais celle-ci reste
        // indispensable : la retirer romprait l'invariant sur ce chemin.
        ...extra,
      };
}
