# Handoff **v0.43.0** — CR-IFFD-48 + complément CR-IFFD-47 : le rendu par défaut, généralisé et VERROUILLÉ

> **Tag à épingler : `v0.43.0`** · additif, aucune rupture d'API, aucun défaut changé.
> Un hôte passif ne bouge pas d'une ligne ; aucun hôte n'a de compensation à retirer dans ce lot.

---

## 1. Complément CR-47 — la voie typée passe désormais TOUTES les options, et une garde l'impose

Le propriétaire a constaté que `.flashcards(…)` ne relayait pas tout. Inventaire exhaustif fait :
sur les 11 options de `ZDefaultFlashcardCard`, **une seule manquait** — `semanticLabel`. Livré :
`semanticLabelOf: String? Function(ZFlashcard)?` (même patron que `colorKeyOf`/`tagsOf`).

**Mais le vrai livrable est la garde de PARITÉ** : la dérive était structurelle — chaque option
ajoutée demain aurait dû être recopiée à la main, sans rien pour rougir à l'oubli. Désormais :

* extraction **réelle** des paramètres des deux constructeurs (garde de source ancrée `melos.yaml`,
  échec **bruyant** si un constructeur est introuvable) ;
* correspondance **NOMINALE par table explicite** (`onTap` → `onCardTap`, `tags` → `tagsOf`, …) —
  jamais un compte : une contre-preuve dédiée vérifie que deux ajouts non reliés restent rouges ;
* **recensement fermé** : tout nouveau constructeur `ZStudyToolsSectionSpec.*` non enregistré comme
  paire rougit aussi ;
* vérifiée **deux fois** : par les injections du lot, puis par une injection **indépendante de
  l'orchestrateur** (option fantôme ajoutée à la carte ⇒ rouge nommant le paramètre et le geste
  attendu ; restauration bit à bit).

⇒ Une option de carte inatteignable depuis la voie typée est désormais un état **impossible en
silence** — pour les **cinq** paires, pas seulement la flashcard.

## 2. CR-48 — quatre cartes par défaut, votre règle appliquée à la lettre

> *« Ce qui migre, c'est la FORME. Ce qui reste au thème, c'est la MATIÈRE. »*

C'est votre formulation, et elle a tranché chaque décision de dessin : **11 décisions de
couleur/graisse recensées, 11/11 exprimées en rôles** (`ColorScheme` via `zResolveColorKeyOrSlot`,
paires `*Container`, `TextTheme`). **Zéro jeton nouveau** — `zcrud_core` n'est pas modifié dans ce
lot (0 fichier). Votre question « les rôles suffisent-ils ? » a donc sa réponse mesurée : **oui,
intégralement**, pour ces quatre cartes.

| Carte | Voie typée | Pourquoi |
|---|---|---|
| `ZDefaultFlashcardCard` (v0.42.0) | `.flashcards(cards:)` | déjà livrée |
| `ZDefaultMindmapCard` (vignette) | ✅ `.mindmaps(maps:)` | `ZMindmap` ∈ dépendances déclarées |
| `ZDefaultExamCard` | ✅ `.exams(exams:)` | `ZExam` ∈ dépendances déclarées |
| `ZDefaultDocumentCard` | 🔴 **carte autonome seule** | `ZStudyDocument` ∈ `zcrud_document`, **non-dépendance** |
| `ZDefaultNoteCard` | 🔴 **carte autonome seule** | `ZSmartNote` ∈ `zcrud_note`, **non-dépendance** |

**Pourquoi pas de `.documents(…)`/`.notes(…)`** : les modèles vivent dans des packages dont
`zcrud_study` ne dépend pas, et **AD-1 interdit d'ajouter une arête** pour un constructeur de
confort. Les deux cartes existent (paramètres primitifs : titre, sous-titre, format…) ; l'hôte les
instancie dans son `itemBuilder` — deux lignes. Un test **rougira si l'arête est un jour déclarée**,
pour que la voie typée soit alors livrée au lieu d'être oubliée.

**L'icône typée par format** (votre point sur le document) : un **mapping ouvert injecté** —
`formatIcons` fourni par l'hôte > table par défaut (27 formats) > repli neutre — sur une clé de
format **opaque normalisée** (extension, casse, MIME). Jamais un enum : un format nouveau ne demande
pas de CR.

## 3. La mesure rail/grille — encore un vrai défaut trouvé

Comme en v0.42.0, la mesure que vous déclariez non faite a mordu : le corps de `ZDefaultNoteCard`
**débordait de 156 px** en cellule 300 × 80 (la classe exacte de CR-IFFD-37 — un coût invisible aux
gardes de présence). Corrigé à la source (`Flexible` loose, espacement compris). Les hauteurs des
quatre cartes à 300 / 800 / 1200 dp sont dans le rapport de lot ; **aucun débordement restant**.

## 4. Votre ligne

| Vous êtes… | Geste |
|---|---|
| **hôte passif** | **rien** — `itemBuilder` reste requis dans le constructeur principal, les défauts ne s'appliquent qu'aux voies typées |
| **vous, IFFD** | remplacez vos `StudyToolsItemCardView` par les cartes par défaut + vos actions par créneaux ; `.mindmaps`/`.exams` directs ; documents/notes via `itemBuilder` à deux lignes |
| **hôte ayant compensé** | **rien à retirer dans CE lot** — mais les deux points du handoff v0.42.0 § 6 (`ZTagChips`, `onLongPress`) restent valables si vous ne les avez pas encore traités |

🟢 **Tripwire recommandé** : si vous adoptez une carte par défaut en remplacement de la vôtre, gardez
un test qui affirme la présence de **votre** carte. Il rougira à la migration et vous donnera la
liste exacte des écrans touchés.

## 5. Vérification

`melos analyze` **RC=0** · `melos verify` **RC=0** (ACYCLIQUE + CORE OUT=0, 36 paquets) ·
`zcrud_study` **1040** (+35) · **0 error, 0 warning, 0 info neuf** (baseline 57 exacte) ·
voisins rejoués verts : `zcrud_flashcard` 586, `zcrud_session` 565, `zcrud_mindmap` 207, `zcrud_exam` 79.

**R3 — 4 injections du lot + 1 de l'orchestrateur, toutes ROUGES D'ASSERTION.** La complémentarité
signature/câblage est démontrée (une injection sur la signature seule, une sur le câblage seul —
chacune rougit sa garde et pas l'autre).

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 6. Ce que nous savons ne pas avoir couvert

* La **vignette de mindmap est un croquis structurel**, pas un rendu du graphe réel (SM-1 : un rendu
  de graphe par vignette dans une grille serait un coût par cellule).
* `reminderLabel` est **unique par section**, pas par examen.
* Toujours **aucun golden**, et le RTL des nouvelles cartes n'est couvert que par la garde de source.
* Les cartes autonomes document/note ne sont pas testées **à travers** un `itemBuilder` d'hôte réel.
* Le comportement des voies typées `.mindmaps`/`.exams` **à travers** `ZSectionedStudyLayout` n'est
  pas testé (même limite que `.flashcards`, déclarée en v0.42.0).
