# Code-review — epic CHAT · lentille « tests porteurs : la garde mord-elle vraiment ? »

**Date** : 2026-08-01 · **Mode** : LECTURE SEULE du code (injections temporaires restaurées par copie,
vérifiées par `md5sum -c`) · **Périmètre** : `zcrud_chat_kernel` (283), `zcrud_chat` (152),
`zcrud_chat_syncfusion` (52), `zcrud_menu` (67), `zcrud_study` (tests touchés par la migration du menu).

## Méthode

* Manifeste `md5sum` des 244 `.dart` (`lib/` + `test/`) des cinq paquets pris **avant** toute
  manipulation ; sauvegarde par `cp -a` dans le scratchpad ; restauration **par copie**, jamais
  `git checkout` ; `md5sum -c` **après chaque** restauration (toujours 0 divergence) ; grep négatif
  final prouvant qu'aucun motif d'injection ne subsiste.
* Chaque motif d'injection **compté avant** application (toujours exactement 1 occurrence).
* Tests lancés **depuis le dossier de chaque paquet** (`dart test` pour le kernel pur-Dart,
  `flutter test` ailleurs). Aucun gate global (`melos run …`) lancé.
* **Baselines vertes mesurées** : `zcrud_chat_kernel` 283/283, `zcrud_menu` 67/67,
  `zcrud_chat_syncfusion` 52/52, `zcrud_chat` 156 verts (dont ~5 d'un fichier-sonde d'un autre
  relecteur, cf. §Observation).

**10 injections de régression** ont été appliquées et mesurées, couvrant 8 groupes de gardes.

---

## Verdict global

La qualité de garde de cette epic est **au-dessus de la moyenne du dépôt** : contrôles positifs,
compteurs anti-vacuité (`scanned > N`), témoins synthétiques et contre-preuves R3 sont présents
presque partout, et les défauts historiques du catalogue (RTL sous `Overlay`, `Align` non monté,
regex `Text(` ligne-à-ligne, virtualisation prouvée par comptage) ont été **réellement corrigés** —
je l'ai vérifié par injection, pas par lecture.

**Cinq gardes ne mordent pas.** Toutes relèvent de la même famille : **une assertion de taille ou de
capacité qui mesure autre chose que le code qu'elle prétend défendre** (plancher du SDK, motif
satisfait par un fichier voisin, dimension imposée par un conteneur). Aucune n'indique un défaut
produit : le comportement mesuré est correct aujourd'hui — c'est la **détection de sa régression**
qui est absente.

---

## Findings — gardes NON MORDANTES (prouvées par injection)

### F1 — MAJEUR · `z_flashcard_a11y_test.dart:184-196` — la garde 48 dp mesure le plancher de Material, pas le nôtre

**Ce qu'elle prétend défendre** : « chaque item du menu est une cible ≥ 48 dp » sur le menu d'actions
de `ZFlashcardListView`.

**Le motif exact** : la mesure porte sur `find.ancestor(of: text, matching:
find.byType(PopupMenuItem<ZMenuEntry>)).first`. `PopupMenuItem` impose lui-même
`kMinInteractiveDimension` (48). Le plancher de `ZMenuEntryTile` — **le nôtre** — n'est jamais lu.

C'est **exactement le défaut que CHAT-4b a documenté et retendu chez lui**
(`chat4b_item_actions_menu_delegation_test.dart:477-488` : « la mesure ci-dessus, sur l'ancêtre
`PopupMenuItem`, est TAUTOLOGIQUE […] Injecter `minHeight: 1.0` dans `ZMenuEntryTile` laissait donc
la garde VERTE »). La migration a renommé le paramètre de type
(`PopupMenuItem<ZItemAction>` → `PopupMenuItem<ZMenuEntry>`) **sans reporter le resserrement sur le
jumeau** — la classe de défaut « un paquet l'a resserrée, son jumeau ne l'a pas suivie ».

**Injection** : `packages/zcrud_menu/lib/src/presentation/z_menu_entry_tile.dart:79-80`,
`minWidth/minHeight: kZMenuMinTapTarget` → `0.0` (1 occurrence, comptée).

**Mesure** :

```
cd packages/zcrud_study && flutter test test/presentation/z_flashcard_a11y_test.dart \
                                        test/cr_iffd32_item_actions_menu_slot_test.dart
→ 00:01 +19: All tests passed!
```

**Verdict : NE MORD PAS.** (Le même `test/presentation/z_flashcard_a11y_test.dart:267-275` — le volet
`Semantics` annoncées une seule fois — vise aussi `PopupMenuItem` mais reste, lui, porteur : c'est le
label FUSIONNÉ qui est mesuré, et il dépend bien de notre `excludeSemantics`.)

