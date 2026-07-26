# AGENTS.md

Consignes pour Codex et les agents qui travaillent dans ce dépôt.

## Projet et langue

**zcrud** est un monorepo Flutter/Melos de packages CRUD réutilisables. Un même schéma de champs (`ZFieldSpec`) alimente les formulaires (`DynamicEdition`) et les listes (`DynamicList`). Le projet comprend également Markdown riche, flashcards/SRS, mindmaps et champs spécialisés.

Objectif produit prioritaire : éliminer le rafraîchissement global du formulaire à chaque frappe ; les rebuilds doivent être réactifs et granulaires.

- Communiquer et documenter en français.
- Préserver les changements non liés déjà présents dans l’arbre de travail.
- Ne jamais pousser, créer une PR, ni effectuer une opération destructive sans demande explicite.

## Architecture non négociable

Architecture hexagonale : `domain` / `data` / `presentation`, avec une dépendance acyclique.

```text
zcrud_core         domaine, édition, ports, ZFieldSpec, l10n, ZcrudScope
zcrud_annotations  annotations du générateur
zcrud_generator    build_runner : sérialisation, specs et registre
zcrud_markdown     Quill, ZCodec et embeds
zcrud_list         liste Syncfusion via ZListRenderer
zcrud_mindmap      mindmaps
zcrud_flashcard    flashcards et SRS
zcrud_firestore    adaptateurs Firestore/Hive
zcrud_geo          géographie
zcrud_intl         téléphone, pays et devise
zcrud_export       PDF/Excel
zcrud_riverpod     binding Riverpod optionnel
zcrud_get          binding GetX/get_it optionnel
zcrud_provider     binding provider optionnel
```

- `zcrud_core` ne dépend d’aucun autre package zcrud, ni de Firebase, Syncfusion, Quill, Maps ou d’un gestionnaire d’état.
- Tout satellite peut dépendre de `zcrud_core`, jamais l’inverse.
- L’API publique d’un package est son barrel `lib/<package>.dart`; l’implémentation est sous `lib/src/{domain,data,presentation}`.
- Source de vérité détaillée : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` (AD-1 à AD-16).

## Invariants de code essentiels

### Réactivité et Flutter

- Le cœur utilise uniquement Flutter : `ZFormController` est un `ChangeNotifier`/`Listenable` avec une `ValueListenable` par champ.
- Un widget de champ n’écoute que sa propre tranche avec `ValueListenableBuilder` ou `ListenableBuilder`.
- Ne jamais utiliser Riverpod, GetX ou provider dans `zcrud_core`; les intégrations vivent exclusivement dans leurs packages de binding.
- Ne jamais faire de `setState` à l’échelle d’un formulaire, recréer un `TextEditingController` au rebuild, construire les champs dans une closure de `build()`, ni réinjecter une valeur qui détruit sélection/focus.
- Utiliser un controller stable, `ValueKey(field.name)`, des validateurs mémoïsés, `AutovalidateMode.onUserInteraction` par champ et une place stable pour les champs conditionnels.
- Pour l’accessibilité : `Semantics` explicites, cibles d’au moins 48 dp et variantes directionnelles RTL (`EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, `TextAlign.start/end`).

### Modèles, sérialisation et données

- Le codegen `@ZcrudModel` / `@ZcrudField` produit `toMap`, `fromMap`, `copyWith`, `ZFieldSpec[]` et l’enregistrement au registre. Le modèle est la source de vérité.
- `reflectable` est interdit dans le moteur (seul `ReflectableCodec` DODLP est une exception). Ne pas imposer `freezed`.
- Persistance : clés snake_case, valeurs d’enum camelCase, `@JsonKey(unknownEnumValue:)` pour tout enum public.
- Toute désérialisation est défensive : donnée manquante ou corrompue ne doit jamais invalider le parent. Évolution additive seulement.
- L’extensibilité est additive : `ZExtension?` versionnée, `extra: Map<String,dynamic>`, et `ZTypeRegistry`/`ZSourceRegistry`; ne pas recourir à l’héritage sérialisé, `sealed` inter-package ou aux generics pour sérialiser.
- Les repositories retournent `Either<ZFailure, T>` (`Unit` pour void); les flux restent des `Stream<List<T>>` nus.
- Aucun type Firebase/Hive ne fuit dans le domaine. Utiliser les ports neutres (`ZRepository`, `ZLocalStore`, `ZRemoteStore`, `ZAcl`, `DataRequest`).
- Offline-first : local source de vérité, merge LWW sur `updatedAt`, soft-delete via `ZSyncMeta`, et voie SRS unique `reviewCard() → ZSrsScheduler.apply`.

