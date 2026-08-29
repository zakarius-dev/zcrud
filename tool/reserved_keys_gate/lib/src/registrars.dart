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
  registerZStudyStreak, // study_streak    — zcrud_study_kernel (SU-6, NON ZExtensible)
  // ── Structure d'étude (zcrud_study_kernel, `lib/src/domain/structure/`) ──
  // 23 entités d'un même patron : ctor `const` (l'ACCESSEUR `extra` filtre),
  // `copyWith` à sentinelle (sanitisation EAGER), canal manuel `external_refs`
  // (sauf `study_explanation`) et, pour certaines, des références manuelles
  // (`*_ref`, `topic_refs`, `classification_constraints`).
  registerZStudyWorkspace, // study_workspace
  registerZStudyPrincipal, // study_principal
  registerZStudyOrganization, // study_organization
  registerZStudyOrgUnit, // study_org_unit
  registerZStudyProgram, // study_program
  registerZStudyGroup, // study_group
  registerZStudyClassification, // study_classification
  registerZStudySubject, // study_subject
  registerZStudyCourse, // study_course
  registerZStudyProgramCourse, // study_program_course
  registerZStudyCalendar, // study_calendar
  registerZStudyPeriod, // study_period
  registerZStudySession, // study_session
  registerZStudyOffering, // study_offering
  registerZStudyOfferingAudience, // study_offering_audience
  registerZStudyParticipation, // study_participation
  registerZStudyCurriculum, // study_curriculum
  registerZStudyTopic, // study_topic
  registerZStudyCompetency, // study_competency
  registerZStudyCompetencyFramework, // study_competency_framework
  registerZStudyExplanation, // study_explanation
  registerZStudyRoleBinding, // study_role_binding
  registerZStudyShareGrant, // study_share_grant
];

