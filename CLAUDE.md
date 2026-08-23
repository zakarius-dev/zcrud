# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**zcrud** est un **monorepo Flutter (melos) de packages CRUD riches réutilisables**, extrait et consolidé à partir d'un moteur déclaratif dupliqué à l'identique dans trois applications — **DODLP**, **IFFD**, **DLCFTI**. Un même schéma de champs (`ZFieldSpec`) génère à la fois les **formulaires d'édition** (`DynamicEdition`) et les **tableaux de liste** (`DynamicList`). Le package fournit aussi l'édition/lecture **Markdown** riche (Quill + embeds LaTeX/tables), les **flashcards** (SRS), les **cartes mentales** (mindmaps), et des champs spécialisés (géo, téléphone, pays).

**Objectif produit n°1** : corriger par conception le bug historique de **rafraîchissement global du formulaire** à chaque frappe (jank, perte de focus) → **rebuilds réactifs granulaires**.

**Objectif produit n°2 (owner, 2026-08-12)** : **minimiser le code consommateur, maximiser les
fonctionnalités livrées** — la déclarativité doit aller jusqu'au bout. Tout ce qui est dérivable
d'une déclaration existante (`@ZcrudModel` → `ZFieldSpec[]` → formulaire **et** liste **et**
cellules via le registre) ne doit **jamais** être re-demandé au consommateur ; les assemblages
(écran CRUD complet) sont fournis par zcrud comme **couches minces au-dessus des briques
publiques** (satellites, AD-1 respecté), avec échappatoire : descendre d'un cran vers les briques
sans rien perdre. Toute CR révélant du code dupliqué chez un hôte est un signal d'assemblage
manquant.

**Consommateurs cibles** : **DODLP** (prioritaire, GetX) puis **lex_douane** (Riverpod). Le schéma canonique est porté des modèles les plus avancés de lex_douane (module « Étude »).

**Communication et documentation en français.**

---

## Continuation autonome (consigne utilisateur)

Si à la fin d'une étape je propose au user de continuer (ex. « Continue vers l'architecture ? » / « J'enchaîne `/dev-story` ? ») et que le user **ne répond pas dans la minute**, je **continue automatiquement** avec l'étape proposée — sans nouvelle question. Cela s'applique au cycle BMAD de planification (brief → PRD → architecture → epics → readiness) **et** au cycle BMAD strict d'implémentation (`create-story` → `dev-story` → `code-review` → next story).

## Résumé après chaque étape du cycle BMAD (NON-NÉGOCIABLE)

**Après CHAQUE étape** (planification ou implémentation), fournir au user un **résumé concis** — sans attendre qu'il le redemande :
- ✅ L'étape et le **skill réel** invoqué.
- ✅ Ce qui a été produit (fichiers créés/modifiés, ACs, tâches).
- ✅ Les **résultats de vérification rejoués réellement sur disque** (`melos run generate`, `dart/flutter analyze`, `flutter test` RC + nb de tests) — jamais sur la seule foi du rapport d'un agent.
- ✅ Les **findings** de code-review (HIGH/MAJEUR/MEDIUM/LOW + statut corrigé/justifié).
- ✅ La **transition de statut** appliquée (édition ciblée du sprint-status).

## Traitement d'un CR ≠ cycle BMAD (consigne owner, 2026-08-12)

Un **CR d'application hôte** (`iffd`/`lex_douane`/`dodlp-otr`/`dlcfti-otr`, ou `zcrud/docs/cr-*`) se
traite par **sous-agents lancés directement** (tool `Agent`), **sans** passer par le cycle BMAD
d'implémentation (`create-story` → `dev-story` → `code-review` → sprint-status). Pas de fichier de
story, pas de transition de statut, pas de Workflow multi-agent à lentilles : le CR **est** la
spécification, et il porte déjà ses constats mesurés côté hôte.

🔴 **Exécution déléguée à CODEX (consigne owner, 2026-08-17)** : les lots exécutés en arrière-plan
partent désormais aux **sous-agents codex** (`subagent_type: 'codex:codex-rescue'`), et non plus au
`general-purpose`. L'orchestrateur, lui, ne change pas de rôle : c'est toujours **lui** qui vérifie
les constats du CR sur disque avant de déléguer, qui rejoue la vérif verte **au repos**, qui édite
le sprint-status, qui rédige le handoff et qui publie. Un rapport d'agent codex n'est pas plus une
preuve que celui d'un autre agent.
Les garde-fous de concurrence sont **inchangés** et s'appliquent identiquement : un seul rédacteur
par paquet, scratchpads distincts, aucune mesure d'un paquet pendant qu'un agent y écrit
(`.dart_tool/package_config` est partagé), health-check des agents en vol.

⚠️ **Le sous-agent codex ne fait PAS le travail : il DISPATCHE.** Mesuré le 2026-08-17 : l'agent
lance une tâche Codex de fond, rend la main en ~50 s, et le travail réel vit sous un
**identifiant de tâche séparé** (`task-…`). Conséquence : **aucune notification de complétion
n'arrive** par le canal habituel pour le travail réel.

🔴 **Et `/codex:status` n'est PAS invocable par l'orchestrateur** (mesuré : `disable-model-invocation`
— la commande est réservée à une invocation explicite du owner). La surveillance d'un lot codex
repose donc **entièrement sur l'activité disque** : `git status <paquet>` et horodatages de
`lib/`+`test/` (`find … -newermt`). C'est de toute façon la meilleure preuve — un rapport n'en est
pas une, un fichier modifié si. Seuil d'inactivité ~5 min avant de considérer un lot planté ; en
cas de doute, demander au owner de lancer `/codex:status <task-id>`. Toujours **retenir
l'identifiant `task-…`** rendu au lancement : sans lui, ni statut ni annulation ne sont possibles.

**Veille et publication (consigne owner, 2026-08-14, cadence révisée le 2026-08-22)** : cycle
permanent — **toutes les 1 h 30**, vérifier si l'un des quatre dépôts hôtes a **émis ou modifié** un CR (un CR *modifié* compte
autant qu'un CR neuf : le pilote réécrit ses CR, cf. le retour de pilote passé de 7 à 8 écarts
en cours de traitement) ; traiter les CR trouvés ; **publier de façon GROUPÉE quand plusieurs CR
sont traités dans la même vague**, sinon publier le CR seul ; puis attendre les suivants.
Release = vérif verte au repos, bump des paquets **et** de `tool/*`, CHANGELOGs datés,
`docs/handoff-vX.Y.Z.md`, tag, push. La publication du **site** reste un geste distinct, demandé
explicitement par le owner.

