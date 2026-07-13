/// CÂBLAGE du volet (A) : registrars, corps de sondes, décodeurs de domaine et
/// allowlist legacy (AD-19.1.c / AD-19.2).
///
/// ## Contrat d'extension (ES-2) — 3 lignes par entité
///
/// Créer une entité study (`ZStudyDocument`, `ZSmartNote`, `ZExam`…) ⇒ ajouter :
///   1. son `registerZXxx` à [kRegistrars] ;
///   2. son corps de sonde minimal valide à [kProbeBodies] ;
///   3. son décodeur de domaine (`ZXxx.fromMap`) à [kDomainDecoders].
///
/// **L'oublier ne passe PAS inaperçu** : `scripts/ci/gate_reserved_keys.dart`
/// confronte l'inventaire du DISQUE (`grep` des `void registerZ…` dans
/// `packages/*/lib/**/*.g.dart`) au câblage de CE fichier et rougit sur
/// `R_disk \ R_wired ≠ ∅` (anti-faux-vert par omission, AD-19.1.c pt.1).
library;

import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
// L'analyzer signale cet import comme « inutile » parce que `zcrud_flashcard`
// RÉEXPORTE le barrel du kernel (AD-18). On le garde EXPLICITE : le harnais
// dépend RÉELLEMENT de `zcrud_study_kernel` (déclaré en `dependencies`), et le
// jour où `zcrud_flashcard` cessera de réexporter le kernel (surface publique en
// cours de resserrage, ES-1.1), l'implicite casserait sans raison lisible.
// ignore: unnecessary_import
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Signature d'un registrar généré (`void registerZXxx(ZcrudRegistry)`).
typedef ZRegistrar = void Function(ZcrudRegistry registry);

/// Décodeur **de domaine** d'un kind : la factory défensive `fromMap` de
/// l'entité (AD-10).
typedef ZDomainDecoder = Object Function(Map<String, dynamic> map);

/// **TOUS** les registrars générés du repo (`R_wired`).
///
/// Confronté à `R_disk` par le gate : tout registrar présent sur disque et
/// absent d'ici ⇒ gate **ROUGE**.
const List<ZRegistrar> kRegistrars = <ZRegistrar>[
  registerZStudyFolder, // study_folder          — zcrud_study_kernel
  registerZStudySessionConfig, // study_session_config  — zcrud_study_kernel
  registerZFlashcard, // flashcard             — zcrud_flashcard
  registerZRepetitionInfo, // repetition_info       — zcrud_flashcard
  registerZChoice, // flashcard_choice      — zcrud_flashcard (NON ZExtensible)
];

/// Corps métier **minimal valide** de la sonde de chaque `kind`.
///
/// Pas de fallback générique (`{}` implicite) : un kind enregistré **sans**
/// corps ici fait ROUGIR le gate (le test de cohérence du harnais) — sinon un
/// oubli produirait une sonde muette, donc un faux vert.
const Map<String, Map<String, dynamic>> kProbeBodies =
    <String, Map<String, dynamic>>{
  'study_folder': <String, dynamic>{'id': 'p', 'title': 'p'},
  'study_session_config': <String, dynamic>{'mode': 'spaced'},
  'flashcard': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'question': 'q',
  },
  'repetition_info': <String, dynamic>{'flashcard_id': 'p', 'folder_id': 'f'},
  'flashcard_choice': <String, dynamic>{'content': 'c', 'is_correct': true},
};