**Correctif suggéré** : viser `find.byType(ZMenuEntryTile)` (ou une composition hors `PopupMenuItem`),
comme le fait déjà `z_menu_a11y_rtl_test.dart:131-143` — qui, lui, **mord** (mesuré : rouge sous la
même injection).

---

### F2 — MAJEUR · `z_chat_attachment_test.dart:365-376` — « cible de retrait ≥ 48 dp » mesure la hauteur de la bande

**Ce qu'elle prétend défendre** : le bouton de retrait d'une pièce jointe porte son propre plancher
tactile (`ConstrainedBox(minHeight/minWidth: kZChatMinTapTarget)` dans
`z_chat_attachment_strip.dart:173-177`).

**Le motif exact** : la mesure porte sur `find.byType(GestureDetector)`, dont la taille est en réalité
imposée par `_kStripHeight = kZChatMinTapTarget + 16.0` (bande de 64 dp) en hauteur et par la largeur
intrinsèque du libellé. Retirer le plancher propre ne change donc rien à la mesure.

**Injection (deux passes, la seconde étant la concluante)** :

1. `minHeight/minWidth: kZChatMinTapTarget` → `0.0` → **1 rouge**, mais dans
   `z_chat_c5_guard_test.dart` (« la cible tactile est ADOSSÉE à la constante partagée ») : rouge
   **TEXTUEL** (`RegExp(r'minHeight:\s*\d')`), qui ne dit rien de la taille rendue. La garde
   comportementale, elle, était verte.
2. Pour isoler : `minHeight/minWidth: kZChatMinTapTarget * 0` — plancher **réellement nul**, référence
   textuelle **conservée** :

```
cd packages/zcrud_chat && flutter test test/z_chat_attachment_test.dart test/z_chat_c5_guard_test.dart
→ 00:00 +39: All tests passed!
```

**Verdict : NE MORD PAS.** Le plancher tactile du bouton de retrait peut être supprimé sans qu'aucune
garde de comportement ne rougisse.

**Correctif suggéré** : mesurer le `ConstrainedBox` du bouton (pattern déjà employé et **mordant**
dans `z_chat_shell_seam_test.dart:336-367` et `z_sf_assist_view_test.dart:291-314`), ou rendre la
bande à une hauteur < 48 dp dans le test pour que le plancher propre soit la seule contrainte active.

---

### F3 — MEDIUM · `z_menu_supersedes_test.dart:78` — « glyphe de déclencheur injecté » : motif dupliqué avec « glyphe injecté »

**Ce qu'elle prétend défendre** : la capacité historique « le déclencheur porte un glyphe injecté »
survit dans `zcrud_menu`.

**Le motif exact** : `_Capacite('glyphe de déclencheur injecté', 'final IconData? icon;')` — **le même
littéral** que `_Capacite('glyphe injecté', …)` ligne 76. Or `final IconData? icon;` est déclaré dans
**deux** fichiers (`z_menu_entry.dart` et `z_menu_trigger.dart`), et la table est évaluée sur la
**concaténation** de tout `lib/`. La capacité du déclencheur est donc couverte par la déclaration de
l'entrée.

**Injection** : `packages/zcrud_menu/lib/src/domain/z_menu_trigger.dart` **entièrement vidé**
(remplacé par `library;`). C'est légitime ici : `z_menu_supersedes_test.dart` n'importe pas
`zcrud_menu` — il lit le disque, la compilation n'entre pas en jeu.

**Mesure** : sur 34 tests, **1 seul rouge** — « label a11y du déclencheur » (`final String? tooltip;`,
motif unique au fichier). « **glyphe de déclencheur injecté** » et l'ensemble du groupe PRÉSERVATION
sont restés **verts** alors que `ZMenuTrigger`, son `icon`, son `semanticLabel` et son assert
anti-déclencheur-muet avaient tous disparu.

**Verdict : NE MORD PAS.** **Correctif** : motif distinctif, p. ex. `class ZMenuTrigger` ou
`const ZMenuTrigger.widget(`.

---

### F4 — MEDIUM · `z_menu_supersedes_test.dart:81` — « cible ≥ 48 dp explicite » satisfaite par un autre fichier

**Ce qu'elle prétend défendre** — sa propre dartdoc le dit (ligne 22-24) : « retirer `excludeSemantics`
de `ZMenuEntryTile` **ou** le filtrage amont de `ZActionMenu` rougit ici ».

**Le motif exact** : `minHeight: kZMenuMinTapTarget` est présent **deux fois** dans le code
dé-commenté — dans `z_menu_entry_tile.dart:80` **et** dans `z_default_menu_renderer.dart:56`
(le `ConstrainedBox` du déclencheur). Perdre le plancher de la **cellule** laisse le motif satisfait
par le **déclencheur**.