⚠️ **DEUX conventions de dépôt de CR, à balayer toutes les deux** : `dodlp-otr` écrit **un fichier
par CR** (`docs/cr-zcrud/cr-*.md`) ; `iffd` **et** `lex_douane` tiennent un **registre unique**
(`docs/zcrud-change-requests.md`, plusieurs centaines de Ko). Un balayage qui ne cherche que
`cr-*.md` est **aveugle aux registres** — mesuré le 2026-08-18 : trois CR IFFD ouvertes depuis dix
jours n'avaient jamais été signalées. Pour un registre, isoler le neuf par l'historique git
(`git log -- <registre>` puis `git show <commit> -- <registre>`), jamais en relisant 350 Ko.

⚠️ **Règle de stabilité** : un fichier de CR écrit il y a moins de **2 minutes** peut encore être
en cours de rédaction — remesurer (mtime + taille inchangés) avant de le lire et de le traiter.

Ce qui **reste** obligatoire, sans exception :
- ✅ **Vérifier chaque constat du CR sur disque** avant de déléguer — un CR est un signalement, pas
  une preuve (les causes supposées par le pilote se sont déjà révélées justes *et* incomplètes).
- ✅ **Discipline R3** sur toute garde ajoutée (rouge par assertion, restauration par copie, sha
  avant/après, résidus par grep négatif montré).
- ✅ **Vérif verte rejouée par l'orchestrateur** (`generate` → `analyze` → `flutter test` depuis le
  dossier de chaque paquet) avant tout commit/tag.
- ✅ **Handoff** distinguant hôte **passif** et hôte ayant **compensé** le défaut corrigé.
- ✅ Scratchpads **distincts** par sous-agent, paquets **disjoints**, health-check des agents en vol.

Le cycle BMAD complet reste la règle pour les **stories du sprint-status**, jamais pour un CR.

## Délégation des étapes BMAD via Workflow + effort par étape (NON-NÉGOCIABLE)

Chaque étape BMAD est exécutée via le tool **`Workflow`** — pour régler le niveau d'**effort par étape** (impossible via le tool `Agent`). **`create-story` / `dev-story` / `retrospective`** utilisent un **script à agent unique** (un seul `agent()` invoquant le vrai skill `bmad-*`). **`code-review` est l'exception : il est MULTI-AGENT** (cf. section dédiée ci-dessous).

- ✅ **L'orchestrateur (boucle principale) reste le pilote** : entre chaque étape il **vérifie l'état réel sur disque** (`git status`, statut de la story, tests réels), **rejoue lui-même la vérif verte** via bash, édite le sprint-status de façon **ciblée et sérialisée** (jamais deux écritures parallèles), produit le **résumé d'étape**, arme le `ScheduleWakeup`. Le Workflow n'absorbe aucune de ces responsabilités.
- ✅ **Effort par étape** :

  | Étape | Effort |
  |-------|--------|
  | `create-story` | **medium** par défaut, **`high` si la story est jugée complexe** (choix orchestrateur : multi-couches/packages, nouvelle entité/modèle, règles métier non triviales, ACs nombreux, story L/XL) |
  | `dev-story` | **high** |
  | `code-review` | **high** |
  | `retrospective` | **medium** |

- ✅ **Modèle** : hérité de l'orchestrateur → paramètre `model` **OMIS** sur les `agent()` BMAD (planification **et** développement). Les tâches **hors BMAD** (exploration read-only, remédiations massives) → `model:'sonnet'`.
- ✅ **Un seul stage `agent()` par étape** (sauf `code-review`, multi-agent). Jusqu'à **3 étapes en vol simultanément**, mais UNIQUEMENT si elles relèvent de **stories/epics parallélisables à fichiers disjoints** (cf. règle parallélisation ci-dessous) ; jamais deux écritures concurrentes du sprint-status (sérialisées par l'orchestrateur).
- ✅ Si le tool `Skill` n'est pas invocable dans l'agent de Workflow, bascule explicite sur le **fallback disque** (`.claude/skills/bmad-*/SKILL.md` + fichiers annexes), signalée dans le rapport. **Ne jamais simuler une étape de mémoire.**

## Code-review = Workflow MULTI-AGENT à lentilles (NON-NÉGOCIABLE)

**Opt-in permanent du owner** : le `code-review` de chaque story s'exécute comme un **Workflow multi-agent** dont les lentilles couvrent **toutes les facettes** de la story, en parallèle. C'est ce qui rend tenables des **stories volumineuses (découpées par livrable)** : la couverture vient du **nombre de lentilles**, pas de la finesse du découpage.

- ✅ **L'orchestrateur est AUTONOME** sur le dimensionnement : il **choisit seul** le nombre et la nature des agents de revue (une seule lentille sur une story triviale, un large éventail adversarial sur une story lourde), **sans demander l'autorisation**. Il calibre sur la story réelle : surface touchée, packages, criticité des invariants en jeu, densité d'ACs.
- ✅ **Lentilles de référence** (à composer, jamais un catalogue figé) :

  | Lentille | Ce qu'elle traque |
  |---|---|
  | Conformité AD | violations des invariants hérités et du spine de l'epic |
  | Tests porteurs | tests tautologiques (qui ne rougissent pas quand la logique casse) — discipline R3 |
  | A11y / RTL | `Semantics`, ≥ 48 dp, variantes directionnelles, Reduce Motion |
  | L10n / thème | libellé ou couleur codés en dur |
  | SM-1 / perf | rebuilds non granulaires, controllers recréés, listes non virtualisées |
  | Isolation deps | dépendance qui fuit hors de son satellite ; CORE OUT ≠ 0 |
  | Robustesse | chemin d'exception là où un repli est exigé (AD-10) |
  | Adversariale | deux lectures conformes mais **incompatibles** d'une même règle |
  | Réalité du code | affirmation jamais vérifiée sur disque — **toute « absence » doit être prouvée par un grep négatif** |

- ✅ **Chaque agent écrit son rapport complet dans un fichier** et ne retourne qu'un **résumé compact** (verdict + 2-5 findings + chemin) — le contexte de l'orchestrateur ne porte jamais le texte intégral des revues.
- ✅ **L'orchestrateur vérifie lui-même sur disque** tout finding structurant avant de l'appliquer — un rapport d'agent n'est **jamais** une preuve (cf. surveillance des sous-agents).
- ✅ Le triage des findings reste inchangé (HIGH/MAJEUR obligatoires, MEDIUM par défaut, LOW consignés) et la **vérif verte est rejouée par l'orchestrateur** avant tout `done`.

## 🔴 Un message envoyé à un agent TERMINÉ le RÉVEILLE (incident du 2026-08-01)

