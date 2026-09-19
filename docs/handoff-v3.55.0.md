# Handoff v3.55.0 — apprentissage confirmé et résultat de recherche partagé

Release du 2026-09-19, tag `v3.55.0`. Origine : Lex CR-102 et CR-103, vérifiées sur le socle v3.54.0. Aucun modèle persisté ni clé de schéma modifié ; aucune migration de données.

## CR-102 — le cycle d’apprentissage devient configurable

Le socle savait déjà afficher des points de progression et produire des aperçus d’intervalle par carte. Le manque confirmé portait sur la correction typée, le choix d’un palier suivi d’une confirmation, et une file dont le seuil de retrait est indépendant du seuil de réussite SRS.

### Montage depuis la page de session

`ZStudySessionHost` et `ZStudySessionScaffold` acceptent `learning: ZLearningSessionOptions(...)`. Leurs constructeurs `.wired` reçoivent ces options via `ZStudySessionWiring.learning`. La saisie évalue la réponse, rend la correction et laisse ajuster le palier. Seule la confirmation appelle le reviewer. Si celui-ci rend un échec, la même réponse reste disponible pour réessayer ; un clic pendant l’écriture ne lance pas de deuxième écriture.

**Adaptation obligatoire du montage énuméré.** Le constructeur `ZStudySessionWiring(...)` exige maintenant `learning:` : ajouter `learning: null` pour conserver le comportement précédent, ou les options pour activer l’apprentissage. C’est une rupture de compilation ciblée, conforme au contrat existant de ce type qui exige de nommer chaque capacité. `ZStudySessionWiring.none()` reste inchangé. Les constructeurs usuels host/scaffold gardent leur compatibilité ; ne pas ajouter `learning` à plat sur `.wired`.

```dart
ZStudySessionScaffold(
  title: Text(l10n.study),
  mode: ZReviewMode.learn,
  config: const ZSrsConfig(minQuality: 1), // cinq paliers, de 1 à 5
  queue: cards,
  reviewer: reviewCard,
  learning: ZLearningSessionOptions(
    queuePolicy: ZQueuePolicy(
      removeAtOrAbove: 5,
      reinsertOffsetFor: (q) => q <= 1 ? 3 : q == 2 ? 5 : 1 << 30,
    ),
    showProgressBadge: true,
  ),
  labels: ZStudySessionLabels(
    confirmAction: l10n.nextQuestion,
    feedbackTitleFor: (q) => l10n.feedbackTitle(q),
    explanationTitle: l10n.explanation,
    progressBadgeLabelFor: (percent) => '$percent %',
    learningCounterLabelFor: (completed, total, remaining) =>
        l10n.studyCounts(completed, total, remaining),
  ),
  qualityPreviewLabelForCard: (card, q) => intervalLabel(card, q),
)
```

Les noms `l10n`, `cards`, `reviewCard` et `intervalLabel` représentent les dépendances de l’application.

**Politique de file.** L’offset désigne la position de retour parmi les cartes restantes, après retrait de la carte courante : `3` la remet en troisième position, `5` en cinquième. L’index est borné aux limites de la file. Un offset très grand place q3/q4 en fin de file ; q5 retire la carte. Le compteur des lapses reste fondé sur le seuil SRS, donc réinsérer q3/q4 ne crée pas un échec artificiel. Cette politique ne modifie pas le calcul SM-2 ni la voie unique de persistance `reviewCard`.

Les options d’apprentissage s’appliquent uniquement aux modes SRS `learn` et `spaced` ; les autres modes les ignorent. Une politique modifiée à chaud s’applique aux prochaines notations, sans réamorcer la file ; une écriture déjà engagée conserve sa politique initiale. Une réponse tardive d’une session remplacée ne modifie pas la nouvelle session.

**Retour et présentation.** `ZLearningFeedback` porte `quality`, `message`, `explanation`. `feedbackBuilder` remplace sa présentation ; les titres et les couleurs peuvent être injectés. Les boutons carrés et puces d’intervalle sont activés par les options d’apprentissage. Les points déjà présents restent configurables via les paramètres de progression habituels.