### UI, dépendances et conventions

- Rich text : Delta interne Quill et `ZCodec` sélectionné par l’application; controller isolé.
- Liste : `SfDataGrid` est l’implémentation par défaut dans `zcrud_list`, derrière l’abstraction `ZListRenderer` du core.
- Préfixer les types publics par `Z`; fichiers Dart en snake_case; identifiants en `String` opaque; dates ISO-8601.
- Préférer `const` pour les widgets immuables et `ListView.builder` aux listes de `children` matérialisées.
- Aucune couleur ou style codé en dur dans les packages : injecter thème via `ZcrudScope`/`ThemeExtension`, avec repli `Theme.of(context)`.
- Aucun secret, clé Maps, endpoint privé ou `badCertificateCallback => true` dans les packages.

## Code généré et vérifications

Les fichiers générés sous `packages/*/lib/` sont suivis par Git : les consommateurs utilisent les packages comme dépendances Git et ne régénèrent pas nécessairement le code.

Après toute modification d’annotation, de modèle ou de générateur, exécuter puis inclure les fichiers générés concernés :

```bash
dart run melos run generate
dart run melos run analyze
dart run melos run test
```

La vérification verte avant une story terminée est : codegen OK, analyse RC=0, tests RC=0. Une modification de documentation seule requiert au minimum `git diff --check`; toute autre modification localisée requiert les contrôles ciblés du package concerné. Indiquer explicitement les contrôles non rejoués. Une story ne peut toutefois être terminée sans les trois gates complètes.

Ne jamais modifier un `*.g.dart` manuellement. Les `*.g.dart` / `*.freezed.dart` sous `packages/*/lib/` doivent être committés lorsqu’ils sont régénérés; ne pas inclure les lockfiles racine ou `example/` sans nécessité.

## Workflow BMAD

BMAD est installé sous `_bmad/`; sa configuration est `_bmad/bmm/config.yaml`. Utiliser les skills `bmad-*` disponibles dans l’environnement Codex et lire leur `SKILL.md` avant de les appliquer.

### Continuation autonome

Lorsqu’un agent BMAD propose explicitement la prochaine étape du cycle (par exemple architecture, création de story, implémentation, revue ou rétrospective), il consigne dans son résumé l’étape, son périmètre, ses prérequis et les preuves déjà vérifiées. Après une minute sans réponse, il poursuit automatiquement sans redemander confirmation si la session peut rester active et attendre. Sinon, il reprend cette étape au prochain tour utilisateur, sans redemander l’autorisation déjà donnée.

- Cette règle vaut pour la planification (brief → PRD → architecture → epics → readiness) comme pour le cycle d’implémentation (`bmad-create-story` → `bmad-dev-story` → `bmad-code-review` → story suivante).
- Elle ne confère pas d’autorisation supplémentaire : arrêter et demander une décision si l’étape exige un choix produit non résolu, une nouvelle autorité, une coordination externe, une action destructive ou une publication.
- Vérifier l’état réel sur disque avant toute reprise (diff Git, statut de la story et contrôles applicables); ne pas reprendre sur la seule foi d’un rapport antérieur.
- N’enchaîner que si l’artefact et la story satisfont la transition BMAD attendue; sinon signaler l’écart et le résoudre avant de poursuivre.

### Orchestration et effort dynamique

Le pilote Codex reste responsable de l’orchestration : il sélectionne le skill BMAD, contrôle les fichiers, l’état Git, les tests et le `sprint-status.yaml`. Les agents délégués reçoivent une mission bornée; ils ne sont jamais l’unique preuve qu’une étape est achevée.