/// Corps métier **minimal valide** de la sonde de chaque `kind`.
///
/// Pas de fallback générique (`{}` implicite) : un kind enregistré **sans**
/// corps ici fait ROUGIR le gate (le test de cohérence du harnais) — sinon un
/// oubli produirait une sonde muette, donc un faux vert.
const Map<String, Map<String, dynamic>>
kProbeBodies = <String, Map<String, dynamic>>{
  // 🔴 `owner_ref`, `primary_scope_ref` et `bindings` sont des CANAUX
  // HORS-CODEGEN (patron `source`/`learning`) : décodés et réémis À LA MAIN par
  // `ZStudyFolder.fromMap`/`toMap`, leurs clés étant RÉSERVÉES. Ils sont ici, et
  // **NON VIDES** — règle (g2) : une sonde sans le canal (ou avec un canal vide)
  // le rendrait « préservé PAR PROSE », et le retirer de `_reservedKeys`
  // laisserait le gate VERT.
  'study_folder': <String, dynamic>{
    'id': 'p',
    'title': 'p',
    'owner_ref': <String, dynamic>{'type': 'study_principal', 'id': 'pr1'},
    'primary_scope_ref': <String, dynamic>{
      'type': 'study_organization',
      'id': 'o1',
    },
    'bindings': <Map<String, dynamic>>[
      <String, dynamic>{
        'source_ref': <String, dynamic>{'type': 'study_folder', 'id': 'p'},
        'target_ref': <String, dynamic>{'type': 'study_course', 'id': 'c1'},
        'propagation': 'exact',
      },
    ],
  },
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
    'source': <String, dynamic>{'kind': 'zz_source_test', 'zz_payload': 'brut'},
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
    // CR-IFFD-17 — canal HORS-CODEGEN `reminderRecurrence`. Valeur NON VIDE :
    // une sonde vide ne prouverait rien (le slot serait omis a l'emission, donc
    // la reservation de la cle ne serait jamais exercee).
    'reminder_recurrence': <String, dynamic>{
      'days_before': <int>[7],
      'weekdays': <int>[1, 5],
    },
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
  // ── SU-6 (zcrud_study_kernel) ────────────────────────────────────────────
  // `ZStudyStreak` — NON `ZExtensible` (cf. `kNonExtensibleKinds`) : ni `extra`,
  // ni `extension` ⇒ (a)/(b)/(e) sautent, (c)/(d) s'appliquent.
  //
  // Tous les champs sont codegen-ables (2 `int`, 2 `String?`) ⇒ AUCUN canal `Map`
  // hors-codegen (contraste `learning`/`content`/`section_orders`) : la règle
  // (g)/(g2) ne détecte aucun canal non réservé. Précédent EXACT : `suggested_tag`.
  //
  // ⚠️ **Portée HONNÊTE de cette sonde** (code-review su-6, LOW-1 — la version
  // précédente de ce commentaire SUR-PROMETTAIT). Elle affirmait qu'un `toMap()`
  // écrasant/permutant `current`/`best` « ROUGIRAIT » ici. **C'est faux, mesuré
  // sur le harnais** : pour un kind de `kNonExtensibleKinds`, `assertExtraClean`
  // fait un early-return dès `entity is! ZExtensible` et `assertUnknownKeyRoundTrip`
  // sur `!expectExtensible` ⇒ seule `assertEncodedClean` tourne, et elle
  // n'inspecte QUE les clés réservées (`ZSyncMeta`), **jamais** les valeurs de
  // champ. `{'current': 0, 'best': 0}` laisserait ce gate tout aussi vert.
  //
  // Le round-trip de ces valeurs EST prouvé — mais **ailleurs** :
  // `packages/zcrud_study_kernel/test/z_study_streak_test.dart`. Ici, c'est un
  // **corps minimal VALIDE** ; les valeurs restent choisies non-dégénérées par
  // hygiène (et parce que le gate peut s'étendre), pas parce que ce gate les
  // observerait. Une justification qui sur-promet dans le fichier même du gate
  // anti-vacuité, c'est le « dartdoc rassurant » que ce gate combat.
  //
  // Valeurs et pourquoi elles restent celles-ci :
  //   - `current`/`best` **positifs et distincts** (3 ≠ 7) : le plancher
  //     anti-négatif de `fromMap` ne les touche pas, et des `0` — la valeur par
  //     DÉFAUT du ctor — rendraient toute observation future verte par
  //     COÏNCIDENCE ;
  //   - `best > current` : l'état MÉTIER nominal (un record déjà établi, série en
  //     cours plus courte) — pas un état dégénéré ;
  //   - `last_graded_day` = jour civil **LISIBLE** (`zIsCivilDay` vraie) ⇒ `fromMap`
  //     le préserve VERBATIM. Un jour illisible serait sanitisé en `null` (AC1) et
  //     rendrait le round-trip vert en n'observant RIEN de la clé.
  //
  // AD-19 : aucun `updated_at`/`is_deleted` — le streak n'a AUCUN miroir de sync
  // inline (il n'est PAS dans `kLegacyUpdatedAtMirrors`, et ne doit jamais l'être :
  // sa fraîcheur vit hors-entité dans `ZSyncMeta`, AD-16).
  'study_streak': <String, dynamic>{
    'id': 'p',
    'current': 3,
    'best': 7,
    'last_graded_day': '2026-07-16',
  },
  // ── Structure d'étude (zcrud_study_kernel) ───────────────────────────────
  // 🔴 Chaque corps porte, EN PLUS de son minimum métier, **TOUS** les canaux
  // hors-codegen que la règle (g) relève sur l'entité — et **NON VIDES**.
  // `external_refs`, `*_ref`, `topic_refs`, `classification_constraints` et
  // `bindings` sont décodés/réémis À LA MAIN (le générateur ne supporte aucun
  // type `Map`), leurs clés étant RÉSERVÉES : une sonde qui ne les transporte
  // pas les rendrait « préservés PAR PROSE » — l'assertion (f) ne les
  // observerait JAMAIS, et les retirer de `_reservedKeys` laisserait le gate
  // VERT (finding H1 d'ES-2.1 / H2 d'ES-2.0, à NE PAS REJOUER).
  'study_workspace': <String, dynamic>{
    'id': 'p',
    'kind': 'tenant',
    'label': 'espace',
    'external_refs': _kProbeExternalRefs,
  },
  'study_principal': <String, dynamic>{
    'id': 'p',
    'kind': 'person',
    'label': 'mandant',
    'external_refs': _kProbeExternalRefs,
  },
  'study_organization': <String, dynamic>{
    'id': 'p',
    'kind': 'school',
    'label': 'organisation',
    'external_refs': _kProbeExternalRefs,
  },
  'study_org_unit': <String, dynamic>{
    'id': 'p',
    'organization_id': 'o1',
    'kind': 'department',
    'label': 'unite',
    'external_refs': _kProbeExternalRefs,
  },
  'study_program': <String, dynamic>{
    'id': 'p',
    'kind': 'degree',
    'label': 'programme',
    'external_refs': _kProbeExternalRefs,
  },
  'study_group': <String, dynamic>{
    'id': 'p',
    'kind': 'class',
    'label': 'groupe',
    'external_refs': _kProbeExternalRefs,
  },
  'study_classification': <String, dynamic>{
    'id': 'p',
    'vocabulary_key': 'level',
    'value_key': 'l1',
    'target_ref': <String, dynamic>{'type': 'study_course', 'id': 'c1'},
    'external_refs': _kProbeExternalRefs,
  },
  'study_subject': <String, dynamic>{
    'id': 'p',
    'kind': 'discipline',
    'label': 'matiere',
    'color_key': 'blue',
    'external_refs': _kProbeExternalRefs,
  },
  'study_course': <String, dynamic>{
    'id': 'p',
    'kind': 'course',
    'label': 'cours',
    'external_refs': _kProbeExternalRefs,
  },
  'study_program_course': <String, dynamic>{
    'id': 'p',
    'program_id': 'pr1',
    'course_id': 'c1',
    'classification_constraints': <Map<String, dynamic>>[
      <String, dynamic>{'vocabulary_key': 'level', 'value_key': 'l1'},
    ],
    'external_refs': _kProbeExternalRefs,
  },
  'study_calendar': <String, dynamic>{
    'id': 'p',
    'timezone': 'Europe/Paris',
    'kind': 'academic',
    'label': 'calendrier',
    'external_refs': _kProbeExternalRefs,
  },
  'study_period': <String, dynamic>{
    'id': 'p',
    'calendar_id': 'cal1',
    'kind': 'semester',
    'label': 'S1',
    'external_refs': _kProbeExternalRefs,
  },
  'study_session': <String, dynamic>{
    'id': 'p',
    'offering_id': 'of1',
    'kind': 'lecture',
    'location_ref': <String, dynamic>{'type': 'study_org_unit', 'id': 'u1'},
    'topic_refs': <Map<String, dynamic>>[
      <String, dynamic>{'type': 'study_topic', 'id': 't1'},
    ],
    'external_refs': _kProbeExternalRefs,
  },
  'study_offering': <String, dynamic>{
    'id': 'p',
    'course_id': 'c1',
    'period_id': 'per1',
    'external_refs': _kProbeExternalRefs,
  },
  'study_offering_audience': <String, dynamic>{
    'id': 'p',
    'offering_id': 'of1',
    'group_id': 'g1',
    'external_refs': _kProbeExternalRefs,
  },
  'study_participation': <String, dynamic>{
    'id': 'p',
    'principal_ref': <String, dynamic>{'type': 'study_principal', 'id': 'pr1'},
    'target_ref': <String, dynamic>{'type': 'study_offering', 'id': 'of1'},
    'role': 'student',
    'external_refs': _kProbeExternalRefs,
  },
  'study_curriculum': <String, dynamic>{
    'id': 'p',
    'label': 'cursus',
    'version': '1',
    'external_refs': _kProbeExternalRefs,
  },
  'study_topic': <String, dynamic>{
    'id': 'p',
    'curriculum_id': 'cur1',
    'label': 'chapitre',
    'external_refs': _kProbeExternalRefs,
  },
  'study_competency': <String, dynamic>{
    'id': 'p',
    'framework_id': 'fw1',
    'label': 'competence',
    'external_refs': _kProbeExternalRefs,
  },
  'study_competency_framework': <String, dynamic>{
    'id': 'p',
    'label': 'referentiel',
    'version': '1',
    'external_refs': _kProbeExternalRefs,
  },
  // `ZStudyExplanation` ne porte AUCUN canal hors-codegen : tous ses champs
  // sont codegen-ables (`String`, `List<String>`, date ISO-8601). La règle
  // (g)/(g2) ne relève donc rien sur elle — précédent EXACT `study_podcast`.
  'study_explanation': <String, dynamic>{
    'id': 'p',
    'folder_id': 'f',
    'content': 'texte',
  },
  'study_role_binding': <String, dynamic>{
    'id': 'p',
    'principal_ref': <String, dynamic>{'type': 'study_principal', 'id': 'pr1'},
    'scope_ref': <String, dynamic>{'type': 'study_organization', 'id': 'o1'},
    'role_key': 'teacher',
    'external_refs': _kProbeExternalRefs,
  },
  'study_share_grant': <String, dynamic>{
    'id': 'p',
    'artifact_ref': <String, dynamic>{'type': 'study_document', 'id': 'd1'},
    'grantee_ref': <String, dynamic>{'type': 'study_principal', 'id': 'pr1'},
    'external_refs': _kProbeExternalRefs,
  },
};

