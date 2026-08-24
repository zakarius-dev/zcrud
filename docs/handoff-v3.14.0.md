# Handoff v3.14.0 — CR-IFFD-93 à 103 : l'audit des formulaires d'édition

> **Date** : 2026-08-24. **Portée prévue** : `zcrud_core`, `zcrud_markdown`, `zcrud_screen`.
> **Traite** : les onze CR de l'audit des formulaires (35 écrans, 13 jumeaux champ à champ, 20
> capacités re-mesurées ; une douzième candidate retirée par l'hôte à la re-mesure — la méthode
> qu'on souhaite à tous les émetteurs).

## 1. Les onze manques (chacun vérifié sur disque avant délégation)

| CR | Défaut | Nature |
|---|---|---|
| 93 | `ZTextConfig.keyboardType` déclaré, documenté, **jamais lu** — clavier alphabétique sur les emails/téléphones | option inerte |
| 94 | Pas de port de formatage d'affichage des **nombres** (le symétrique du port de dates existe) | port manquant |
| 95 | Pas de `lowercase`, et **aucun défaut de configuration au scope** — ~42 champs re-déclarés un à un | canal manquant |
| 96 | La teinte par type de champ (`gradientResolver`) n'atteint pas la décoration — **cadré par le propriétaire** : canaux prévus, jamais l'UI par défaut ; présets = données ; couleurs normalisées pour le contraste | canal manquant |
| 97 | Copie riche mono-format ; paramètres d'état vide du lecteur non relayés par le champ | relais manquant |
| 98 | `minValueKey`/`maxValueKey` acceptés puis ignorés | option inerte |
| 99 | **Garde d'inertie** : toute propriété publique d'une config a un consommateur en présentation, ou est marquée « domaine pur » — rougit à l'ajout d'une option morte | garde structurelle |
| 100 | Pas de lecture seule **conditionnelle** par champ (cinquième cible de dérivation) | capacité manquante |
| 101 | Mot de passe sans œil ; adornments purement décoratifs (pas d'`onTap`) | capacité manquante |
| 102 | `ZFieldSpec.defaultValue` jamais appliqué par le moteur (le générateur le consomme, la présentation non) | option inerte |
| 103 | Pas de `beforeSubmit(Map) → Map` sous `ZCrudScreen` (la map est décodée sans crochet) | crochet manquant |

## 2. Ce que le socle livre

### 97 — `zcrud_markdown` (589 → 597 tests)
Copie multi-format déclarée par l'hôte (formats, libellés par clé l10n, transformations — le socle n'invente rien) ; l'état vide du lecteur relayé jusqu'au champ. Sans déclaration : comportement inchangé (étalons).

### 103 — `zcrud_screen` (354 → 360 tests)
`ZCrudScreen.beforeSubmit(values, original)` entre validation et décodage — création, édition et duplication passent tous par le site unique ; une levée échoue proprement, aucune écriture ; sans crochet, map `identical`. `presentFormEdition` n'avait pas besoin du paramètre : il rend déjà la map à l'appelant.

### 93–96, 98–102 — `zcrud_core` (2 416 → 2 455 tests)
- **93** clavier déclaré honoré (multi-ligne conservé, inconnu ⇒ repli) · **94** port de format des nombres (lecture + résumé) · **95** `lowercase` + défauts au scope (champ > scope) · **96** teinte par type de champ — étalon pixel-identique, présets = données jamais lues (gardé par grep), contraste ≥ 3.0:1 clair/sombre · **98** bornes dynamiques revalidées au changement du champ référencé · **99** garde d'inertie (7 exemptions justifiées, liste bornée) · **100** cinquième cible `readOnly` de `ZDerivation`, propagée jusqu'au champ `widget` · **101** œil natif + adornments interactifs · **102** `defaultValue` amorcé, clé présente autoritaire même nulle.

## 3. Ce qui change pour un hôte
- **Passif** : rien — défauts corrigés et canaux à défauts inertes ; l'étalon de la teinte (96) est
  **pixel-identique** sans déclaration.
- **IFFD** : retire les re-déclarations champ par champ (95), les recopies de `defaultValue` (102),
  les contournements d'`onSubmit` (103) ; pose l'œil (101) et les claviers (93). Ses tripwires
  (`formulaires_socle_tripwires_test.dart`, un par CR, chacun vu rouge avant d'être cru) le
  rappellent un par un.

## 4. Vérification

Rejouée par l'orchestrateur, au repos : `zcrud_core` **2 455** (2 416 → +39, ~65 s) ; `zcrud_screen` **360** (354 → +6) ; `zcrud_markdown` **597** (589 → +8) ; `melos run generate` 0 `.g.dart` ; `melos run analyze` 0 erreur ; `melos run verify` **RC=0** (douze gates) ; balayage des **41 paquets** : 40 verts, `zcrud_generator` rouge environnemental. **26 injections R3** (16 cœur + 4 markdown + 6 screen), toutes rouges par assertion — dont une option morte injectée qui fait rougir la nouvelle garde d'inertie, un préset lu par défaut qui rougit, et un étalon teinté qui rougit. Incidents de campagne : deux agents coupés en vol (API, notification attendue à tort) — état mesuré sur disque avant reprise, 43 rouges de chargement requalifiés en contamination de deux harnais fantômes de la veille, tués.
