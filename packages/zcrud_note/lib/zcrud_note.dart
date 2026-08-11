/// Barrel d'API publique de `zcrud_note`.
///
/// Note intelligente à **contenu TYPÉ** :
/// - `ZSmartNote` : le **contenu PARTAGEABLE** (titre, dossier, corps) dont le
///   corps est une **`List<Map<String, dynamic>>`** d'ops Delta neutres — **jamais
///   une `String` ambiguë**. Invariant AD-28 ;
/// - `normalizeNoteContentOps` : la coercition **défensive et TOTALE** d'un
///   corpus historique — une `String` markdown **survit VERBATIM**, **jamais `[]`** ;
/// - `ZNoteAudio` : le slot audio **typé, versionné, OPT-IN** (`ZExtension`,
///   invariant AD-4) — l'audio est **hors-schéma** ;
/// - `ZOpaqueNoteExtension` : le **canal de SURVIE** d'un payload `extension` que
///   **rien n'a su typer** — il est **réémis VERBATIM** au lieu d'être **détruit**
///   (AD-4, « évolution additive »).
///
/// ## À lire avant de câbler un store sur `ZSmartNote`
///
/// `ZNoteAudio` est la **première `ZExtension` concrète** de ce paquet : la voie
/// registre reste utilisable seulement si l'entité n'utilise pas le slot
/// `extension` — or elle l'utilise. `ZcrudRegistry` /
/// `FirebaseZRepositoryImpl.fromRegistry` appellent `ZSmartNote.fromMap(map)`
/// **sans `extensionParser`** ⇒ le slot n'est **jamais typé** sur cette voie (le
/// payload, lui, **survit** — cf. `ZOpaqueNoteExtension`). **Pour utiliser
/// l'audio, câbler l'entité par le constructeur nominal avec
/// `extensionParser: ZNoteAudio.fromJsonSafe`.**
///
/// **Invariant AD-19** : `ZSmartNote` ne déclare **NI `updated_at` NI
/// `is_deleted`** — l'autorité Last-Write-Wins et le soft-delete vivent
/// **hors-entité** (`ZSyncMeta`), qui écrit sa méta **APRÈS** le corps à
/// chaque `put`. Un champ métier qui reprendrait l'une de ces clés serait donc
/// écrasé silencieusement.
///
/// Dépend **UNIQUEMENT** de `zcrud_core` (surface **pur-Dart** `domain.dart`) et
/// `zcrud_annotations` — **zéro** dép lourde, **zéro** gestionnaire
/// d'état, **zéro** `cloud_firestore`, **zéro** SDK Flutter, **zéro** Quill
/// dans le domaine. Tests sous **`dart test`**.
///
/// **Pas d'arête vers `zcrud_markdown`** dans le domaine : c'est un paquet
/// **Flutter** (`flutter_quill`, `flutter_math_fork`) ; l'arête n'existe que
/// côté **présentation** (`ZSmartNoteEditor`/`ZSmartNoteReader`), qui compose
/// les widgets `zcrud_markdown` **tels quels**.
///
/// ## Extensions générées masquées (`hide`), tenue par machine
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
/// Une classe d'extension générée exportée par erreur reste verte sous des
/// centaines de tests tant que personne n'appelle son `copyWith` explicitement
/// — c'est ce qui rend le défaut facile à manquer. ⇒ **Politique UNIFORME :
/// aucune extension générée n'est exportée.** La (dé)sérialisation et la copie
/// passent par l'**API d'instance** (`fromMap` / `toMap` / `copyWith` à
/// sentinelle). La règle est tenue par `scripts/ci/gate_reserved_keys.dart`,
/// pas par un simple commentaire.
///
/// ## Présentation : édition/lecture du corps riche
///
/// `ZSmartNoteEditor` / `ZSmartNoteReader` sont de **minces adaptateurs**
/// composant `ZMarkdownField`/`ZMarkdownReader` + `ZDeltaCodec` de `zcrud_markdown`
/// **TELS QUELS** (aucun nouveau codec, aucune duplication). Ils exposent
/// **UNIQUEMENT** des symboles neutres — `ZSmartNote`, `ValueChanged<ZSmartNote>`,
/// valeurs neutres — **jamais** un type Quill (`QuillController`/`Document`/
/// `Delta`), invariants AD-1/AD-7. Cette moitié `presentation/` fait de `zcrud_note` un
/// package **Flutter** (tests sous `flutter test`) ; le DOMAINE reste PUR-DART.
///
/// ## `ZNoteContentFaithChannel` : À LIRE SI VOS DONNÉES
/// PRÉCÈDENT LA MIGRATION
///
/// Un hôte migré par *strangler fig* **double** son corps de note : le champ TYPÉ
/// `ZSmartNote.content` (ops, lisible par un consommateur zcrud pur) **et** une
/// clé d'`extra` portant son format d'origine, laquelle **FAIT FOI** à la
/// relecture. `ZSmartNoteEditor` ne remontait que `copyWith(content: ops)` :
/// **MESURÉ**, la clé de foi restait figée et la note se rouvrait **sans la
/// modification**, silencieusement.
///
/// ⇒ Déclarer `ZSmartNoteEditor.faithChannel` (**facultatif**) fait écrire les
/// **DEUX** canaux dans la **même** remontée, depuis les **mêmes** ops. Un
/// producteur zcrud pur (aucun doublage) est **strictement inchangé** — le
/// paramètre est `null` par défaut, aucune rupture d'API.
///
/// Le round-trip `String → ops → String` n'est **pas** fidèle à l'octet
/// (mesuré sur 46 constructions markdown : **2 %** en octet, **67 %** en tolérant
/// le `\n` terminal ; cassent notamment le **LaTeX bloc**, la fusion du **saut de
/// ligne simple**, les lignes vides multiples, les entités HTML). C'est pourquoi
/// le canal de foi reste nécessaire — et pourquoi il doit être **écrit à chaque
/// édition**. Détail dans la dartdoc de `ZNoteContentFaithChannel`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_note_table_migration.dart'
    show zMigrateNoteTables, zMigrateStickyNote, zUpgradeLegacyNoteContent;
export 'src/domain/z_note_audio.dart';
export 'src/domain/z_note_content.dart';
export 'src/domain/z_note_faith_channel.dart';
export 'src/domain/z_opaque_note_extension.dart';
export 'src/domain/z_smart_note.dart' hide ZSmartNoteZcrud;
export 'src/presentation/z_smart_note_editor.dart' show ZSmartNoteEditor;
export 'src/presentation/z_smart_note_reader.dart' show ZSmartNoteReader;
