# Code Review — Story E1-1 : Workspace melos + resolution workspace

- **Skill invoqué** : `bmad-code-review` (tool `Skill`, chargé — architecture step-file, steps 01→04 suivis pour la méthodologie de triage).
- **Chemin pris** : Skill réel (pas de fallback disque).
- **Story sous revue** : `_bmad-output/implementation-artifacts/stories/e1-1-workspace-melos-resolution-workspace.md` (9 ACs).
- **Statut courant** : `review`.
- **Baseline diff** : `baseline_commit: 8f2875559aee498774eca8590744e816f8a5c93f` (fichiers non suivis créés par dev-story E1-1).
- **Mode de revue** : `full` (spec fournie → couche Acceptance Auditor active).
- **Grounding** : `architecture.md` (AD-1 acyclique/14 packages, AD-12 zéro secret, AD-15 pas de manager d'état dans `zcrud_core`, Stack SDK `^3.12.2` / melos `^7.0.0`) + `CLAUDE.md` (Key Don'ts, conventions).
- **Date** : 2026-07-09.

## Périmètre revu

Root `pubspec.yaml`, `melos.yaml`, `.gitignore`, `pubspec.lock`, et pour les 14 packages `packages/<pkg>/pubspec.yaml` + `packages/<pkg>/lib/<pkg>.dart`.

## Vérification verte rejouée réellement (sur disque, par le reviewer)

| Contrôle | Résultat |
| --- | --- |
| `dart --version` | `3.12.2 (stable)` → satisfait `^3.12.2` (≥3.12.2, <4.0.0) |
| Membres `workspace:` dans root pubspec | **14** |
| `resolution: workspace` sur les membres | **14/14** |
| `sdk: ^3.12.2` sur les membres | **14/14** |
| Barrels `packages/*/lib/*.dart` | **14** |
| `dart pub get --dry-run` | `No dependencies would change.` — **RC=0** |
| `melos list` | **14** noms = liste canonique exacte, sans doublon/manquant — RC=0 |
| `melos run analyze` | 14 packages `No issues found!` — **RC=0** |
| `pubspec.lock` racine | présent (unique) |
| `find packages -name pubspec.lock` | **aucun** (0 lockfile par-package) |
| `.gitignore` codegen | `*.g.dart` + `*.freezed.dart` présents |

**Note** : `dart pub get --dry-run` signale `melos 8.2.0 available` (contrainte `^7.0.0`, résolu 7.8.2) — informatif, non bloquant, la contrainte `^7.0.0` est respectée.

## Audit d'acceptation (9 ACs)

Les 9 ACs sont **satisfaits et re-vérifiés sur disque**. Aucune violation d'AC. AD-1/AD-15 respectés (`zcrud_core` sans bloc `dependencies:` — zéro dépendance lourde ni gestionnaire d'état). AD-12 respecté (aucun secret). Pas d'empiètement sur E1-2 : les barrels sont des placeholders vides (aucun `export`, aucune API), aucune dépendance inter-packages déclarée.

---

## Findings (triage par sévérité)

### HIGH / MAJEUR

_Aucun._

### MEDIUM

