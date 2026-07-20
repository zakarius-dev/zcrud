# Prompt — Session Claude dédiée : montée de version des dépendances de lex_douane

> À coller tel quel comme **premier message** d'une session Claude Code ouverte dans
> `/home/zakarius/DEV/lex_douane`.
>
> **Cette session précède** celle d'intégration zcrud (`prompt-session-migration-lex-douane.md`).
> Elle ne parle **pas** de zcrud : c'est une passe d'hygiène autonome, dont la valeur tient debout
> même si l'intégration zcrud était abandonnée.

---

## 0. Rôle et périmètre

Tu conduis une **montée de version des dépendances de lex_douane vers les versions les plus
récentes atteignables**, en préparation d'une intégration ultérieure. Objectif : réduire la dette
de résolution **avant** d'ajouter une famille de dépendances externes, pour ne pas avoir à
diagnostiquer simultanément « ma montée de version » et « la nouvelle dépendance ».

**Contrainte d'écriture — NON-NÉGOCIABLE :**

| Repo | Droit |
|---|---|
| `/home/zakarius/DEV/lex_douane` | **ÉCRITURE AUTORISÉE** (seul repo modifiable) |
| `/home/zakarius/DEV/zcrud`, `/home/zakarius/DEV/iffd`, `/home/zakarius/DEV/dodlp-otr`, `/home/zakarius/DEV/dlcfti-otr` | **LECTURE SEULE** |

---

## 1. Baseline mesurée le 2026-07-20 — à re-mesurer, pas à croire

Monorepo melos : `packages/{lex_core, lex_localizations, lex_data, lex_ui}` +
`apps/{lex_douane, lex_douane_admin}` — **2 793 fichiers Dart, ~174 k lignes**
(`lex_ui` 882, `lex_douane_admin` 796, `lex_core` 611, `lex_data` 350).
`packages/lex_aa7_lint` est **hors workspace** (voir § 4).

Commence par re-mesurer :

```bash
dart pub outdated                 # résolution actuelle vs résolvable vs latest
dart pub outdated --mode=null-safety
flutter --version && dart --version
```

État constaté (extrait) :

| Dépendance | Actuel | Résolvable | Latest | Nature |
|---|---|---|---|---|
| `syncfusion_flutter_*` (core, datagrid, calendar, pdfviewer, datepicker, localizations) | 33.2.15 | **34.1.31** | 34.1.31 | 🔶 **majeure — breaking** |
| `cunning_document_scanner` | 1.4.0 | **2.6.0** | 2.6.0 | 🔶 majeure |
| `google_mlkit_text_recognition` / `google_mlkit_commons` | 0.15.1 / 0.11.1 | 0.16.0 / 0.12.0 | idem | 🔶 majeure de fait (0.x) |
| `firebase_core_platform_interface` | 7.1.0 | **8.0.0** | 8.0.0 | 🔶 majeure (transitive) |
| `firebase_app_check` | 0.4.4+2 | 0.4.5+2 | 0.4.5+2 | 🔶 majeure de fait (0.x) |
| `cloud_firestore` | 6.6.0 | 6.7.1 | 6.7.1 | 🟢 mineure |
| `firebase_*` (auth, storage, messaging, analytics, crashlytics, functions) | 6.5.4 / 13.4.3 / 16.4.1 / 12.4.3 / 5.2.4 / 6.3.3 | +1 patch/mineure chacun | idem | 🟢 |
| `connectivity_plus`, `mobile_scanner`, `google_fonts`, `uuid`, `share_plus`, `local_auth`, `app_links`, `package_info_plus`, `flutter_markdown_plus`, `gpt_markdown` | — | mineures | — | 🟢 |
| `analyzer` / `_fe_analyzer_shared` | 12.1.0 / 99.0.0 | bloqués | 14.1.0 / 105.0.0 | ⚠️ **plafonnés — voir § 4** |
| `file_picker` | 12.0.0-**beta**.5 | 12.0.0-beta.7 | beta.7 | ⚠️ **préversion en production** |
| `intl` | 0.20.2 | 0.20.2 | 0.20.3 | 🔒 **plafonné par le SDK Flutter — ne pas forcer** |
| `package_config` 2→3, `pointycastle` 3→4, `qr` 3→4, `record_use` 0.6→1.0, `hooks` 2.0→2.1, `flutter_secure_storage_darwin` 0.3→0.4, `dbus`, `matcher`, `meta` | — | bloqués | majeures dispo | 🔒 transitifs — **remontent d'eux-mêmes** ou pas du tout, ne les force jamais à la main |
| `melos` | ^7.0.0 | — | **8.2.2** | 🔶 outil, majeure |

