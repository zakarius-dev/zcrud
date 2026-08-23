/// SONDES MANUELLES : entités `ZExtensible` **hors registre** (AD-19.1.c pt.1).
///
/// `ZMindmap` et `ZMindmapNode` portent un `extra` (AD-4) mais ne sont **pas**
/// annotées `@ZcrudModel` : leur (dé)sérialisation est **manuelle**
/// (`fromJson`/`toJson`) et aucun `registerZ…` n'existe pour elles. Le volet (A)
/// ne peut donc PAS les atteindre par le registre — elles seraient un **trou
/// silencieux** du gate.
///
/// Elles subissent ici **exactement** les mêmes assertions (a)(b)(c)(d), **sans
/// allowlist** (aucun miroir `updated_at` : la sync des mindmaps est hors-entité
/// depuis l'origine, AD-16).
///
/// ⚠️ Le gate confronte `E_disk` (classes `with ZExtensible` sur disque) à
/// `E_covered` (= kinds câblés ∪ **`className` déclarés ici**) : une nouvelle
/// classe `ZExtensible` non enregistrée et non sondée ⇒ gate **ROUGE**. Le champ
/// [className] est donc LU PAR LE GATE (regex `className: '…'`) : le garder
/// littéral (jamais interpolé).
library;

import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_mindmap/zcrud_mindmap.dart';

import 'assertions.dart';
import 'registrars.dart';

/// Sonde manuelle d'une entité `ZExtensible` non enregistrée.
class ZManualProbe {
  /// Construit une sonde manuelle.
  const ZManualProbe({
    required this.className,
    required this.body,
    required this.decode,
    required this.encode,
    required this.writes,
  });

  /// Nom de la classe sondée — **littéral**, lu par le gate (couverture
  /// `E_disk \ E_covered`).
  final String className;

  /// Corps métier minimal valide (avant pollution par [buildProbe]).
  final Map<String, dynamic> body;

  /// Décodeur défensif de domaine (`fromJson`).
  final Object Function(Map<String, dynamic> map) decode;

  /// Encodeur de domaine (`toJson`).
  final Map<String, dynamic> Function(Object entity) encode;

  /// 🔴 **TOUTES les voies d'écriture publiques de `extra`** (ES-2.2b — assertions
  /// **(i.1)**/**(i.3)**), même contrat que [kExtraWriters] pour les kinds du
  /// registre — et **même contrôle AST** : la règle **(j)** du gate dérive les
  /// voies du **DISQUE** et exige qu'elles figurent **toutes** ici.
  ///
  /// ⚠️ Ces deux entités n'ont **AUCUN `copyWith`** public (*« la mutation passe
  /// EXCLUSIVEMENT par TreeOps »*) : leur SEULE voie est le **CONSTRUCTEUR
  /// NOMINAL** — et elle était **CASSÉE** (mesuré : `toJson()` réémettait
  /// `updated_at` **et** `is_deleted`, en contradiction directe avec la dartdoc
  /// « INVARIANT AD-16 » de leur propre `toJson`). Ce constructeur est
  /// **non-`const`** : il **PEUT** filtrer (et le fait, dans son initializer) ⇒
  /// `eagerlyNormalized: true`.
  final List<ZExtraWriter> writes;
}

