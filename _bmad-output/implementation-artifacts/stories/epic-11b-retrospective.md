# Rétrospective — Epic E11b : Reste géo / intl / export (v1.x)

- **Mode d'exécution** : skill réel `bmad-retrospective` invoqué via le tool `Skill` (workflow step-file chargé). Rétro conduite en mode non-interactif (subagent, pas d'utilisateur live) : les phases « party mode » du skill sont synthétisées en analyse écrite, la structure du workflow (review → prep épic suivant → action items → readiness) est respectée. **Aucune écriture de `sprint-status.yaml`** (réservé à l'orchestrateur), **aucun commit**.
- **Épic** : E11b — compléter au-delà de la parité MVP (E11a) : `zcrud_geo`, `zcrud_intl`, `zcrud_export`. Dépend de E11a. Phase v1.x. Source `epics.md` §E11b (l. 150-155).
- **Stories** : E11b-1 (`zcrud_geo`), E11b-2 (`zcrud_intl`), E11b-3 (`zcrud_export`) — **toutes `done`**.
- **Date** : 2026-07-10.

---

## 1. Résumé de livraison

| Story | Périmètre | Analyze | Tests | Findings review | Statut |
|-------|-----------|---------|-------|-----------------|--------|
| **E11b-1** | `zcrud_geo` : géométrie **cercle** (`ZGeoCircle`), `ZGeoFieldConfig` surchargeable, **2ᵉ adaptateur Google** en parité de l'OSM existant | RC=0 | **98** (52 E11a-1 + 46) | 0 HIGH · **1 MEDIUM corrigé** · 4 LOW consignés | done |
| **E11b-2** | `zcrud_intl` : **devise** (`ZMoney`/`ZCurrencyInfo`), **états/provinces** (`ZSubdivision`), `ZIntlFieldConfig`, défauts nationaux surchargeables | RC=0 | **129** (59 E11a-2 + 70) | 0 HIGH · 0 MEDIUM · 4 LOW consignés | done |
| **E11b-3** | `zcrud_export` : `ZPdfCreationService` unique (dédup DODLP/IFFD), `FileSaver` web (`package:web`/`dart:js_interop`), `ZPdfExportOptions`, anti-rognage tables larges | RC=0 | **42** | 0 HIGH · 0 MEDIUM · 3 LOW consignés | done |

**Invariants durs tenus sur les 3 stories** : graphe **ACYCLIQUE, CORE OUT=0**, `melos list = 14` préservé ; **zéro secret** (aucune clé Google, aucun `registerLicense`, aucun `badCertificateCallback`, aucun endpoint réseau) ; **SDK tiers confinés** (google_maps_flutter à 1 importateur, phone_numbers_parser à 1 importateur, Syncfusion aux seuls backends `src/data/`) ; **rétro-compat stricte** vs E11a (52/59 tests baseline non régressés) ; **AD-1** (zéro écriture `zcrud_core`) ; **AD-4** (configs `ZFieldConfig` additives, aucun `sealed`, aucune nouvelle `EditionFieldType`) ; **AD-10** (`fromMapSafe` neutre partout) ; **AD-12** (aucun défaut national/clé codé en dur non surchargeable) ; **AD-13** (a11y opérable via helpers `assertSemanticActionTap`/`assertMinTapTarget`, cibles ≥48 dp, directionnel/RTL).

---

## 2. Réussites

1. **Épic livré propre, dette quasi nulle.** Sur 3 stories : **0 HIGH, 0 MAJEUR, 1 seul MEDIUM** (E11b-1, corrigé dans le périmètre, pas reporté). Le reste = LOW consignés à impact fonctionnel nul. C'est le profil d'un épic « compléments » mûr, bâti sur des fondations E11a déjà éprouvées.

2. **Isolation des SDK tiers érigée en invariant structurel testé.** Chaque story ajoute un backend lourd (Google Maps, parseur téléphone, Syncfusion PDF/Excel) sans qu'aucun type propriétaire ne fuite en signature publique. Prouvé non par relecture mais par des **gates d'isolation exécutables** : import-confinement (`hasLength(1)`), sorties neutres (`Uint8List`, `ZGeoCircle` pur-Dart), barrel sans symbole tiers. E11b-3 a même **durci** son gate (allowlist Syncfusion + fichiers publics dérivés dynamiquement), clôturant un LOW d'E11a-3.

3. **Zéro secret, confirmé par gate à chaque story.** Clé Google en config plateforme (documentée, jamais embarquée), licence Syncfusion propriété de l'app hôte, `zcrud_intl`/`zcrud_export` hors-ligne sans réseau. La discipline AD-12 est désormais réflexe.

4. **API strictement additive + rétro-compat verrouillée par test.** E11b-3 verrouille la surface publique par `api_surface_test.dart` (compile-time) — `ZExportApi`/`ZExporter`/`ZExportTable` intacts, `version` bumpé 0.0.1→0.1.0 **sans renommage** (consommé par `zcrud_flashcard`). La régression historique E11a-3 (suppression de `ZExportApi`) n'est **pas** reproduite. Sur les 3 stories, les tests baseline E11a (52+59) restent verts.

5. **Action items E10/E11a réellement appliqués (continuité).** Le helper a11y outillé **AI-E10-1** (`assertSemanticActionTap` + `assertMinTapTarget`) est **effectivement consommé** par les widgets E11b-2 (devise/état) — la leçon d'a11y n'est plus seulement documentée, elle est outillée et rejouée. Le pattern **fabrique-par-montage** (AI-E11a-1) est appliqué aux contrôleurs/focus `late final` des 3 widgets. Le cadrage **AI-E11a-3** (géo complet / devise+états / export riche) est exactement le périmètre livré.

---

## 3. Points de friction & findings récurrents

1. **Champs de config morts (E11b-1, MEDIUM-1).** `ZGeoFieldConfig` exposait `tileUrlTemplate`/`mapStyleJson`/`defaultZoom` **jamais lus** par le widget ni transmis aux adaptateurs : la fabrique `ZMapAdapter Function()` était sans argument, `buildMap` n'avait aucun paramètre tuiles/style/zoom. Promesse d'API partiellement creuse, masquée par des tests AC ne couvrant que `==`/`hashCode`. **Corrigé (option « plomber »)** : `buildMap` reçoit 3 paramètres additifs optionnels, le widget les passe depuis `ctx.field.config`, chaque adaptateur honore ceux de son backend, **+ test que `buildMap` reçoit réellement les surcharges**. → **Motif récurrent : un champ de config n'est pas « surchargeable » tant qu'un test ne prouve pas qu'il atteint le consommateur.**

2. **Sous-ensemble curaté vs couverture exhaustive (E11b-2, LOW-2).** `currencies.json` livre **61** devises là où la note de conception disait « ~180 » (ISO 4217). Non bloquant : catalogue **injectable/extensible** (`fromList`), code inconnu dégrade en code brut sans crash, aucun AC n'impose de compte. **Résolu par documentation** : assumer « sous-ensemble curaté » (comme les subdivisions : 7 pays / 79 entrées) et le compléter sans changement d'API si un besoin réel émerge. → **Motif : écart note-de-conception ≠ écart AC ; le trancher explicitement en review évite la dette silencieuse.**

3. **LOW d'infra web non exerçables sous VM (E11b-3, LOW-1).** L'ancre `<a download>` non attachée au DOM + `revokeObjectURL` synchrone : pattern standard OK navigateurs modernes, mais non testable sous `flutter test` (VM charge le stub io), couvert seulement par gate statique. Consigné en dette v1.x. → **Motif : une surface plateforme-seulement (web) ne peut être garantie que par gate statique + robustification défensive ; l'accepter et le tracer plutôt que feindre une couverture.**

4. **Récurrence a11y désormais éteinte.** Le motif d'a11y répété E11a→E10 (`Semantics(button:true) > ExcludeSemantics` sans `SemanticsAction.tap`) **ne réapparaît pas** en E11b-2 : le helper outillé AI-E10-1 a été appliqué dès la conception. La récurrence est close par outillage, pas par vigilance.

---

## 4. LEÇON PROCESS CENTRALE — le gate repo-wide attrape le RED latent d'un AUTRE package

**Fait observé.** Pendant le dev d'E11b-1 (`zcrud_geo`), le dev-agent a rejoué `melos run verify` **repo-wide** (et non seulement `dart analyze/test packages/zcrud_geo`). Ce gate global a révélé un **RED latent `verify:serialization`** dans un package **totalement différent et non touché par E11b-1** : `zcrud_flashcard` (`test/z_study_session_config_test.dart` — *« type 'InvalidType' is not a subtype of type 'FunctionType' »*), défaut appartenant au workstream parallèle WS-B / E9-3. `zcrud_geo` lui-même était vert (SKIP serialization, aucune dépendance vers flashcard).

**Pourquoi c'est décisif.** Une vérif **par-package** sur `zcrud_geo` n'aurait **jamais** vu ce RED : le package fautif est ailleurs dans le graphe. C'est **exactement** le scénario que CLAUDE.md documente déjà (`ZExportApi` supprimé en E11a-3 cassant `zcrud_flashcard`, `melos analyze` resté RED plusieurs commits sans être vu). E11b-1 en fournit une **confirmation empirique fraîche** : sans `melos verify` repo-wide au bon moment, un RED cross-package reste invisible aux gates ciblés et se propage silencieusement jusqu'au gate d'epic.

**Confirmation de la règle CLAUDE.md.** La consigne « à CHAQUE gate de commit d'epic, rejouer `melos run analyze` ET `melos run verify` REPO-WIDE » n'est pas de la prudence théorique — **les faits E11b-1 la valident**. Un `graph_proof`/`secrets`/`melos list` verts (comme ceux rejoués par package en E11b) **ne remplacent pas** `melos analyze`/`verify` global : ils prouvent l'acyclicité et la neutralité, pas la compilation croisée de tous les tests.

**Nuance de discipline de parallélisation.** Dans un dev actif multi-workstream (E9 tournait en parallèle), on **ne bloque pas** la story courante sur le RED d'un autre workstream : E11b-1 a correctement **isolé** le finding comme HORS-PÉRIMÈTRE, l'a tracé, et a livré `zcrud_geo` vert. Le repo-wide sert à **rendre le RED visible et attribué**, pas à faire échouer à tort la story voisine. La résolution du RED appartient au gate d'epic de E9 (workstreams au repos), sérialisée par l'orchestrateur.

---

## 5. Action items

| # | Action | Catégorie | Owner |
|---|--------|-----------|-------|
| **AI-E11b-1** | **Rejouer `melos run analyze` ET `melos run verify` REPO-WIDE au gate de fin d'epic E11b** (workstreams au repos), pour confirmer 0 régression cross-package avant tout `done`/commit d'épic — en particulier reconfirmer que `zcrud_flashcard` consomme toujours `ZExportApi.version` sans casse (E11b-3). Ne PAS se contenter des gates par-package rejoués pendant le dev. | Orchestrateur |
| **AI-E11b-2** | **Résoudre le RED latent `verify:serialization` de `zcrud_flashcard`** (E9-3, `z_study_session_config_test.dart` — `InvalidType`/`FunctionType`) : il DOIT être vert avant le gate de commit de l'épic E9. Tracé ici car révélé par le repo-wide d'E11b-1. | Dev (E9) |
| **AI-E11b-3** | **Règle de review « config surchargeable » (généralise MEDIUM-1 E11b-1)** : tout champ de `ZFieldConfig` annoncé « surchargeable » exige un test prouvant qu'il **atteint le consommateur** (widget/adaptateur), pas seulement `==`/`hashCode`. Sinon = champ mort → plomber ou retirer. | Dev / Review |
| **AI-E11b-4** | **Compléter ou aligner les catalogues curatés** (`currencies.json` 61, `subdivisions.json` 7 pays) : soit étendre vers la couverture ISO 4217 active si un besoin app réel émerge (DODLP/lex_douane), soit acter « sous-ensemble curaté extensible via `fromList` » comme choix documenté. Non bloquant. | PM / Dev |
| **AI-E11b-5** | **Consigner en dette v1.x les LOW différés** : robustification ancre web (append/remove + `revokeObjectURL` différé, E11b-3 LOW-1) ; labels lat/lng `zcrud_geo` non routés l10n (`geo.latitude`/`geo.longitude`, E11b-1 LOW-2) ; recentrage cercle sans rayon (LOW-1) ; sémantique `interactive:false` vs `onTap` (LOW-3). À reprendre si besoin d'intégration réel. | Dev |
| **AI-E11b-6** | **Réutiliser tel quel en E7/E8 l'outillage validé par E11b** : helper a11y (AI-E10-1), fabrique-par-montage (AI-E11a-1), template de garde grep exhaustif (AI-E10-2), gate d'isolation SDK durci (dérivation dynamique de l'allowlist). | Dev (E7/E8) |

---

## 6. Continuité — suivi des action items antérieurs

- **AI-E11a-3 (cadrer E11b)** : ✅ **réalisé** — le périmètre livré (géo cercle + 2ᵉ adaptateur, devise+états surchargeables, export PDF documents + FileSaver web) correspond exactement au cadrage.
- **AI-E11a-1 (fabrique-par-montage)** : ✅ **appliqué** — contrôleurs/focus `late final` créés 1× / disposés sur les 3 widgets, dispose idempotent testé.
- **AI-E10-1 (helper a11y outillé)** : ✅ **appliqué et consommé** — `assertSemanticActionTap`/`assertMinTapTarget` sur les pickers devise/état ; la récurrence a11y E11a→E10 ne se reproduit pas.
- **AI-E10-2 (template de garde grep exhaustif)** : ✅ **hérité** — gates d'isolation/secrets/FR-26 réutilisés et, pour E11b-3, **durcis** (dérivation dynamique de l'allowlist Syncfusion, clôt LOW-2 E11a-3).
- **Dette E11a-3 (anti-rognage tables larges PDF, LOW-1)** : ✅ **clôturée** en E11b-3 (`allowHorizontalOverflow` + police compacte, dernière colonne extraite par `PdfTextExtractor` sur 16 colonnes).
- **AI-E5 (dettes réseau/serveur A1, requête→cache A2)** : ⏳ **hors périmètre E11b**, reste porté par E9-4 (consommateur réel du patron offline-first).

---

## 7. Lecture pour la suite (E7/E8, publication REL)

1. **Gate d'epic REPO-WIDE non négociable avant `done`/commit d'épic** — la leçon §4 est la conclusion process n°1 : `melos analyze` + `verify` global, pas seulement les gates par-package. C'est la seule barrière qui attrape un RED cross-package (ex. un consommateur de symbole public dans un autre package). **E7 (intégration DODLP)** est précisément l'étape où un symbole public zcrud est massivement consommé de l'extérieur → gate repo-wide critique.
2. **Le RED `zcrud_flashcard`/E9-3 doit être résolu avant le commit d'épic E9** — sinon il bloque `melos verify` global et masquera d'autres régressions. À traiter workstreams au repos, sérialisé par l'orchestrateur (jamais deux écritures concurrentes du sprint-status).
3. **AI-E11a-4 s'exécute en E7** : suppression effective du `badCertificateCallback` hérité DODLP dans l'app hôte ; le `gate:secrets` verrouille déjà la non-réintroduction côté package.
4. **Publication REL** : les 3 packages E11b sont publiables-compatibles (API additive, versions bumpées sans renommage, zéro secret, SDK confinés, `dart pub get --dry-run` RC=0). Confirmer au moment de REL que `ZExportApi.version` reste stable pour ne pas casser `zcrud_flashcard`, et acter le statut « sous-ensemble curaté » des catalogues intl dans les notes de publication.
5. **Aucune découverte E11b ne remet en cause le plan des epics suivants.** E11b clôt le lot compléments v1.x géo/intl/export sur des fondations E11a stables ; **aucune mise à jour d'épic/PRD/architecture requise**.

---

## 8. Readiness — verdict

Épic E11b **complet et vert** : 3 stories `done`, gates verts par-package (analyze RC=0, 98+129+42 tests RC=0, graphe ACYCLIQUE/CORE OUT=0, secrets, SDK confinés, rétro-compat E11a stricte), 0 HIGH/MAJEUR/MEDIUM ouvert. **Seule réserve avant clôture formelle de l'épic** : rejouer le **gate REPO-WIDE** (`melos analyze` + `verify`) une fois les workstreams parallèles (E9) au repos et le RED `zcrud_flashcard` résolu — condition portée par AI-E11b-1/AI-E11b-2, à exécuter par l'orchestrateur.
