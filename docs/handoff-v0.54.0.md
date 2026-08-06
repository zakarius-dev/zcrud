# Handoff **v0.54.0** — le domaine « étude » remonte dans le socle, et un piège de migration se ferme

> **Tag à épingler : `v0.54.0`** · **strictement additif**, aucune rupture d'API.
> Trois destinataires cette fois, avec des sections distinctes : **IFFD** (§ 1-3),
> **DODLP** (§ 4-6), **hôte passif** (§ 7).
> 🔴 **Un seul changement de comportement par défaut**, et il corrige un défaut :
> § 4.1, l'ordre d'affichage des champs.

---

# Partie A — pour IFFD

## 1. L'écran de session de révision existe enfin

Les douze briques existaient depuis longtemps (carte retournable, boutons de qualité,
progression, pile, saisie notée, bilan, flamme) — **l'assemblage n'existait nulle part** hors
d'une démo. Grep négatif à l'appui : aucune classe `Z*Session*Page/Screen/Scaffold` dans aucun
paquet.

Livré, en **couple** (patron `ZPageScaffold`/`ZPageShellBody` déjà éprouvé) :
* **`ZStudySessionView`** — corps composable, **aucun `Scaffold`** : à poser en page, en
  feuille ou en dialogue, c'est votre choix ;
* **`ZStudySessionScaffold`** — enveloppe mince, slots en pass-through ;
* **`ZStudySessionHost`** — détient le runtime **via `zSessionRuntimeForMode`** (jamais une
  table parallèle) et reçoit le `ZSessionReviewer` **injecté** ;
* **`ZStudySessionReference` + `zStudySessionChromeOf`** — priorité **paramètre > jeton
  `ZcrudTheme.studySession*` > référence**, champ par champ. **Aucune exemption FR-26** : la
  référence tient sur les seuls rôles du `ColorScheme`.
* Sept builders (`headerBuilder`, `counterBuilder`, `cardBuilder`, `gradingBuilder`,
  `summaryBuilder`, `emptyBuilder`, `celebrationBuilder`) — slot `null` ⇒ **absent de l'arbre**.

🔵 **Le mode « cramming » est livré au passage** : le runtime le servait déjà, seul le point
d'entrée manquait. Il est maintenant dans le sélecteur de modes — file = corpus entier, ordre
d'entrée, **sans lecture SRS**.
⚠️ Pas de `shuffle()` malgré votre référence : un `Random` dans un `build()` viole AD-14. À
votre main si vous le voulez.

### Un défaut trouvé par une contre-preuve
Le `gradingBuilder` prenait deux arguments : un hôte remplaçant la surface de notation n'avait
**aucun moyen d'atteindre le runtime** — la session aurait noté dans le vide. Ce n'est pas une
relecture qui l'a vu, c'est la garde écrite pour prouver qu'une **autre** garde n'était pas
vacante (le compteur SRS restait à zéro).

## 2. Le hub d'ajout est branché

Il était complet depuis v0.51.0 et **composé nulle part**. Livré : `ZContentHubLauncher`
(value-type, 18 champs en pass-through — **pas** de second site de résolution),
`ZContentHubScope` (le `+` de l'app-bar et celui d'une section ouvrent **le même** hub), et le
câblage sur `ZStudyFolderDetail` + la voie d'ajout des sections.
🔴 **`null` ⇒ arbre strictement identique à aujourd'hui**, prouvé par signature d'arbre.
Seul vocabulaire ajouté : **6 clés de couleur stables** (`'flashcards'`, `'note'`…), **zéro
libellé** — ce qui garde la teinte stable quand vous **insérez un type au milieu** ou changez de
langue.

## 3. Les tâches du jour ont enfin une surface

Le kernel les portait entièrement ; **aucune UI** ne les rendait. Livré `ZDailyTasksView`
(bandeau 7 jours, liste, état vide **injecté**), avec deux propriétés que le kernel exige :
**dispatch à `default` obligatoire** (une variante inconnue est **absente**, jamais un throw —
prouvé avec deux variantes inventées) et **horloge injectée** (aucun `DateTime.now()`).
⚠️ Vos 4 « actions rapides » **ne sont pas portées** : 3 sur 4 sont inertes chez vous
(`enabled: false`).

---

# Partie B — pour DODLP (réponse à votre CR d'exploration)

Merci pour ce document : c'est le premier retour de **terrain de migration** que nous recevons,
et il a fait remonter en tête du chantier un défaut qu'aucune CR IFFD n'avait vu.

## 4.1 🔴 F1 — vous aviez raison, et c'était pire que « une aspérité »

Confirmé à la source (`z_form_controller.dart:51`) : sans `visibleFields` explicite, l'ensemble
**et l'ordre** des champs venaient de l'ordre de la **Map de persistance**, pas du schéma.

**La mesure a expliqué le silence du défaut** : il ne se déclenche **qu'en l'absence de toute
condition**. Ajoutez une condition, il disparaît ; retirez-la, il revient. D'où l'impression
d'un comportement erratique.

