# Code Review — E11b-2 : `zcrud_intl` complet (devise + états/provinces + `ZIntlFieldConfig`)

- **Story** : `_bmad-output/implementation-artifacts/stories/e11b-2-zcrud-intl-complet.md`
- **Baseline** : `04aaaf0` (HEAD)
- **Périmètre** : `packages/zcrud_intl/` uniquement (11 fichiers lib créés, 6 modifiés, 1 support + 6 tests créés, 1 test modifié)
- **Mode d'exécution** : skill BMAD `bmad-code-review` invoqué via le tool `Skill` (workflow step-file résolu ; customization `resolve_customization.py` OK). Revue adversariale conduite par l'agent (sous-agents parallèles non disponibles en contexte subagent → couches Blind/Edge/Auditor jouées en revue directe, comme prévu par le fallback du step-02).
- **Date** : 2026-07-10

## Verdict

**PRÊT POUR `done`.** Aucun finding **HIGH/MAJEUR** ni **MEDIUM bloquant**. Le code est défensif, isolé, rétro-compatible E11a-2, a11y opérable et sans secret. Les findings ci-dessous sont **LOW/nits** optionnels (consignés, non bloquants).

## Vérif verte rejouée (réelle, sur disque)

| Gate | Commande | Résultat |
|------|----------|----------|
| pub get | `dart pub get` (cwd package) | RC=0 |
| analyze | `dart analyze .` (cwd package) | **No issues found!** RC=0 |
| test | `flutter test` (cwd package) | **129 tests passés** RC=0 (59 baseline E11a-2 + 70 E11b-2) |
| graphe | `python3 scripts/dev/graph_proof.py` | `zcrud_intl -> zcrud_core` ; **CORE OUT=0** ; **ACYCLIQUE OK** |

## Confirmations d'invariants

- **Isolation (AD-1)** : `graph_proof` CORE OUT=0 acyclique ; gate `isolation_gates_test.dart` vert : `phone_numbers_parser` **confiné à 1 importateur** (`z_phone_codec.dart`), **0 nouvelle lib intl/devise** (`intl`/`money2`/`currency_picker`… bannies et absentes de `pubspec.yaml`), barrel `zcrud_intl.dart` sans symbole tiers (ni pont phone, ni pickers internes exportés), `zcrud_core/pubspec.yaml` sans lib intl. Devise/états = **assets JSON bundlés** (`currencies.json` 61 entrées, `subdivisions.json` 7 pays / 79 subdivisions).
- **Zéro secret (AD-12)** : gate secrets vert (aucune clé `AIza…`, aucun `badCertificateCallback`, aucun endpoint `http(s)://` dans `lib/`). Hors-ligne, sans réseau.
- **Rétro-compat E11a-2 STRICTE** : les 59 tests E11a-2 restent verts (inclus dans les 129) ; aucun export retiré/renommé du barrel ; lecture `ctx.field.config is ZIntlFieldConfig` avec `config == null` → chemin E11a-2 identique dans phone/country/address ; `preferredIsos`/`searchable` par défaut `[]`/`true` = identité.
- **A11y opérable (AD-13/AI-E10-1)** : `ZOptionPickerField` porte `SemanticsAction.tap` sur le nœud englobant (trigger **et** items) via `Semantics(onTap:) > ExcludeSemantics`, cibles ≥48 dp (`ConstrainedBox(minHeight:48)`) ; helpers `assertSemanticActionTap`/`assertMinTapTarget` créés et appliqués.
- **SM-1/AD-2** : contrôleurs/focus `late final` créés 1× en `initState`, disposés, sync guardée hors focus (`_hasAmountFocus`/`_hasFreeFocus`/`_hasNumberFocus`) ; rebuilds locaux (`setState` de picker), chargement catalogue paresseux → rebuild local `if (mounted)`. Par-montage (chaque widget crée ses propres contrôleurs).
- **Défensif (AD-10)** : `fromMapSafe` neutre partout (`ZMoney`/`ZCurrencyInfo`/`ZSubdivision`), amount non fini rejeté, catalogues → vide sur asset absent/JSON malformé/bucket non-liste ; dé-dup `_loading` (MEDIUM-1) présente dans les 2 nouveaux catalogues.

## Findings