/// Sondes manuelles du repo (entités `ZExtensible` **hors registre**).
final List<ZManualProbe> kManualProbes = <ZManualProbe>[
  ZManualProbe(
    className: 'ZMindmap',
    body: const <String, dynamic>{'id': 'm', 'folder_id': 'f'},
    decode: ZMindmap.fromJson,
    encode: (Object e) => (e as ZMindmap).toJson(),
    // Deux voies d'écriture publiques depuis CR-LEX-29.
    // ⚠️ `x` est passé **VERBATIM** — la règle AST (k) l'exige (MAJEUR-2).
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: true, // ctor NON-`const` ⇒ il filtre (initializer).
        write: _ctorMindmap,
      ),
      // CR-LEX-29 : `copyWithPreservingTree` délègue au constructeur, donc au
      // même dépouillement. Le gate l'a exigé de lui-même — il a détecté une
      // voie d'écriture publique de `extra` non sondée, ce qui est exactement
      // son rôle.
      ZExtraWriter(
        voie: 'copyWithPreservingTree',
        eagerlyNormalized: true,
        write: _copyWithMindmap,
      ),
    ],
  ),
  ZManualProbe(
    className: 'ZMindmapNode',
    body: const <String, dynamic>{'id': 'n'},
    decode: ZMindmapNode.fromJson,
    encode: (Object e) => (e as ZMindmapNode).toJson(),
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: true,
        write: _ctorMindmapNode,
      ),
    ],
  ),
  // ═════════════════════════════════════════════════════════════════════════
  // CHAT-0 — `ZChatMessage` / `ZChatConversation` (**`zcrud_chat_kernel`**
  // depuis CHAT-0r : le domaine chat a quitté `zcrud_core`, dont 30 packages sur
  // 31 dépendent, pour son propre satellite — patron du dépôt, aucun domaine
  // MÉTIER dans le cœur).
  //
  // Ni `zcrud_core` ni `zcrud_chat_kernel` n'ont de **codegen** (aucune
  // dépendance de génération, aucun `.g.dart` sous `lib/`) : le cœur ne peut pas
  // en gagner (`zcrud_annotations` dépend de lui, l'inverse serait un CYCLE ⇒
  // `graph_proof` ROUGE) et le kernel s'en tient volontairement à la
  // (dé)sérialisation ÉCRITE À LA MAIN héritée de CHAT-0 (D1).
  // Ces deux entités mixent donc `ZExtensible` **hors registre** : elles
  // tombent EXACTEMENT dans le trou que ce fichier existe pour boucher —
  // sans ces deux sondes, la règle (3) du gate (`E_disk \ E_covered ≠ ∅`)
  // rend `melos run verify` ROUGE.
  //
  // ⚠️ Contrairement à `ZMindmap`, leur constructeur nominal est **`const`** :
  // il ne peut appeler AUCUNE fonction dans son initializer ⇒ il ne filtre
  // RIEN. C'est l'**ACCESSEUR** `extra` (`zNormalizeExtra`) qui porte la
  // garde ⇒ `eagerlyNormalized: false` sur la voie `ctor` (assertion (i.3) :
  // la COPIE à la lecture PROUVE que l'accesseur a réellement travaillé, et
  // démasquerait un writer auto-sanitisant — MAJEUR-2).
  // `copyWith`, lui, sanitise EAGER ⇒ `eagerlyNormalized: true`.
  ZManualProbe(
    className: 'ZChatMessage',
    body: const <String, dynamic>{'id': 'm', 'conversation_id': 'c'},
    decode: ZChatMessage.fromMap,
    encode: (Object e) => (e as ZChatMessage).toMap(),
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: false, // ctor `const` ⇒ l'ACCESSEUR filtre.
        write: _ctorChatMessage,
      ),
      ZExtraWriter(
        voie: 'copyWith',
        eagerlyNormalized: true,
        write: _copyWithChatMessage,
      ),
    ],
  ),
  ZManualProbe(
    className: 'ZChatConversation',
    body: const <String, dynamic>{'id': 'c', 'title': 't'},
    decode: ZChatConversation.fromMap,
    encode: (Object e) => (e as ZChatConversation).toMap(),
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: false, // ctor `const` ⇒ l'ACCESSEUR filtre.
        write: _ctorChatConversation,
      ),
      ZExtraWriter(
        voie: 'copyWith',
        eagerlyNormalized: true,
        write: _copyWithChatConversation,
      ),
    ],
  ),
  // `ZChatRouter` (`zcrud_chat_kernel`, domaine `route/`) : même patron que
  // `ZChatConversation` — ctor `const` (l'ACCESSEUR filtre) et `copyWith`
  // sanitisant EAGER. Entité ZExtensible écrite à la main, hors registre par
  // construction (le kernel n'a pas de codegen) : sans cette sonde, la règle
  // (3) du gate (`E_disk \ E_covered ≠ ∅`) rend `melos run verify` ROUGE.
  ZManualProbe(
    className: 'ZChatRouter',
    body: const <String, dynamic>{'id': 'r', 'name': 'n'},
    decode: ZChatRouter.fromMap,
    encode: (Object e) => (e as ZChatRouter).toMap(),
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: false, // ctor `const` ⇒ l'ACCESSEUR filtre.
        write: _ctorChatRouter,
      ),
      ZExtraWriter(
        voie: 'copyWith',
        eagerlyNormalized: true,
        write: _copyWithChatRouter,
      ),
    ],
  ),
];

