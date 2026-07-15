/// CÂBLAGE du volet (A) : registrars, corps de sondes et allowlist legacy
/// (AD-19.1.c / AD-19.2).
///
/// ## Contrat d'extension (ES-2) — **3 lignes** par entité
///
/// Créer une entité study (`ZStudyDocument`, `ZSmartNote`, `ZExam`…) ⇒ ajouter :
///   1. son `registerZXxx` à [kRegistrars] ;
///   2. son corps de sonde minimal valide à [kProbeBodies] ;
///   3. 🔴 **TOUTES ses VOIES D'ÉCRITURE de `extra` à [kExtraWriters]** (ES-2.2b)
///      — constructeur nominal **ET** `copyWith` **ET** toute méthode publique
///      prenant un `extra` — sans quoi les assertions **(i.1)** (la voie
///      d'écriture ne rouvre pas le filtre des clés réservées), **(i.2)** (égalité
///      PROFONDE) et **(i.3)** (quelle garde a réellement travaillé) ne les
///      atteindraient **jamais**.
///
///      ⚠️ **La couverture est vérifiée dans DEUX dimensions** :
///        - **par kind** (bidirectionnelle) : kind `ZExtensible` sans writer ⇒
///          **ROUGE** ; writer orphelin ⇒ **ROUGE** ;
///        - **par VOIE** (règle AST **(j)**, `scripts/ci/gate_reserved_keys.dart`)
///          : les voies sont **DÉRIVÉES DU DISQUE**. **Le harnais ne choisit plus
///          la voie** — il choisissait la plus SÛRE (`copyWith`), ce qui rendait
///          (i.1a)/(i.1b) **vacuellement vertes sur 8 entités sur 9** et laissait
///          la voie **CONSTRUCTEUR** (polluante) hors de portée de toute machine
///          (code-review ES-2.2b, HIGH-1/HIGH-2).
///      La règle **(k)** exige en outre qu'un writer transmette `extra`
///      **VERBATIM** (un writer qui sanitise lui-même rendrait (i.1) trivialement
///      verte — **MAJEUR-2**).
///
/// ⇒ **Une entité ES-2.3…ES-2.8 ne peut pas naître sans être couverte.** C'est le
/// point de la story ES-2.2b : la parade est une **MACHINE**, pas une discipline
/// (les 8 entités déjà livrées, elles, ont TOUTES reproduit le défaut — mesuré).
///
/// *(La 3ᵉ ligne historique — un « décodeur de domaine » `kDomainDecoders` —
/// **n'existe plus** : depuis ES-2.0 / DW-ES14-1, le registrar généré câble
/// `fromMap: ZXxx.fromMap` (la factory de DOMAINE), donc `registry.decode` **EST**
/// la voie de domaine. Le volet (A) décode par le registre, comme le prescrivait
/// la lettre d'AD-19.1.c.)*
///
/// **L'oublier ne passe PAS inaperçu** : `scripts/ci/gate_reserved_keys.dart`
/// confronte l'inventaire du DISQUE (`grep` des `void registerZ…` dans
/// `packages/*/lib/**/*.g.dart`) au câblage de CE fichier et rougit sur
/// `R_disk \ R_wired ≠ ∅` (anti-faux-vert par omission, AD-19.1.c pt.1).
library;