**Injection** (simultanée, pour distinguer les deux moitiés de la promesse) :
`minWidth/minHeight: kZMenuMinTapTarget → 0.0` **et** `excludeSemantics: true → false`, toutes deux
dans `z_menu_entry_tile.dart` (1 occurrence chacune).

**Mesure** : `flutter test test/z_menu_supersedes_test.dart` → **1 seul rouge** :
« Semantics non dupliquées ». « **cible ≥ 48 dp explicite** » est resté **vert**.

**Verdict : NE MORD PAS** (la moitié `excludeSemantics` de la promesse, elle, **mord**).
**Correctif** : ancrer le motif au fichier (`_Capacite` portant aussi le chemin attendu), comme le
fait `declarationsOf()` dans `z_chat_c5_guard_test.dart`.

---

### F5 — LOW · `chat4b_item_actions_menu_delegation_test.dart:373-385` — 48 dp du slot mesuré sur un `ConstrainedBox` sans contrainte

**Ce qu'elle prétend défendre** : dans une composition de slot (`Wrap` de `ZMenuEntryTile` en
`Axis.vertical`), la cellule tient bien les 48 dp.

**Le motif exact** : la mesure porte sur `find.ancestor(of: text, matching:
find.byType(ConstrainedBox)).first`, c'est-à-dire **notre** `ConstrainedBox` — mais elle en lit la
**taille rendue**, pas la contrainte. En composition verticale (icône 24 + `gapS` + libellé) la
hauteur naturelle dépasse déjà 48 dp, et la largeur est fixée par le `SizedBox(width: 120)` du test.

**Injection** : celle de F1/F4 (`minWidth/minHeight → 0.0` dans `z_menu_entry_tile.dart`).

**Mesure** : `cd packages/zcrud_study && flutter test test/chat4b_item_actions_menu_delegation_test.dart`
→ **1 rouge**, et c'est bien la garde **retendue** de la ligne 477 (« la CELLULE DU SOCLE porte
elle-même le plancher de 48 dp »). Le test de la ligne 332 est resté **vert**.

**Verdict : NE MORD PAS** — mais la garde retendue de la ligne 477 couvre la même propriété et **mord**
(mesuré). Impact réel faible ; à corriger par cohérence (lire `widget.constraints.minHeight`, comme le
fait `z_sf_assist_view_test.dart:311-312`).

---

## Gardes VÉRIFIÉES MORDANTES (injection appliquée, rouge mesuré)