`SendMessage` vers un agent **déjà complété** ne dépose pas une note : il **reprend l'agent depuis son
transcript** et le remet à écrire. Constaté : une correction envoyée à l'agent CHAT-1 après son rapport
final l'a relancé sur `zcrud_chat_kernel` — pendant que CHAT-1b, lancé pour le même travail, y écrivait
aussi. **Deux rédacteurs sur les mêmes fichiers, du seul fait de l'orchestrateur.** Le second agent l'a
détecté (horodatages de fichiers changeant sous lui), a **restauré son unique écriture par copie** et
s'est arrêté — comportement exemplaire. Coût réel : le paquet laissé **rouge** (13 erreurs, toutes dues
à un paramètre rendu obligatoire) et un lot à reprendre.

**Règles** :
1. Une correction qui arrive **après** la fin d'un lot n'est pas un message : c'est un **nouveau lot**.
   La transmettre par `Agent`, jamais par `SendMessage` à l'agent terminé.
2. `SendMessage` ne s'utilise que vers un agent **encore en vol**, et seulement si son travail n'est pas
   déjà couvert par un autre agent lancé entre-temps.
3. Avant de lancer un rédacteur sur un paquet : **vérifier qu'aucun fichier n'y a bougé récemment**
   (`find lib test -newermt '-90 seconds'`) et que les transcripts des agents concernés sont figés.
4. Ne jamais écrire « aucun autre agent n'édite » dans un prompt sans l'avoir **mesuré** — le sous-agent
   s'y fie pour décider s'il peut faire confiance à ses propres mesures.
5. 🔴 **Un `TaskStop` ne prend pas forcément effet tout de suite** : un agent arrêté a continué d'écrire
   ~10 min. Un retour « stopped » n'est **pas** une preuve d'arrêt — le vérifier par les horodatages
   avant de lancer un remplaçant.
6. 🔴 **Deux agents parallèles doivent avoir des SCRATCHPADS DISTINCTS.** Constaté le 2026-08-01 : les
   lots C3 et C4, lancés en parallèle sur des packages pourtant disjoints, partageaient le même
   répertoire de travail temporaire. Le `rmtree`/`copytree` de l'un a **détruit la sauvegarde de
   l'autre en pleine campagne R3**, laissant **8 injections en place**. Le package était donc cassé
   par construction, et l'agent a dû restaurer à la main puis tout rejouer depuis une sauvegarde
   privée. **La disjonction des packages ne suffit pas : il faut aussi disjoindre les scratchpads**
   (un sous-dossier par agent, nommé dans le prompt).
7. 🔴 **`.dart_tool/package_config` est PARTAGÉ par le workspace** : chaque `flutter test` le réécrit.
   Deux workstreams parallèles produisent donc des échecs de **CHARGEMENT** qui n'appartiennent à
   personne. Un rouge concomitant d'un autre run se qualifie **avant** d'être imputé au code.
8. 🔴 **Toute affirmation d'ABSENCE porte son grep négatif MONTRÉ.** « Je n'ai pas trouvé » n'est pas
   un constat. Vaut pour les rapports d'agent comme pour les miens.
9. 🔴 **Après TOUT arrêt d'agent, vérifier qu'aucune INJECTION R3 ne subsiste** (grep du marqueur **et**
   rejeu des tests). Un agent interrompu en pleine campagne R3 laisse le code **cassé par construction** :
   constaté sur `zcrud_chat`, paquet trouvé rouge avec un jeton d'instance injecté et **deux** sites
   d'usage — dont un qu'un grep naïf masquait. Le retrait doit être **ciblé** (motif asserté), jamais
   `git checkout`.

## 🔴 Une garde hérite de l'angle mort de son auteur (rétrospective epic CHAT, 2026-08-01)

**R3 corrige la RIGUEUR d'une garde, jamais le CHOIX DE LA PROPRIÉTÉ qu'elle mesure.** Une garde
peut être verte, mordante, correctement écrite — et regarder à côté. Trois des huit familles de
défauts recensées sont **structurellement invisibles** à une R3 menée par l'auteur lui-même :
elle mesure le plancher du SDK au lieu du nôtre, elle vise un sujet non monté, ou **elle défend le
défaut** (deux gardes assertaient « sans registre, c'est la CLÉ qui s'affiche »).

Mesuré : **1 378 tests verts** au moment où la revue multi-lentilles établissait **3 HIGH / 9 MAJEUR**.

⇒ **Seul un changement de LENTILLE y accède** — c'est ce qui justifie la revue multi-agent, et ce
qui rend une revue à agent unique insuffisante sur une epic large. Les huit familles et leur règle
actionnable : `_bmad-output/implementation-artifacts/stories/epic-chat-retrospective.md`.

🟢 **Comportements à reproduire**, observés pendant cette epic : refuser de **fabriquer** une donnée
que la source n'a pas ; **rejeter sa propre solution** après l'avoir mesurée inerte plutôt que de
re-promettre le défaut ; **refuser d'écrire une garde** là où le scénario n'est pas atteignable ;
**arrêter un script R3** dès qu'un motif d'injection est ambigu.

## Surveillance des sous-agents en arrière-plan (NON-NÉGOCIABLE)

Les sous-agents/Workflows lancés en arrière-plan peuvent **planter ou se figer silencieusement** sans notifier.
- ✅ **Health-check périodique** tant qu'un agent est censé tourner : mesurer l'inactivité de son transcript ; **seuil ~5 min (300 s)** sans résultat → considéré planté, ne pas attendre davantage.
- ✅ En cas de plantage : **vérifier l'état réel sur disque** (statut story, `git status/log`, tests réels) **sans faire confiance** au `review`/`done` laissé par l'agent mort, puis relancer un agent de reprise.
- 🚫 Ne **jamais** enchaîner sur la foi du seul rapport d'un agent : confirmer d'abord l'état git/tests réel.
- 🚫 Ne **jamais** faire écrire le même `sprint-status.yaml` par deux agents en parallèle — écritures **sérialisées et ciblées** par l'orchestrateur (jamais de réécriture globale du YAML).

## Réveil de sécurité (heartbeat)

Armer un `ScheduleWakeup` de sécurité (délai **1 h / 3600 s**) pour garantir que le cycle BMAD ne meurt jamais silencieusement. Simple filet : la reprise principale reste pilotée par la complétion réelle des étapes.

## Findings MEDIUM du code-review

- ✅ **HIGH/MAJEUR/critiques** : correction **obligatoire** avant `done`.
- ✅ **MEDIUM** : correction **par défaut** si possible dans le périmètre de la story sans régression ; un MEDIUM reporté doit être **justifié par écrit** dans `code-review-<story>.md`.
- 🟡 **LOW/nits** : optionnels (corrigés si triviaux, sinon consignés).
- ✅ Story reste **verte** après correction des MEDIUM, avant `done`.