import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_document/zcrud_document.dart';
import 'package:zcrud_exam/zcrud_exam.dart';
import 'package:zcrud_flashcard/zcrud_flashcard.dart';
import 'package:zcrud_note/zcrud_note.dart';
// L'analyzer signale cet import comme « inutile » parce que `zcrud_flashcard`
// RÉEXPORTE le barrel du kernel (AD-18). On le garde EXPLICITE : le harnais
// dépend RÉELLEMENT de `zcrud_study_kernel` (déclaré en `dependencies`), et le
// jour où `zcrud_flashcard` cessera de réexporter le kernel (surface publique en
// cours de resserrage, ES-1.1), l'implicite casserait sans raison lisible.
// ignore: unnecessary_import
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Signature d'un registrar généré (`void registerZXxx(ZcrudRegistry)`).
typedef ZRegistrar = void Function(ZcrudRegistry registry);

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
  registerZStudyDocument, // study_document        — zcrud_document (ES-2.1)
  registerZDocumentReadingState, // document_reading_state — zcrud_document (ES-2.1)
  registerZDocumentViewerPrefs, // document_viewer_prefs  — zcrud_document (NON ZExtensible)
  registerZSmartNote, // smart_note            — zcrud_note (ES-2.2)
  registerZFlashcardTag, // flashcard_tag       — zcrud_study_kernel (ES-2.3)
  registerZSuggestedTag, // suggested_tag       — zcrud_study_kernel (ES-2.3, NON ZExtensible)
  registerZFolderContentsOrder, // folder_contents_order — zcrud_study_kernel (ES-2.4)
  registerZDocumentAnnotation, // document_annotation   — zcrud_document (ES-2.5)
  registerZAnnotationBounds, // annotation_bounds     — zcrud_document (ES-2.5, NON ZExtensible)
  registerZExam, // exam                  — zcrud_exam (ES-2.6)
  registerZStudyPodcast, // study_podcast   — zcrud_study_kernel (ES-2.8)
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
  // ⚠️ H2 (code-review ES-2.0) : la sonde `flashcard` ne portait AUCUNE clé
  // `source` — le canal était donc affirmé « ✅ PRÉSERVÉ » dans la dartdoc
  // publique de `FirebaseZRepositoryImpl.fromRegistry` (celle qui AUTORISE le
  // câblage d'un store) **sans qu'aucune machine ne l'observe jamais**. C'est le
  // motif exact que cette story déclare combattre, appliqué à `extra` et oublié
  // sur `source`. La clé est désormais dans la sonde, et son round-trip est
  // ÉPINGLÉ (`reserved_keys_test.dart` › groupe « H2 — canal `source` »).
  //
  // `kind: 'zz_source_test'` est volontairement INCONNU des variants génériques
  // (`note`/`conversation`/`document`) : il exerce la voie `ZCustomSource`, celle
  // qu'un consommateur ouvre via `ZSourceRegistry` (AD-4 pt.3).
  'flashcard': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'question': 'q',
    'source': <String, dynamic>{
      'kind': 'zz_source_test',
      'zz_payload': 'brut',
    },
  },
  'repetition_info': <String, dynamic>{'flashcard_id': 'p', 'folder_id': 'f'},
  'flashcard_choice': <String, dynamic>{'content': 'c', 'is_correct': true},
  // ── ES-2.1 (zcrud_document) ──────────────────────────────────────────────
  'study_document': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'file_name': 'cours.pdf',
  },
  // ⚠️ H2 (code-review ES-2.0), À NE PAS REJOUER : la clé `learning` est un
  // CANAL HORS-CODEGEN (D4, patron `ZFlashcard.source`) — décodée et réémise À LA
  // MAIN, sa clé étant RÉSERVÉE. Une sonde SANS `learning` (ou avec un `learning`
  // VIDE) rendrait ce canal « préservé » par PROSE, sans qu'AUCUNE machine ne
  // l'observe — exactement le finding H2, où la sonde `flashcard` ne portait
  // aucune clé `source`. Elle est donc ici, et NON VIDE.
  'document_reading_state': <String, dynamic>{
    'doc_id': 'p',
    'current_page': 3,
    'learning': <String, dynamic>{
      'quality_by_page': <String, dynamic>{'1': 2, '3': 0},
    },
  },
  'document_viewer_prefs': <String, dynamic>{
    'zoom_level': 1.5,
    'scroll_direction': 'horizontal',
  },
  // ── ES-2.2 (zcrud_note) ──────────────────────────────────────────────────
  // 🔴 `content` est un CANAL HORS-CODEGEN (D3, patron `learning`/`source`) : le
  // générateur ne supporte AUCUN type `Map`, donc `List<Map<String, dynamic>>`
  // ne peut PAS être un `@ZcrudField`. Il est décodé/réémis À LA MAIN, sa clé
  // étant RÉSERVÉE.
  //
  // ⚠️ LA CLÉ `content` EST ICI, ET **NON VIDE** — c'est la règle (g2), et c'est
  // le finding H1 d'ES-2.1 (et H2 d'ES-2.0 sur `source`) à NE PAS REJOUER : une
  // sonde SANS le canal (ou avec un canal VIDE) rendrait celui-ci « préservé »
  // PAR PROSE — l'assertion comportementale (f) (`extra ∩ corps-de-sonde == ∅`)
  // ne l'observerait JAMAIS, et retirer `kContentKey` de `_reservedKeys`
  // laisserait le gate VERT.
  'smart_note': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'title': 't',
    'content': <Map<String, dynamic>>[
      <String, dynamic>{'insert': 'sonde\n'},
    ],
  },
  // ── ES-2.3 (zcrud_study_kernel) ──────────────────────────────────────────
  'flashcard_tag': <String, dynamic>{
    'id': 'p',
    'title': 't',
    'color_key': 'blue',
  },
  'suggested_tag': <String, dynamic>{'title': 't', 'color_key': 'blue'},
  // ── ES-2.4 (zcrud_study_kernel) ──────────────────────────────────────────
  // 🔴 `section_orders` est un CANAL HORS-CODEGEN (D3, patron `learning`) : le
  // générateur ne supporte AUCUN type `Map`, donc `Map<String, List<String>>`
  // ne peut PAS être un `@ZcrudField`. Il est décodé/réémis À LA MAIN, sa clé
  // étant RÉSERVÉE.
  //
  // ⚠️ LA CLÉ `section_orders` EST ICI, ET **NON VIDE** — règle (g2) : une sonde
  // SANS le canal (ou avec un canal VIDE) le rendrait « préservé PAR PROSE »
  // (finding H1 d'ES-2.1 / H2 d'ES-2.0 à NE PAS rejouer).
  'folder_contents_order': <String, dynamic>{
    'folder_id': 'p',
    'section_orders': <String, dynamic>{
      'flashcards': <String>['c3', 'c1'],
      'notes': <String>['n2'],
    },
  },
  // ── ES-2.5 (zcrud_document) ──────────────────────────────────────────────
  // Tous les champs sont codegen-ables (`bounds` = subModel, `rects` = listModel)
  // ⇒ AUCUN canal `Map` hors-codegen (contraste `learning`/`content`/
  // `section_orders`). La règle (g)/(g2) ne détecte donc aucun canal hors-codegen
  // non réservé sur cette entité.
  'document_annotation': <String, dynamic>{
    'id': 'p',
    'doc_id': 'd',
    'page': 3,
    'kind': 'highlight',
    'color_key': 'yellow',
    'bounds': <String, dynamic>{
      'x': 0.1,
      'y': 0.2,
      'width': 0.3,
      'height': 0.4,
    },
  },
  'annotation_bounds': <String, dynamic>{
    'x': 0.1,
    'y': 0.2,
    'width': 0.3,
    'height': 0.4,
  },
  // ── ES-2.6 (zcrud_exam) ──────────────────────────────────────────────────
  // 🔴 `reminder_time` est un CANAL HORS-CODEGEN (D3, patron `content`/`learning`)
  // : le champ `reminderTime` (typé `ZReminderTime?`, non annoté `@ZcrudField`)
  // est décodé/réémis À LA MAIN en `'HH:mm'`, sa clé étant RÉSERVÉE.
  //
  // ⚠️ LA CLÉ `reminder_time` EST ICI, ET **NON VIDE** — c'est la règle (g2) :
  // une sonde SANS le canal (ou avec un canal VIDE) le rendrait « préservé PAR
  // PROSE », et retirer `kReminderTimeKey` de `_reservedKeys` laisserait le gate
  // VERT (finding H1 d'ES-2.1 / H2 d'ES-2.0 à NE PAS REJOUER).
  'exam': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'title': 't',
    'date': '2026-07-20T00:00:00.000Z',
    'reminder_enabled': true,
    'reminder_days_before': <int>[7, 1],
    'reminder_time': '08:30',
  },
  // ── ES-2.8 (zcrud_study_kernel) ──────────────────────────────────────────
  // TOUS les champs sont codegen-ables (3 `String` + `folder_id` + 3 enums
  // `select` + `created_at` ISO-8601) ⇒ AUCUN canal `Map` hors-codegen
  // (contraste `learning`/`content`/`section_orders`/`reminder_time`). La règle
  // (g)/(g2) ne détecte donc aucun canal hors-codegen non réservé sur cette
  // entité (précédent EXACT `document_annotation`). `source_hash` est une
  // empreinte OPAQUE COMPARÉE, JAMAIS calculée (D4).
  'study_podcast': <String, dynamic>{
    'id': 'p',
    'source_kind': 'folder',
    'source_id': 's',
    'folder_id': 'f',
    'mode': 'dialogue',
    'source_hash': 'h',
    'result_ref': 'r',
    'status': 'ready',
  },
};