**Corrigé — par défaut, pas en opt-in.** Un opt-in aurait laissé le piège armé pour exactement
ceux qui l'ignorent. La correction a dû vivre **dans les deux** (`ZFormController` +
`DynamicEdition`) : mesuré, après le constructeur les états d'un hôte explicite et d'un hôte
implicite sont **littéralement indiscernables** — corriger dans la vue seule aurait écrasé
l'ensemble voulu d'un hôte explicite.

> **Ce qui change à l'écran** si vous ne passiez rien : l'ordre suit le **schéma** ; les champs
> du schéma absents de `initialValues` **apparaissent** ; un contrôleur vide ne rend plus un
> formulaire blanc.
> **Si vous passiez `visibleFields`** : rien ne bouge (gardé).
> 🔴 **Si vous réordonniez votre Map** pour compenser : **retirez cette compensation**, elle est
> devenue inerte.

## 4.2 G1 — le stepper, et ce que la mesure a révélé chez vous

Livré : `zPartitionFieldsIntoSteps` (**pure et totale**, 21 tests sans `BuildContext`),
`ZStepFieldConfig` sur le canal `ZFieldConfig` existant, et — sur décision de notre propriétaire
de **ne pas nous limiter à votre implémentation actuelle** — trois capacités au-dessus :
**étapes conditionnelles** (`ZCondition` réutilisé), **étapes optionnelles** (relâchement
**local**, ce que `validateOnNext: false` ne sait pas faire), et **reprise** (patron du seam de
persistance neutre existant). `ZStepperEdition` est **étendu, jamais dupliqué** — ses 502 tests
passent inchangés.

🔵 **Ce que nous avons mesuré chez vous, et qui vous sera utile** : `StepperConfig` déclare
**19 membres, 4 honorés**. Surtout, **`indicatorPosition` est écrit par 39 sites d'appel et
jamais lu** — 21 de vos formulaires demandent un indicateur latéral que votre moteur ignore.
`style` : 4 écritures, 0 lecture. `stepIcon` : déclaré, jamais lu.
Et une correction : **votre récursivité ne passe pas par la liste plate** — le seul cas réel
construit un stepper dans un champ `type: widget`. Une liste plate ne peut structurellement pas
exprimer l'imbrication.

⚠️ **Arbitrage laissé ouvert** : `ZFieldSpec.config` est un slot **exclusif** (19 sites) —
annoter un champ qui porte déjà un `ZTextConfig` le lui retirerait. Contourné par un seam ; la
levée propre serait un slot `step:` additif, décision de schéma canonique non prise seule.

## 4.3 🔵 G3 est INFIRMÉ — la capacité existait déjà

Vous demandez `inputFormatters`/`textCapitalization` et déclarez avoir contourné en normalisant
**à la soumission**. Or **`ZTextConfig.capitalization` et `ZTextConfig.textTransform` existent**,
et la présentation les applique via un `TextInputFormatter` interne — donc **pendant la frappe**,
exactement ce que vous vouliez. Votre contournement était inutile.
Le dartdoc explique même pourquoi ce n'est délibérément **pas** `inputFormatters` :
`TextInputFormatter` est un type **Flutter**, et cette configuration est du **domaine pur**
(AD-15) — comme `keyboardType`, qui est une `String` opaque pour la même raison.

## 5. Les listes — la zone que votre CR déclarait non tranchée

Mesuré : **5 des 7 familles sont déjà couvertes intégralement.**

| Capacité | Verdict |
|---|---|
| recherche sans accents multi-champ | **déjà couverte** (`zFoldDiacritics` → `zApplyListRequest`) |
| sélection multiple, sous-listes, **ACL 11 flags** | **déjà couverte** — `ZCrudAction` porte **exactement** vos 11 flags |
| pagination curseur | **déjà couverte** (`limit`/`startAfter`, mode `backendCursor`) |
| soft-delete / restauration | **déjà couverte** sauf la *vue* corbeille (un filtre + un toggle) |
| projection → export | **déjà couvert** (`ZExportTable.fromRequest`) |

🔴 **Deux choses à savoir sur votre propre code** :
* **Votre historique CRUD est mort.** `DynamicHystoryScreen` n'est appelé que depuis
  `StreamedDynamicListScreen` — qui a **0 site d'usage hors de son propre fichier** (recompté :
  6 occurrences, toutes internes, **1 965 lignes**) ; l'appel vivant est **commenté** ; et
  **aucun Dart n'écrit `crud_operations`**.
* **L'« en-tête PDF propriétaire » est un mythe** : `dodlp_pdf_header` a **0 occurrence** dans
  vos deux écrans de liste. L'en-tête réel est un titre texte — déjà couvert par
  `ZPdfExportOptions.title`.

Reste **~320 lignes** au total : store d'onglets persistés, vue corbeille, bouton d'export,
seam de couleur de cellule, paramètres de grille. Planifié.