## Skills BMAD (noms canoniques)

Invoquer via le tool `Skill` (préfixe `bmad-*`). Fallback disque : `.claude/skills/<nom>/SKILL.md`.

| Étape | Skill | Rôle |
|-------|-------|------|
| Product brief | `bmad-product-brief` | Brief produit |
| PRD | `bmad-prd` (`bmad-create-prd`) | Exigences |
| Architecture | `bmad-architecture` (`bmad-create-architecture`) | Spine d'architecture |
| Epics & Stories | `bmad-create-epics-and-stories` | Backlog |
| Readiness | `bmad-check-implementation-readiness` | Contrôle de complétude |
| Sprint planning | `bmad-sprint-planning` | Génère le sprint-status |
| Sprint status | `bmad-sprint-status` | Suivi |
| create-story | `bmad-create-story` | Story enrichie (specs + ACs + tests) |
| dev-story | `bmad-dev-story` | Implémentation |
| code-review | `bmad-code-review` | Revue adversariale |
| retrospective | `bmad-retrospective` | Rétro d'epic |

En cas de doute sur un nom exact, **lister `.claude/skills/bmad-*` avant d'invoquer.**

---

## Build & Development Commands (monorepo melos)

> **Code généré : SUIVI par git sous `packages/*/lib/`** (depuis ES-1). Le `.gitignore` ignore
> les `*.g.dart` / `*.freezed.dart` **partout SAUF** `packages/*/lib/**` (négation explicite).
> Raison : les packages sont consommés en **dépendance git** — un consommateur clone l'arbre au
> tag et **ne régénère PAS** le code d'une dépendance ; un `part` manquant casserait son build.
> Le gate `codegen-distribution` (`melos run verify`) échoue si un `part` d'un `packages/*/lib/`
> vise un fichier gitignoré.
>
> Conséquences : après avoir modifié une annotation `@ZcrudModel`/`@JsonSerializable` **ou le
> générateur**, régénérer (`melos run generate`) **et committer les `*.g.dart` régénérés** — les
> omettre laisserait dans git un code généré périmé (ex. un registrar câblé sur l'ancienne
> factory). Le codegen reste exécuté par la CI avant analyze/test/build.

```bash
# Bootstrap du workspace (resolution: workspace)
dart pub get            # ou: melos bootstrap

# Régénérer le code de TOUS les packages
dart run melos run generate     # (build_runner sur chaque package annoté)
# Ou par package :
dart run build_runner build --delete-conflicting-outputs
dart run build_runner watch     # mode watch

# Analyse
dart run melos run analyze      # ou: dart analyze / flutter analyze

# Tests (tout le workspace)
dart run melos run test         # ou: flutter test  (par package)

# Gate de compatibilité (dry-run vs workspace lex_douane, cf. FR-25/E1-4)
dart pub get --dry-run
```

**Vérif verte (à rejouer réellement avant tout `done`)** : `melos run generate` OK → `analyze` RC=0 → `flutter test` RC=0.