### LOW-1 — Sélection de subdivision dans l'adresse : pas de `setState` local (repose sur l'écho réactif)
- **Fichier** : `packages/zcrud_intl/lib/src/presentation/z_address_field_widget.dart:203` (`_onSubdivisionSelected`)
- **Constat** : `_onSubdivisionSelected` fait `_region.text = s.code; _emit();` **sans** `setState` local, contrairement à `_onCountrySelected` (l. 196) qui fait `setState(...) + _emit()` (ceinture+bretelles). Le libellé du trigger d'état (`selectedTitle` recalculé dans `_regionSlot` depuis `_region.text`) ne se rafraîchit donc **que** via l'écho `onChanged → dispatch DynamicEdition → rebuild` du champ.
- **Impact** : nul dans l'intégration réelle (DynamicEdition rebuild la tranche après `onChanged`, ce que les tests AC6/AC8 confirment). Théoriquement, un usage **hors dispatch réactif** (ctx.onChanged = callback inerte, montage direct) laisserait le trigger afficher l'ancienne valeur jusqu'au prochain rebuild.
- **Reco** : par cohérence avec le chemin pays, ajouter `setState(() {})` dans `_onSubdivisionSelected` (robustesse hors-dispatch, coût nul). Optionnel.

### LOW-2 — `currencies.json` : 61 entrées vs « ~180 » annoncées dans la Conception
- **Fichier** : `packages/zcrud_intl/lib/assets/currencies.json`
- **Constat** : la section *Conception* de la story écrit « liste ISO 4217, **~180 entrées** » ; l'asset livré en contient **61** (majeures : XOF/XAF/EUR/USD/GBP/… couvrant les besoins prioritaires DODLP/lex_douane).
- **Impact** : tolérable. AC3 n'impose **aucun** compte ; le catalogue est **injectable/extensible** (`fromList`) et un code ISO 4217 valide absent dégrade **gracieusement** (`byCode → null`, le trigger affiche le code brut via `_triggerText`, jamais de crash). Écart par rapport à la note de conception, pas par rapport à un AC.
- **Reco** : soit compléter l'asset vers la couverture ISO 4217 active (~180), soit aligner la note de conception sur le choix « sous-ensemble curaté » (comme pour les subdivisions) et le justifier. Non bloquant.

### LOW-3 (nit) — `_ordered` : `preferredIsos` en double dupliquerait la tête
- **Fichier** : `packages/zcrud_intl/lib/src/presentation/z_country_picker_field.dart:216` (`_ordered`)
- **Constat** : la boucle `for (final iso in prefs)` ajoute la première correspondance sans dé-dup ; `preferredIsos: ['US','US']` remonterait `US` deux fois en tête (le `tail` filtre par `up` set, donc pas de doublon tête/queue, mais un doublon **intra-tête**).
- **Impact** : cosmétique, entrée de config aberrante uniquement.
- **Reco** : dé-dup `prefs` (ou skip si déjà présent dans `head`). Optionnel.

### LOW-4 (nit) — `ZMoney._asNum` : séparateur décimal locale non géré
- **Fichier** : `packages/zcrud_intl/lib/src/domain/z_money.dart:77` (`_asNum`)
- **Constat** : `num.tryParse` sur une chaîne `"5,5"` (virgule) → `null`.
- **Impact** : nul — par conception, la persistance est canonique (`amount` numérique) ; le formatage locale-aware est explicitement HORS périmètre (AD-1). Documenté.
- **Reco** : aucune action requise ; consigné pour mémoire.

## Qualité des tests (70 nouveaux)

Couverture solide et alignée sur les ACs : round-trip + tables défensives des 3 modèles + `ZIntlFieldConfig` (`==`/`hashCode`) ; catalogues (paresse, cache, **charges concurrentes → 1 seul parse**, `fromList`/`fromMap` injectés, asset absent/malformé → vide) ; widgets devise/état (registre, tranche neutre, dépendance pays, changement de pays, repli texte libre, SM-1 `onInit==1`, dispose par-montage, RTL, a11y opérable via helpers) ; wiring config (défaut par-champ, rétro-compat `null`). Rien de manquant identifié.

---

## Résolution (orchestrateur)

Vérif verte (intl, depuis le package pour les assets) : `dart analyze .` RC=0, `flutter test` **129 tests** RC=0, `graph_proof` CORE OUT=0 / ACYCLIQUE.

- **0 HIGH / 0 MAJEUR / 0 MEDIUM.**
- **LOW-1/2/3/4 — CONSIGNÉS** (optionnels, nul impact fonctionnel, tests verts) : LOW-1 `setState` local absent sur sélection de subdivision (l'écho `onChanged→dispatch` suffit — cohérence pure) ; LOW-2 `currencies.json` = **sous-ensemble curaté** de 61 devises ISO 4217 (catalogue injectable, code inconnu dégrade en code brut sans crash — la note de conception vaut « sous-ensemble curaté », complétable sans changement d'API) ; LOW-3/LOW-4 nits (dédup `preferredIsos`, séparateur décimal locale hors périmètre persistance canonique).
- Isolation confirmée (phone_numbers_parser confiné, 0 nouvelle lib, CORE OUT=0), zéro secret, rétro-compat E11a-2 stricte (59 tests inchangés), a11y opérable (SemanticsAction.tap + ≥48dp via helpers AI-E10-1).

**Verdict final : `done`.** 0 HIGH / 0 MAJEUR / 0 MEDIUM ouvert.
