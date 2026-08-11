# zcrud_note

Note intelligente zcrud à contenu partageable et **typé** — jamais une
`String` ambiguë.

## Aperçu {#apercu}

`zcrud_note` porte l'entité `ZSmartNote` : une note rattachée à un dossier
dont le corps est une `List<Map<String, dynamic>>` d'ops Delta neutres — le
**type** dit le format, sans heuristique de lecture à deviner. Le domaine
(`lib/src/domain/`) reste **pur Dart** ; seule la couche présentation
(`ZSmartNoteEditor`/`ZSmartNoteReader`) compose les widgets de
`zcrud_markdown` et requiert donc le SDK Flutter.

Ce paquet fournit :

- `ZSmartNote` — l'entité, avec son slot d'extension typé `ZNoteAudio` (audio,
  opt-in, hors-schéma) et le canal de survie `ZOpaqueNoteExtension` pour tout
  payload d'extension que rien n'a su typer ;
- `normalizeNoteContentOps` — la coercition défensive et totale d'un corps
  hérité (une `String` markdown, un Delta déjà sérialisé, une valeur
  corrompue) vers des ops neutres, sans jamais perdre le contenu ;
- `ZSmartNoteEditor`/`ZSmartNoteReader` — de minces adaptateurs qui composent
  `ZMarkdownField`/`ZMarkdownReader` **tels quels**, sans nouveau codec ;
- `ZNoteContentFaithChannel` — un canal optionnel qui garde une note
  double-persistée (corps typé + copie legacy en `extra`) cohérente à chaque
  édition.

**Utilisez ce paquet** pour une note au corps rich-text dans une application
zcrud — carnet, mémo, pièce jointe textuelle à un dossier d'étude. **N'utilisez
pas ce paquet** si votre contenu n'a pas besoin de rich-text (un `String`
simple suffit alors dans votre propre modèle), ou si vous cherchez un domaine
totalement pur-Dart sans aucune dépendance Flutter : la présentation de ce
paquet en tire une (le domaine seul, lui, reste pur-Dart et testable sous
`dart test`).

## Installation {#installation}

Ce paquet est distribué en dépendance git privée depuis le monorepo zcrud —
voir [Consommation privée des packages zcrud](../../docs/private-git-consumption.md)
pour l'épinglage par tag et la déclaration `dependency_overrides` requise par
les arêtes inter-`zcrud_*`.

## Démarrage rapide {#demarrage-rapide}

```dart
import 'package:flutter/widgets.dart';
import 'package:zcrud_note/zcrud_note.dart';

/// Une note, reconstruite défensivement depuis une map persistée : jamais
/// de throw, même sur un corps corrompu ou d'un format hérité.
ZSmartNote loadNote(Map<String, dynamic> map) => ZSmartNote.fromMap(map);

/// Édition du corps riche : `onChanged` reçoit la note mise à jour, prête à
/// persister via `note.toMap()`.
Widget buildEditor(ZSmartNote note, ValueChanged<ZSmartNote> save) =>
    ZSmartNoteEditor(note: note, onChanged: save);

/// Lecture seule du même corps.
Widget buildReader(ZSmartNote note) => ZSmartNoteReader(note: note);
```

## Concepts clés {#concepts-cles}

- **Contenu typé** — `ZSmartNote.content` est toujours une
  `List<Map<String, dynamic>>` d'ops Delta ; aucun code applicatif n'a besoin
  de deviner si une valeur est du markdown ou du Delta JSON.
- **Extension additive (invariant [AD-4](../../docs/site/concepts/invariants.md#ad-4))** —
  le slot `extension` porte `ZNoteAudio` quand un `extensionParser` est
  injecté au constructeur nominal ; sur la voie registre générique (sans
  parser), le payload survit quand même via `ZOpaqueNoteExtension`, mais son
  type reste indisponible tant que l'entité n'est pas reconstruite avec le
  parser adéquat.
- **Pas d'horodatage de synchronisation inline** — `ZSmartNote` ne déclare ni
  `updated_at` ni `is_deleted` : cette autorité vit hors-entité, dans le
  `ZSyncMeta` du store (patron décrit par l'invariant [AD-9](../../docs/site/concepts/invariants.md#ad-9)).
- **Présentation = adaptateurs minces** — `ZSmartNoteEditor`/`ZSmartNoteReader`
  ne réimplémentent rien : ils branchent `ZSmartNote.content` directement sur
  `ZMarkdownField`/`ZMarkdownReader`, la valeur neutre étant déjà celle
  attendue par ces widgets.

## API principale {#api-principale}

| Type | Rôle |
|---|---|
| `ZSmartNote` | Entité note — titre, dossier, corps typé, extension et `extra` additifs. |
| `normalizeNoteContentOps` | Coercition défensive et totale d'un corps hérité vers des ops Delta neutres. |
| `ZNoteAudio` | Slot audio typé et versionné, opt-in via `ZExtension`. |
| `ZOpaqueNoteExtension` | Canal de survie d'un payload d'extension que rien n'a su typer. |
| `ZSmartNoteEditor` | Éditeur du corps riche, adaptateur mince de `ZMarkdownField`. |
| `ZSmartNoteReader` | Lecteur non éditable du corps riche, adaptateur mince de `ZMarkdownReader`. |
| `ZNoteContentFaithChannel` | Canal optionnel gardant une double-persistance (corps typé + copie legacy) cohérente. |
| `zMigrateNoteTables` / `zMigrateStickyNote` / `zUpgradeLegacyNoteContent` | Utilitaires de migration d'un corps hérité vers le format canonique. |

## Cas limites et invariants {#cas-limites}

- **Désérialisation totale et préservante (invariant [AD-10](../../docs/site/concepts/invariants.md#ad-10))** —
  `normalizeNoteContentOps` ne réduit jamais un corps lisible à `[]` : une
  `String` non-Delta survit verbatim en un seul op texte plutôt que d'être
  perdue.
- **La voie registre ne type pas `extension`** — un hôte qui désérialise via
  `ZcrudRegistry` récupère toujours la donnée audio (dans
  `ZOpaqueNoteExtension`), mais jamais l'instance `ZNoteAudio` typée : pour
  l'obtenir, passer par le constructeur nominal avec
  `extensionParser: ZNoteAudio.fromJsonSafe`.
- **Le round-trip Markdown n'est pas fidèle à l'octet** — un corps hérité
  reconverti via `ZMarkdownCodec` peut perdre des détails de mise en forme
  (LaTeX bloc, sauts de ligne simples...). Pour une note qui double sa
  persistance pendant une migration, `ZNoteContentFaithChannel` garde les deux
  copies cohérentes sans prétendre à un round-trip parfait.
- **`copyWith`/`toMap` d'instance, jamais l'extension générée** — la copie et
  la sérialisation passent par les méthodes d'instance de `ZSmartNote`, qui
  seules préservent `content`, `extra` et `extension` ; l'extension générée
  par le codegen n'est pas exportée par ce barrel.

## Voir aussi {#voir-aussi}

- Fiche paquet : [`docs/site/paquets/zcrud_note.md`](../../docs/site/paquets/zcrud_note.md)
- [Invariants d'architecture](../../docs/site/concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_markdown` — l'éditeur/lecteur rich-text composé par la présentation de ce paquet.
- `zcrud_core` — `ZExtension`, `ZSyncMeta`, `ZcrudRegistry`.

## Licence {#licence}

MIT — voir la racine du dépôt.