/// Valeur NON VIDE du canal manuel `external_refs`, partagée par les sondes de
/// la structure d'étude (forme exacte de `ZExternalRef.toMap`).
const List<Map<String, dynamic>> _kProbeExternalRefs = <Map<String, dynamic>>[
  <String, dynamic>{'system': 'sis', 'value': 'ext-1'},
];

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
  // SU-6 — `ZStudyStreak` : compteur d'assiduité FERMÉ (`class ZStudyStreak
  // extends ZEntity {`, sans `with ZExtensible`) — ni `extra`, ni `extension`.
  // Le cast `(e as ZExtensible)` de la lettre d'AD-19.1.c throw dessus (piège n°1),
  // et (e) y serait ROUGE À JAMAIS (aucun slot où préserver une clé inconnue).
  // Le saut de (a)/(b)/(e) est donc DÉCLARÉ ici, jamais silencieux. Sans cette
  // ligne, le verrou bidirectionnel du harnais ROUGIT (vacuité non déclarée) —
  // c'est pourquoi SU-6 coûte 3 lignes, non les « 2 lignes » du message du gate
  // (qui suppose une entité `ZExtensible`, munie de writers).
  'study_streak',
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
const Set<String> kLegacyUpdatedAtMirrors = <String>{
  'study_folder',
  'flashcard',
};

