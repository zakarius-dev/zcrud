# Code Review — E6-1 : éditeur Quill rich-text isolé (`ZMarkdownField`, `zcrud_markdown`)

- **Statut story** : review
- **Skill** : `bmad-code-review` (invoqué via tool `Skill`) — chemin pris : **skill Skill** (fallback disque non requis).
- **Reviewer** : agent BMAD adversarial (Opus 4.8).
- **Portée revue** : `packages/zcrud_markdown/` uniquement (aucune modif de `zcrud_core`, `example/`, `zcrud_geo`).
- **Baseline** : `fe203b90bb95a659063452af4cf584f66e7bab0f` (frontmatter story).

## Fichiers revus
- `lib/src/presentation/z_markdown_field.dart` (widget)
- `lib/zcrud_markdown.dart` (barrel)
- `pubspec.yaml`
- `test/z_markdown_field_test.dart`, `test/z_markdown_field_lifecycle_test.dart`, `test/flutter_quill_isolation_graph_test.dart`, `test/quill_signature_isolation_test.dart`
- Références de parité : `zcrud_core` `z_edition_field.dart`, `z_form_controller.dart`, `z_field_listenable_builder.dart`, `theme/z_theme.dart` ; source `flutter_quill-11.5.1`.

---

## Verdicts adversariaux (vérifiés sur disque)

