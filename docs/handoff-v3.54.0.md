# Handoff v3.54.0 — trois briques que deux hôtes réécrivaient

> Version publiée le 2026-09-09 (tag `v3.54.0`).

Origine : trois demandes d'un hôte, toutes fondées sur la règle du dépôt « une redondance
entre applications est une CR » — deux hôtes réécrivaient la même chose, un troisième
l'aurait réécrite. L'une est bloquante.

## Clés de schéma ajoutées

**Aucune.** Aucune entité persistée n'est touchée ; aucune migration n'est requise.

## Constats vérifiés sur disque avant tout travail

| # | Constat de l'hôte | Vérification | Verdict |
|---|---|---|---|
| 101 🔴 | Le multi-éditeur n'édite ni choix, ni Vrai/Faux, ni balises ; garde de sortie en anglais sans seam | `ZFlashcardEditorField` = question/answer/explanation/hint (`z_multi_flashcard_editor.dart:77-88`), aucune logique `choices`/`isTrue`/`tagIds` ; `ZDiscardChangesGuard` monté sans libellés | réel — bloquant |
| 100 | `ZWhiteExamSessionView` rend une question à la fois ; pas de réponse par index, ni « je ne sais pas », ni drapeau, ni soumission incomplète, ni bandeau | `state.current` (`z_white_exam_session_view.dart:211`), 283 l ; contrôleur `answer(int)` sans index | réel |
| 99 | Aucune section repliable à en-tête daté ; deux hôtes la réécrivent | aucun `ZCollapsibleSection` public ; des sections repliables existent dans l'étude et le moteur d'édition — **à mesurer** avant de créer | réel, existant à mesurer |

## Une piste remontée par un hôte, non lancée

Dans son rejeu de la version précédente, un hôte note que sans `gradingBuilder`, la
soumission **note dès la soumission** avec le cran suggéré par l'évaluation — l'apprenant ne
peut plus l'ajuster avant l'écriture. Il garde son créneau pour cette seule raison. Ce n'est
pas une demande ; c'est une différence de parité mesurée. Elle est consignée ici pour qu'une
décision puisse être prise — un mode « suggestion modifiable, puis un cran tapé note ce cran »
—, elle n'est pas livrée dans cette version.

## Lot M2 — section repliable (`zcrud_core` + `zcrud_ui_kit`)

**Existant mesuré, décision : créer.** Trois candidats écartés : l'en-tête repliable du moteur
d'édition (`zcrud_core/.../dynamic_edition.dart:1603`) est un en-tête de formulaire sans
`Material` élevé ni pastille, et ne rend pas le corps ; le corps repliable de la disposition
d'étude (`zcrud_study/.../z_sectioned_study_layout.dart:1254`) est couplé à
`ZStudyToolsSectionSpec` dans un paquet aval de `zcrud_ui_kit` ; `ZCountBadge` est une pastille
d'alerte (`error`/`onError`), laissée intacte et réutilisable via le slot `countBadge`.

**Livré.** `ZCollapsibleSection` (`zcrud_ui_kit`) : `child`, `title`/`titleWidget`,
`leading`/`leadingIcon` (+ `leadingColorKey`), `count`/`countBadge`, `countSemanticsLabel`,
`trailing`, `initiallyExpanded`, `expandController`, `onExpansionChanged`, `semanticsLabel`,
`spec`, `margin`, `backgroundColor`, `headerColor` ; clés publiques `containerKey`/`headerKey`/
`bodyKey`/`chevronKey`. `ZCollapsibleSectionSpec` (10 champs, `merge`), référence
`ZCollapsibleSectionReference` (22 scalaires, zéro couleur, provenance `fichier:ligne` en `//`).
Corps **démonté** quand fermé (AD-4), chevron `AnimatedRotation` à durée nulle sous Reduce
Motion, `Semantics` bouton avec état, cible ≥ 48 dp, directionnel.