/// Kinds enregistrés dont l'entité n'est **PAS** `ZExtensible` (aucun `extra`).
///
/// - `flashcard_choice` : `ZChoice` — value object de QCM (`class ZChoice {`),
///   sans slot d'extension. Le cast `(e as ZExtensible)` de la lettre d'AD-19.1.c
///   **throw** dessus (piège n°1).
/// - `document_viewer_prefs` : `ZDocumentViewerPrefs` (ES-2.1) — value object de
///   préférences de lecture, même patron : `class ZDocumentViewerPrefs {`, aucun
///   `extra`. (Ses deux sœurs d'ES-2.1, `ZStudyDocument` et
///   `ZDocumentReadingState`, **SONT** `ZExtensible` : elles ne figurent PAS ici.)
///
/// ## ⚠️ Pourquoi cette liste existe (L1, code-review ES-1.4)
///
/// Les assertions **(a)/(b)/(e)** ne s'appliquent qu'aux entités `ZExtensible`.
/// Sans cette liste, le saut était **SILENCIEUX** : un registrar recâblé par
/// erreur vers un type non-`ZExtensible` aurait rendu (a)/(b) **vacuellement
/// vertes sans le moindre signal**. Le saut est désormais **DÉCLARÉ** — et
/// vérifié dans les DEUX sens (cf. `assertExtraClean`, `assertUnknownKeyRoundTrip`) :
///   - kind **absent** d'ici mais entité non-`ZExtensible` ⇒ **ROUGE** (vacuité) ;
///   - kind **présent** ici mais entité `ZExtensible` ⇒ **ROUGE** (liste périmée).
/// (c)/(d) restent appliquées à **TOUS** les kinds, sans exception.
///
/// ⚠️ **(e) NE PEUT PAS être « appliquée à chaque kind »** (D3, ES-2.0) : `ZChoice`
/// n'a pas d'`extra` — elle ne peut structurellement pas préserver une clé
/// inconnue, et (e) y serait ROUGE À JAMAIS. (e) s'applique EXACTEMENT là où
/// (a)/(b) s'appliquent.
const Set<String> kNonExtensibleKinds = <String>{
  'flashcard_choice',
  'document_viewer_prefs',
  // ES-2.3 — `ZSuggestedTag` : DTO éphémère value object (`class ZSuggestedTag {`),
  // sans slot d'extension. `ZFlashcardTag`, elle, EST `ZExtensible` (absente ici).
  'suggested_tag',
  // ES-2.5 — `ZAnnotationBounds` : VO borné `[0,1]` (`class ZAnnotationBounds {`),
  // aucun slot `extra`. Le cast `(e as ZExtensible)` throw dessus (piège n°1).
  // `ZDocumentAnnotation`, elle, EST `ZExtensible` (absente ici, munie de writers).
  'annotation_bounds',
};