**Saisie seule.** `ZFlashcardAnswerInput` accepte `ZCardAdvanceBehavior.confirm`, `onConfirm` (asynchrone, `false` autorise une nouvelle tentative) et `onAdvanceWithQuality`. L’ancien `onAdvance: VoidCallback` reste disponible. `onConfirm` est prioritaire ; sans lui la voie typée est prioritaire sur le callback historique.

**Adoption hôte.** Retirer la file et la confirmation locales seulement après avoir branché ces options et rejoué la recette de l’application. Ne pas conserver une écriture du reviewer dans le callback de soumission : elle doublerait celle du socle. Les montages sans `learning` gardent leurs défauts historiques. Fournir `learning` sans `queuePolicy` active la confirmation mais conserve la politique de file historique.

## CR-103 — la recherche publie exactement le résultat affiché

`ZFlashcardListView.onVisibleChanged` reçoit un `ZFlashcardVisibleSnapshot` : requête effective après debounce, `sortMode`, liste non modifiable `cards` et `ids` ordonnés. Le snapshot est calculé depuis le résultat déjà utilisé par le rendu : filtres métier, portée, recherche, tri et ordre personnel restent dans une seule implémentation.

```dart
ZFlashcardListView(
  cards: cards,
  labels: listLabels,
  onVisibleChanged: (snapshot) {
    setState(() => visibleSnapshot = snapshot);
  },
  onOpen: (card) => openSession(
    visibleSnapshot.cards,
    initialCard: card,
  ),
)
```

Initialiser `visibleSnapshot` côté hôte ou rendre l’action indisponible tant que le premier snapshot n’a pas été reçu. Pour restaurer la navigation, réinjecter sa requête dans `filters.query` et son tri dans `sortMode`, ainsi que les filtres métier conservés par l’application.

La notification intervient après la frame et seulement si le résultat change : une closure recréée par `setState` ne boucle pas. Le passage de `null` à un callback republie l’état courant. Remplacer directement un callback non nul n’est pas un abonnement neuf : transmettre au nouveau destinataire le dernier snapshot déjà conservé. Les cartes sans identifiant figurent dans `cards` mais pas dans `ids`. Sans callback, aucun snapshot supplémentaire n’est alloué.

## Vérifications et publication

| Contrôle réellement exécuté | Résultat |
|---|---|
| `dart run melos run generate` | RC=0 ; aucun fichier généré modifié |
| `dart run melos run analyze` sur le code final | RC=0 ; aucune erreur ni warning, diagnostics informatifs préexistants |
| `dart run melos run verify` | RC=0 ; architecture, codegen, compatibilité, recette, tests Node et sérialisation |
| `dart run melos run test` | 41 packages verts ; un échec initial study a révélé le relais wiring manquant, corrigé |
| Rejeu complet `flutter test --no-pub -j 4` dans `packages/zcrud_study` après corrections wiring/audit | RC=0 ; **2 435 tests** |
| Suite session dans le passage monorepo | RC=0 ; **841 tests** |
| Confirmation sous thème shrinkWrap, rejouée après renforcement du test | RC=0 ; 4 tests |
| `git diff --check` | RC=0 |

Les **42 suites de packages ont donc été validées**, avec rejeu complet du seul package corrigé après le premier passage global. La commande globale `melos run test` n’a pas été répétée intégralement après cette correction : son RC initial était 1, et le rejeu final du package concerné est explicitement indiqué ci-dessus. Le générateur compte 214 tests verts ; le core 2 707. Aucune recette visuelle dans les applications hôtes ni publication de leur code n’est incluse.

La revue indépendante et les corrections sont consignées dans `_bmad-output/implementation-artifacts/code-review-cr-102-103.md`. Aucun finding retenu ne reste ouvert. Les 42 versions de packages et leurs dépendances internes sont alignées sur `3.55.0` ; la recette de consommation épingle ce même tag.

Les lockfiles racine et `example/` préexistants sont exclus de la release et conservés identiques à leurs empreintes de début de travail. Publication par le tag annoté `v3.55.0` ; aucune publication pub.dev ni modification des dépôts hôtes. Le contrôle automatique a refusé de modifier `origin/main` sans autorisation explicite visant cette branche partagée : le tag contient la release, mais la branche distante reste inchangée.