## 6. Vos frictions F2/F3/F4

* **F3** — vous avez raison, et nous l'avions mesuré indépendamment : `zcrud_get` impose
  `reflectable` → `auto_route ^11` pour livrer un présentateur de ~110 lignes. **Extraction d'un
  satellite mince planifiée** ; elle lèvera le blocage sans toucher à votre routage.
* **F2** (doc de consommation git) et **F4** (table de découverte type → statut) : planifiés.
  Votre § 7 est repris tel quel comme base — il comble exactement le manque qui vous a fait
  écrire un `ZDateRangeField` custom alors que `dateRange` existait.
* 🟢 **Votre § 5 nous évite une erreur** : vous examinez le satellite `zcrud_formfields_*` et
  **le refusez vous-mêmes**, avec le bon argument — pour `color`, `signature`, `select`, un
  builder de registre serait **du code mort jamais appelé**, ces kinds étant pré-routés vers des
  familles natives. Nous retenons votre recommandation (lifter le composeur hors du binding).

---

# Partie C — hôte passif (dont lex_douane)

**Un seul changement de comportement** vous concerne : § 4.1, l'ordre d'affichage des champs —
et **seulement** si vous montez un `DynamicEdition` **sans** passer `visibleFields`. Dans ce cas
l'ordre suit désormais votre **schéma** au lieu de l'ordre de votre Map. C'est une correction.

Tout le reste est **opt-in** : l'écran de session, le hub, les tâches du jour, le stepper
annoté, les ports neutres — rien n'apparaît sans geste explicite, et les arbres rendus par
défaut sont prouvés identiques.

---

## 8. Vérification

`melos generate` **RC=0** (0 `.g.dart` modifié) · `melos analyze` **RC=0** · `melos verify`
**RC=0** (ACYCLIQUE + `CORE OUT = 0` + corpus de sérialisation, 36 paquets).

`zcrud_study` **1521** · `zcrud_core` **1311** · `zcrud_session` **569** ·
`zcrud_study_kernel` **398** · `zcrud_document` **235** · voisins inchangés
(`zcrud_flashcard` 586, `zcrud_note` 173) · **0 erreur, 0 avertissement** partout.

**R3 — 68 injections mordantes documentées** (12 + 5 + 7 + 11 + 19 + 14), toutes
**ROUGE-ASSERTION**, restaurations par copie, intégrité `sha256` vérifiée **après chaque**
injection, aucun résidu.

🟢 **Six gardes vacantes démasquées pendant ces lots — dont cinq par les agents sur leur propre
travail** : une garde mesurant un `Center` qui occupe toute la surface (verte quoi qu'il
arrive) · une qui n'assérait qu'une **clé**, juste même quand le contenu résolu était faux ·
une dont les données de test étaient **accidentellement déjà triées**, rendant l'injection
« trier » inobservable · une propriété **inatteignable** sur un hôte en UTC, déplacée sur une
garde de source qui, elle, mord · une injection rendant un rouge de **compilation** qui
**masquait** l'assertion, refaite en multi-fichiers.

🟢 **Deux tripwires ont fait leur travail et ont été CONVERTIS, pas supprimés** : celui qui
assertait l'absence des jetons `studySession*` garde désormais que le maillon est **branché** ;
celui du mode `cramming` garde désormais sa correspondance. Un tripwire qu'on retire laisse la
propriété sans surveillance.

⚠️ Notre CI reste à l'arrêt (facturation) : **ces chiffres sont des vérifications locales**.

## 9. Ce que nous savons ne pas avoir couvert

* **`ZSmartNote implements ZStudyNoteRef` non livré** : `zcrud_note` **ne dépend pas** de
  `zcrud_study_kernel`, et c'est une décision documentée (D7) tenue par une garde machine.
  ⇒ pour les **notes**, l'adaptation vers le port se fait **côté hôte** (quelques lignes) ; pour
  les **documents**, `ZStudyDocument` implémente nativement.
* **Défaut préexistant de FR-26 dans le cœur** : `'Étape k sur N'` est codé en dur **en
  français** dans `z_stepper_edition.dart`. C'est ce qui bloque l'annonce a11y de progression du
  stepper — la greffer dupliquerait le littéral. Lot dédié à venir.
* **États d'étape avec erreur**, indicateur adaptatif, récapitulatif final, focus clavier du
  stepper : mesurés comme un lot en soi, non livrés (le focus clavier n'a **pas** été deviné —
  son comportement actuel n'a pas été mesuré).
* `z_study_tools_page.dart` non câblé au hub (seuls `ZStudyFolderDetail` et la voie de section
  le sont) · aucun golden neuf · aucune enveloppe de page pour `ZDailyTasksView`.
* Dettes antérieures ouvertes : champ de recherche sous dégradé (v0.49.0), deux gardes inertes
  de `ZMindmapView` (v0.49.0), estampillage par carte en multi-sources (v0.51.0),
  `ZChatRequestBuilder` non élargi (v0.52.0).