/// Kinds dont l'entité **PRÉSERVE** le payload `extension` **non typé** au lieu de
/// le **DÉTRUIRE** — mitigation locale de **DW-ES14-2** (story ES-2.2, findings
/// **MAJEUR-1**/**MAJEUR-2**).
///
/// ## Ce que cette liste dit — et surtout ce qu'elle NE DIT PAS
///
/// `ZcrudRegistry` n'offre **TOUJOURS AUCUN SLOT D'INJECTION** : sur la voie
/// registre, **aucun** `extensionParser` n'est fourni ⇒ **le slot n'est JAMAIS
/// TYPÉ**. **DW-ES14-2 reste OUVERTE, entière, et BLOQUANTE avant ES-3.2/ES-3.5.**
///
/// Ce que ces entités ont changé, c'est le **sort de la DONNÉE** :
///
/// | | payload d'`extension` non typé |
/// |---|---|
/// | kind **hors** de cette liste | ⛔ **DÉTRUIT** (`extension == null` ⇒ `toMap()` **omet la clé** ⇒ effacé du store au premier `put`) |
/// | kind **dans** cette liste | ✅ **PORTÉ VERBATIM** et **RÉÉMIS À L'IDENTIQUE** (`ZOpaqueNoteExtension` — AD-4 pt.1 « évolution additive ») |
///
/// ⚠️ **Ce n'est PAS un échappatoire de confort** : le verrou `DW-ES14-2` est
/// **RENFORCÉ** pour ces kinds, pas relâché — il exige que le payload soit réémis
/// **BIT POUR BIT** (`extension.toJson() == payload`), ce qui **PROUVE** qu'aucun
/// parser typé ne l'a interprété : **la dette est toujours là, et on l'observe**.
///
/// 🔴 **`ZNoteAudio` (zcrud_note) est la PREMIÈRE `ZExtension` CONCRÈTE du repo** :
/// elle **FALSIFIE la clause d'échappement n°1 de DW-ES14-2** (*« si — et seulement
/// si — l'entité **n'utilise pas** le slot `extension` »*). La dette n'est plus
/// **théorique** : elle porte sur une entité **livrée**.
///
/// ⇒ **Quand DW-ES14-2 sera soldée**, cette liste **DISPARAÎT** (le registre typera
/// le slot pour **tous** les kinds) et les verrous sont **INVERSÉS**, jamais
/// supprimés.
const Set<String> kExtensionPayloadPreservers = <String>{
  'smart_note', // zcrud_note — ZSmartNote / ZOpaqueNoteExtension (ES-2.2)
};

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

