# Code Review adversariale — Story ES-2.6 (`ZExam` / `ZReminderTime`)

- **Skill** : `bmad-code-review` invoqué via le tool `Skill` (SUCCÈS — **pas** de fallback disque).
- **Date** : 2026-07-15
- **Périmètre du diff** : `packages/zcrud_exam/**` (nouveau, untracked), `pubspec.yaml` racine (membre workspace), `tool/reserved_keys_gate/{pubspec.yaml, lib/src/registrars.dart}`. Aucun widget, aucun repository, aucun `.g.dart` d'un autre package touché. Conforme au périmètre annoncé (T1–T6).
- **Motif dominant traqué** : « un artefact déclaré valide sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT observé ». → Tous les filets ont été rejoués par un ROUGE PROVOQUÉ (voir §Injections).

## Verdict : ✅ APPROVED / GO

Story robuste. **0 HIGH, 0 MAJEUR, 0 MEDIUM.** 2 LOW informationnels (aucune action bloquante). Toutes les gardes ont un pouvoir discriminant OBSERVÉ (rougissent sur injection réelle, restaurées par édition ciblée). Baseline verte confirmée : `zcrud_exam` 41 tests VM / 39 node (2 `@TestOn('vm')` exclus), `gate:reserved-keys` OK.

---

## Injections adversariales rejouées (RC réel, restauration par ÉDITION CIBLÉE — jamais `git checkout`)

| # | Injection | Cible | Résultat OBSERVÉ | RC |
|---|-----------|-------|------------------|----|
| A | `final _r3probe = DateTime.now();` dans `daysUntil` | `no_datetime_now_test.dart` (filet anti-`DateTime.now()`) | **ROUGE** — `scan tokenisé de tout lib/` échoue, `Actual: [z_exam.dart]` | fail (-1) |
| B | `daysUntil` renvoie `return 0;` (ignore `now`) | `z_exam_clock_test.dart` (balayage {J-7,J-1,J0,J+1}) | **ROUGE** — 4 échecs : `daysUntil={7,1,0,-1}`, `isPast`, `isApproaching`, calendaire | fail (-4) |
| C | `kReminderTimeKey` retiré de `_reservedKeys` | `gate_reserved_keys.dart` règle (g1)/volet (A) | **ROUGE** — `exam : sonde polluée → decode/encode` + double émission | fail |
| D | `registerZExam` retiré de `kRegistrars` | `gate_reserved_keys.dart` (R_disk\R_wired) | **ROUGE** — `ZUnregisteredTypeError kind "exam"`, `Actual: Set:['exam']` | fail |
| E | ligne `map[kReminderTimeKey]=…` retirée de `toMap()` | `z_exam_test.dart` AC5 R3 | **ROUGE** — `R3 — reminderTime non-null ⇒ toMap réémet reminder_time` | fail (-3) |

Après restauration : `grep -rn R3-INJECTION packages/zcrud_exam tool/reserved_keys_gate` = **VIDE** (aucun résidu) ; `git diff --stat` = uniquement `registrars.dart +202` (la vraie modif de story, inchangée). Re-vérif verte post-restauration : 41 VM / 39 node / gate OK.

Ces 5 injections recouvrent et confirment les 5 rapportées par le dev (registrar, reserved-key, voie ctor via gate, `hide`, `DateTime.now()`), plus la couverture directe des ACs.

---

## Vérification adversariale de l'HORLOGE (cœur de la FR)

