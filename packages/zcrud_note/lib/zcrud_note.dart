/// Barrel d'API publique de `zcrud_note` (ES-2.2, **FR-S5**).
///
/// Note intelligente à **contenu TYPÉ** :
/// - `ZSmartNote` : le **contenu PARTAGEABLE** (titre, dossier, corps) dont le
///   corps est une **`List<Map<String, dynamic>>`** d'ops Delta neutres — **jamais
///   une `String` ambiguë** (AD-28) ;
/// - `normalizeNoteContentOps` : la coercition **défensive et TOTALE** du corpus
///   legacy (**D5**) — une `String` markdown **survit VERBATIM**, **jamais `[]`** ;
/// - `ZNoteAudio` : le slot audio **typé, versionné, OPT-IN** (`ZExtension`,
///   AD-4 pt.1) — l'audio est **hors-schéma** (FR-S5) ;
/// - `ZOpaqueNoteExtension` : le **canal de SURVIE** d'un payload `extension` que
///   **rien n'a su typer** — il est **réémis VERBATIM** au lieu d'être **détruit**
///   (AD-4 pt.1, « évolution additive »).
///
/// ## ⛔ DW-ES14-2 — À LIRE AVANT DE CÂBLER UN STORE SUR `ZSmartNote`
///
/// `ZNoteAudio` est la **PREMIÈRE `ZExtension` concrète du repo** : elle
/// **FALSIFIE** la clause d'échappement n°1 de **DW-ES14-2** (*« la voie registre
/// reste utilisable si — et seulement si — l'entité n'utilise pas le slot
/// `extension` »*). `ZcrudRegistry` / `FirebaseZRepositoryImpl.fromRegistry`
/// appellent `ZSmartNote.fromMap(map)` **sans `extensionParser`** ⇒ le slot n'est
/// **jamais typé** sur cette voie (le payload, lui, **survit** — cf.
/// `ZOpaqueNoteExtension`). **Pour utiliser l'audio, câbler l'entité par le
/// constructeur nominal avec `extensionParser: ZNoteAudio.fromJsonSafe`.**
///
/// **AD-19** : `ZSmartNote` ne déclare **NI `updated_at` NI `is_deleted`** —
/// l'autorité Last-Write-Wins et le soft-delete vivent **hors-entité**
/// (`ZSyncMeta`). Porter le schéma lex verbatim — qui loge `updatedAt` **inline**
/// et en maintient « à la main » une copie hors-entité — recréerait la perte de
/// valeur métier soldée en ES-1.3 (le store écrit sa méta **APRÈS** le corps à
/// chaque `put`).
///
/// Dépend **UNIQUEMENT** de `zcrud_core` (surface **pur-Dart** `domain.dart`) et
/// `zcrud_annotations` (AD-1/AD-17) — **zéro** dép lourde, **zéro** gestionnaire
/// d'état, **zéro** `cloud_firestore`, **zéro** SDK Flutter, **zéro** Quill
/// (NFR-S3/SM-S5/NFR-S10). Tests sous **`dart test`**.
///
/// ⛔ **Pas d'arête vers `zcrud_markdown`** (D4) : c'est un package **Flutter**
/// (`flutter_quill`, `flutter_math_fork`) — l'arête ferait de ce **domaine pur**
/// un package Flutter. Elle naîtra en **ES-6.1**, avec le **premier widget**.
///
/// ## 🔴 Extensions générées masquées (`hide`) — règle **(h)**, tenue par machine
///
/// `ZSmartNoteZcrud` porte un `copyWith` **GÉNÉRÉ** qui ne connaît que les champs
/// `@ZcrudField` : il **IGNORE** `extra`, `extension` **et le canal hors-codegen
/// `content`**, et les remet à leurs **DÉFAUTS** ⇒ **destruction silencieuse du
/// corps de la note**. Le `copyWith` d'**instance** ne masque que l'appel
/// **implicite** ; l'appel **explicite d'extension** reste ouvert **dès que le
/// barrel exporte l'extension** :
///
/// ```dart
/// ZSmartNoteZcrud(note).copyWith(title: 'x')  // ⇒ content, extra, extension
///                                             //   REMIS AUX DÉFAUTS. DÉTRUITS.
/// ```
///
/// C'était **littéralement** le finding **H3** d'ES-2.1 : `ZFlashcardZcrud` — la
/// classe phare, porteuse du canal `source` — était **EXPORTÉE**, **sous 1000+
/// tests verts**. ⇒ **Politique UNIFORME : aucune extension générée n'est
/// exportée.** La (dé)sérialisation et la copie passent par l'**API d'instance**
/// (`fromMap` / `toMap` / `copyWith` à sentinelle). La règle est désormais tenue
/// par `scripts/ci/gate_reserved_keys.dart` (règle **(h)**), plus par un
/// commentaire.
///
/// ## ES-6.1 — Présentation : édition/lecture du corps riche (FR-S25)
///
/// `ZSmartNoteEditor` / `ZSmartNoteReader` sont de **minces adaptateurs** (D1/D2)
/// composant `ZMarkdownField`/`ZMarkdownReader` + `ZDeltaCodec` de `zcrud_markdown`
/// **TELS QUELS** (SM-S4 : aucun nouveau codec, aucune duplication). Ils exposent
/// **UNIQUEMENT** des symboles neutres — `ZSmartNote`, `ValueChanged<ZSmartNote>`,
/// valeurs neutres — **jamais** un type Quill (`QuillController`/`Document`/
/// `Delta`, AC8/AD-1/AD-7). Cette moitié `presentation/` fait de `zcrud_note` un
/// package **Flutter** (tests sous `flutter test`) ; le DOMAINE reste PUR-DART.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_note_table_migration.dart'
    show zMigrateNoteTables, zMigrateStickyNote, zUpgradeLegacyNoteContent;
export 'src/domain/z_note_audio.dart';
export 'src/domain/z_note_content.dart';
export 'src/domain/z_opaque_note_extension.dart';
export 'src/domain/z_smart_note.dart' hide ZSmartNoteZcrud;
export 'src/presentation/z_smart_note_editor.dart' show ZSmartNoteEditor;
export 'src/presentation/z_smart_note_reader.dart' show ZSmartNoteReader;