**Jetons `ZcrudTheme`** (tous lus, garde d'inertie) : `collapsibleSectionExpandedElevation`,
`…CollapsedElevation`, `…CornerRadius`, `…BorderAlpha`, `…BodyBorderAlpha`, `…BodyCornerRadius`,
`…ChevronDuration`, `…LeadingIconSize`, `…LeadingBackgroundAlpha`, `…CountCornerRadius`.

**Contrastes mesurés** (thème par défaut) : clair titre 16,2 / pastille 7,2 / glyphe 5,3 ;
sombre 14,4 / 7,2 / 9,0. Aucune correction nécessaire.

**Une garde verte sous injection, corrigée** : `find.byKey` ignore par défaut les widgets
hors-scène, donc un corps mis en `Offstage` passait pour « absent ». La garde mesurait
l'invisibilité, pas le démontage ; corrigée en `skipOffstage: false`, réinjection rouge.

**Montage hôte** (section de semaine avec compte) :

```dart
ZCollapsibleSection(
  leadingIcon: Icons.calendar_month_rounded,
  title: l10n.weekRange(startLabel, endLabel),
  count: week.folders.length,
  countSemanticsLabel: l10n.folderCount(week.folders.length),
  trailing: IconButton(
    onPressed: () => onCreateExam(date: week.start),
    icon: const Icon(Icons.add_circle_outline_rounded),
    tooltip: l10n.add,
  ),
  child: FolderGrid(folders: week.folders),
)
```

⚠️ **Hôte ayant compensé** : les deux hôtes enveloppent leur section d'un
`Padding(symmetric(horizontal: 12, vertical: 6))` et recréent leur contrôleur d'expansion dans
`build` (d'où un `key: UniqueKey()`). La brique porte cette marge (`margin`, défaut identique) et
détient son état : **retirer** le `Padding` externe et le `UniqueKey()`, sinon la marge double et
le repli se réinitialise à chaque `build` du parent. Tripwire conseillé : un test qui mesure la
marge rendue à 12 dp et qui rougira si le `Padding` externe est laissé (24 dp). Hôte passif : rien.

**Vérif du lot** (par l'agent, à rejouer au repos) : `zcrud_core` analyze RC=0 / 2707 tests ;
`zcrud_ui_kit` analyze RC=0 / 413 tests (+50). R3 : 13 injections rouges par assertion, sha256
identiques, `ZR3-LOTM2-INJECT` absent (RC=1).

## Lot M3 — examen blanc en liste (`zcrud_session`)

**Constats re-prouvés** : coquille « une question à la fois » (`z_white_exam_session_view.dart:211`),
`startAction`/`remaining` requis, contrôleur limité à `start`/`answer(int)`/`submit`. Le harnais
de test du paquet déclarait lui-même « `answer({index, quality})` hors périmètre » : c'est ce lot.

**Livré, tout additif.**
- Domaine : `ZExamAnswer` (`answered(q)` / `dontKnow` / `unanswered`, `scoredQuality(incorrectQuality:)`) ;
  `ZWhiteExamState.answersByIndex` / `marked` / `answeredCount` / `unansweredCount` / `answerFor` /
  `isMarkedAt` ; moteur `answerAt(i, q)`, `dontKnowAt(i)`, `toggleMarkAt(i)`,
  `submit({countUnansweredAsIncorrect})`, constructeur `startImmediately: true` (pas de phase de
  réglage) ; contrôleur relais.
- Présentation : `ZWhiteExamListView` (toutes les questions, `ListView.builder`, slots
  `headerBuilder` / `questionBuilder` / `resultBuilder` ; l'en-tête par défaut porte le badge de
  numéro, « Je ne sais pas » et le drapeau), `ZWhiteExamSubmitPolicy` (dialogue « incomplet » avec
  le compte de non répondues ; `.immediate()` pour s'en passer), `ZWhiteExamScoreBanner` (trois
  statistiques : correctes, temps total, moyenne par question), `zWhiteExamDigits`.
- `remaining`, `startAction`, `elapsed` et tous les libellés de `ZWhiteExamSessionLabels` sont
  désormais nullables : `null` ⇒ la surface omet l'élément.

**Règles de comptage** (documentées en dartdoc) : « Je ne sais pas » compte faux ; une question
laissée blanche à une soumission confirmée compte faux (`countUnansweredAsIncorrect: false` pour
noter sur les seules réponses données).

**Partage du barème, prouvé** : la voie par index et la coquille alimentent la même liste de
réponses et le même scoreur ; garde d'équivalence (même `ZStudySessionResult` pour les mêmes
réponses en saisie désordonnée, scoreur espion appelé une fois par voie). Mêler les deux voies sur
une même question lève au lieu de compter deux fois.

**Écart assumé vis-à-vis de la demande** : le seuil « 0,7 en fichier de référence » est
**refusé par une garde existante** du paquet (aucun littéral `0.7`/`70` dans `lib`, « pas même en
repli »). Retenu : `successRatio` nullable, `null` = aucun verdict (teinte neutre). Le seuil est
une règle de l'application : l'hôte le pose (voir montage).

**Aucune écriture SRS** : le moteur d'examen ne détient aucun seam de review/scheduler/store et une
garde de source interdit tout symbole SRS dans les surfaces d'examen par index. L'invariant tient
par construction ; aucun compteur n'a été écrit sur un scénario inatteignable.

**Inertie** : arbre de la coquille gelé **avant** le lot (fichiers HEAD restaurés par copie),
identique aux trois phases après le lot. Garde jumelle hors paquet : un seul site
(`zcrud_study/.../z_study_session_host.dart:1210`, `ZWhiteExamSessionEngine(queue:, config:)`),
inchangé et sans risque (tous les paramètres neufs ont un défaut).

**Montage hôte** (page d'examen blanc complète, chrono libre, seuil de l'application) :

```dart
class WhiteExamPage extends StatefulWidget {
  const WhiteExamPage({required this.cards, super.key});
  final List<FlashcardModel> cards;
  @override
  State<WhiteExamPage> createState() => _WhiteExamPageState();
}

class _WhiteExamPageState extends State<WhiteExamPage> {
  static const double _successRatio = 0.7; // règle de l'app, jamais du socle

  late final ZWhiteExamSessionEngine _engine = ZWhiteExamSessionEngine(
    queue: <ZSessionItem>[
      for (final c in widget.cards)
        ZSessionItem(flashcardId: c.id!, folderId: c.folderId!),
    ],
    startImmediately: true,
    successRatio: _successRatio,
  );
  late final ZWhiteExamSessionController _controller =
      ZWhiteExamSessionController(engine: _engine);
  final ValueNotifier<Duration> _elapsed = ValueNotifier<Duration>(Duration.zero);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1),
        (_) => _elapsed.value += const Duration(seconds: 1));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    _controller.dispose();
    _engine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: ValueListenableBuilder<Duration>(
            valueListenable: _elapsed,
            builder: (_, v, __) => Text(zWhiteExamDigits(v)),
          ),
        ),
        body: ZWhiteExamListView(
          controller: _controller,
          onSubmitted: () => _timer?.cancel(),
          submitPolicy: const ZWhiteExamSubmitPolicy(),
          questionBuilder: (context, q) => WhiteExamQuestionCard(
            flashcard: widget.cards[q.index],
            submitted: q.phase == ZWhiteExamSessionViewPhase.submitted,
            onGraded: q.onAnswer, // la note part sous SA question
          ),
          resultBuilder: (context, state) => switch (state.result) {
            final r? => ZWhiteExamScoreBanner(
                result: r,
                elapsed: _elapsed.value,
                successRatio: _successRatio,
              ),
            _ => const SizedBox.shrink(),
          },
        ),
      );
}
```

⚠️ **Hôte ayant compensé** : ceux qui passaient des libellés bouchons (`Text('')` pour
`startAction`, chronomètre figé à `Duration.zero` pour `remaining`) les **retirent** : la surface
omet désormais ces éléments d'elle-même. Hôte passif : rien à faire, arbre identique.

**Vérif du lot** (par l'agent, amont mesuré au repos deux fois ; à rejouer à la clôture) :
analyze 0 error / 0 warning ; `flutter test` RC=0, 833 tests (+58). R3 : 15 injections rouges par
assertion, sha256 identiques, `ZR3-LOTM3-INJECT` absent (RC=1).

## Lot M1 — multi-éditeur : formulaire complet (`zcrud_study`)

**Existant mesuré, décision : réutiliser.** Le socle n'a pas de formulaire mono-carte assemblé,
mais il a tous les widgets : `ZChoicesFieldWidget` et `ZTrueFalseFieldWidget` (`zcrud_flashcard`),
`ZTagsFieldWidget` (`zcrud_core`), `ZFlashcardEditionValidator`. Ils se montent sans
`DynamicEdition`. Le défaut du multi-éditeur **s'enrichit par réutilisation** : aucun second
éditeur n'a été écrit ; le sélecteur de type reste inchangé.

**Livré.**
- `ZMultiFlashcardEditor.cardFormBuilder(context, ZFlashcardCardFormSlot)` : `card` (carte vivante
  du brouillon), `controllerOf(field)` (4 contrôleurs stables), tranches `type` / `choices` /
  `isTrue` / `tagIds` (`ValueListenable`), `onChanged` typés pour les huit champs,
  `onEditingComplete`, `validate()`. Toute écriture passe par la voie du formulaire par défaut
  (`_draft.updateCard`), donc par la validation et le commit unique. Fourni, il **remplace** le
  formulaire du socle.
- `cardValidator` : règle de validité (défaut = celle du socle ; `(c) => null` la désactive).
- Le défaut rend désormais les choix (type `multipleChoice`), le vrai/faux (`trueOrFalse`) à
  place stable, et les balises. **Une carte invalide bloque le commit** (carte focalisée,
  message par clé d'état), là où rien n'était validé.
- `ZMultiFlashcardEditorLabels` : `discardTitle` / `discardMessage` / `discardConfirmLabel` /
  `discardCancelLabel` relayés à `ZDiscardChangesGuard`, plus `choicesLabel`, `addChoiceLabel`,
  `trueFalseLabel`, `trueLabel`, `falseLabel`, `tagsLabel`, `editionMessages`. Tous nullables :
  un libellé omis laisse le défaut audité du widget d'édition.

**Libellés de sortie** : `ZcrudLabels` ne porte aucune clé « modifications non enregistrées »
(grep négatif montré) ; le défaut reste donc le repli neutre de `ZDiscardChangesGuard`. Zéro
libellé écrit dans `zcrud_study` (garde de source, contre-preuve du motif).

**Montage hôte** :

```dart
ZMultiFlashcardEditor(
  initialCards: cartes,
  onCommit: (cards) => repo.saveFlashcards(cards),
  labels: ZMultiFlashcardEditorLabels(
    // … champs existants inchangés …
    choicesLabel: l10n.choix, addChoiceLabel: l10n.ajouterUnChoix,
    trueFalseLabel: l10n.vraiFaux, trueLabel: l10n.vrai, falseLabel: l10n.faux,
    tagsLabel: l10n.etiquettes,
    editionMessages: ZFlashcardEditionMessages(
      questionRequired: l10n.enonceRequis,
      qcmMinChoices: l10n.qcmDeuxChoix,
      qcmNoCorrect: l10n.qcmUneBonneReponse,
    ),
    discardTitle: l10n.abandonnerTitre,
    discardMessage: l10n.abandonnerMessage,
    discardConfirmLabel: l10n.abandonner,
    discardCancelLabel: l10n.continuer,
  ),
  // Option A : rien de plus, le défaut édite choix / vrai-faux / balises.
  // Option B : l'hôte monte SON formulaire dans l'ossature de lot :
  cardFormBuilder: (context, slot) => MonFormulaireCarte(
    card: slot.card,
    questionController: slot.controllerOf(ZFlashcardEditorField.question),
    answerController: slot.controllerOf(ZFlashcardEditorField.answer),
    type: slot.type, choices: slot.choices, isTrue: slot.isTrue, tagIds: slot.tagIds,
    onTypeChanged: slot.onTypeChanged,
    onChoicesChanged: slot.onChoicesChanged,
    onIsTrueChanged: slot.onIsTrueChanged,
    onTagIdsChanged: slot.onTagIdsChanged,
    onEditingComplete: slot.onEditingComplete,
    errorText: slot.validate(),
  ),
)
```

⚠️ **Rupture visible.** Le volet détail rend deux champs de plus. Un hôte qui **compensait** en
rendant lui-même choix / vrai-faux / balises à côté du multi-éditeur les verrait en double : il
retire sa compensation ou passe à `cardFormBuilder`. Le blocage de commit mord aussi sur un lot
déjà invalide (énoncé vide, QCM incomplet) : `cardValidator: (card) => null` restitue l'ancien
comportement. Aucun paramètre `required` ajouté : les montages existants compilent inchangés.
Hôte passif : rien à faire hormis constater deux champs de plus. L'hôte qui avait réécrit tout le
multi-éditeur (~850 lignes) peut revenir au socle avec `cardFormBuilder`.

**Vérif du lot** (par l'agent, amont au repos ; à rejouer à la clôture) : analyze 0 error /
0 warning ; `flutter test` RC=0, 2414 tests (+20). R3 : 11 injections rouges par assertion,
sha256 identiques, `ZR3-LOTM1-INJECT` absent (RC=1).

## Vérification (orchestrateur, tous paquets au repos, 2026-09-09)

| Étape | Résultat |
|---|---|
| `melos run generate` | RC=0, 0 `.g.dart` modifié |
| `melos run analyze` (repo-wide) | RC=0, 0 error, 0 warning |
| `melos run verify` (gates) | RC=0 |
| Balayage des 42 paquets, `flutter test --no-pub -j 4` **depuis le dossier de chaque paquet** | 41 verts ; `zcrud_generator` rouge environnemental (`Isolate.packageConfig`, 75 cas), qualifié **byte-identique à v3.53.0** sur `lib` et `test` |
| Paquets touchés | `zcrud_core` 2707 · `zcrud_ui_kit` 413 (+50) · `zcrud_session` 833 (+58) · `zcrud_study` 2414 (+20) |
| Résidus R3 (`ZR3-LOTM1/2/3-INJECT`, `--no-ignore-files -a`) | aucun |
| Recette de consommation | 49 pins à `v3.54.0`, gate `consumption-recipe` vert |

Aucune clé de schéma ajoutée. Trois ruptures visibles annoncées ci-dessus, toutes pour un hôte
qui compensait : la marge et le contrôleur de la section repliable (M2), les libellés bouchons
de l'examen blanc (M3), les champs choix / vrai-faux / balises rendus à côté du multi-éditeur et
le blocage de commit sur un lot déjà invalide (M1, échappatoire `cardValidator: (c) => null`).