// ===========================================================================
// 🔴 ES-2.2b — `kExtraWriters` : LA VOIE D'ÉCRITURE PUBLIQUE DE `extra`.
// ===========================================================================

/// Écrit [extra] dans [entity] **par UNE voie d'écriture PUBLIQUE** et rend
/// l'entité résultante.
typedef ZExtraWrite =
    Object Function(Object entity, Map<String, dynamic> extra);

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
const Map<String, List<ZExtraWriter>>
kExtraWriters = <String, List<ZExtraWriter>>{
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
    ZExtraWriter(voie: 'ctor', write: _ctorFlashcard, eagerlyNormalized: false),
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
    ZExtraWriter(voie: 'ctor', write: _ctorSmartNote, eagerlyNormalized: false),
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
  // ── Structure d'étude (zcrud_study_kernel) ───────────────────────────────
  // Les 23 entités partagent EXACTEMENT deux voies publiques d'écriture de
  // `extra` (règle AST (j), dérivée du disque) : le constructeur nominal
  // `const` — qui ne peut RIEN filtrer, c'est l'ACCESSEUR `extra`
  // (`zNormalizeExtra`) qui porte la garde ⇒ `eagerlyNormalized: false` — et
  // `copyWith`, qui sanitise EAGER (`_sanitizeExtra`) ⇒ `true`.
  'study_workspace': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyWorkspace,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyWorkspace,
      eagerlyNormalized: true,
    ),
  ],
  'study_principal': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyPrincipal,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyPrincipal,
      eagerlyNormalized: true,
    ),
  ],
  'study_organization': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyOrganization,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyOrganization,
      eagerlyNormalized: true,
    ),
  ],
  'study_org_unit': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyOrgUnit,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyOrgUnit,
      eagerlyNormalized: true,
    ),
  ],
  'study_program': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyProgram,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyProgram,
      eagerlyNormalized: true,
    ),
  ],
  'study_group': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyGroup,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyGroup,
      eagerlyNormalized: true,
    ),
  ],
  'study_classification': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyClassification,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyClassification,
      eagerlyNormalized: true,
    ),
  ],
  'study_subject': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudySubject,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudySubject,
      eagerlyNormalized: true,
    ),
  ],
  'study_course': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyCourse,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyCourse,
      eagerlyNormalized: true,
    ),
  ],
  'study_program_course': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyProgramCourse,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyProgramCourse,
      eagerlyNormalized: true,
    ),
  ],
  'study_calendar': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyCalendar,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyCalendar,
      eagerlyNormalized: true,
    ),
  ],
  'study_period': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyPeriod,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyPeriod,
      eagerlyNormalized: true,
    ),
  ],
  'study_session': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudySession,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudySession,
      eagerlyNormalized: true,
    ),
  ],
  'study_offering': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyOffering,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyOffering,
      eagerlyNormalized: true,
    ),
  ],
  'study_offering_audience': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyOfferingAudience,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyOfferingAudience,
      eagerlyNormalized: true,
    ),
  ],
  'study_participation': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyParticipation,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyParticipation,
      eagerlyNormalized: true,
    ),
  ],
  'study_curriculum': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyCurriculum,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyCurriculum,
      eagerlyNormalized: true,
    ),
  ],
  'study_topic': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyTopic,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyTopic,
      eagerlyNormalized: true,
    ),
  ],
  'study_competency': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyCompetency,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyCompetency,
      eagerlyNormalized: true,
    ),
  ],
  'study_competency_framework': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyCompetencyFramework,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyCompetencyFramework,
      eagerlyNormalized: true,
    ),
  ],
  'study_explanation': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyExplanation,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyExplanation,
      eagerlyNormalized: true,
    ),
  ],
  'study_role_binding': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyRoleBinding,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyRoleBinding,
      eagerlyNormalized: true,
    ),
  ],
  'study_share_grant': <ZExtraWriter>[
    ZExtraWriter(
      voie: 'ctor',
      write: _ctorStudyShareGrant,
      eagerlyNormalized: false,
    ),
    ZExtraWriter(
      voie: 'copyWith',
      write: _copyWithStudyShareGrant,
      eagerlyNormalized: true,
    ),
  ],
};