**Deux anomalies à instruire, pas à ignorer :**

1. **`firebase_core` est marqué `(overridden)`** → il existe un `dependency_overrides` quelque
   part. Trouve-le, **documente pourquoi il a été posé**, et **teste s'il est encore nécessaire**.
   Un override oublié est une bombe à retardement lors d'une montée Firebase.
2. **`file_picker` est épinglé sur une préversion `12.0.0-beta.5`.** Détermine si c'était un
   contournement de bug ; si oui, vérifie si la stable 12.x le corrige.

---

## 2. Séquencement imposé — par vagues de risque croissant

**N'exécute JAMAIS `dart pub upgrade --major-versions` en un seul coup.** Sur 2 793 fichiers,
un échec groupé est indiagnosticable. Une vague = une story = un commit = une vérif verte.

| Vague | Contenu | Risque |
|---|---|---|
| **U0** | Toolchain : `flutter upgrade` (canal stable) + `melos` 7→8. Rien d'autre. | Faible mais **transverse** — si ça casse, ça casse tout |
| **U1** | `dart pub upgrade` **sans** `--major-versions` : les 12 dépendances verrouillées plus vieilles que leur contrainte. Zéro édition de `pubspec.yaml`. | Très faible |
| **U2** | Mineures des contraintes directes : `cloud_firestore` 6.7.1, la famille `firebase_*`, `connectivity_plus`, `mobile_scanner`, `google_fonts`, `uuid`, `share_plus`, `local_auth`, `app_links`, `package_info_plus`, `flutter_markdown_plus`, `gpt_markdown` | Faible |
| **U3** | **`firebase_core_platform_interface` 7→8** + `firebase_app_check` 0.4.5 — la famille Firebase se monte **ensemble**, jamais à moitié | Moyen |
| **U4** | **Syncfusion 33.2.15 → 34.1.31** (6 modules, **majeures alignées obligatoires**) | **Élevé** — `SfDataGrid` (admin), `SfCalendar`, `SfPdfViewer` sont des surfaces UI larges. **Lis le changelog de breaking changes 33→34 AVANT d'éditer.** |
| **U5** | `cunning_document_scanner` 1→2, `google_mlkit_*`, `file_picker` (sortie de beta) | **Élevé** — APIs de capture/OCR/fichiers, souvent breaking en profondeur, et **difficiles à tester sans device** |
| **U6** | `analyzer`/`custom_lint` — voir § 4 | Élevé, **peut légitimement échouer** |

Après **chaque** vague : vérif verte complète (§ 3) + commit. Si une vague échoue, **elle
s'arrête là** — tu ne l'empiles pas sur la suivante.

---

## 3. Vérif verte — à rejouer TOI-MÊME, jamais sur la foi d'un rapport d'agent

```bash
dart pub get                       # résolution sans conflit
dart run melos run generate        # build_runner (freezed + json_serializable + riverpod_generator)
dart run melos run analyze         # RC=0 REPO-WIDE
dart run melos run test            # RC=0
dart run melos run l10n-check      # gate « 0 untranslated », 7 locales
```

⚠️ Une vérif ciblée sur un package **ne détecte pas** une régression cross-package. À chaque gate
de commit : **repo-wide**.

**Le codegen est un risque de premier ordre ici** : `freezed 3.2.6-dev.1` (une **préversion**),
`json_serializable` 6.14, `riverpod_generator` 4.0.4, `build_runner` 2.15 — tous sensibles à
`analyzer`. Vérifie qu'ils **régénèrent réellement** (pas seulement qu'ils compilent) : `git diff`
sur les `*.g.dart`/`*.freezed.dart` après chaque vague. Un codegen qui produit un output différent
sans que tu l'aies voulu est un finding, pas un détail.

**Ce que `melos run analyze` ne couvre pas** — les surfaces UI et natives. Sur U4/U5, ajoute :

```bash
dart run melos run build-apk           # compilation Android réelle
dart run melos run build-admin-apk
flutter build web --release            # dans apps/lex_douane
```

Et **exerce à la main** les écrans touchés (grille admin, calendrier, viewer PDF, scanner de
document, OCR). Un `analyze` vert sur une montée Syncfusion majeure ne prouve rien du rendu.

---

## 4. Le nœud `analyzer` / `custom_lint` — dette déjà identifiée par vous

