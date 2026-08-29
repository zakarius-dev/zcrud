# Handoff v3.35.0 — le rich-text s'ouvre : formules, tableaux, embeds, HTML

> **Date** : 2026-08-29. **Portée** : `zcrud_markdown`. **Traite** : les cinq CR d'IFFD du
> 2026-08-29 (129 à 133), toutes vérifiées sur disque avant d'écrire. Livraison **entièrement
> additive** : chaque défaut reconduit l'existant.

## Clés de schéma ajoutées

**Aucune.**

## 1. Ce que le socle livre

| CR | Livré |
|---|---|
| **129** | `ZRichTextFormulaSpec.fallbackBuilder(context, source, error)` — appelé par `onErrorFallback` **avant** le placeholder d'icône ; `null` ⇒ rendu inchangé ; un repli qui lève est neutralisé ; le second moteur reste chez l'hôte (gate anti-`flutter_tex` intact et vert) |
| **130** | `z_latex_normalize.dart` public, fonctions **pures** : `zFixLatexLineBreaks`, `zUnescapeLatexCommands` (dictionnaire `kZLatexCommands` — **79** commandes, recompté sur la source citée, pas 81), `zAutoDelimitLatex`, `zNormalizeLegacyLatexSource`, `zNormalizeLatexInText` ; les deux premières réparations **actives sur le chemin de lecture hérité** (`formula`/`formula_inline`) — les clés d'écriture du socle traversent nues ; `sourceNormalizer` sur la spec. Écart mesuré : l'auto-délimitation opère sur du **texte**, pas sur une source de formule — l'appliquer au chemin hérité aurait cassé ce qu'elle répare ; livrée pour le Markdown amont. Défaut d'origine corrigé au passage : l'auto-délimitation mangeait l'espace suivant une formule nue |
| **131** | `showZTableDialog(maxDim:, cellWidth:, cellBuilder:)` + `ZTableEditorScope` (le dialogue est ouvert par la barre d'outils : le scope porte les réglages de l'hôte jusqu'à lui) ; défauts 12 et 96 dp inchangés |
| **132** | `extraEmbedRenderers` sur les trois points de montage + `showZRichTextFullscreenDialog` + `registerZMarkdownFields` (le registre est la voie hôte — une garde l'a exigé). Type **neutre** `ZEmbedRenderer` (clé, builder, `block`) plutôt que le `EmbedBuilder` de flutter_quill demandé : un type d'éditeur en signature publique aurait imposé la dépendance à tout hôte (AD-1). Collision : **l'hôte gagne** (ses rendus en tête ; flutter_quill retient le premier builder dont la clé correspond — mesuré) |
| **133** | `ZHtmlCodec({customBlocks})` relayé à `HtmlToDelta` ; vide ⇒ décodage identique ; `CustomHtmlPart` assumé en signature (une règle de conversion se définit contre le DOM de la bibliothèque — pas d'équivalent neutre possible) ; AD-12 intact (conversion, pas rendu) |

## 2. Ce qui change pour un hôte

**Hôte passif : rien** — tous les défauts reconduisent l'existant, prouvé par gardes d'inertie
stricte (formules valides inchangées à l'octet sur le chemin hérité compris).

**Hôte ayant compensé** : le jour où il pose `fallbackBuilder`, retirer le **second moteur de
formules** posé sur le chemin socle (sinon les deux s'additionnent) ; ses normalisations LaTeX
locales deviennent **sans objet** sur le chemin hérité (inoffensives car idempotentes).

## 3. Vérification

`zcrud_markdown` : **701 verts** (655 + 46), analyze propre, gate d'isolation vert ·
`zcrud_core` (gardes inter-paquets) rejoué : **2 690 verts** · `melos run generate` 0 `.g.dart` ·
`analyze` RC=0 · `verify` RC=0 · R3 : 7 injections (une par volet), rouges par assertion,
restaurations par copie, sha identiques, greps négatifs · Balayage des 41 : **41/41 verts**.