// ---------------------------------------------------------------------------
// Structure d'étude — voies `copyWith` (`x` transmis **VERBATIM**, règle (k)).
// ---------------------------------------------------------------------------

Object _copyWithStudyWorkspace(Object e, Map<String, dynamic> x) =>
    (e as ZStudyWorkspace).copyWith(extra: x);

Object _copyWithStudyPrincipal(Object e, Map<String, dynamic> x) =>
    (e as ZStudyPrincipal).copyWith(extra: x);

Object _copyWithStudyOrganization(Object e, Map<String, dynamic> x) =>
    (e as ZStudyOrganization).copyWith(extra: x);

Object _copyWithStudyOrgUnit(Object e, Map<String, dynamic> x) =>
    (e as ZStudyOrgUnit).copyWith(extra: x);

Object _copyWithStudyProgram(Object e, Map<String, dynamic> x) =>
    (e as ZStudyProgram).copyWith(extra: x);

Object _copyWithStudyGroup(Object e, Map<String, dynamic> x) =>
    (e as ZStudyGroup).copyWith(extra: x);

Object _copyWithStudyClassification(Object e, Map<String, dynamic> x) =>
    (e as ZStudyClassification).copyWith(extra: x);

Object _copyWithStudySubject(Object e, Map<String, dynamic> x) =>
    (e as ZStudySubject).copyWith(extra: x);

Object _copyWithStudyCourse(Object e, Map<String, dynamic> x) =>
    (e as ZStudyCourse).copyWith(extra: x);

Object _copyWithStudyProgramCourse(Object e, Map<String, dynamic> x) =>
    (e as ZStudyProgramCourse).copyWith(extra: x);

Object _copyWithStudyCalendar(Object e, Map<String, dynamic> x) =>
    (e as ZStudyCalendar).copyWith(extra: x);

Object _copyWithStudyPeriod(Object e, Map<String, dynamic> x) =>
    (e as ZStudyPeriod).copyWith(extra: x);

Object _copyWithStudySession(Object e, Map<String, dynamic> x) =>
    (e as ZStudySession).copyWith(extra: x);

Object _copyWithStudyOffering(Object e, Map<String, dynamic> x) =>
    (e as ZStudyOffering).copyWith(extra: x);

Object _copyWithStudyOfferingAudience(Object e, Map<String, dynamic> x) =>
    (e as ZStudyOfferingAudience).copyWith(extra: x);

Object _copyWithStudyParticipation(Object e, Map<String, dynamic> x) =>
    (e as ZStudyParticipation).copyWith(extra: x);

Object _copyWithStudyCurriculum(Object e, Map<String, dynamic> x) =>
    (e as ZStudyCurriculum).copyWith(extra: x);