// ===========================================================================
// 🔴 ES-2.2b — `kExtraWriters` : LA VOIE D'ÉCRITURE PUBLIQUE DE `extra`.
// ===========================================================================

/// Écrit [extra] dans [entity] **par UNE voie d'écriture PUBLIQUE** et rend
/// l'entité résultante.
typedef ZExtraWrite = Object Function(Object entity, Map<String, dynamic> extra);

/// **UNE** voie d'écriture publique de `extra` (ES-2.2b — remédiation **HIGH-1**,
/// **HIGH-2**, **MAJEUR-2** de la code-review).
///
/// ## Pourquoi une LISTE de voies, et non « LA » voie
///
/// La v1 câblait **UNE SEULE** voie par entité — et **le harnais CHOISISSAIT
/// laquelle** : systématiquement la **plus sûre** (`copyWith`, qui filtre déjà).
/// **MESURÉ (code-review ES-2.2b)** : l'entité encodée par (i.1a)/(i.1b) avait donc
/// un `extra` **DÉJÀ PROPRE** ⇒ retirer la garde de `toMap()` laissait le gate
/// **VERT sur 8 entités sur 9**, et la **voie CONSTRUCTEUR** — polluante, publique,
/// jamais sondée — restait **hors de portée de TOUTE machine** (6 entités sur 9
/// portaient `updated_at`/`is_deleted` dans leur `extra` **EN MÉMOIRE**, dont
/// `ZSmartNote`).
///
/// ⇒ **Le harnais ne choisit plus la voie** : il les câble **TOUTES**, et la
/// **règle AST (j)** du gate (`scripts/ci/gate_reserved_keys.dart`) **DÉRIVE DU
/// DISQUE** les voies publiques de chaque entité `ZExtensible` (tout constructeur
/// public et toute méthode publique portant un paramètre `extra`) et **EXIGE**
/// qu'elles soient toutes ici — dans les **deux sens** (voie non câblée ⇒ ROUGE ;
/// voie morte ⇒ ROUGE).
class ZExtraWriter {
  /// Déclare une voie d'écriture.
  const ZExtraWriter({
    required this.voie,
    required this.write,
    required this.eagerlyNormalized,
  });

  /// Nom de la voie — **LITTÉRAL, LU PAR LE GATE** (règle (j)) : `'ctor'` pour le
  /// constructeur nominal, sinon le nom de la méthode (`'copyWith'`). Ne jamais
  /// l'interpoler.
  final String voie;

  /// La voie elle-même : elle DOIT transmettre `extra` **VERBATIM** à l'API
  /// publique de l'entité. **La règle AST (k) l'EXIGE** (un writer qui
  /// pré-sanitise — « writer menteur POLI » — rendrait (i.1) trivialement verte :
  /// c'est le finding **MAJEUR-2**).
  final ZExtraWrite write;

  /// Cette voie **NORMALISE-t-elle le slot STOCKÉ** (`_extra`) ?
  ///
  /// - `true` — `copyWith`, ou un constructeur **non-`const`** (`ZMindmap`) :
  ///   ils appellent `zSanitizeExtra` ⇒ le slot stocké est **déjà propre** ⇒ la
  ///   lecture d'`extra` est **SANS COPIE** (`identical(e.extra, e.extra)`).
  /// - `false` — le constructeur **`const`** des 7 entités codegen : il ne peut
  ///   appeler **aucune** fonction (AD-10 y interdit l'`assert`) ⇒ le slot stocké
  ///   reste **BRUT**, et c'est l'**ACCESSEUR** `extra` qui filtre à la lecture.
  ///
  /// **C'est une MACHINE, pas une étiquette** — assertion **(i.3)** :
  ///   - `true` ⇒ on ASSERTE `identical(e.extra, e.extra)` ⇒ retirer
  ///     `_sanitizeExtra` de `copyWith`/du ctor de `ZMindmap` fait **ROUGIR** ;
  ///   - `false` ⇒ on ASSERTE **l'inverse** ⇒ (1) l'accesseur a **réellement
  ///     travaillé** (la garde est PORTEUSE, pas décorative), (2) le writer a
  ///     transmis les clés réservées **VERBATIM** — un writer **auto-sanitisant**
  ///     rendrait le slot propre et **ROUGIRAIT** (**MAJEUR-2**, second filet,
  ///     dynamique celui-ci).
  final bool eagerlyNormalized;
}

