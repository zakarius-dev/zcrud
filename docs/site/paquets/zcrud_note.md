---
title: zcrud_note
description: Note intelligente zcrud à contenu partageable et typé — jamais une String ambiguë entre markdown et Delta.
---

# zcrud_note

## Rôle

`zcrud_note` porte l'entité `ZSmartNote` : une note rattachée à un dossier
dont le corps est une `List<Map<String, dynamic>>` d'ops Delta neutres — le
type dit le format, sans heuristique de lecture à deviner. Le domaine
(`lib/src/domain/`) reste pur Dart ; seule la couche présentation
(`ZSmartNoteEditor`/`ZSmartNoteReader`) compose les widgets de
`zcrud_markdown` et requiert donc Flutter. Le paquet fournit aussi un slot
d'extension typé pour l'audio (`ZNoteAudio`), une coercition défensive du
contenu hérité, et un canal optionnel qui garde une note double-persistée
cohérente pendant une migration.

## Quand l'utiliser

- Pour une note au corps rich-text dans une application zcrud — carnet,
  mémo, pièce jointe textuelle à un dossier d'étude.
- Pour migrer un corpus de notes hérité (markdown brut, Delta déjà
  sérialisé, texte plat) vers un contenu typé, sans perte silencieuse.

## Quand ne pas l'utiliser

- Si le contenu n'a pas besoin de rich-text : un `String` simple dans votre
  propre modèle suffit.
- Si vous cherchez un domaine totalement pur-Dart sans aucune dépendance
  Flutter : la présentation de ce paquet en tire une (le domaine seul reste
  pur-Dart, testable sous `dart test`).

## Types clés

| Type | Rôle |
|---|---|
| `ZSmartNote` | Entité note — titre, dossier, corps typé, extension et `extra` additifs. |
| `normalizeNoteContentOps` | Coercition défensive et totale d'un corps hérité vers des ops Delta neutres. |
| `ZNoteAudio` / `ZOpaqueNoteExtension` | Slot audio typé, opt-in ; canal de survie d'un payload d'extension non typé. |
| `ZSmartNoteEditor` / `ZSmartNoteReader` | Adaptateurs minces sur `ZMarkdownField`/`ZMarkdownReader`. |
| `ZNoteContentFaithChannel` | Garde une double-persistance (corps typé + copie legacy) cohérente à chaque édition. |

## Voir aussi

- [README du paquet](../../packages/zcrud_note/README.md) — installation, démarrage rapide, API complète.
- [Invariants d'architecture](../concepts/invariants.md) — définitions canoniques AD-1 à AD-16.
- `zcrud_markdown` — l'éditeur/lecteur rich-text composé par la présentation de ce paquet.