Object _copyWithChatRouter(Object e, Map<String, dynamic> x) =>
    (e as ZChatRouter).copyWith(extra: x);

Object _ctorChatRouter(Object e, Map<String, dynamic> x) {
  final ZChatRouter r = e as ZChatRouter;
  return ZChatRouter(
    id: r.id,
    name: r.name,
    description: r.description,
    isActive: r.isActive,
    tier: r.tier,
    model: r.model,
    fallbacks: r.fallbacks,
    computeEffort: r.computeEffort,
    routes: r.routes,
    params: r.params,
    extension: r.extension,
    extra: x,
  );
}

Object _copyWithMindmap(Object e, Map<String, dynamic> x) =>
    (e as ZMindmap).copyWithPreservingTree(extra: x);

Object _ctorMindmap(Object e, Map<String, dynamic> x) {
  final m = e as ZMindmap;
  return ZMindmap(
    id: m.id,
    folderId: m.folderId,
    title: m.title,
    description: m.description,
    nodes: m.nodes,
    extension: m.extension,
    extra: x,
  );
}

// ⚠️ `x` est transmis **VERBATIM** — la règle AST (k) l'exige (un writer qui
// pré-sanitiserait rendrait (i.1) trivialement verte : finding MAJEUR-2).
Object _copyWithChatMessage(Object e, Map<String, dynamic> x) =>
    (e as ZChatMessage).copyWith(extra: x);

Object _ctorChatMessage(Object e, Map<String, dynamic> x) {
  final ZChatMessage m = e as ZChatMessage;
  return ZChatMessage(
    id: m.id,
    conversationId: m.conversationId,
    role: m.role,
    contentBlocks: m.contentBlocks,
    sources: m.sources,
    attachments: m.attachments,
    createdAt: m.createdAt,
    thinking: m.thinking,
    suggestions: m.suggestions,
    feedbackRating: m.feedbackRating,
    feedbackCategory: m.feedbackCategory,
    feedbackComment: m.feedbackComment,
    agentsCalled: m.agentsCalled,
    confidence: m.confidence,
    sourceFreshness: m.sourceFreshness,
    versionKey: m.versionKey,
    extension: m.extension,
    extra: x,
  );
}

Object _copyWithChatConversation(Object e, Map<String, dynamic> x) =>
    (e as ZChatConversation).copyWith(extra: x);

Object _ctorChatConversation(Object e, Map<String, dynamic> x) {
  final ZChatConversation c = e as ZChatConversation;
  return ZChatConversation(
    id: c.id,
    title: c.title,
    createdAt: c.createdAt,
    lastMessageAt: c.lastMessageAt,
    messageCount: c.messageCount,
    pinned: c.pinned,
    pinnedAt: c.pinnedAt,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorMindmapNode(Object e, Map<String, dynamic> x) {
  final n = e as ZMindmapNode;
  return ZMindmapNode(
    id: n.id,
    label: n.label,
    content: n.content,
    level: n.level,
    children: n.children,
    extension: n.extension,
    extra: x,
  );
}