/// **TOUTES** les voies d'écriture publiques de `extra`, par kind (`E_covered`).
///
/// ⚠️ La couverture est vérifiée dans **DEUX** dimensions :
///   - **par kind** (test AC9 du harnais) : un kind `ZExtensible` sans writer ⇒ ROUGE ;
///   - **par VOIE** (règle **(j)**, AST, dérivée du DISQUE) : une voie publique de
///     l'entité non câblée ici ⇒ **ROUGE**. Le harnais **ne peut plus** se
///     contenter de la voie la plus sûre.
const Map<String, List<ZExtraWriter>> kExtraWriters =
    <String, List<ZExtraWriter>>{
  'study_folder': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyFolder,
      eagerlyNormalized: false, // ctor `const` : ne peut RIEN filtrer.
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyFolder,
      eagerlyNormalized: true,
    ),
  ],
  'study_session_config': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudySessionConfig,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudySessionConfig,
      eagerlyNormalized: true,
    ),
  ],
  'flashcard': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorFlashcard,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithFlashcard,
      eagerlyNormalized: true,
    ),
  ],
  // ⚠️ `ZRepetitionInfo` n'a **AUCUN `copyWith`** (voie SRS unique) : sa SEULE
  // voie publique est le constructeur nominal. La règle (j) le vérifie sur le
  // DISQUE — si elle gagne un `copyWith` un jour, le gate EXIGE son câblage ici.
  'repetition_info': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorRepetitionInfo,
      eagerlyNormalized: false,
    ),
  ],
  'study_document': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyDocument,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyDocument,
      eagerlyNormalized: true,
    ),
  ],
  'document_reading_state': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorDocumentReadingState,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithDocumentReadingState,
      eagerlyNormalized: true,
    ),
  ],
  'smart_note': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorSmartNote,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithSmartNote,
      eagerlyNormalized: true,
    ),
  ],
  // ES-2.3 — `ZFlashcardTag` : DEUX voies publiques d'écriture de `extra`
  // (règle AST (j), HIGH-1/HIGH-2 d'ES-2.2b). `ZSuggestedTag` n'a pas d'`extra`.
  'flashcard_tag': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorFlashcardTag,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithFlashcardTag,
      eagerlyNormalized: true,
    ),
  ],
  // ES-2.4 — `ZFolderContentsOrder` : DEUX voies publiques d'écriture de `extra`
  // (règle AST (j), HIGH-1/HIGH-2 d'ES-2.2b). Le canal `section_orders` n'est PAS
  // une voie `extra`.
  'folder_contents_order': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorFolderContentsOrder,
      eagerlyNormalized: false, // ctor `const` : ne peut RIEN filtrer.
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithFolderContentsOrder,
      eagerlyNormalized: true,
    ),
  ],
  // ES-2.5 — `ZDocumentAnnotation` : DEUX voies publiques d'écriture de `extra`
  // (règle AST (j), HIGH-1/HIGH-2 d'ES-2.2b). `ZAnnotationBounds` (le VO borné)
  // n'a PAS d'`extra` (kNonExtensibleKinds).
  'document_annotation': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorDocumentAnnotation,
      eagerlyNormalized: false, // ctor `const` : ne peut RIEN filtrer.
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithDocumentAnnotation,
      eagerlyNormalized: true,
    ),
  ],
  // ES-2.6 — `ZExam` : DEUX voies publiques d'écriture de `extra` (règle AST (j),
  // HIGH-1/HIGH-2 d'ES-2.2b). Le canal `reminderTime` n'est PAS une voie `extra`.
  'exam': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorExam,
      eagerlyNormalized: false, // ctor `const` : ne peut RIEN filtrer.
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithExam,
      eagerlyNormalized: true,
    ),
  ],
  // ES-2.8 — `ZStudyPodcast` : DEUX voies publiques d'écriture de `extra` (règle
  // AST (j), HIGH-1/HIGH-2 d'ES-2.2b). Aucun canal hors-codegen (D5).
  'study_podcast': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyPodcast,
      eagerlyNormalized: false, // ctor `const` : ne peut RIEN filtrer.
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyPodcast,
      eagerlyNormalized: true,
    ),
  ],
};

// ---------------------------------------------------------------------------
// VOIE `copyWith` — `x` est passé **VERBATIM** (règle AST (k) : aucune
// transformation ; un writer qui pré-sanitiserait serait un MENTEUR POLI).
// ---------------------------------------------------------------------------

Object _copyWithStudyFolder(Object e, Map<String, dynamic> x) =>
    (e as ZStudyFolder).copyWith(extra: x);

Object _copyWithStudySessionConfig(Object e, Map<String, dynamic> x) =>
    (e as ZStudySessionConfig).copyWith(extra: x);

Object _copyWithFlashcard(Object e, Map<String, dynamic> x) =>
    (e as ZFlashcard).copyWith(extra: x);

Object _copyWithStudyDocument(Object e, Map<String, dynamic> x) =>
    (e as ZStudyDocument).copyWith(extra: x);