/// Décodeurs **de domaine** par `kind` — la voie que le garde `_reservedKeys`
/// de chaque entité protège réellement.
///
/// ## ⚠️ POURQUOI PAS UNIQUEMENT `registry.decode(kind, probe)` (déviation
/// DOCUMENTÉE de la lettre d'AD-19.1.c, constat de disque ES-1.4)
///
/// Les registrars **générés** câblent `fromMap: _$ZXxxFromMap` — la factory du
/// **codegen**, qui ne connaît QUE les champs annotés `@ZcrudField` et ne peuple
/// donc **PAS** `extra` (canal **hors-codegen**, cf. `ZStudyFolder.fromMap`).
/// Résultat : une entité décodée *via le registre* a toujours `extra == {}`.
///
/// Conséquences si le gate décodait **uniquement** par le registre :
///   - l'assertion (a) serait **vacuellement verte** (`extra` vide) — le gate ne
///     protégerait RIEN, y compris contre les 2 findings HIGH d'ES-1.3 ;
///   - l'assertion (b) serait **structurellement rouge** (la clé inconnue ne
///     survit pas), donc intenable.
///
/// Le gate décode donc par la **voie de domaine** (`ZXxx.fromMap`) — celle qui
/// peuple `extra`, celle où vit `_reservedKeys`, celle qu'exercent les tests et
/// les apps — puis **ré-encode via le registre** (`registry.encode`), ce qui
/// exerce bien le `toMap` d'instance (assertions (c)/(d)).
///
/// **Dette tracée (DW-ES14-1)** : `FirebaseZRepositoryImpl` décode via
/// `registry.decode(kind, map)` (`firebase_z_repository_impl.dart:143`) ⇒ sur
/// ce chemin, `extra` est **perdu** (round-trip AD-4 non préservé côté store).
/// C'est un défaut du **câblage du registrar généré**, hors périmètre ES-1.4
/// (correctif = `zcrud_generator`) : signalé, non masqué. Le gate ne prétend PAS
/// couvrir ce chemin.
final Map<String, ZDomainDecoder> kDomainDecoders = <String, ZDomainDecoder>{
  'study_folder': ZStudyFolder.fromMap,
  'study_session_config': ZStudySessionConfig.fromMap,
  'flashcard': ZFlashcard.fromMap,
  'repetition_info': ZRepetitionInfo.fromMap,
  'flashcard_choice': ZChoice.fromMap,
};

/// Kinds enregistrés dont l'entité n'est **PAS** `ZExtensible` (aucun `extra`).
///
/// - `flashcard_choice` : `ZChoice` — value object de QCM (`class ZChoice {`),
///   sans slot d'extension. Le cast `(e as ZExtensible)` de la lettre d'AD-19.1.c
///   **throw** dessus (piège n°1).
///
/// ## ⚠️ Pourquoi cette liste existe (L1, code-review ES-1.4)
///
/// Les assertions **(a)/(b)** ne s'appliquent qu'aux entités `ZExtensible`. Sans
/// cette liste, le saut était **SILENCIEUX** : un `kDomainDecoders` recâblé par
/// erreur vers un type non-`ZExtensible` aurait rendu (a)/(b) **vacuellement
/// vertes sans le moindre signal**. Le saut est désormais **DÉCLARÉ** — et
/// vérifié dans les DEUX sens (cf. `assertExtraClean`) :
///   - kind **absent** d'ici mais entité non-`ZExtensible` ⇒ **ROUGE** (vacuité) ;
///   - kind **présent** ici mais entité `ZExtensible` ⇒ **ROUGE** (liste périmée).
/// (c)/(d) restent appliquées à **TOUS** les kinds, sans exception.
const Set<String> kNonExtensibleKinds = <String>{'flashcard_choice'};

/// Miroirs de compat AD-19.2 (pts 1-3) — **SEULS** kinds tolérés à ÉMETTRE
/// `updated_at` depuis leur `toMap()` (assertion **(d) UNIQUEMENT**).
///
/// - `study_folder` : `ZStudyFolder.updatedAt`, miroir **DÉPRÉCIÉ** maintenu par
///   collision de clé (le store écrit la méta APRÈS le corps ⇒ le miroir n'a
///   AUCUN pouvoir d'écriture — AD-19.2 pt.1/2, prouvé ES-1.3 AC5-bis) ;
/// - `flashcard` : `ZFlashcard.updatedAt`, miroir de même nature NON déprécié
///   (surface E9 consommée par la migration DODLP — AD-19.2 pt.3, dette
///   DW-ES13-2).
///
/// ⛔ TOUTE nouvelle entrée = **DÉCISION D'ARCHITECTURE** (mise à jour d'AD-19.2
/// + note écrite en code-review). CE N'EST PAS UN ÉCHAPPATOIRE DE CONFORT :
///   - portée **minimale** — (a)/(b)/(c) restent **SANS EXCEPTION**, legacy compris ;
///   - **test de verrou** (`reserved_keys_test.dart`) : l'ensemble est comparé à
///     un attendu FIGÉ ⇒ toute croissance **ou** réduction rend la suite ROUGE ;
///   - **anti-inertie** : une entrée dont le kind n'émet plus `updated_at` (ou
///     n'existe plus) rend la suite ROUGE.
const Set<String> kLegacyUpdatedAtMirrors = <String>{'study_folder', 'flashcard'};

/// Construit un [ZcrudRegistry] peuplé par **tous** les [kRegistrars].
ZcrudRegistry buildRegistry() {
  final registry = ZcrudRegistry();
  for (final register in kRegistrars) {
    register(registry);
  }
  return registry;
}