**M-1 — Double source de vérité pour la config des scripts melos (risque de désynchronisation).**
- **Fichiers** : `melos.yaml` (l.10-30, bloc `scripts:`) **et** `pubspec.yaml` (l.29-45, bloc `melos: scripts:`).
- **Problème** : le contournement documenté (melos 7.8.2 sous pub workspace lit sa config depuis la clé `melos:` du **root `pubspec.yaml`** ; `melos.yaml` conservé pour AC 3 + lisibilité) crée **deux définitions concurrentes** des scripts `generate`/`analyze`/`test`. Elles sont **actuellement identiques** (vérifié), donc aucun impact fonctionnel aujourd'hui. Mais **c'est `pubspec.yaml` qui fait autorité** : une modification future faite dans `melos.yaml` seul serait **silencieusement ignorée** par melos 7.8.2. Les commentaires d'en-tête expliquent la répartition résolution vs ciblage, mais **n'avertissent pas explicitement** que les *scripts* de `melos.yaml` ne sont pas consommés — un mainteneur peut légitimement éditer le mauvais fichier.
- **Sévérité** : MEDIUM (tolérable en l'état, aléa de maintenabilité réel dès qu'un script évolue en E1-3+).
- **Correctif proposé** (au choix de l'orchestrateur) :
  1. _Trivial, en scope_ : ajouter dans `melos.yaml` un commentaire d'avertissement clair du type « ⚠️ Source de vérité des scripts = root `pubspec.yaml` (clé `melos:`) sous melos 7.8.2 + pub workspace ; garder ce bloc en miroir strict » (et réciproquement) — lève l'ambiguïté sans changer la mécanique.
  2. _Report justifié vers E1-3_ : y ajouter un **garde-fou CI** qui échoue si les deux blocs `scripts:` divergent (ou consolider sur une source unique une fois le comportement melos figé). E1-3 étant la story des gates CI, c'est son domicile naturel.
- **Recommandation** : appliquer (1) maintenant (coût nul, supprime le piège) et consigner (2) pour E1-3. Un report pur doit être justifié par écrit (règle MEDIUM du CLAUDE.md).

### LOW / nit

**L-1 — `.gitignore` : ligne `pubspec.lock` commentée ; AC 9 mentionne « lockfiles de package superflus ».**
- **Fichier** : `.gitignore` (l.15, `# pubspec.lock`).
- **Problème** : aucun ignore de lockfile n'est actif. Le `pubspec.lock` racine est donc **suivi** (comportement souhaitable pour un workspace reproductible), mais les `packages/*/pubspec.lock` ne sont **pas** explicitement ignorés. Sous `resolution: workspace` aucun lock par-package n'est généré → **aucun impact pratique** aujourd'hui. Formulation d'AC 9 non strictement matérialisée.
- **Sévérité** : LOW (cosmétique, aucune conséquence courante).
- **Correctif proposé** : optionnel — ajouter `packages/*/pubspec.lock` (ou `packages/**/pubspec.lock`) au `.gitignore` en filet de sécurité, sans décommenter le `pubspec.lock` global (le lock racine doit rester suivi).

**L-2 — Redondance `version: 0.0.1` + `publish_to: none` sur les 14 membres.**
- **Fichiers** : les 14 `packages/<pkg>/pubspec.yaml`.
- **Problème** : AC 2 autorisait `publish_to: none` **ou** une version SemVer ; les deux sont présents. Inoffensif.
- **Sévérité** : LOW (nit). **Aucune action requise.**

**L-3 — (Informationnel, hors code) commit hygiène du `pubspec.lock`.**
- Le `CLAUDE.md` demande d'exclure du commit « les `pubspec.lock` de package ». Le seul lock présent est le **lock racine du workspace** (à conserver/suivre) — ce n'est pas un lock de package. Rien à corriger dans le code ; simple rappel pour l'étape de commit de l'orchestrateur (le lock racine peut être suivi).

### Dismissed (bruit / faux positifs)

- **Script `generate` filtré `dependsOn: build_runner` → 0 package ciblé actuellement** : attendu pour E1-1 (stubs sans `build_runner`). Non-défaut.
- **Descriptions mentionnant Syncfusion/Quill/Firebase** : chaînes de documentation uniquement ; aucun bloc `dependencies:` réel → pas de violation AD-1.

---

## Verdict global

**APPROVED.**

- **0 HIGH/MAJEUR**, **1 MEDIUM** (M-1, non bloquant : état actuellement cohérent + domicile naturel en E1-3), **3 LOW** dont 1 informationnel.
- Les 9 ACs sont satisfaits et re-vérifiés sur disque ; AD-1, AD-12, AD-15 respectés ; pas d'empiètement E1-2 ; pas de secret.
- **Condition sur le MEDIUM** : conformément au CLAUDE.md, M-1 doit être **corrigé par défaut** (correctif (1), trivial et en scope) ou **reporté avec justification écrite** vers E1-3 (garde-fou CI). L'orchestrateur pilote la correction.