Object _copyWithStudyTopic(Object e, Map<String, dynamic> x) =>
    (e as ZStudyTopic).copyWith(extra: x);

Object _copyWithStudyCompetency(Object e, Map<String, dynamic> x) =>
    (e as ZStudyCompetency).copyWith(extra: x);

Object _copyWithStudyCompetencyFramework(Object e, Map<String, dynamic> x) =>
    (e as ZStudyCompetencyFramework).copyWith(extra: x);

Object _copyWithStudyExplanation(Object e, Map<String, dynamic> x) =>
    (e as ZStudyExplanation).copyWith(extra: x);

Object _copyWithStudyRoleBinding(Object e, Map<String, dynamic> x) =>
    (e as ZStudyRoleBinding).copyWith(extra: x);

Object _copyWithStudyShareGrant(Object e, Map<String, dynamic> x) =>
    (e as ZStudyShareGrant).copyWith(extra: x);

// ---------------------------------------------------------------------------
// Structure d'étude — voies `ctor` (constructeur nominal `const` : il stocke
// `extra` BRUT ; c'est l'accesseur qui filtre — c'est la voie que le harnais ne
// sondait pas avant ES-2.2b).
// ---------------------------------------------------------------------------

Object _ctorStudyWorkspace(Object e, Map<String, dynamic> x) {
  final w = e as ZStudyWorkspace;
  return ZStudyWorkspace(
    id: w.id,
    kind: w.kind,
    label: w.label,
    ownerPrincipalId: w.ownerPrincipalId,
    externalRefs: w.externalRefs,
    extension: w.extension,
    extra: x,
  );
}

Object _ctorStudyPrincipal(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyPrincipal;
  return ZStudyPrincipal(
    id: p.id,
    kind: p.kind,
    label: p.label,
    avatarKey: p.avatarKey,
    externalRefs: p.externalRefs,
    extension: p.extension,
    extra: x,
  );
}

Object _ctorStudyOrganization(Object e, Map<String, dynamic> x) {
  final o = e as ZStudyOrganization;
  return ZStudyOrganization(
    id: o.id,
    workspaceId: o.workspaceId,
    parentId: o.parentId,
    kind: o.kind,
    label: o.label,
    code: o.code,
    ancestorIds: o.ancestorIds,
    externalRefs: o.externalRefs,
    extension: o.extension,
    extra: x,
  );
}

Object _ctorStudyOrgUnit(Object e, Map<String, dynamic> x) {
  final u = e as ZStudyOrgUnit;
  return ZStudyOrgUnit(
    id: u.id,
    organizationId: u.organizationId,
    parentId: u.parentId,
    kind: u.kind,
    label: u.label,
    code: u.code,
    ancestorIds: u.ancestorIds,
    externalRefs: u.externalRefs,
    extension: u.extension,
    extra: x,
  );
}

Object _ctorStudyProgram(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyProgram;
  return ZStudyProgram(
    id: p.id,
    organizationId: p.organizationId,
    parentId: p.parentId,
    kind: p.kind,
    code: p.code,
    label: p.label,
    credentialKind: p.credentialKind,
    duration: p.duration,
    ancestorIds: p.ancestorIds,
    externalRefs: p.externalRefs,
    extension: p.extension,
    extra: x,
  );
}

Object _ctorStudyGroup(Object e, Map<String, dynamic> x) {
  final g = e as ZStudyGroup;
  return ZStudyGroup(
    id: g.id,
    organizationId: g.organizationId,
    parentGroupId: g.parentGroupId,
    kind: g.kind,
    label: g.label,
    code: g.code,
    status: g.status,
    ancestorIds: g.ancestorIds,
    externalRefs: g.externalRefs,
    extension: g.extension,
    extra: x,
  );
}

