# Handoff v3.32.0 — les gardes de couleur qui voyaient à moitié

> **Date** : 2026-08-29. **Portée** : `zcrud_core`, `zcrud_document`, `zcrud_chat`,
> `zcrud_chat_syncfusion`. **Nature** : durcissement de gardes uniquement — **aucun changement
> d'API, de rendu ni de comportement** ; aucun code de `lib/` modifié dans aucun paquet.

## 1. Le défaut

Découvert par une campagne R3 (une injection restée inerte, pas une relecture) : les gardes de
style FR-26 ne reconnaissaient qu'une partie des formes d'écriture d'une couleur. Selon le paquet,
passaient inaperçus : `Color(4280391411)` (entier décimal), la même forme sur plusieurs lignes,
`Color.from(alpha: …)` à composantes littérales, un hex hors de `Color(` (`0x2196F3`,
`0x80112233`), un grand décimal nu de la plage ARGB, `Color( 0xFF…)` avec une simple espace après
la parenthèse — et, dans `zcrud_chat` et `zcrud_chat_syncfusion`, `Color.fromARGB(` /
`Color.fromRGBO(` n'avaient jamais été portées.

## 2. Ce que le socle livre

Les quatre gardes durcies au même patron : motif hexadécimal élargi
(`0x(?:[0-9a-fA-F]{6}|[fF][0-9a-fA-F]{7}|80[0-9a-fA-F]{6})`), **second scan sur contenu joint**
(les formes multi-lignes ne se reconstituent pas à cheval sur un commentaire ou une exemption),
offenders nommant le motif qui a mordu. Renoncement documenté partout : un hex de 8 chiffres à
octet de tête quelconque reste hors de portée — il est indistinguable d'un masque
(`0x00FFFFFF`), d'une graine FNV (`0x811C9DC5`) ou d'une sentinelle de `clamp`
(`0x7fffffff`, réellement présente dans `z_chat_tile_shell.dart:498`) ; ces usages légitimes sont
figés en contre-preuves. `Color.from` à composantes **calculées** reste permise (voie de
`zReadableTintOn`).

**Aucun site fautif exhumé** : les motifs neufs rejoués sur tout `lib/` du dépôt ne désignent que
les fichiers de référence exemptés nominativement. Le durcissement protège l'avenir, il n'a rien
révélé de livré.

## 3. Ce qui change pour un hôte

Rien — aucun octet de `lib/` n'a bougé (sha vérifiés). Un hôte qui copie le patron de garde chez
lui (tripwire recommandé) peut reprendre les motifs durcis.

## 4. Vérification

| Paquet | Avant | Après |
|---|---|---|
| `zcrud_core` | 2 669 | **2 670** |
| `zcrud_document` | 330 | **331** |
| `zcrud_chat` | 1 068 | **1 069** |
| `zcrud_chat_syncfusion` | 69 | **70** |

`melos run generate` : 0 `.g.dart` · `analyze` RC=0 · `verify` RC=0 · R3 : chaque forme prouvée
inerte AVANT et mordante APRÈS par injection réelle dans `lib/`, rouge par assertion, restauration
par copie, sha identiques, grep négatif montré. Balayage des 41 : **41/41 verts** — premier balayage intégralement vert (la suite du generator, sortie de son rouge environnemental, est mesurée en `dart test`).