- **Le filet anti-`DateTime.now()` est-il discriminant ?** **OUI (OBSERVÉ)** — injection A rougit. Le test porte AUSSI sa propre fixture R2 (`_dateTimeNow.hasMatch('DateTime.now();')==true` ET ne mord pas sur `DateTime.utc(...)`/`tryParse`/`is DateTime?`) : jamais POWERLESS (leçon DW-ES25-1 respectée).
- **Portée exacte du filet (LU + pas surpromis)** : regex `\bDateTime\s*\.\s*now\s*\(` + `\bDateTime\s*\(\s*\)`. Attrape `DateTime.now()` et `DateTime()` argless (espaces tolérés). **Ne prétend PAS** attraper un tearoff `var f = DateTime.now; f();` (pas de `(` après `.now`) ni un hypothétique `clock.now()` (aucun package `clock` au repo). Le fichier documente explicitement viser « une invocation `DateTime.now(` » — scope HONNÊTE, non surpromis. Le `.g.dart` est inclus au scan (ne contient que `_$asDateTime`/`tryParse`/`is DateTime`) — aucune exclusion nécessaire. → LOW-1.
- **Pouvoir discriminant de l'horloge** : injection B (constante) rougit. Le balayage FAIT VARIER `now` sur 4 valeurs et asserte 4 sorties DISTINCTES (`hasLength(4)`) — un `DateTime.now()` caché ne pourrait pas produire ces 4 sorties. Anti-golden-fortuit satisfait.
- **Off-by-one sur `daysUntil` ?** **NON.** `target = DateTime.utc(d.y,d.m,d.d)` et `today = DateTime.utc(now.y,now.m,now.d)` : deux minuits UTC ⇒ `difference().inDays` est un nombre ENTIER exact, aucune dérive DST (UTC sans heure d'été), aucune troncature partielle. Vérifié par le test « jours CALENDAIRES » (`now` à 00:01 vs 23:59 le même jour ⇒ même sortie) et J-8⇒8. Les champs calendaires sont extraits indépendamment de `date` et de `now` ⇒ sémantique « jours calendaires tels qu'écrits », documentée. Aucune faille limite trouvée.

## Canal hors-codegen `reminder_time`

- **Statut : CONFORME (MESURÉ).** Règle (g1) : retirer `reminder_time` de `_reservedKeys` ⇒ gate ROUGE (injection C). Le `.g.dart` (`_$ZExamFromMap`) ne décode PAS `reminder_time` (canal manuel via `ZReminderTime.parse(map[kReminderTimeKey])`). `toMap()` réémet toujours `reminder_time` si non-null (idempotent, omis si null — testé) et étale `...extra` via l'ACCESSEUR normalisant. La sonde `kProbeBodies['exam']` porte `reminder_time: '08:30'` **NON VIDE** (règle (g2)) ⇒ pas de « préservé par prose ». Clé déclarée une seule fois (`kReminderTimeKey`), consommée par `fromMap`/`toMap`/`_reservedKeys` : zéro littéral dupliqué.

---

## Findings

### LOW-1 — Filet anti-`DateTime.now()` : scope tokenisé, tearoff non couvert (documenté)
`packages/zcrud_exam/test/no_datetime_now_test.dart:37,41` — le scan par regex n'attrape pas un tearoff `var f = DateTime.now; f();` (nécessiterait `(` après `.now`). **Non bloquant** : (a) le fichier documente explicitement sa portée (« une invocation `DateTime.now(` »), sans surpromettre ; (b) la story AC10 autorise explicitement « un scan tokenisé documenté à défaut de `package:analyzer` » (que le package ne dépend pas, AC11) ; (c) le filet a un pouvoir discriminant OBSERVÉ sur la forme réelle qu'un dev écrirait. Amélioration future possible (analyzer) si `zcrud_exam` acquiert un jour cette dép — non requis ici.

### LOW-2 — `toMap()` émet toujours les clés de schéma nullables (comportement hérité du codegen)
`packages/zcrud_exam/lib/src/domain/z_exam.g.dart:190-197` — le `toMap()` généré émet `'id': null`, `'date': null` etc. même absents de la map source, donc `fromMap(m).toMap()` ajoute des clés non présentes dans `m`. **Non-défaut** : comportement UNIFORME de toutes les entités du repo (`ZSmartNote`, `ZDocumentAnnotation`…), l'idempotence réelle (`toMap∘fromMap` stable, re-décodage `==`) est prouvée par les tests AC5. AC5 (« mêmes clés/valeurs ») est vérifié sur les clés significatives, pas sur l'égalité exacte du set — conforme au patron établi. Aucune action.

---

## Contrôles AD / anti-vacuité — tous VERTS (LU + OBSERVÉ)

- **AD-19 / AD-16** : `ZExam` ne déclare NI `updatedAt` NI `isDeleted` inline. `_reservedKeys ⊇ ZSyncMeta.reservedKeys` (`{updated_at,is_deleted}`). `date`/`createdAt`(absent) sous clé MÉTIER `date` distincte. `$ZExamFieldSpecs` (id, folder_id, title, date, reminder_enabled, reminder_days_before) ∩ `ZSyncMeta.reservedKeys` = ∅. Clés de sync écrites dans le corps → ni dans `extra` ni réémises par `toMap` (tests AC6). `kLegacyUpdatedAtMirrors` NON touché (correct : aucun miroir). ✅
- **AD-10 défensif** : `fromMap(const {})` sûr ; `date` non-parsable → null ; `reminder_time` invalide → null ; `ZReminderTime.parse` totale (`'25:00'`,`'08:60'`,`''`,`null`,`-1:30`→null, `returnsNormally`) ; AUCUN `assert` dans les ctors `const` de `ZExam` et `ZReminderTime` (vérifié LU). ✅
- **AC7 anti-vacuité / AC8 pollution ctor** : clé inconnue imbriquée survit `fromMap`+`toMap` (verbatim) ; `ZExam(extra:{'updated_at':…}).extra` VIDE de réservées (voie ctor const, la polluante) ; égalité PROFONDE `zJsonEquals`/`zJsonHash` (injection dev remplaçant par `==` rougit) ; `_sanitizeExtra` = MÊME fonction nommée sur `fromMap` ET `copyWith`. ✅
- **`ZReminderTime`** : VO pur (`class`, non `@ZcrudModel`, non `ZExtensible`), `import 'package:zcrud_core/domain.dart'` uniquement (aucun Flutter/`TimeOfDay`), réutilise `ZTimeCodec.hhmmToMap` (pas de duplication). Round-trip `parse(t.toHhmm())==t` (boucle 24×). Politique de bornes : hors-plage à la construction directe PRÉSERVÉ (`'99:00'`), rejeté seulement à `parse` — cohérent avec la story (garde à la frontière). Non enregistré ⇒ aucun câblage gate. ✅
- **Graphe / NFR-S10** : deps `zcrud_exam` = `{zcrud_core, zcrud_annotations}` (+ generator/build_runner/test en dev). **ZÉRO** package lib entrant (seul lui-même se référence ; `tool/reserved_keys_gate` est un harnais, pas une arête de graphe). ZÉRO Flutter/dart:ui. Membre workspace ajouté au `pubspec.yaml` RACINE (pas de melos.yaml). `hide ZExamZcrud` au barrel (règle (h)). ✅
- **DW-ES24-1** : `reminderDaysBefore` (List) — la dartdoc NE promet PAS l'immuabilité profonde au ctor `const` (mention explicite). ✅
- **DW-ES25-1** : aucun test de « non-export d'extension générée » via import interne (powerless) n'est présent — le `hide ZExamZcrud` tient l'invariant, prouvé par le gate (règle (h)), non par un test menteur. ✅

## Recommandation
Corriger les MEDIUM : **aucun**. Les 2 LOW sont informationnels et peuvent rester consignés sans action. **Passer la story à `done`** après la vérif verte repo-wide de l'orchestrateur (déjà rejouée : analyze RC=0, verify, prove_gates 41/0, graph acyclique CORE OUT=0, gate:web).
