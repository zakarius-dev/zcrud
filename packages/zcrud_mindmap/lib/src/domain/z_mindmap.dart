/// Carte mentale canonique `ZMindmap` (Story E10-1, FR-19).
///
/// origine: lex_core (module « Étude ») — unifie `Mindmap.nodes` (forêt) et
/// `LexiaMindmap.root` (mono-racine, cas dégénéré). Forêt titrée dans un
/// container/dossier ; multi-racine autorisé.
///
/// **INVARIANT DUR (AD-16) : `ZMindmap` NE PORTE NI `updatedAt` NI
/// `isDeleted`/`is_deleted` dans l'entité.** Les métadonnées de sync sont
/// **HORS-ENTITÉ**, portées par `ZSyncMeta` (déjà dans `zcrud_core`), gérées
/// par le store/dépôt (E5), hors périmètre de cette story.
///
/// Mixe `ZExtensible` (slots AD-4 au niveau carte) ; réutilise le cœur (AD-1).
library;

import 'package:zcrud_core/domain.dart';

import 'z_mindmap_node.dart';
import 'z_mindmap_tree_ops.dart';

/// Carte mentale immuable : forêt de [nodes] racines titrée dans un container.
///
/// ## Conformité `ZEntity` (CR-LEX-14)
///
/// `ZMindmap` était la **seule** entité persistable du dossier d'étude à ne pas
/// étendre [ZEntity] (`ZExam`, `ZStudyFolder`, `ZStudyDocument`, `ZSmartNote`…
/// le font toutes). Or **toute** la chaîne de persistance est bornée
/// `T extends ZEntity` : `buildFolderScopedStudyRepository`, `ZStudyRepository`,
/// `ZLocalStore`, `HiveZLocalStore`. La carte mentale était donc **statiquement
/// exclue** du noyau de persistance, et chaque hôte devait redécouvrir et
/// réécrire un adaptateur d'entité — avec le risque que deux hôtes enveloppent
/// **différemment** et produisent des documents incompatibles entre eux.
///
/// ⚠️ **[id] reste `String` NON-NULLABLE** : Dart autorise une sous-classe à
/// **restreindre** le type de retour d'un getter (`String` est un sous-type de
/// `String?`). La conformité au contrat n'exige donc **aucune rupture** pour le
/// code existant — contrairement à ce qu'un passage en `String?` aurait imposé.
/// [isEphemeral] est en revanche redéfini : le défaut hérité (`id == null`) ne
/// pourrait jamais être vrai ici, alors que la chaîne **vide** est précisément
/// le marqueur d'absence d'identité de cette entité (cf. `fromJson`).
/// Sentinelle de [ZMindmap.copyWithPreservingTree] : distingue « paramètre non
/// fourni » de « mets explicitement à `null` ». Pendant local de la `_$undefined`
/// que le générateur émet pour les entités annotées.
const Object _$undefinedMindmap = _ZUndefinedMindmap();

class _ZUndefinedMindmap {
  const _ZUndefinedMindmap();
}

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
        // 🔴 DW-ES22-3 (ES-2.2b) : la garde partagée, dès la CONSTRUCTION.
        // Ce constructeur est **non-`const`** ⇒ il PEUT filtrer (contrairement à
        // `ZRepetitionInfo`). Ce n'est PAS un `assert` (AD-10 l'interdirait) :
        // c'est un dépouillement SILENCIEUX et TOTAL — la désérialisation d'une
        // donnée corrompue ne throw JAMAIS.
        extra = _sanitizeExtra(extra);

  /// Identifiant opaque de la carte (non-null — cf. note de conformité).
  @override
  final String id;

  /// `true` tant que la carte n'a pas d'identité (CR-LEX-14).
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

  /// Copie en **préservant les champs qui ne sont PAS l'arbre** (CR-LEX-29).
  ///
  /// ## Pourquoi cette méthode existe, et pourquoi elle exclut `nodes`
  ///
  /// `ZMindmap` était la SEULE entité du dépôt sans `copyWith` — mesuré :
  /// `ZExam`, `ZStudyFolder`, `ZStudyDocument` en ont un, `ZMindmap` zéro. Le
  /// motif documenté (« la mutation passe EXCLUSIVEMENT par
  /// `ZMindmapTreeOps` ») protège la cohérence de l'**arbre**, et il reste
  /// valable : `nodes` n'est **pas** un paramètre ici.
  ///
  /// Mais il ne devrait pas interdire de préserver ce qui **n'est pas l'arbre**.
  /// Un hôte qui reconstruisait la carte champ par champ perdait
  /// `description`, `extension` et `extra` à chaque sauvegarde — dont le slot
  /// d'extension AD-4, celui qui porte les données d'un **autre** hôte.
  ///
  /// ⚠️ **Sentinelle obligatoire** : `description` et `extension` sont
  /// nullables. Sans elle, `copyWith()` ne saurait pas distinguer « non
  /// fourni » de « mets à `null` », et effacerait ce qu'il prétend préserver —
  /// le défaut même qu'il corrige. Les entités générées utilisent la même
  /// (`_$undefined`, émise par le codegen) ; celle-ci est déclarée à la main
  /// parce que `zcrud_mindmap` est hors codegen.
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
  /// dans [extra] ni ré-émises par [toJson]. Garantit l'invariant AD-16 sur le
  /// chemin `fromJson→toJson`, même si la map d'entrée mêle des métadonnées de
  /// sync (le store est seul responsable de ces clés, hors périmètre E10-1).
  ///
  /// **AD-19 (ES-1.3)** — alias de la **définition machine unique**
  /// `ZSyncMeta.reservedKeys` (`zcrud_core`) : plus aucun littéral redéclaré ici
  /// (solde la dette DW-ES13-1). Si `ZSyncMeta` gagne une clé réservée, ce site
  /// la reprend automatiquement — plus de dérive silencieuse possible.
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
      // CR-LEX-33 : ce ternaire rendait `null` dès qu'aucun décodeur n'était
      // fourni. Comme `extension` est une clé CONNUE (donc exclue d'`extra`),
      // le payload d'un AUTRE hôte était DÉTRUIT au décodage. Le cœur préserve
      // désormais verbatim ce que personne n'a su typer.
      extension: zDecodeExtension(json['extension'], extensionDecoder),
      extra: extra,
    );
  }

  /// Sérialise en clés **snake_case**. `description` omise si `null` ; [extra]
  /// réinjecté tel quel.
  ///
  /// **INVARIANT AD-16** : n'écrit NI `updated_at` NI `is_deleted`.
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'folder_id': folderId,
        'title': title,
        if (description != null) 'description': description,
        'nodes': nodes.map((n) => n.toJson()).toList(),
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
