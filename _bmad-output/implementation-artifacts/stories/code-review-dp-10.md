# Code Review — DP-10 : dates (bornes min/max + mode `dateTime` combiné, B12+B13)

- **Story** : `_bmad-output/implementation-artifacts/stories/dp-10-dates-bornes-datetime.md` (10 ACs)
- **Périmètre** : `zcrud_core` uniquement
- **Mode skill** : `bmad-code-review` (skill réel invoqué ; resolver customization OK)
- **Date** : 2026-07-11
- **Reviewer** : agent BMAD code-review (revue adversariale ciblée)

## Verdict : **APPROVED**

Aucun finding HIGH / MAJEUR / MEDIUM. 3 LOW/nits (non bloquants). Les 10 ACs sont satisfaits et couverts par tests, les invariants AD-1/AD-2/AD-3/AD-10/AD-13/AD-14 sont respectés, les vérifs vertes rejouées réellement sur disque sont toutes RC=0.

---

## Vérifications rejouées (RC réels sur disque)

| Vérif | Commande | RC |
|-------|----------|----|
| Analyse statique | `dart analyze packages/zcrud_core` | **0** (No issues found!) |
| Tests | `flutter test` (dans `packages/zcrud_core`) | **0** (All tests passed! **+664**) |
| Graphe de deps | `python3 scripts/dev/graph_proof.py` | **0** (ACYCLIQUE OK ; CORE OUT=0 OK) |
| Pureté domaine | `dart test test/purity/domain_entrypoint_dart_test.dart` | **0** (All tests passed!) |
| Codegen | `melos run generate` | **sans objet** (aucune annotation `@ZcrudModel`/`@ZcrudField`/`@JsonSerializable` ajoutée ; `ZDateMode`/bornes littérales = pur-Dart non projeté) |

---

## Analyse par axe adversarial

### (1) Enum `ZDateMode` camelCase + `@JsonKey(unknownEnumValue:)` — CONFORME
- `enum ZDateMode { date, dateTime, time }` (`z_field_config.dart:244-253`) — valeurs **camelCase** (canonique §5).
- Enum **pur-Dart, non persisté** : porté par `ZDateConfig.mode` (`const`), jamais sérialisé par le générateur (qui ne projette pas `ZDateConfig` à ce jour). La discipline `@JsonKey(unknownEnumValue:)` **ne s'applique pas** (décision D2, documentée en docstring `:242-243`). Confirmé pur-Dart non projeté. **OK.**

### (2) Résolution mode + bornes (littéral > cross-champ > repli) — CONFORME
- Mode (`_mode`, `z_date_field_widget.dart:62-67`) : `config.mode` s'il est non nul ; sinon `type==time`→`time` ; sinon `dateTime`. Conforme D2.
- Bornes (`_resolveDateBound`, `z_field_widget.dart:463-472`) : `DateTime.tryParse(iso)` (littéral) **d'abord**, sinon `controller.valueOf(key)` (cross-champ, `DateTime` accepté tel quel, `String` parsée), sinon `null` → repli `1900/2100` côté widget (`z_date_field_widget.dart:127-128`). Priorité **littéral > cross-champ > repli** exacte (D4). **Fin du hardcode B12 confirmée** : `DateTime(1900)`/`DateTime(2100)` ne sont plus la seule source mais l'ultime repli. **OK.**

### (3) Défensif AD-10 (repli / clamp, jamais de throw) — CONFORME
- ISO littéral invalide (`'pas-une-date'`) → `tryParse`→`null` → repli. Cross-champ non parsable (`'garbage'`) → repli. Aucun throw (`tryParse`/`valueOf` non lançants). Testé (`dp10…:258-290`, `takeException()==null`).
- `first.isAfter(last)` → `first = last` (`z_date_field_widget.dart:131`).
- `initialDate` clampée dans `[first, last]` (`:134-136`), sur `DateTime` complet — le clamp est un **sur-ensemble** monotone de la garde `dateOnly` interne de `showDatePicker`, donc **jamais d'assertion** `initialDate/firstDate/lastDate`. Testé (`dp10…:292-316`). **OK.**

### (4) `dateTime` combiné B13 — préservation de l'heure — CONFORME
- Annulation étape **date** ⇒ `return` sans `onChanged` (abandon complet, `:146`).
- Mode `date` ⇒ **un seul** dialog, valeur à minuit (`:149-151`), pas de `showTimePicker` (testé `dp10…:207-234`).
- `dateTime` ⇒ date **puis** heure ; `preexistingTime` dérivée de la valeur courante ou minuit (`:156-157`) ; annulation heure ⇒ `effectiveTime = pickedTime ?? preexistingTime` (heure préexistante **jamais** écrasée à minuit, `:163`), fusion en un seul `DateTime` (`:164-170`). Testé (nouvelle date + heure conservée → ISO combiné ; annulation heure → 14:30 préservé, `dp10…:152-203`). **OK.**

### (5) SM-1 / AD-2 — seam cross-champ — CONFORME
- `ZDateFieldWidget` = `StatelessWidget` pur, **sans** `ZFormController`, **sans** `TextEditingController` (`:32`, testé `:319-333`).
- Lecture cross-champ (`controller.valueOf`) confinée au **dispatcher** `z_field_widget.dart` (`:467`), injectée via fermetures `ValueGetter<DateTime?>?` évaluées **au tap** (`_pick`) — aucun abonnement réactif, aucun rebuild global. Conforme D3. **OK.**

