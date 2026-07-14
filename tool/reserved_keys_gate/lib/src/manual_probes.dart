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
    // Aucun `copyWith` ⇒ reconstruction NOMINALE (la voie que l'app emprunte).
    // ⚠️ `x` est passé **VERBATIM** — la règle AST (k) l'exige (MAJEUR-2).
    writes: <ZExtraWriter>[
      ZExtraWriter(
        voie: 'ctor',
        eagerlyNormalized: true, // ctor NON-`const` ⇒ il filtre (initializer).
        write: _ctorMindmap,
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
];

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