Object _copyWithDocumentReadingState(Object e, Map<String, dynamic> x) =>
    (e as ZDocumentReadingState).copyWith(extra: x);

Object _copyWithSmartNote(Object e, Map<String, dynamic> x) =>
    (e as ZSmartNote).copyWith(extra: x);

Object _copyWithFlashcardTag(Object e, Map<String, dynamic> x) =>
    (e as ZFlashcardTag).copyWith(extra: x);

Object _copyWithFolderContentsOrder(Object e, Map<String, dynamic> x) =>
    (e as ZFolderContentsOrder).copyWith(extra: x);

Object _copyWithDocumentAnnotation(Object e, Map<String, dynamic> x) =>
    (e as ZDocumentAnnotation).copyWith(extra: x);

Object _copyWithExam(Object e, Map<String, dynamic> x) =>
    (e as ZExam).copyWith(extra: x);

Object _copyWithStudyPodcast(Object e, Map<String, dynamic> x) =>
    (e as ZStudyPodcast).copyWith(extra: x);

// ---------------------------------------------------------------------------
// 🔴 VOIE `ctor` — LA VOIE QUE LE HARNAIS NE SONDAIT PAS (HIGH-1/HIGH-2).
//
// Constructeur nominal, **public** et **`const`** : il ne peut appeler AUCUNE
// fonction (AD-10 y interdit l'`assert`) ⇒ il stocke `extra` **BRUT**. C'est
// l'**ACCESSEUR** `extra` de l'entité qui filtre à la lecture — et ce sont ces
// writers qui le prouvent : sans eux, (i.1a)/(i.1b)/(i.1c) n'encodaient QUE des
// entités à l'`extra` déjà propre, et la garde n'était exigée par AUCUNE machine.
// ---------------------------------------------------------------------------

Object _ctorStudyFolder(Object e, Map<String, dynamic> x) {
  final f = e as ZStudyFolder;
  return ZStudyFolder(
    id: f.id,
    title: f.title,
    colorKey: f.colorKey,
    parentId: f.parentId,
    ownerId: f.ownerId,
    archivedAt: f.archivedAt,
    createdAt: f.createdAt,
    updatedAt: f.updatedAt,
    isPublic: f.isPublic,
    sharedWith: f.sharedWith,
    canBeJoinedWithLink: f.canBeJoinedWithLink,
    coWorkersCanInviteOthers: f.coWorkersCanInviteOthers,
    shareId: f.shareId,
    extension: f.extension,
    extra: x,
  );
}