### (6) Pureté domaine AD-3 / AD-14 — CONFORME
- `z_field_config.dart` : aucun `import 'flutter'`, aucun `DateTime` littéral (bornes = `String?` ISO, D1 const-safe). Les seuls littéraux `DateTime(1900)/DateTime(2100)` + `DateTime.tryParse` vivent en **présentation** (`z_date_field_widget.dart` / `z_field_widget.dart`). `graph_proof` CORE OUT=0 et `domain_entrypoint_dart_test` verts. **OK.**

### (7) Rétro-compat additive stricte — CONFORME
- `ZDateConfig` : nouveaux paramètres **nommés optionnels** (`minDateIso`/`maxDateIso`/`mode`), `firstDateKey`/`lastDateKey` conservés, `const` préservé, `==`/`hashCode` étendus aux 5 champs (`:266-311`). Aucun champ renommé/supprimé.
- Signature `ZDateFieldWidget` : `firstDate`/`lastDate` **optionnels** (défaut `null` → repli). Impact confiné au dispatcher.
- Format de sérialisation (ISO-8601 String) **inchangé**. Barrels additifs (`selectDateTime` en+fr, `z_localizations.dart:48,105`). Suites d'édition existantes vertes (664 tests). **OK.**

### (8) a11y ≥48 dp AD-13 + FR-26 — CONFORME
- `minimumSize: Size.fromHeight(48)` (`:98`), `AlignmentDirectional.centerStart` (`:99,103`), wrapper `Semantics(button, enabled, label, value, excludeSemantics, onTap)` (`:87-93`). Aucune couleur codée en dur (thème hérité). Pickers Material héritent de la `Directionality` ambiante (RTL). **OK.**

---

## Findings

### LOW-1 — Affichage de la valeur en ISO brut (parité/UX vs DODLP)
- **Fichier** : `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart:73,82,104`
- **Description** : le libellé du bouton affiche `value` en **ISO brut** (`Date : 2026-07-11T14:30:00.000`), alors que DODLP formate via `DateFormat.yMMMd().add_Hm()`. Comportement **préexistant** (déjà le cas avant DP-10) et **hors périmètre** de la story (aucun AC ne l'exige). Aucune régression.
- **Remédiation (optionnelle, future story)** : formater l'affichage selon le `_mode` (date / dateTime / time) via `intl`/`MaterialLocalizations` — à traiter dans un lot UX de parité, pas ici.

### LOW-2 — Clamp `first>last` replie sur `last` (et non sur `initialDate` comme DODLP)
- **Fichier** : `packages/zcrud_core/lib/src/presentation/edition/families/z_date_field_widget.dart:131`
- **Description** : quand `first.isAfter(last)` (min-bound déclaré **après** max-bound — pure misconfiguration), l'impl fait `first = last`, épinglant le picker à un seul jour. DODLP (`edition_screen.dart:3600`) replie plutôt la borne basse sur la **date initiale**. Le résultat est **assertion-free** dans les deux cas ; l'AC8 accepte explicitement « repli/clamp ». Divergence de sémantique mineure sur un cas d'erreur de configuration.
- **Remédiation (optionnelle)** : documenter le choix (déjà partiellement en commentaire) ou aligner sur `first = initialDate` si la parité exacte est souhaitée. Non bloquant.

### LOW-3 — Test SM-1/AD-2 au minimum (pas de compteur de rebuild voisin)
- **Fichier** : `packages/zcrud_core/test/presentation/edition/dp10_date_bounds_datetime_test.dart:319-334`
- **Description** : le test AD-2 asserte `isA<StatelessWidget>()` + absence d'`EditableText`, ce qui est le **minimum autorisé** par les Testing Requirements. Un compteur de builds sur un champ voisin (pattern SM-1) prouverait plus fortement l'absence de rebuild global lors de la sélection.
- **Remédiation (optionnelle)** : ajouter un test « voisin non reconstruit après sélection date » réutilisant le pattern des tests SM-1 existants. Non bloquant (le seam D3 garantit déjà l'invariant par construction).

---

## Points de contact « cœur partagé » (signalés, non bloquants)
- `ZDateConfig` (`z_field_config.dart`) : surface de config partagée — modification **strictement additive** (nommés optionnels), aucun modèle/annotation existant cassé.
- `z_field_widget.dart` : seule modification = `case EditionFamily.date` + helper privé `_resolveDateBound`. Point de contact `zcrud_core` unique de la story ; sérialiser si une autre story en vol y écrit.
- `z_localizations.dart` : ajout de clé additif (deux maps), aucune suppression.

---

## Conclusion
Story **DP-10** : implémentation correcte, défensive, conforme AD-1/2/3/10/13/14 et aux 10 ACs. **Aucun finding bloquant**, 3 LOW optionnels. Vérifs vertes réelles (analyze RC=0, 664 tests RC=0, graph RC=0, purity RC=0). **APPROVED** — prête pour transition `review → done` (édition sprint-status par l'orchestrateur).
