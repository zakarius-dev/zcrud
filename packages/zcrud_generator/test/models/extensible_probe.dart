/// Modèles de PREUVE du **garde exécutoire DW-ES14-1** (H1, code-review ES-2.0)
/// — test-only, PAS un package produit.
///
/// ## Pourquoi ces deux modèles existent (R2 — fixture ISOLÉE PAR RÈGLE)
///
/// Le contrat de **BUILD** (`_requireDomainFromMap`) ne juge que la **FORME** du
/// décodeur : signature compatible, et — sur une classe `ZExtensible` — refus de
/// la **délégation nue** `=> _$XxxFromMap(map)`. Il ne peut PAS prouver qu'un
/// corps ré-écrit à la main peuple réellement `extra`.
///
/// [ProbeDropper] est exactement ce trou : sa factory **N'EST PAS** une délégation
/// nue (le contrat de build la laisse donc passer, et c'est **voulu** — sinon
/// cette fixture prouverait la mauvaise règle), mais elle **omet `extra:`**. Seul
/// le **garde RUNTIME** émis dans `registerProbeDropper` peut la faire rougir :
/// c'est le filet qui **OBSERVE le POUVOIR** au lieu de juger une forme, et le
/// seul qui suive les packages **publiés** chez un consommateur externe (lequel
/// n'a pas `tool/reserved_keys_gate`).
///
/// [ProbeKeeper] est son **témoin** : même schéma, même forme de factory, mais
/// `extra: _extraFrom(map)` — son registrar passe. La paire prouve donc que le
/// garde **discrimine** (il ne rougit pas sur tout, il rougit sur le défaut).
library;

import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

part 'extensible_probe.g.dart';

/// Clés persistées réservées, dérivées des `ZFieldSpec` du modèle + AD-19.1.
Map<String, dynamic> _extraFrom(
  Map<String, dynamic> map,
  Set<String> reservedKeys,
) =>
    Map<String, dynamic>.unmodifiable(<String, dynamic>{
      for (final e in map.entries)
        if (!reservedKeys.contains(e.key)) e.key: e.value,
    });

/// ✅ TÉMOIN — `ZExtensible` **conforme sur les DEUX jambes** (patron `ZFlashcard`) :
/// `fromMap` peuple `extra`, et `toMap()` d'instance **étale `...extra`**.
@ZcrudModel(kind: 'probe_keeper')
class ProbeKeeper with ZExtensible {
  /// Construit le témoin.
  const ProbeKeeper({
    required this.title,
    this.extra = const <String, dynamic>{},
  });

  /// Décodeur de DOMAINE **conforme** : champs du schéma via le codegen, PUIS
  /// les clés hors-schéma dans `extra` (AD-4).
  factory ProbeKeeper.fromMap(Map<String, dynamic> map) {
    final base = _$ProbeKeeperFromMap(map);
    return ProbeKeeper(title: base.title, extra: _extraFrom(map, _reservedKeys));
  }

  /// Champ de schéma.
  @ZcrudField()
  final String title;

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ProbeKeeperFieldSpecs) spec.name,
    ...ZSyncMeta.reservedKeys,
  };

  /// Encodage **conforme** : l'échappatoire est réémise (masque l'extension
  /// générée, qui n'étale PAS `extra`).
  Map<String, dynamic> toMap() => <String, dynamic>{
        ...extra,
        ...ProbeKeeperZcrud(this).toMap(),
      };
}

/// ⛔ CONTRE-EXEMPLE PERMANENT n°1 — jambe **ENTRÉE** : `fromMap` DÉTRUIT `extra`.
///
/// ⚠️ **Ne PAS « réparer » ce modèle** : il est fautif **par conception**. Sa
/// factory est le mode de destruction exact de DW-ES14-1 vu depuis l'entrée
/// (`fromMap` amnésique), sous une forme que le contrat de build **ne peut pas**
/// voir (ce n'est pas une délégation nue : le corps recopie les champs à la main).
/// `registerProbeDropper(registry)` DOIT lever un `StateError` — c'est la preuve
/// que le garde runtime MORD.
///
/// **Isolée par règle (R2)** : sa jambe de SORTIE est CORRECTE (`toMap()` étale
/// `...extra`) — seule la jambe d'entrée peut la faire rougir.
@ZcrudModel(kind: 'probe_dropper')
class ProbeDropper with ZExtensible {
  /// Construit le contre-exemple.
  const ProbeDropper({
    required this.title,
    this.extra = const <String, dynamic>{},
  });

  /// ⛔ Décodeur IMPOTENT : recopie les champs du schéma… et **oublie `extra:`**.
  /// Toute clé métier inconnue est perdue dès le décodage.
  factory ProbeDropper.fromMap(Map<String, dynamic> map) {
    final base = _$ProbeDropperFromMap(map);
    return ProbeDropper(title: base.title); // ⛔ `extra` reste VIDE
  }

  /// Champ de schéma.
  @ZcrudField()
  final String title;

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  /// ✅ Jambe de SORTIE conforme (isolation R2).
  Map<String, dynamic> toMap() => <String, dynamic>{
        ...extra,
        ...ProbeDropperZcrud(this).toMap(),
      };
}

/// ⛔ CONTRE-EXEMPLE PERMANENT n°2 — jambe **SORTIE** : `toMap` ne réémet pas `extra`.
///
/// ⚠️ **Ne PAS « réparer » ce modèle** : fautif par conception. Il décode
/// correctement (`extra` peuplé) mais s'appuie sur le `toMap()` **GÉNÉRÉ**, qui
/// n'étale PAS `extra` — c'est le mode de destruction de DW-ES14-1 vu depuis la
/// **sortie** (`decode` correct, `encode` amnésique), celui-là même que la fixture
/// `_ExtraDroppingEntity` du harnais épingle pour l'assertion (e).
///
/// Il est ici épinglé **DANS LE CODE GÉNÉRÉ** — donc chez tout consommateur du
/// package publié, harnais ou pas. `registerProbeEncodeDropper(registry)` DOIT
/// lever un `StateError`.
///
/// **Isolée par règle (R2)** : sa jambe d'ENTRÉE est CORRECTE (`fromMap` peuple
/// `extra`) — seule la jambe de sortie peut la faire rougir.
@ZcrudModel(kind: 'probe_encode_dropper')
class ProbeEncodeDropper with ZExtensible {
  /// Construit le contre-exemple.
  const ProbeEncodeDropper({
    required this.title,
    this.extra = const <String, dynamic>{},
  });

  /// ✅ Jambe d'ENTRÉE conforme (isolation R2).
  factory ProbeEncodeDropper.fromMap(Map<String, dynamic> map) {
    final base = _$ProbeEncodeDropperFromMap(map);
    return ProbeEncodeDropper(
      title: base.title,
      extra: _extraFrom(map, _reservedKeys),
    );
  }

  /// Champ de schéma.
  @ZcrudField()
  final String title;

  @override
  final Map<String, dynamic> extra;

  @override
  ZExtension? get extension => null;

  static final Set<String> _reservedKeys = <String>{
    for (final spec in $ProbeEncodeDropperFieldSpecs) spec.name,
    ...ZSyncMeta.reservedKeys,
  };

  // ⛔ AUCUN `toMap()` d'instance : le registrar câble le `toMap()` GÉNÉRÉ
  //    (extension `ProbeEncodeDropperZcrud`), qui n'étale PAS `...extra`.
}