Object _ctorStudyClassification(Object e, Map<String, dynamic> x) {
  final c = e as ZStudyClassification;
  return ZStudyClassification(
    id: c.id,
    targetRef: c.targetRef,
    vocabularyKey: c.vocabularyKey,
    valueKey: c.valueKey,
    periodId: c.periodId,
    validFrom: c.validFrom,
    validTo: c.validTo,
    externalRefs: c.externalRefs,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorStudySubject(Object e, Map<String, dynamic> x) {
  final s = e as ZStudySubject;
  return ZStudySubject(
    id: s.id,
    organizationId: s.organizationId,
    kind: s.kind,
    code: s.code,
    label: s.label,
    colorKey: s.colorKey,
    externalRefs: s.externalRefs,
    extension: s.extension,
    extra: x,
  );
}

Object _ctorStudyCourse(Object e, Map<String, dynamic> x) {
  final c = e as ZStudyCourse;
  return ZStudyCourse(
    id: c.id,
    organizationId: c.organizationId,
    subjectId: c.subjectId,
    kind: c.kind,
    code: c.code,
    label: c.label,
    credits: c.credits,
    expectedHours: c.expectedHours,
    externalRefs: c.externalRefs,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorStudyProgramCourse(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyProgramCourse;
  return ZStudyProgramCourse(
    id: p.id,
    programId: p.programId,
    courseId: p.courseId,
    periodPattern: p.periodPattern,
    classificationConstraints: p.classificationConstraints,
    isRequired: p.isRequired,
    credits: p.credits,
    coefficient: p.coefficient,
    order: p.order,
    externalRefs: p.externalRefs,
    extension: p.extension,
    extra: x,
  );
}

Object _ctorStudyCalendar(Object e, Map<String, dynamic> x) {
  final c = e as ZStudyCalendar;
  return ZStudyCalendar(
    id: c.id,
    organizationId: c.organizationId,
    timezone: c.timezone,
    label: c.label,
    kind: c.kind,
    externalRefs: c.externalRefs,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorStudyPeriod(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyPeriod;
  return ZStudyPeriod(
    id: p.id,
    calendarId: p.calendarId,
    parentId: p.parentId,
    kind: p.kind,
    code: p.code,
    label: p.label,
    startsAt: p.startsAt,
    endsAt: p.endsAt,
    order: p.order,
    ancestorIds: p.ancestorIds,
    externalRefs: p.externalRefs,
    extension: p.extension,
    extra: x,
  );
}

Object _ctorStudySession(Object e, Map<String, dynamic> x) {
  final s = e as ZStudySession;
  return ZStudySession(
    id: s.id,
    offeringId: s.offeringId,
    startsAt: s.startsAt,
    endsAt: s.endsAt,
    kind: s.kind,
    locationRef: s.locationRef,
    meetingUrl: s.meetingUrl,
    topicRefs: s.topicRefs,
    externalRefs: s.externalRefs,
    extension: s.extension,
    extra: x,
  );
}

Object _ctorStudyOffering(Object e, Map<String, dynamic> x) {
  final o = e as ZStudyOffering;
  return ZStudyOffering(
    id: o.id,
    organizationId: o.organizationId,
    courseId: o.courseId,
    periodId: o.periodId,
    curriculumId: o.curriculumId,
    label: o.label,
    code: o.code,
    status: o.status,
    externalRefs: o.externalRefs,
    extension: o.extension,
    extra: x,
  );
}

Object _ctorStudyOfferingAudience(Object e, Map<String, dynamic> x) {
  final a = e as ZStudyOfferingAudience;
  return ZStudyOfferingAudience(
    id: a.id,
    offeringId: a.offeringId,
    groupId: a.groupId,
    role: a.role,
    externalRefs: a.externalRefs,
    extension: a.extension,
    extra: x,
  );
}

Object _ctorStudyParticipation(Object e, Map<String, dynamic> x) {
  final p = e as ZStudyParticipation;
  return ZStudyParticipation(
    id: p.id,
    principalRef: p.principalRef,
    targetRef: p.targetRef,
    role: p.role,
    periodId: p.periodId,
    validFrom: p.validFrom,
    validTo: p.validTo,
    externalRefs: p.externalRefs,
    extension: p.extension,
    extra: x,
  );
}

Object _ctorStudyCurriculum(Object e, Map<String, dynamic> x) {
  final c = e as ZStudyCurriculum;
  return ZStudyCurriculum(
    id: c.id,
    organizationId: c.organizationId,
    subjectId: c.subjectId,
    courseId: c.courseId,
    programId: c.programId,
    code: c.code,
    label: c.label,
    version: c.version,
    status: c.status,
    effectiveFrom: c.effectiveFrom,
    effectiveTo: c.effectiveTo,
    externalRefs: c.externalRefs,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorStudyTopic(Object e, Map<String, dynamic> x) {
  final t = e as ZStudyTopic;
  return ZStudyTopic(
    id: t.id,
    curriculumId: t.curriculumId,
    parentId: t.parentId,
    kind: t.kind,
    code: t.code,
    label: t.label,
    order: t.order,
    expectedDuration: t.expectedDuration,
    weight: t.weight,
    ancestorIds: t.ancestorIds,
    externalRefs: t.externalRefs,
    extension: t.extension,
    extra: x,
  );
}

Object _ctorStudyCompetency(Object e, Map<String, dynamic> x) {
  final c = e as ZStudyCompetency;
  return ZStudyCompetency(
    id: c.id,
    frameworkId: c.frameworkId,
    code: c.code,
    label: c.label,
    description: c.description,
    externalRefs: c.externalRefs,
    extension: c.extension,
    extra: x,
  );
}

Object _ctorStudyCompetencyFramework(Object e, Map<String, dynamic> x) {
  final f = e as ZStudyCompetencyFramework;
  return ZStudyCompetencyFramework(
    id: f.id,
    organizationId: f.organizationId,
    code: f.code,
    label: f.label,
    version: f.version,
    status: f.status,
    externalRefs: f.externalRefs,
    extension: f.extension,
    extra: x,
  );
}

Object _ctorStudyExplanation(Object e, Map<String, dynamic> x) {
  final s = e as ZStudyExplanation;
  return ZStudyExplanation(
    id: s.id,
    folderId: s.folderId,
    content: s.content,
    style: s.style,
    operation: s.operation,
    relatedTopics: s.relatedTopics,
    createdAt: s.createdAt,
    extension: s.extension,
    extra: x,
  );
}

Object _ctorStudyRoleBinding(Object e, Map<String, dynamic> x) {
  final b = e as ZStudyRoleBinding;
  return ZStudyRoleBinding(
    id: b.id,
    principalRef: b.principalRef,
    scopeRef: b.scopeRef,
    roleKey: b.roleKey,
    periodId: b.periodId,
    validFrom: b.validFrom,
    validTo: b.validTo,
    inheritance: b.inheritance,
    externalRefs: b.externalRefs,
    extension: b.extension,
    extra: x,
  );
}

Object _ctorStudyShareGrant(Object e, Map<String, dynamic> x) {
  final g = e as ZStudyShareGrant;
  return ZStudyShareGrant(
    id: g.id,
    artifactRef: g.artifactRef,
    granteeRef: g.granteeRef,
    accessKey: g.accessKey,
    validFrom: g.validFrom,
    validTo: g.validTo,
    externalRefs: g.externalRefs,
    extension: g.extension,
    extra: x,
  );
}

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
    subjectId: f.subjectId,
    ownerId: f.ownerId,
    archivedAt: f.archivedAt,
    createdAt: f.createdAt,
    updatedAt: f.updatedAt,
    isPublic: f.isPublic,
    sharedWith: f.sharedWith,
    canBeJoinedWithLink: f.canBeJoinedWithLink,
    coWorkersCanInviteOthers: f.coWorkersCanInviteOthers,
    shareId: f.shareId,
    // Canaux hors-codegen : le writer reconstruit l'entité À L'IDENTIQUE, sans
    // quoi il perdrait la matière que la sonde transporte pour (f)/(g2).
    ownerRef: f.ownerRef,
    primaryScopeRef: f.primaryScopeRef,
    bindings: f.bindings,
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
const Set<String> kNoValueEqualityProbes = <String>{'ZMindmap', 'ZMindmapNode'};

/// Construit un [ZcrudRegistry] peuplé par **tous** les [kRegistrars].
///
/// [decodeContext] (DW-ES14-2, ES-3.0) est **optionnel** : `null` ⇒ voie
/// historique (slot `extension` non typé / provenance non résolue), utilisée par
/// le gros des assertions (a)-(i) qui ne touchent PAS au typage de `extension`.
/// Fourni ⇒ le registre thread le contexte (résolution typée) — voie prouvée par
/// le groupe « DW-ES14-2 » inversé et le groupe « H2 — canal `source` ».
ZcrudRegistry buildRegistry({ZDecodeContext? decodeContext}) {
  final registry = ZcrudRegistry(decodeContext: decodeContext);
  for (final register in kRegistrars) {
    register(registry);
  }
  return registry;
}