| # | Garde | Injection | Résultat |
|---|---|---|---|
| 1 | `z_menu_a11y_rtl_test.dart:123` — cibles ≥ 48 dp (entrées) | plancher de `ZMenuEntryTile` → 0 | **ROUGE** (assertion, l.138) |
| 2 | `z_menu_a11y_rtl_test.dart:170` — libellé annoncé exactement 1× | `excludeSemantics: false` | **ROUGE** |
| 3 | `z_menu_supersedes_test.dart` — « Semantics non dupliquées » | idem | **ROUGE** |
| 4 | `z_menu_supersedes_test.dart` — « label a11y du déclencheur » | `z_menu_trigger.dart` vidé | **ROUGE** |
| 5 | **G-U1** `z_chat_action_contract_guard_test.dart:78` — un verbe = un seul site d'appel | `executor.regenerate(…)` ajouté dans `zcrud_chat/lib/.../z_chat_controller.dart` | **ROUGE**, en nommant le fichier |
| 6 | **G-R5** `z_chat_render_behavior_test.dart:439` — cible du bouton de dépli | plancher de `_ZToggleButton` → 0 | **ROUGE** |
| 7 | **G-R5** `z_chat_render_behavior_test.dart:464` — RTL du bouton de dépli | `AlignmentDirectional.centerStart` → `Alignment.centerLeft` | **ROUGE** |
| 8 | `z_sf_assist_view_test.dart:291` — tuile en cours ≥ 48 dp | plancher de `_ZStreamingTile` → 0 | **ROUGE** |
| 9 | `z_sf_assist_view_test.dart:348` — **RTL sous la coquille** (l'ancien faux vert C6) | `Alignment.centerLeft` dans `_ZStreamingTile` | **ROUGE** — la réparation (tuile montée + `findsWidgets`) est **réelle** |
| 10 | `z_chat_purity_test.dart` — grep directionnel | idem | **ROUGE** (jumeau de source présent, contrairement à F1) |
| 11 | `z_chat_shell_seam_test.dart:336` — tuile en cours ≥ 48 dp | plancher de `_ZStreamingTile` → 0 | **ROUGE** |
| 12 | **G-S4** `z_chat_shell_seam_test.dart:372` — SM-1 sous coquille | abonnement au flux **remonté au-dessus** du seam (`ValueListenableBuilder` autour de `_ZStreamingTile`) | **ROUGE** |
| 13 | `chat4b_…_delegation_test.dart:477` — plancher propre de la cellule | plancher de `ZMenuEntryTile` → 0 | **ROUGE** |

Tous les rouges ci-dessus sont des **échecs d'ASSERTION** (message de garde affiché), jamais des
échecs de compilation ni de chargement.

---

## Observations complémentaires (pas des findings de garde)

### O1 — `z_chat_sm1_test.dart` mesure le CONTRÔLEUR, pas la vue

Le fichier nommé « SM-1 » construit son **propre** arbre de `ValueListenableBuilder` (`_host`,
l.53-112). Il prouve la granularité des **tranches du contrôleur** — une propriété réelle — mais il
est **structurellement aveugle** à une régression de granularité dans `ZChatConversationView`.
**Mesuré** : sous l'injection n°12 (abonnement remonté au-dessus du seam), la suite complète de
`zcrud_chat` ne produit **qu'un seul rouge**, et il vient de `z_chat_shell_seam_test.dart` (G-S4), pas
de `z_chat_sm1_test.dart`. La couverture existe donc, mais elle passe par le chemin **avec coquille**
(`FakeShellRenderer`) ; le chemin **neutre** (`shell: null`) n'a pas d'équivalent. Recommandation :
dupliquer G-S4 sans coquille — c'est le chemin AD-57 par défaut, celui que tout hôte obtient sans rien
brancher.

### O2 — gardes de COMPTAGE restantes (à surveiller, non testées faute d'ambiguïté de motif)

* `z_chat_render_guard_test.dart:377-386` (G-R11) : « au moins 3 `Semantics(` dans les fichiers de
  rendu ». N'importe quels trois. La garde de comportement G-R3 couvre le fond ; celle-ci n'ajoute
  rien de discriminant.
* `z_chat_ai_ports_guard_test.dart:688-696` (G-C10) : `relais == variants.length` compte les
  occurrences de `super.sequenceId` **sur tout le fichier** — un variant qui en porterait deux
  compenserait un variant qui n'en porte aucun.
* `z_chat_action_contract_guard_test.dart:51` : `members.length >= 7` — vaut exactement le compte
  actuel (7), donc mord aujourd'hui ; l'inégalité laisse cependant passer un ajout non gardé si le
  parseur casse en même temps.

### O3 — points de qualité remarquables (à propager)

* `z_sf_ad57_isolation_guard_test.dart` : scanner écrit en **fonction pure** `chemin → source`, ce qui
  permet de le faire rougir sur des **témoins synthétiques** dans le même run, sans écrire un octet.
  C'est le meilleur patron du dépôt pour prouver qu'une garde de source sait rougir.
* `z_repo_sources.dart` : `strippedLines` gère les commentaires de **bloc** ET les littéraux, avec la
  justification mesurée (`packages/*/lib` dans une dartdoc avalait la fin du fichier).
* `chat4b_…_delegation_test.dart:519-553` : la sonde `Directionality.of(element(find.text(...)))`
  **dans la surface flottante** rend le piège « `Directionality` sous `MaterialApp` » impossible à
  réintroduire silencieusement.
* `z_menu_stale_entry_test.dart` : deux compteurs (`avant`/`apres`) pour distinguer « ça marche » de
  « ça marche avec l'ancien callback ». Exemplaire.

### O4 — hygiène du dépôt pendant la revue

Un fichier `packages/zcrud_chat/test/zz_tmp_a11y_probe_test.dart` (3,5 ko) est apparu **pendant** cette
revue (horodatage mesuré à 20 s de sa création), écrit par un relecteur travaillant en parallèle. Il
n'a **pas** été touché ici. Il gonfle le compte de la suite `zcrud_chat` (156 verts au lieu de 152) et
**doit être supprimé** avant tout `done`.

---

## Restauration — preuve

* `md5sum -c` du manifeste des 244 fichiers rejoué après **chacune** des 10 injections : **0
  divergence** à chaque fois.
* Grep négatif final sur les quatre `lib/` (`minHeight: 0.0`, `minWidth: 0.0`,
  `kZChatMinTapTarget * 0`, `_injectionSecondSite`, `_inner(context)`, `Alignment.centerLeft`) :
  **0 occurrence**.
* Suites rejouées après restauration : `zcrud_menu` **67/67**, `zcrud_chat_syncfusion` **52/52**,
  `zcrud_chat_kernel` **283/283**.
* Aucun `git checkout` n'a été exécuté.