🔴 **`flutter test` DOIT être lancé DEPUIS LE DOSSIER DU PACKAGE** (`cd packages/<pkg> && flutter test`),
jamais depuis la racine (`flutter test packages/<pkg>`). Mesuré le 2026-08-01 : depuis la racine,
`zcrud_study` rend **48 rouges**, `zcrud_session` **27**, `zcrud_flashcard` **11** — et **0 depuis le
dossier du package**. Cause : des dizaines de gardes lisent des sources par **chemin relatif**
(`Directory('lib')`, `File('pubspec.yaml')`), résolu contre le répertoire courant. C'est la convention
de `melos exec`. Un rouge obtenu depuis la racine **n'est pas un rouge du code** — et un vert obtenu au
mauvais endroit ne prouve rien non plus. Ancrage correct pour toute nouvelle garde : `_repoRoot()`
(remontée jusqu'au dossier portant `melos.yaml`), pas un `../` relatif.

🔴 **La CI est MORTE — elle ne vérifie plus RIEN.** Constaté le 2026-08-01 : **75 runs sur 75 en échec**,
durées de 3 à 10 s, annotation GitHub *« The job was not started because your account is locked due to a
billing issue »*. Le job `codegen → analyze → test → gates` **n'a jamais démarré**. Conséquence : tous
les gates CI sont **décoratifs** depuis ~75 pushes, et le rouge permanent de la CI est devenu du bruit
sans signal. **La vérif verte locale rejouée par l'orchestrateur est donc la SEULE ligne de défense** —
elle n'est plus un doublon de la CI. Un test rouge a ainsi été **taggé et livré en v0.29.0**
(`zcrud_firestore`, garde CR-LEX-26 laissée sur `ZDomainFailure` après que CR-LEX-44 eut délibérément
substitué `ZUnsupportedOperationFailure`). ⚠️ Action **owner** requise : débloquer la facturation.

⚠️ **Une CR qui change un contrat doit chercher ses gardes JUMELLES dans les autres packages**
(`grep -rn "<TypeChangé>" packages/*/test`). CR-LEX-44 a mis à jour ses tests locaux et laissé la garde
équivalente de `zcrud_firestore` sur l'ancien type — pendant symétrique du tripwire côté aval.

⚠️ **`melos run test` HANGE** — ne pas compter dessus : lancer package par package.

🔴 **Rejouer les suites de TOUS les paquets avant un tag — pas seulement ceux qu'on a touchés.**
Mesuré **deux fois le 2026-08-18** : des **gardes INTER-PAQUETS** vivent ailleurs que dans le code
qu'elles surveillent. `zcrud_study` porte une garde qui lit la liste réelle des paramètres de
`ZcrudScope` dans la source de `zcrud_core` ; `zcrud_core` porte une garde qui **scanne les sources
de tous les autres paquets** et interdit un `IconTheme.merge` coloré hors de `ZForegroundOverride`.
Les deux ont mordu sur des défauts **livrés**, parce que la vérif ne couvrait que les paquets
modifiés. `melos run analyze` et `melos run verify` verts ne disent **rien** d'un test rouge.
Boucle de secours (`melos run test` pend) :
```bash
cd packages; for p in */; do p=${p%/}; [ -d "$p/test" ] || continue; (cd "$p" && flutter test --no-pub -r compact 2>&1 | tail -1); done
```
⚠️ `zcrud_generator` échoue de façon **environnementale** (`Unsupported operation:
Isolate.packageConfig`, via `build_test`) : rouge attendu, à qualifier et non à imputer au code.

---

## Architecture

**Paradigme : monorepo melos + hexagonal (ports & adapters) sur couches `domain` / `data` / `presentation`.** Source de vérité complète : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` (**16 décisions AD-1..AD-16, NON-NÉGOCIABLES**).

### Structure des packages (14)

```
packages/
  zcrud_core/        # domaine pur (Dart) + moteur édition + ports + ZFieldSpec + l10n + ZcrudScope. AUCUNE dep lourde.
  zcrud_annotations/ # @ZcrudModel / @ZcrudField / @ZcrudId
  zcrud_generator/   # builder build_runner (dev_dependency) : (dé)sérialisation + ZFieldSpec + registre
  zcrud_markdown/    # Quill + ZCodec + embeds LaTeX/tables
  zcrud_list/        # DynamicList Syncfusion (ZListRenderer par défaut)
  zcrud_mindmap/     # ZMindmap + ZMindmapTreeOps + ZMindmapView (graphite)
  zcrud_flashcard/   # ZFlashcard + ZRepetitionInfo + ZSrsScheduler + sessions
  zcrud_firestore/   # adapters Firestore + Hive (offline-first)
  zcrud_geo/         # champs géo (adapters Google/OSM optionnels)
  zcrud_intl/        # téléphone/pays/devise (assets)
  zcrud_export/      # PDF/Excel (Syncfusion)
  zcrud_riverpod/    # binding état/injection <-> Riverpod (optionnel)  ← lex_douane/IFFD
  zcrud_get/         # binding état/injection <-> GetX + get_it (optionnel)  ← DODLP
  zcrud_provider/    # binding état/injection <-> provider (optionnel)
```

**Direction de dépendance (AD-1) : acyclique.** `zcrud_core` ne dépend **d'aucun** autre package zcrud ni de Firebase/Syncfusion/Quill/Maps ni d'un gestionnaire d'état. Tout satellite dépend de `zcrud_core` ; jamais l'inverse. Chaque package : API publique = `lib/<pkg>.dart` (barrel), impl sous `lib/src/{domain,data,presentation}`.

---

## Critical Patterns (invariants d'architecture)

### Réactivité Flutter-native — PAS de gestionnaire d'état dans le cœur (AD-2, AD-15)

> ⚠️ **Diffère de lex_douane.** Ici le **cœur `zcrud_core` n'importe AUCUN gestionnaire d'état** (ni Riverpod, ni GetX, ni provider).

- L'état du formulaire vit dans un `ZFormController` **`ChangeNotifier`/`Listenable` pur-Flutter**, exposant une `ValueListenable` par champ.
- **Un champ = un widget qui n'écoute que sa tranche** via `ValueListenableBuilder`/`ListenableBuilder` (rebuild ciblé) — jamais un `ConsumerWidget` dans le cœur.
- Interdits : `setState` à l'échelle du formulaire ; construction des champs dans une closure de `build()` ; recréation de `TextEditingController` au rebuild ; ré-injection de valeur écrasant la sélection.
- Obligatoires : controller stable (create/dispose), `ValueKey(field.name)`, validateurs mémoïsés, `AutovalidateMode.onUserInteraction` par champ, place stable pour les champs conditionnels.
- **Multi-gestionnaire par bindings** : injection/lifecycle branchés via `ZcrudScope` (défaut, `InheritedWidget`, zéro-dépendance) **ou** un binding (`zcrud_riverpod`/`zcrud_get`/`zcrud_provider`). Le code spécifique à un manager vit **uniquement** dans son package de binding.

### Serialisation — codegen, `reflectable` banni, `freezed` NON imposé (AD-3)

- Le générateur zcrud (`@ZcrudModel`/`@ZcrudField`) produit `toMap/fromMap/copyWith` + le `ZFieldSpec[]` + l'enregistrement au `ZcrudRegistry`. **Modèle = source unique de vérité.**
- **Jamais `reflectable`** (sauf l'adaptateur `ReflectableCodec` pour DODLP). **`freezed` n'est pas imposé** : zcrud partage structure + invariants, pas la mécanique de (dé)sérialisation.
- Conventions : `@JsonSerializable` pur, `fieldRename: snake` en persistance, **valeurs d'enum en camelCase**, `@JsonKey(unknownEnumValue:)` sur tout enum public.
- **Désérialisation défensive** (AD-10) : un champ absent/corrompu ne fait **jamais** échouer le parent (`unknownEnumValue`, `defaultValue`, `fromJsonSafe → null`). Évolution de schéma **additive seulement**.

### Extensibilité (AD-4)

Chaque entité canonique expose : (1) un slot `ZExtension?` typé additif **versionné** (`formatVersion`, `fromJsonSafe`) ; (2) `extra: Map<String,dynamic>` ; (3) l'extension de type/provenance via `ZTypeRegistry`/`ZSourceRegistry.register(kind, fromJson, toJson)`. **Rejetés** : héritage de classes sérialisées, `sealed` pour l'extension inter-package, generics pour la sérialisation.

### Erreurs & data (AD-5, AD-11, AD-16)

- Tout contrat repository retourne **`Either<ZFailure, T>`** (dartz) ; `Unit` pour void ; les flux sont des **`Stream<List<T>>` nus**.
- Hiérarchie `ZFailure` maison (`DomainFailure`, `CacheFailure`, `NotFoundFailure`, `ServerFailure`…).
- **Domaine backend-agnostique** : `cloud_firestore`/Hive (`Timestamp`/`Filter`/`FirebaseException`) ne fuient **jamais** dans `zcrud_core`. Ports `ZRepository<T>`, `ZLocalStore`, `ZRemoteStore`, `ZAcl`, pagination **curseur** dans `DataRequest` neutre ; adapters dans `zcrud_firestore`.
- **Offline-first** (AD-9) : store local source de vérité, distant fire-and-forget, merge **Last-Write-Wins sur `updatedAt`**, soft-delete `is_deleted` (hors-entité `ZSyncMeta`), cascade ≤ 450 écritures/lot, `ZSyncOrchestrator` (débounce ~400 ms). État SRS séparé de la carte ; voie d'écriture unique `reviewCard() → ZSrsScheduler.apply`.

### Rich-text & liste (AD-7, AD-8)

- Éditeur en **Delta** interne (Quill) ; (dé)sérialisation via `ZCodec` pluggable (Delta/Markdown/HTML) choisi par l'app. Champ rich-text à controller isolé (conforme AD-2).
- Liste : **Syncfusion `SfDataGrid` par défaut** dans `zcrud_list`, derrière `ZListRenderer` ; `zcrud_core` n'expose que l'abstraction (un consommateur sans `zcrud_list` ne tire pas Syncfusion).

---

## Dartdoc = DOCUMENTATION PUBLIÉE, jamais le journal du traitement (consigne owner, 2026-08-21)

🔴 **La documentation du projet est GÉNÉRÉE à partir des commentaires Dart.** Une dartdoc (`///`
sur une API publique) s'adresse donc au **consommateur du paquet**, jamais à nous.

