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

/// Sonde manuelle d'une entité `ZExtensible` non enregistrée.
class ZManualProbe {
  /// Construit une sonde manuelle.
  const ZManualProbe({
    required this.className,
    required this.body,
    required this.decode,
    required this.encode,
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
}

/// Sondes manuelles du repo (entités `ZExtensible` **hors registre**).
final List<ZManualProbe> kManualProbes = <ZManualProbe>[
  ZManualProbe(
    className: 'ZMindmap',
    body: const <String, dynamic>{'id': 'm', 'folder_id': 'f'},
    decode: ZMindmap.fromJson,
    encode: (Object e) => (e as ZMindmap).toJson(),
  ),
  ZManualProbe(
    className: 'ZMindmapNode',
    body: const <String, dynamic>{'id': 'n'},
    decode: ZMindmapNode.fromJson,
    encode: (Object e) => (e as ZMindmapNode).toJson(),
  ),
];