| Axe | Verdict | Preuve vérifiée |
|---|---|---|
| **SM-1 réellement prouvé (focus + sélection)** | **OUI** | T2 : 100 frappes une par une au **point courant** ; `initA==1` (controller jamais recréé) ; `identical(controller)` en fin ; `buildB==buildBBefore` (voisin figé) ; `globalBuilds==globalBefore` (l'`AnimatedBuilder(controller)` ne rebuild pas car `setValue` ne fait **aucun** `notifyListeners()` global — confirmé dans `z_form_controller.dart`) ; `focus.hasFocus` vrai ; `selection.baseOffset==101`. Le widget ne ré-injecte jamais pendant l'édition (`_syncFromExternal` sort si `hasFocus`), donc le curseur au milieu n'est **pas** écrasé. Preuve réelle, pas un proxy. |
| **Isolation `flutter_quill`** | **OUI** | Gate de graphe par **fermeture transitive** via `dart pub deps --json` (fallback local honnête documenté) : `zcrud_core` closure sans `flutter_quill` ; **contrôle positif** `zcrud_markdown` **avec** `flutter_quill` + transitif externe `dart_quill_delta` (anti-faux-vert, confirmé présent dans `pubspec.lock`) ; acyclicité `md→core`, `core` out-degree zcrud_*=0. `flutter_quill` au **seul** pubspec de `zcrud_markdown`. |
| **Valeur du form neutre** | **OUI** | `_encodeNeutral` → `List<Map<String,dynamic>>` JSON-safe ; runtime `valueOf` = `isA<List<Map<String,dynamic>>>` **et** `isNot(isA<Document>())` **et** round-trip `jsonDecode(jsonEncode(v))==v` ; scan statique : barrel sans directive `flutter_quill`, région publique sans nom de type Quill. |
| **Anti-fuite prouvé** | **PARTIEL** | Code correct : `removeListener` **avant** `dispose()` du `QuillController`/`FocusNode`/`ScrollController` ; `_applyingExternal` empêche la ré-entrance. MAIS le test AC3 est un **proxy faible** (finding LOW-1) : `setValue` post-démontage ne touche jamais `_quill`, donc il ne détecterait pas un `removeListener` manquant. Aucune fuite réelle constatée. |
| **Défensif cas réels (AD-10)** | **OUI** | 9 cas RÉELS : `null`, `[]`, `{}`, JSON tronqué, string vide, string non-JSON, op non-Map, op sans `insert`, nombre brut → doc vide (`toPlainText()=='\n'`), `takeException()` null. `_decodeDefensive` borne tout (`on Object catch`) ; s'appuie légitimement sur le throw de `Document.fromJson` pour un Delta sans `\n` terminal. |
| **Frontière respectée** | **OUI** | Aucune anticipation d'E6-2 (`ZCodec`), E6-3 (LaTeX), E6-4 (tableau) : conversion via l'API native `Document.fromJson` / `toDelta().toJson()` uniquement. `flutter_quill: ^11.5.0` résolu en **11.5.1** (satisfait la contrainte). |

**RTL/thème/a11y (AD-13)** : `fieldPadding` = `EdgeInsetsDirectional` (vérifié dans `z_theme.dart`), `EdgeInsetsDirectional.zero`, `Column(crossAxisAlignment: start)`, `BorderRadius.all(radiusM)` symétrique → RTL-safe. Zéro couleur en dur : `borderColor = zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline`. `Semantics` éditeur + toolbar. `const` sur widgets immuables. Aucun `ListView(children:)`, aucun `setState`, aucun secret.

---

## Findings

### MEDIUM

**MED-1 — `_onQuillChanged` sérialise tout le document à CHAQUE notification, y compris les déplacements de curseur (sélection seule).**
`z_markdown_field.dart:149-156`. Le listener est branché sur `_quill.addListener(...)`, qui notifie **aussi** sur `updateSelection` (cf. `flutter_quill` `_updateSelection → notifyListeners`). À chaque frappe **et** à chaque déplacement de caret (flèches, clic, sélection), le listener exécute `_encodeNeutral(_quill.document)` (`document.toDelta().toJson()`) **+** `jsonEncode(...)` — un travail **O(taille du document)**. La garde de dédup (`neutralJson == _lastValueJson`) évite le `setValue` superflu mais **pas** le coût d'encodage.
- *Scénario concret* : document riche de plusieurs Ko ; l'utilisateur navigue au clavier/clic → sérialisation JSON complète répétée à chaque mouvement de curseur, sans aucun changement de contenu. Divergence avec le patron `ZEditionField` qui ne lit qu'une `String` bon marché. Contre l'esprit « zéro jank » de SM-1 sur gros contenu.
- *Remède* : écouter le flux de **mutations de document** plutôt que le controller entier — p. ex. `_quill.document.changes.listen(...)` (n'émet que sur changement de contenu, pas de sélection), ou comparer une version/longueur de document avant de sérialiser. Conserver la garde `_applyingExternal`.
- *Sévérité* : MEDIUM (efficacité/scalabilité ; pas de bug de correction).

### LOW

**LOW-1 — Le test anti-fuite (AC3) ne peut pas détecter un `removeListener` oublié (proxy).**
`z_markdown_field_lifecycle_test.dart:69-73`. Après démontage, `controller.setValue('notes', …)` mute la **tranche du form**, jamais `_quill` ; le listener du widget est sur `_quill` (déjà disposé). Donc « aucun throw » serait vrai **même si** `removeListener` était omis (disposer un `ChangeNotifier` avec listener attaché ne lève pas). Le code est correct, mais l'assurance du test est illusoire.
- *Remède* : prouver directement le retrait — p. ex. exposer un compteur d'invocations de `_onQuillChanged`, muter le `QuillController` capturé après démontage et vérifier que le compteur n'incrémente pas ; ou vérifier `hasListeners==false` sur le controller avant `dispose`.

**LOW-2 — Cible de tap ≥48 dp de la toolbar prouvée seulement par la hauteur du conteneur.**
`z_markdown_field_lifecycle_test.dart:140-141`. `getSize(QuillSimpleToolbar).height >= 48` mesure le **conteneur**, pas la surface interactive de chaque bouton. `toolbarSize: 48` dimensionne les boutons, mais l'AC6 (« cibles interactives ≥ 48 dp ») n'est validée que par proxy.
- *Remède* : asserter la taille d'un `QuillToolbar*Button` réel, ou au moins documenter que `toolbarSize` gouverne la cible.

**LOW-3 — Double couche sémantique potentielle sur l'éditeur.**
`z_markdown_field.dart:194-196`. `Semantics(textField: true, label: …)` enveloppe `QuillEditor`, qui expose déjà ses propres nœuds sémantiques d'édition. Risque de nœuds sémantiques redondants/concurrents pour les lecteurs d'écran. À vérifier sur un vrai TalkBack/VoiceOver ; sinon envisager `Semantics(container: true)` ou fusion.

---

## Points explicitement vérifiés et **écartés** (pas de finding)

- **Sélection hors-borne après reseed externe** : le setter `QuillController.document` (v11.5.1, l.81-91) **réinitialise** `_selection` à `(0,0)` → pas de `RangeError` même si le nouveau document est plus court. Écarté.
- **Contrainte de version** : `^11.5.0` résolu en `11.5.1` dans `pubspec.lock` (le `11.4.2` en cache est un résidu d'un autre projet). Écarté.
- **Sens unique / boucle de ré-injection** : `_applyingExternal` neutralise la notification déclenchée par `_quill.document = …` ; la dédup `_lastValueJson` rend `_syncFromExternal` idempotent pendant la frappe locale. Écarté.
- **Perte de contenu sur corruption partielle** : `_asDeltaOps` renvoie `null` si **une** op est malformée → document vide. Conforme à AC4/AD-10 (« document VIDE, jamais de throw »). Écarté (par conception).
- **`_settle` masquant une instabilité** : les timers drainés (`Timer.run(0)` toolbar, `Timer.periodic` curseur) appartiennent à `flutter_quill` et sont annulés au démontage ; `_settle` ne masque aucun timer possédé par `ZMarkdownField`. Écarté.
- **`Localizations.override`** : fusionne les délégués Quill avec ceux hérités (Material/Widgets restent disponibles) ; rendu sans exception en test. Écarté.

---

## Synthèse

Implémentation **solide**, fidèle au patron canonique `ZEditionField` (AD-2). SM-1, isolation et défensif sont **réellement prouvés** (pas des proxies creux). Aucun finding **HIGH/MAJEUR**. Un **MEDIUM** (sérialisation complète sur déplacement de curseur — efficacité sur gros documents) recommandé pour correction dans le périmètre de la story ; trois **LOW** (renforcement de tests anti-fuite/cible ≥48 dp, double sémantique) optionnels.

**Recommandation** : corriger **MED-1** (dans le périmètre, sans régression : basculer le listener sur `document.changes`), consigner LOW-1/2/3, puis passer à `done`.

---

## Remédiation (orchestrateur, 2026-07-10)

| # | Sév | Statut | Détail |
|---|-----|--------|--------|
| 1 | MEDIUM | ✅ **corrigé** | Listener basculé de `_quill.addListener` vers `_quill.document.changes.listen(...)` (mutations de CONTENU seulement, plus sur sélection). `StreamSubscription` annulé au dispose + **ré-abonné après reseed** (`_quill.document = incoming` swappe l'instance Document, sinon frappes post-reseed muettes — vérifié dans flutter_quill 11.5.1). Nouveau test : 20 déplacements de curseur + 1 sélection étendue → `debugDocChangeCount` et nb `setValue` inchangés. |
| 2 | LOW-1 | ✅ corrigé | `ZMarkdownFieldDebug` (`@visibleForTesting`) expose `debugDocSubscriptionActive` → test prouve DIRECTEMENT `== false` après dispose (un cancel oublié échouerait). |
| 3 | LOW-2 | ✅ corrigé | Test assère la taille d'un `IconButton` réel de la toolbar ≥ 48 dp (plus seulement le conteneur). |
| 4 | LOW-3 | ✅ documenté | `Semantics(textField:label:)` intentionnel (étiquette+rôle, nœuds d'édition Quill préservés) ; QA a11y TalkBack/VoiceOver = intégration. |

**Vérif verte rejouée (orchestrateur, ciblée)** : `flutter analyze` zcrud_markdown **0 issue** · `flutter test` **29/29** (dont test sélection-seule MED-1 + anti-fuite direct LOW-1) · graphe **CORE OUT=0**. SM-1 reste prouvé (test AC2 inchangé vert).

**Verdict final** : 1 MEDIUM + 3 LOW traités. Story E6-1 → **done**.