⇒ Une dartdoc décrit **ce que l'API fait, comment on s'en sert, ses contrats, ses défauts et ses
garanties**. Elle ne raconte **ni** le traitement d'une CR, **ni** l'historique des versions, **ni**
comment le défaut a été trouvé.

**Bannis des `///`** : numéros de CR (`CR-IFFD-84`, `CR-LEX-76`…), « livré en vX.Y.Z », « trouvé par
la garde… », « quatrième fois qu'elle mord », le récit d'un lot, la justification d'un arbitrage
interne.

**Où cette matière va, à la place** : commentaires d'implémentation `//` **dans les corps**, fichiers
de tests, CHANGELOG, handoff. Elle garde toute sa valeur — elle change de support, parce qu'elle ne
s'adresse pas au consommateur.

**Ce qui RESTE légitime en dartdoc**, même né d'une CR : la **règle** elle-même, quand un appelant
doit la connaître. « La mesure porte sur `surface`, et sur rien d'autre » est de la documentation ;
« la CR-IFFD-84 a signalé que… » n'en est pas.

⚠️ **À rappeler dans CHAQUE brief de sous-agent** : la consigne a été enfreinte en masse parce que
les briefs demandaient de « justifier en dartdoc ». Demander une justification, oui — **en `//`**.

---

## Naming & Consistency Conventions (AD, Consistency Conventions)

