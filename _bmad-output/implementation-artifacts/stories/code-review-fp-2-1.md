# Code-review — fp-2-1 (natifs : correction a11y double-annonce dans 5 familles)

**Dispositif** : Workflow code-review MINIMAL (1 lentille adversariale a11y + phase R3), proportionné à une story mécanique triviale (retrait du `label:` de `Semantics(container:true)`, patron déjà revu en fp-4-4/fp-5-1). Rapports : `$CLAUDE_JOB_DIR/tmp/cr-fp-2-1/`.

**Verdict** : **CLEAN — 0 finding.**

## Falsifiabilité vérifiée (R3, réverts par ré-édition inverse)
- **Injection A** — ré-ajout de `label: resolvedLabel` sur le `Semantics(container:true)` des 5 familles (color/rating/tags/rowChips/app_file) ⇒ les 5 tests `count==1` ROUGISSENT (`Expected <1> / Actual <2>`). La double annonce est détectée par famille — tests **porteurs, non tautologiques**.
- **Injection B** — retrait du `Text(resolvedLabel)` visible (spot-check tags+rating) ⇒ ROUGE (`Expected <1> / Actual <0>`). La perte du nom accessible EST détectée : le nom vient bien du `Text` (le conteneur n'a plus de `label:`), **aucune régression a11y**.

## Conformité
- Les 5 corrections retirent la double annonce SANS perdre le nom accessible. `rating` conserve `value:'$current/$max'` ; `app_file` : le 2ᵉ `Semantics` (altLabel + liveRegion) reste INTACT.
- **Aucun changement hors des 5 familles**, aucune API/enum touchée, aucune famille déjà-conforme modifiée (pas de polish gratuit — périmètre honnêtement mince, la plupart des natifs étant déjà à parité DODLP). SM-1 intact.

## Vérif verte (rejouée par l'orchestrateur)
`flutter test packages/zcrud_core` = **1018 passed, RC=0** ; enum/domaine non touché ; `graph_proof` ACYCLIQUE + CORE OUT=0. Gate repo-wide (`melos analyze` SUCCESS, `melos verify` OK) vert avant `done`.

**Statut** : `done` (aucune correction requise).
