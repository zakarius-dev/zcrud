# Code-review — fp-2-2 (binding zcrud_get : composeur `registerZcrudFormFields`)

**Dispositif** : Workflow multi-lentilles (4 lentilles : association/dispatcher, exclusivité html/markdown, graphe/AD-1, réalité) + phase R3. Rapports : `$CLAUDE_JOB_DIR/tmp/cr-fp-2-2/`.

**Verdict** : **CLEAN — 0 finding** (0 HIGH / 0 MAJEUR / 0 MEDIUM / 0 LOW).

## Falsifiabilité vérifiée (R3, injections réédités-inverse)
- **Association via le VRAI dispatcher — PORTEUR** : retirer `registry.register('location', …)` fait ROUGIR `location → ZGeoFieldWidget` (le dispatcher retombe sur `ZUnsupportedFieldWidget`) + le test AD-4 `isRegistered('location')`. L'oracle traverse le vrai `tryBuilderFor(field.type.name)` — présence ≠ association réellement prouvée (pas de `reg.builderFor` direct, leçon fp-4-2 évitée).
- **Exclusivité html/markdown — PORTEUR** : un `try/catch` avalant le throw dans la boucle `additionalRegistrars` fait ROUGIR « double câblage html → `ZDuplicateRegistrationError` ». Le test de double-composition reste vert à raison (collision sur registres par défaut, hors boucle opt-in).

Aucun test tautologique, aucun bug de production sur les facettes sondées.

## Conformité
- **AD-55** : composeur unique appelant les registrars ; seam `additionalRegistrars` opt-in (aucun satellite n'édite de fichier partagé — anti-pattern point de contact évité).
- **AD-1** : arêtes `zcrud_get → zcrud_markdown/zcrud_intl/zcrud_geo` (sortantes) ; `graph_proof` ACYCLIQUE + CORE OUT=0 ; aucun satellite ne dépend du binding ; `zcrud_core` intouché.
- **AD-4** : registre INJECTÉ (paramètre), jamais statique — testé.
- **AD-50** : exclusivité html/markdown (markdown défaut, html opt-in).

## Vérif verte (rejouée par l'orchestrateur)
`flutter test packages/zcrud_get` = **74 passed, RC=0** ; composeur présent + 3 arêtes pubspec ; graph ACYCLIQUE + CORE OUT=0.

**Statut** : `done` (aucune correction requise).