`packages/lex_aa7_lint` a été **sorti du workspace** (commentaire dans le `pubspec.yaml` racine) :
`custom_lint 0.8.1` épingle `analyzer 8.4.0` et bloquait toute montée riverpod/json. Aujourd'hui
lex résout `analyzer 12.1.0` (latest 14.1.0), plafonné par `_fe_analyzer_shared 99.0.0`.

En vague U6 : **vérifie si `custom_lint` supporte enfin analyzer 12+/14**. Si oui, **réintègre
`lex_aa7_lint` au workspace** et prouve que ses lints tournent (RC=0). Si non, **laisse la ligne
commentée telle quelle** et mets à jour le commentaire avec la date et la version testée — la
dette reste tracée, pas oubliée. **Ne supprime pas le package** et ne le réintègre pas de force.

---

## 5. Règles — non négociables

- ✅ **Une vague = une story BMAD** (cycle strict `create-story` → `dev-story` → vérif verte →
  `code-review` → fix → `done`), un commit par vague. Le `pubspec.lock` **fait partie du
  livrable** ici : commit-le délibérément (c'est l'inverse de la règle habituelle, et c'est
  volontaire — le lock *est* le résultat).
- ✅ **Documente chaque breaking change absorbé** dans `docs/upgrade-log-2026-07.md` : dépendance,
  version avant/après, API cassée, correctif appliqué, fichiers touchés. Ce journal est le
  livrable le plus durable de la session.
- ✅ **Contraintes de version : reste sur `^`**, ne fige pas en exact sans raison écrite.
- ✅ **Aucune régression fonctionnelle silencieuse.** Là où il n'existe aucun test protégeant un
  écran que tu touches, **écris-le avant** de monter la dépendance. Un test qui ne rougit pas
  quand la logique casse est un test mort.
- 🚫 **Jamais** `git checkout` / `git restore` / `git stash` sur du travail non committé.
- 🚫 **Jamais** contourner un conflit en **rétrogradant** une dépendance saine.
- 🚫 **Jamais** modifier un fichier hors de `lex_douane`.
- 🚫 **Jamais** éditer un `*.g.dart` / `*.freezed.dart` à la main.
- 🚫 **Jamais** valider une étape sur le rapport d'un sous-agent : **relis le disque**.

---

## 6. ⚠️ Ce que cette session ne doit PAS faire

Une intégration du monorepo **zcrud** est prévue **après**. Deux conséquences :

1. **Ne rétrograde rien pour « préparer » zcrud** — en particulier **ne touche pas à
   `flutter_riverpod` 3.3.2**. lex est en avance (v3), zcrud est en retard (v2) : **c'est à zcrud
   de monter**, pas à lex de descendre. Une rétrogradation Riverpod 3→2 côté lex serait une
   régression majeure sur 321 fichiers en `@riverpod` codegen et 340 `ConsumerWidget`.
2. Deux montées **convergent** naturellement avec zcrud et sont donc **prioritaires** : **Syncfusion
   33→34** (zcrud est déjà sur 34.1.31) et **`cloud_firestore` 6.7.1** (zcrud accepte `^6.0.0`).
   Traite-les avec soin : elles éliminent un conflit futur.

Ne planifie, n'installe et ne référence **aucun package zcrud** dans cette session.

---

## 7. Livrables

1. `docs/upgrade-log-2026-07.md` — le journal des breaking changes absorbés, vague par vague.
2. Un **plan de vagues** (epics/stories BMAD) validé **par moi avant exécution**, avec pour chaque
   vague son critère de vérification **et son critère de rollback**.
3. Une **note sur les 2 anomalies** du § 1 (override `firebase_core`, beta `file_picker`) :
   origine, nécessité actuelle, décision.
4. Une **note sur le nœud `analyzer`/`custom_lint`** (§ 4) : testé, verdict, dette mise à jour.
5. La liste des montées **volontairement non faites**, chacune avec sa raison.

**Commence par re-mesurer la baseline (§ 1) et me présenter le plan de vagues. N'exécute aucune
montée avant que je l'aie validé.**

---

## 8. Communication

**Français**, orthographe et diacritiques complets. Termes techniques et identifiants de code
inchangés. Après **chaque** étape BMAD, un **résumé concis non sollicité** : étape + skill réel
invoqué, ce qui a été produit, **résultats de vérification réellement rejoués sur disque**
(commandes + RC + nombre de tests), findings de code-review avec statut, transition de statut
appliquée.