Object _ctorStudySessionConfig(Object e, Map<String, dynamic> x) {
  final c = e as ZStudySessionConfig;
  return ZStudySessionConfig(
    mode: c.mode,
    folderId: c.folderId,
    tagIds: c.tagIds,
    types: c.types,
    count: c.count,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorFlashcard(Object e, Map<String, dynamic> x) {
  final c = e as ZFlashcard;
  return ZFlashcard(
    id: c.id,
    folderId: c.folderId,
    subFolderId: c.subFolderId,
    type: c.type,
    question: c.question,
    answer: c.answer,
    isTrue: c.isTrue,
    choices: c.choices,
    explanation: c.explanation,
    hint: c.hint,
    tagIds: c.tagIds,
    isReadOnly: c.isReadOnly,
    createdAt: c.createdAt,
    updatedAt: c.updatedAt,
    source: c.source,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorRepetitionInfo(Object e, Map<String, dynamic> x) {
  final r = e as ZRepetitionInfo;
  return ZRepetitionInfo(
    flashcardId: r.flashcardId,
    folderId: r.folderId,
    interval: r.interval,
    repetitions: r.repetitions,
    easeFactor: r.easeFactor,
    nextReviewDate: r.nextReviewDate,
    learnedAt: r.learnedAt,
    lastQuality: r.lastQuality,
    extension: r.extension,
    extra: x,
  );
}

Object _ctorStudyDocument(Object e, Map<String, dynamic> x) {
  final d = e as ZStudyDocument;
  return ZStudyDocument(
    id: d.id,
    folderId: d.folderId,
    fileName: d.fileName,
    status: d.status,
    storagePath: d.storagePath,
    pageCount: d.pageCount,
    sizeBytes: d.sizeBytes,
    createdAt: d.createdAt,
    extension: d.extension,
    extra: x,
  );
}

Object _ctorDocumentReadingState(Object e, Map<String, dynamic> x) {
  final s = e as ZDocumentReadingState;
  return ZDocumentReadingState(
    docId: s.docId,
    currentPage: s.currentPage,
    pageCount: s.pageCount,
    prefs: s.prefs,
    learning: s.learning,
    extension: s.extension,
    extra: x,
  );
}

Object _ctorSmartNote(Object e, Map<String, dynamic> x) {
  final n = e as ZSmartNote;
  return ZSmartNote(
    id: n.id,
    folderId: n.folderId,
    subFolderId: n.subFolderId,
    title: n.title,
    content: n.content,
    createdAt: n.createdAt,
    extension: n.extension,
    extra: x,
  );
}

Object _ctorFlashcardTag(Object e, Map<String, dynamic> x) {
  final t = e as ZFlashcardTag;
  return ZFlashcardTag(
    id: t.id,
    title: t.title,
    colorKey: t.colorKey,
    extension: t.extension,
    extra: x,
  );
}

Object _ctorFolderContentsOrder(Object e, Map<String, dynamic> x) {
  final o = e as ZFolderContentsOrder;
  return ZFolderContentsOrder(
    folderId: o.folderId,
    sectionOrders: o.sectionOrders,
    extension: o.extension,
    extra: x,
  );
}

Object _ctorDocumentAnnotation(Object e, Map<String, dynamic> x) {
  final a = e as ZDocumentAnnotation;
  return ZDocumentAnnotation(
    id: a.id,
    docId: a.docId,
    page: a.page,
    kind: a.kind,
    colorKey: a.colorKey,
    bounds: a.bounds,
    rects: a.rects,
    text: a.text,
    createdAt: a.createdAt,
    extension: a.extension,
    extra: x,
  );
}

Object _ctorExam(Object e, Map<String, dynamic> x) {
  final m = e as ZExam;
  return ZExam(
    id: m.id,
    folderId: m.folderId,
    title: m.title,
    date: m.date,
    reminderEnabled: m.reminderEnabled,
    reminderDaysBefore: m.reminderDaysBefore,
    reminderTime: m.reminderTime,
    extension: m.extension,
    extra: x,
  );
}

Object _ctorStudyPodcast(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyPodcast;
  return ZStudyPodcast(
    id: p.id,
    sourceKind: p.sourceKind,
    sourceId: p.sourceId,
    folderId: p.folderId,
    mode: p.mode,
    sourceHash: p.sourceHash,
    resultRef: p.resultRef,
    status: p.status,
    createdAt: p.createdAt,
    extension: p.extension,
    extra: x,
  );
}

/// Entités `ZExtensible` **sans AUCUN `operator ==`** ⇒ **(i.2) est SAUTÉE**
/// — mais le saut est **DÉCLARÉ ET CONTRÔLÉ** (**R6**, patron de (e)/(d)).
///
/// ## Ce que ce skip dit — et surtout ce qu'il NE DIT PAS
///
/// Ce n'est **PAS** le défaut DW-ES22-4 (« égalité *superficielle* sur `extra` ») :
/// `ZMindmap`/`ZMindmapNode` n'ont **aucune égalité de valeur du tout** (égalité
/// d'**IDENTITÉ** — mesuré : `a != b` **même avec un `extra` SCALAIRE**, et même
/// avec un `extra` **vide**). C'est un défaut **préexistant et PLUS LARGE**, hors
/// du périmètre nommé par la dette.
///
/// Leur donner un `==` profond exigerait une **égalité récursive sur l'arbre
/// `children`** (`ZMindmapNode` est un arbre : O(n), garde-fou de cycle,
/// changement sémantique pour un package à 110 tests). ⇒ **HORS PÉRIMÈTRE
/// ES-2.2b.**
///
/// 📌 **Dette OUVERTE : `DW-ES22-5`** — à statuer en ES-10.x / rétro ES-2.
///
/// ⚠️ **(i.1) LEUR EST BIEN APPLIQUÉE** : leur constructeur nominal acceptait un
/// `extra` pollué et leur `toJson()` le réémettait (MESURÉ CASSÉ). Seule (i.2)
/// est sautée.
///
/// 🔴 **ANTI-INERTIE** : (i.2) **ASSERTE que l'égalité est bien ABSENTE** sur ces
/// entités. Le jour où quelqu'un leur donne un `==` de valeur, l'entrée devient
/// **MORTE** et le test **ROUGIT** en exigeant de la retirer. **Jamais silencieux.**
const Set<String> kNoValueEqualityProbes = <String>{
  'ZMindmap',
  'ZMindmapNode',
};

/// Construit un [ZcrudRegistry] peuplé par **tous** les [kRegistrars].
ZcrudRegistry buildRegistry() {
  final registry = ZcrudRegistry();
  for (final register in kRegistrars) {
    register(registry);
  }
  return registry;
}