- Utiliser les skills `bmad-*` directement pour l’étape BMAD concernée. Déléguer uniquement l’exploration, une implémentation à fichiers isolés ou les lentilles de revue réellement indépendantes.
- Pour chaque délégation, choisir le niveau d’effort selon la surface réelle : `low` pour une exploration read-only ciblée, `medium` si elle couvre plusieurs packages ou doit recouper des artefacts; `medium` pour une création de story ou une rétrospective; `high` pour l’implémentation et la revue; `high` aussi pour la création de story complexe (plusieurs couches/packages, nouveau modèle/entité, logique métier non triviale, nombreux AC, taille L/XL).
- Une revue légère peut employer une seule lentille; une story critique ou large doit combiner les lentilles utiles (invariants AD, tests porteurs, a11y/RTL, l10n/thème, SM-1/performance, isolation des dépendances, robustesse et réalité du code).
- Pour une revue de story, chaque lentille écrit son rapport complet sous `_bmad-output/implementation-artifacts/stories/code-review-<story>-<lentille>.md` et retourne un résumé compact; les revues ponctuelles peuvent répondre directement. Le pilote vérifie les constats structurants sur disque avant correction.
- Ne lancer au plus trois workstreams en parallèle que si chacun a un responsable, des fichiers et packages disjoints vérifiés avant lancement, aucune écriture partagée et aucune modification concurrente de `zcrud_core`. Le pilote sérialise toujours les écritures de `sprint-status.yaml` et les vérifications globales.
- Contrôler périodiquement tout agent attendu : après environ cinq minutes sans progrès observable, considérer la tâche comme potentiellement bloquée, vérifier l’état réel, puis relancer ou reprendre de façon ciblée.

Pour une story du sprint, respecter les transitions :

```text
backlog → ready-for-dev → in-progress → review → done
```

Cycle requis : `bmad-create-story` → `bmad-dev-story` → vérifications vertes → `bmad-code-review` → correction des findings → vérifications vertes → mise à jour ciblée de `sprint-status.yaml`. L’agent principal confirme les preuves sur disque, applique les transitions et est le seul à modifier le sprint-status.

- Ne jamais sauter la revue de code.
- Corriger les findings HIGH/MAJEUR avant `done`; corriger les MEDIUM par défaut ou les justifier dans le rapport; consigner les LOW si non corrigés. Utiliser les niveaux déclarés par le skill de revue concerné et ne pas reclasser silencieusement un finding.
- Ne pas écrire deux fois en parallèle dans `_bmad-output/implementation-artifacts/sprint-status.yaml`; l’agent principal sérialise les mises à jour, après inspection du fichier courant, en conservant sa structure et ses commentaires.
- Une story à la fois par défaut. Ne paralléliser que des stories réellement indépendantes, à fichiers/packages disjoints; une seule peut modifier `zcrud_core` à la fois.
- Après chaque étape BMAD, fournir un résumé concis : skill utilisé, fichiers et AC/tâches, vérifications réellement rejouées, findings et transition de statut.
- Tout rapport d’agent est une piste, pas une preuve : vérifier les findings et l’état Git/tests sur disque avant de conclure.

Artefacts principaux :

- PRD : `_bmad-output/planning-artifacts/prds/prd-zcrud-2026-07-09/prd.md`
- Architecture : `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md`
- Epics : `_bmad-output/planning-artifacts/epics/epics-zcrud-2026-07-09/epics.md`
- Sprint : `_bmad-output/implementation-artifacts/sprint-status.yaml`
- Stories et revues : `_bmad-output/implementation-artifacts/stories/`

## Contrôle final avant livraison

Avant de livrer un changement : examiner le diff, vérifier que les invariants ci-dessus restent respectés et exécuter le gate requis : `git diff --check` pour la documentation seule, contrôles ciblés pour une modification localisée, et codegen + analyse + tests pour une story terminée. Préciser les commandes réellement exécutées et signaler tout contrôle non effectué. Ne pas attribuer une vérification à un agent sans l’avoir confirmée localement.