| Élément | Convention | Exemple |
|---|---|---|
| Types publics | Préfixe **`Z`** | `ZFieldSpec`, `ZFlashcard`, `ZRepository` |
| Packages | `zcrud_<domaine>` | `zcrud_markdown` |
| Fichiers Dart | snake_case | `dynamic_edition.dart` |
| API publique / impl | barrel `lib/<pkg>.dart` / `lib/src/` | — |
| Enum des champs | `EditionFieldType` | — |
| `id` | `String` opaque (nullable pour l'éphémère) | — |
| Dates | ISO-8601 | — |
| Persistance | snake_case ; **enums en camelCase** | `created_at`, `type: "openQuestion"` |
| Métadonnées de sync | hors-entité `ZSyncMeta` | `updated_at`, `is_deleted` |
| Tests | `*_test.dart` | — |
| Code généré | `*.g.dart` / `*.freezed.dart` — **suivis par git sous `packages/*/lib/`** (dép. git), ignorés ailleurs | — |

---

## Key Don'ts (zcrud)

- **Never** importer un gestionnaire d'état (`flutter_riverpod`, `get`, `provider`) dans **`zcrud_core`** — réactivité **Flutter-native** (`ChangeNotifier`/`ValueListenable`) ; le code manager-spécifique vit dans les packages de binding.
- **Never** référencer `WidgetRef`, `Get.find`/`Get.put` ni `Provider.of` dans le cœur — passer par `ZcrudScope.of(context)` ou l'API du binding.
- **Never** de `setState` à l'échelle d'un formulaire — cf. AD-2 (objectif produit n°1).
- **Never** `reflectable` dans le moteur (sauf `ReflectableCodec` DODLP). **Never** imposer `freezed`.
- **Never** faire dépendre `zcrud_core` de Firebase / Syncfusion / Quill / Google Maps (isolés dans `zcrud_firestore`/`zcrud_list`/`zcrud_export`/`zcrud_geo`/`zcrud_markdown`).
- **Never** laisser fuiter un type `cloud_firestore` dans le domaine — passer par les ports neutres.
- **Never** `try-catch` nu dans un repository — envelopper en `Either<ZFailure, T>`.
- **Never** de secret dans un package (clé API Google Maps, endpoints) — config plateforme de l'app ; **never** `badCertificateCallback => true`.
- **Never** `EdgeInsets.only(left:/right:)`, `Alignment.centerLeft/Right`, `Positioned(left:/right:)`, `TextAlign.left/right` — utiliser les variantes **directionnelles** (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`) pour le RTL (AD-13).
- **Never** `ListView(children: [...])` — `ListView.builder`.
- **Never** éditer un `*.g.dart` à la main (généré par build_runner) — mais **TOUJOURS committer** ceux de `packages/*/lib/` après régénération (suivis par git : distribution en dép. git ; cf. gate `codegen-distribution`).
- **Never** style/couleur codé en dur dans un package — thème injecté via `ZcrudScope`/`ThemeExtension` (FR-26), repli `Theme.of(context)`.
  ⚠️ **Exception FR-26 encadrée (owner, 2026-08-04, CR-IFFD-57)** : les **valeurs de référence legacy IFFD** (y compris des hex de dégradés non dérivables du `ColorScheme`) peuvent entrer comme **défauts de jetons NULLABLES**, à trois conditions strictes : (1) centralisées dans un **unique fichier de référence audité** par famille (patron `ZStudyCardReference` — jamais éparpillées dans les widgets) ; (2) **remplaçables** par thème et par paramètre (priorité paramètre > jeton > référence) ; (3) la garde de source anti-couleurs **exempte nominativement** ces fichiers de référence et eux seuls. Partout ailleurs, FR-26 s'applique inchangé.
- **Always** `const` pour les widgets immuables ; `Semantics` explicites + cibles ≥ 48 dp (AD-13).

---

## Handoffs vers les apps consommatrices (NON-NÉGOCIABLE)

🔴 **Ne jamais écrire « aucune modification de votre code » sans qualifier POUR QUI.**

Une livraison additive est sans effet pour un hôte **passif**. Elle en a un pour l'hôte qui
**COMPENSAIT** le défaut qu'on vient de corriger : sa compensation **s'additionne** au correctif.
Mesuré (CR-LEX-76, v0.22.0) : lex restituait par un `Padding` externe la marge que `ZFolderCard`
forçait à zéro ; le socle s'étant mis à lire `CardThemeData.margin`, la marge rendue est passée à
**24 dp au lieu de 12**.

**Trois occurrences de la MÊME classe d'erreur** — affirmer une propriété sur *l'hôte* alors qu'on
n'a vérifié qu'une propriété sur *son propre code* :

| Version | Affirmation | Réalité |
|---|---|---|
| v0.16.0 | « aucun hôte ne casse » | faux au solveur |
| v0.19.1 | « non cassant, vérifié contre le tag » | vérif d'**API** extrapolée au **comportement** (CR-60) |
| v0.22.0 | « aucune modification de votre code » | vrai si passif, faux si l'hôte compensait (CR-76) |

**Règles à appliquer dans tout handoff** :
1. Toute correction qui transforme un **défaut contourné** en comportement natif porte un
   avertissement explicite : *« les hôtes qui compensaient doivent RETIRER leur compensation »*,
   avec la **liste des widgets** concernés.
2. Nommer les widgets touchés **au-delà de la cible de la CR**. Une extension décidée de notre
   initiative (ex. CR-73 étendue à `ZFolderCard`) est **invisible** depuis la lecture de la CR par
   l'hôte : c'est justement celle qu'il faut signaler le plus fort.
3. Distinguer systématiquement **hôte passif** et **hôte ayant contourné** dans les formules
   d'impact. « Rien à faire » peut vouloir dire « rien à faire » ou « rien à faire *si vous n'aviez
   rien contourné* ».
4. 🟢 **Recommander le tripwire** (pratique de lex, à propager) : sur chaque défaut amont contourné,
   garder un test qui **affirme la perte**. Quand l'amont corrige, il rougit et désigne le doublon —
   au lieu de croire le handoff sur parole. C'est le pendant exact de la discipline R3 côté aval.

## Artefacts BMAD — source of truth

| Document | Path |
|---|---|
| Inventaire technique (reconnaissance des 3 `data_crud`) | `docs/technical-inventory.md` |
| Schéma canonique (porté de lex_douane) | `docs/canonical-schema.md` |
| Product Brief (+ addendum, memlog) | `_bmad-output/planning-artifacts/briefs/brief-zcrud-2026-07-09/brief.md` |
| PRD (26 FR) | `_bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md` |
| **Architecture (16 AD)** | `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` |
| Epics & Stories (11 epics) | `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md` |
| Readiness Report | `_bmad-output/planning-artifacts/implementation-readiness-report-2026-07-09.md` |
| Sprint Status (créé par `bmad-sprint-planning`) | `_bmad-output/implementation-artifacts/sprint-status.yaml` |
| Stories enrichies (au fil de l'eau) | `_bmad-output/implementation-artifacts/stories/` |
| Code-review findings | `_bmad-output/implementation-artifacts/stories/code-review-<story>.md` |
| Rétrospectives | `_bmad-output/implementation-artifacts/stories/epic-N-retrospective.md` |

Config BMAD : `_bmad/bmm/config.yaml` (`user_name: Zakarius`, `communication_language: French`, `planning_artifacts`, `implementation_artifacts`).

---

## Phase de développement courante

**Planification BMAD complète** : brief → inventaire → canonique → PRD → architecture → epics → **readiness (verdict NEEDS WORK, 0 critique, 26/26 FR couvertes, 16/16 AD, 0 OQ bloquante)**. Décisions verrouillées : réactivité Flutter-native + bindings multi-gestionnaire (AD-15), codegen (freezed non imposé), melos, Syncfusion pour la liste, ZCodec pour le rich-text, schéma canonique porté de lex_douane.

**Prochaine étape : implémentation.** Séquencement MVP : **E1** (fondations melos + CI + **E1-5 révocation clé Google Maps**) → **E2** (cœur + codegen + bindings) → (**E3** édition granulaire ∥ **E4** liste ∥ **E5** firestore ∥ **E6** markdown ∥ **E11a** lot parité DODLP) → **E7** intégration DODLP → **E8** rich-forms lex_douane. Flashcards (**E9**) / mindmaps (**E10**) / reste géo-intl-export (**E11b**) en v1.x.

---

## Processus BMAD strict pour l'implémentation (NON-NÉGOCIABLE)

Pour chaque story listée dans `_bmad-output/implementation-artifacts/sprint-status.yaml`, suivre **strictement** le cycle BMAD complet, sans sauter d'étape, avec les **vrais skills**.

### Cycle par Story (ordre séquentiel strict)

| Étape | Action BMAD | Statut après |
|-------|-------------|--------------|
| 1 | **`bmad-create-story`** — fichier story enrichi (specs tech + ACs + tests) dans `stories/` | `ready-for-dev` |
| 2 | **`bmad-dev-story`** — implémente selon les ACs | `in-progress` |
| 3 | **Vérif verte rejouée** (`melos run generate` + `analyze` + `flutter test` RC=0) | `review` |
| 4 | **`bmad-code-review`** — revue adversariale | _(reste `review`)_ |
| 5 | Corriger findings **critiques/majeurs + MEDIUM** (si possible) ; re-vérif verte | _(reste `review`)_ |
| 6 | Édition ciblée du sprint-status | `done` |

### Transitions de statut obligatoires

```
backlog → ready-for-dev → in-progress → review → done
```

**Aucun saut autorisé.** Une story ne passe **jamais** directement de `in-progress` à `done`.

### Cycle par Epic

1. Traiter **chaque story une par une**, dans l'ordre du sprint-status (respecter le **graphe de dépendances** des epics, pas la seule numérotation — ex. **E11a précède E7**).
2. Après la dernière story de l'epic : **`bmad-retrospective`**.
3. Mettre l'epic + la retro à `done` dans le sprint-status.
4. **Commit unique en fin d'epic** — message `feat(<pkg-ou-epic>): <titre>` ; **inclure** les `*.g.dart` régénérés de `packages/*/lib/` (suivis par git — les omettre laisserait du code généré périmé chez un consommateur en dép. git) ; **exclure** les `pubspec.lock` (racine et `example/`) et les fichiers d'env.

### Règles générales (NON-NÉGOCIABLES)

- 🚫 **Jamais** plusieurs stories en parallèle par défaut — une seule à la fois. **Exception encadrée** : jusqu'à **3 stories complètement indépendantes** (epics parallélisables, **fichiers disjoints**, aucune dépendance croisée, **3 max**). En cas de doute → séquentiel. Garde-fous obligatoires quand on parallélise : (1) **packages de code disjoints** entre les stories en vol ; (2) le **seul point de contact possible = `zcrud_core`** — si plus d'une story doit y écrire, **re-séquencer ce fichier précis** (une seule story touche `zcrud_core` à la fois) ; (3) l'orchestrateur rejoue ses **vérifs vertes par package ciblé** pendant qu'un autre workstream écrit (pas de `melos test` global au milieu d'un dev actif), vérif globale seulement quand tous les workstreams sont au repos ; (4) **health-check** de chaque workstream ; (5) **NON-NÉGOCIABLE — à CHAQUE gate de commit d'epic** (workstreams au repos), rejouer **`melos run analyze` ET `melos run verify` REPO-WIDE** (pas seulement par-package) : la vérif ciblée d'un package NE détecte PAS une régression cross-package (ex. un symbole public supprimé dans un package et référencé par un autre — cf. `ZExportApi` supprimé en E11a-3, cassant `zcrud_flashcard`, `melos analyze` resté RED plusieurs commits sans être vu). Un `graph_proof`/`secrets`/`melos list` verts ne remplacent PAS `melos analyze`. Les écritures du sprint-status restent **sérialisées et ciblées par l'orchestrateur** ; les sous-agents `dev-story`/`code-review` ne touchent PAS au sprint-status.
- 🚫 **Jamais** sauter le `code-review` — même pour une story d'un paragraphe.
- 🚫 **Jamais** committer au milieu d'une story — commit en fin d'epic.
- 🚫 **Jamais** ignorer un finding critique/majeur — corriger ou justifier ; les MEDIUM corrigés dès que possible (sinon justifiés).
- ✅ Le sprint-status reflète l'état **réel** à chaque transition (édition **ciblée**, jamais réécriture globale du YAML).
- ✅ **Les 16 règles AD** (`architecture.md`, section *Invariants & Rules*) s'appliquent à **chaque** story.
- ✅ **Gates CI** (E1-3/E2-10) : lint **anti-`reflectable`** dans le moteur, **scan de secrets**, contrôle codegen, tests de **rétro-compatibilité de sérialisation** (désérialisation défensive) — verts avant tout `done`.
- ✅ **SM-1** (objectif n°1) : sur un formulaire de référence, taper 100 caractères ne reconstruit que le champ courant, zéro perte de focus — test widget + profiling.

---

## BMAD-METHOD Integration

BMAD v6.10 installé (`_bmad/`). `/bmad-help` pour découvrir les commandes ; lister `.claude/skills/bmad-*` en cas de doute sur un nom.

| Phase | Focus | Skills |
|-------|-------|--------|
| 1. Analyse | Comprendre | `bmad-product-brief`, `bmad-brainstorming`, `bmad-technical-research` |
| 2. Planification | Définir | `bmad-prd`, `bmad-ux` |
| 3. Solution | Concevoir | `bmad-architecture`, `bmad-create-epics-and-stories`, `bmad-check-implementation-readiness` |
| 4. Implémentation | Construire | `bmad-sprint-planning`, puis cycle strict `bmad-create-story` → `bmad-dev-story` → `bmad-code-review` → `bmad-retrospective` |

## 🔴 Le scratchpad est PURGÉ au redémarrage de session (mesuré le 2026-08-23)

Onze rapports d'analyse et de lots (quatre relevés comparatifs, six lots) ont disparu entre deux
sessions ; seuls les deux écrits après le redémarrage existaient encore. **Le handoff est le seul
support durable** : l'écrire **tôt**, dès que la synthèse est établie, et le compléter lot par lot —
jamais « à la fin ». Une analyse qui ne vit que dans le scratchpad n'existe pas.

## 🔴 Vert par paquet ≠ vert pour `verify` (mesuré le 2026-08-23, deux fois dans la même release)

2 153 tests verts sur trois paquets, 104 injections R3 rouges par assertion — et `melos run verify`
a attrapé **deux défauts réels** avant publication :
- **`gate:web`** compile les paquets pur-Dart vers Node : toute garde de source qui lit le disque
  (`dart:io`) doit porter **`@TestOn('vm')`** en tête de fichier, sinon elle rougit en JS. À rappeler
  dans chaque brief de lot touchant `zcrud_chat_kernel`, `zcrud_study_kernel`, `zcrud_exam`,
  `zcrud_annotations`.
- **`gate:reserved-keys`** (AD-19.1) : tout type neuf à `extra` **concret** doit filtrer par
  `zSanitizeExtra`/`zNormalizeExtra` avec un `_reservedKeys` qui **consomme** `ZSyncMeta.reservedKeys`
  (patron `z_chat_message.dart`). Trois types d'une même livraison l'avaient omis.
Autres constats de la même release : un run de tests qui passe de 13 s à **10 min** est un défaut
même s'il finit vert (flux laissé ouvert, `pumpEventQueue` sous `testWidgets`) — la durée est un
critère ; **sept octets de contrôle bruts** (NUL, VT) vivaient dans des littéraux Dart, invisibles à
l'analyseur, et rendaient `grep` sans `-a` aveugle — garde `z_source_control_bytes_guard_test` dans
`zcrud_core` ; en **zsh**, `PIPESTATUS` s'écrit `pipestatus` (un `RC=` vide n'est pas un RC=0).

## Décision d'owner — transport PAR ROUTE (2026-08-23)

Deux modes de transport coexistent chez les hôtes : **un endpoint unique à corps riche** (Lex,
`POST /`) et **une route par intention / type de génération** (IFFD, `generate_subject_explanation`,
`summarize_explanation`…). **Le mode par route doit être pleinement prévu et supporté par le
socle**, au même rang que l'autre : il porte la **gouvernance** (une route et ses accès associés à
un **plan d'abonnement**), et permet à l'app de déclarer **par tâche et par type de génération** le
modèle par défaut et ses callbacks — **récupérables depuis le backend** (catalogue de routes).
À terme, Lex migrera vers ce mode. Conséquence pour toute conception de `ZChatStreamPort` /
`ZChatGenerationRequest` : jamais présupposer le corps unique ; la route est une donnée de la
requête, résolue par un catalogue déclaré par l'hôte ou servi par le backend.

## Concurrence des sous-agents — limite relevée à 10 (consigne owner, 2026-08-23)

Jusqu'à **10 sous-agents simultanés** (au lieu de 3). Les garde-fous sont **inchangés et s'appliquent
à chacun** : un seul rédacteur par paquet, scratchpads distincts nommés dans le prompt, aucune mesure
d'un paquet pendant qu'un agent y écrit (`.dart_tool/package_config` est partagé), health-check des
agents en vol, écritures des fichiers racine (`pubspec.yaml`, `melos.yaml`, sprint-status) sérialisées
par l'orchestrateur. La limite haute ne dispense pas de vérifier le graphe de dépendances entre lots :
un lot qui consomme le contrat d'un autre attend sa fin.

## 🔴 Un plan ancien se MESURE avant de s'exécuter (mesuré le 2026-08-23)

Le plan « parité `ZCrudScreen` » (douze lots) a été resoumis et approuvé alors que **tout était livré
depuis dix jours** (`7f3026e06`, v0.93.0) — sa section « déjà sur disque, non commité » décrivait un
état antérieur à la release. Un agent a été lancé sur un lot dont le défaut n'existait plus ; un
explorateur a ensuite établi, `fichier:ligne` à l'appui, que les onze autres l'étaient aussi.
**Règle** : avant de lancer un lot d'un plan écrit dans une session antérieure, prouver sur disque
que son défaut existe encore (`grep` du symbole attendu, `git log -S`) ; un plan qui survit à une
release doit être **daté et remesuré**, jamais relancé sur la foi de son texte.
