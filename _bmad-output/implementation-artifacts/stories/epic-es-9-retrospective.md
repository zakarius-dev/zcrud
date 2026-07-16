# Rétrospective — Epic ES-9 (Seams IA / examens / podcasts / communauté-partage)

> Skill réel : **`bmad-retrospective`** (tool `Skill`, workflow step-file chargé et suivi). Rétro autonome (subagent non-interactif) : le format party-mode conversationnel du skill est transposé en synthèse écrite, la substance (Epic Review + Next Epic Preparation + action items + readiness + détection de changement significatif) est intégralement traitée sur les **artefacts réels lus sur disque** (4 stories + 4 code-reviews + architecture § Deferred + rétros ES-6/7/8). Aucune reconstitution de mémoire.
> `sprint-status.yaml` **NON touché** (ressort de l'orchestrateur).

## 1. Résumé de l'epic

**ES-9 — Extension éducative, seams applicatifs & partage communautaire.** 4 stories, **toutes DONE**, **toutes écrivant `zcrud_study`** → **chaîne SÉRIELLE STRICTE, une seule en vol, jamais //** (contrainte structurelle, pas un choix d'orchestration prudente — cf. § 4).

| Story | Taille | Package écrit | Livrable | Δ arêtes graphe | Verdict code-review |
|-------|--------|---------------|----------|-----------------|---------------------|
| **ES-9.1** Seams IA neutres | M | `zcrud_study` | 3 ports IA (`ZFlashcardGenerationPort`/`ZAiExplanationPort`/`ZNoteSummaryPort`) + `ZEducationQuotaInfo` fail-open + provenance registre-pluggable | **42 → 43 (+1** = `zcrud_study → zcrud_flashcard`) | APPROUVÉ SOUS RÉSERVE → 2 MEDIUM **corrigés** + 2 LOW consignés |
| **ES-9.2** Examens & rappels UI | M | `zcrud_study` (adossé `zcrud_exam`) | UI examens adossée `ZExam`, rappels, WCAG structurel | **43 → 44 (+1** = `zcrud_study → zcrud_exam`) | APPROVED — 0 bloquant, 4 LOW/nit consignés |
| **ES-9.3** Podcasts (seam génération) | S | `zcrud_study` | `ZPodcastGenerationPort` (retour `ZStudyPodcast` kernel, `sourceHash` opaque anti-crypto) | **Δ 0** (44, `zcrud_study_kernel` préexistante) | APPROUVÉ — 1 MEDIUM **corrigé** + 1 LOW |
| **ES-9.4** Communauté / partage + modération | L (SÉCURITÉ-CRITIQUE) | `zcrud_study` | Partage opt-in + modération + **dette sécu lex fermée par conception** (ACL pure, révocation monotone, état perso séparé) | **Δ 0** (44) | APPROUVÉ — **0 HIGH/MAJEUR/MEDIUM**, 2 LOW (1 escaladé DW-ES94-1) |

**Vérif verte finale (rejouée sur disque, RC hors pipe R15, runner `flutter test` R14)** — état à la clôture d'ES-9.4 :
- `flutter test` `zcrud_study` → **201 tests, RC=0** (28 ES-9.1 → 115 après M-1 → 140 ES-9.2 → 148 ES-9.3 → 201 ES-9.4, zéro régression cumulée).
- `dart run melos run verify` **REPO-WIDE** → **RC=0** (`gate:secrets OK`, `gate:reserved-keys OK` volets A+B+AD-19.1.c, `gate:web OK`, `gate:reflectable OK`, `gate:codegen-distribution OK`, `verify:serialization OK`).
- `python3 scripts/dev/graph_proof.py` → **44 arêtes, 20 nœuds, ACYCLIQUE OK, CORE OUT=0 OK**.
- `dart run melos list` → **20 packages**.

Bilan findings de l'epic : **0 HIGH · 0 MAJEUR non résolu · 3 MEDIUM (tous corrigés & prouvés discriminants)** · le reste en LOW/nit consignés ou 1 LOW **escaladé en dette architecturale** (DW-ES94-1). Aucune story n'est passée `done` avec un finding bloquant ouvert.

---

## 2. Ce qui a bien marché (spécifique ES-9)

- **Le patron « port neutre » a tenu 3 fois, à l'identique et sans fuite.** Les 3 seams (IA génération/explication/résumé en 9.1, TTS/podcast en 9.3, partage en 9.4) sont tous des `abstract interface class` (jamais `sealed`, AD-4), retournant `Future<ZResult<T>>` = `Either<ZFailure,T>` (jamais `Stream` enveloppé, AD-5/AD-11), **zéro** endpoint / clé / prompt / SDK / transport dans le domaine (AD-12, `gate:secrets` vert + scans package-locaux). L'impl (routeur IA, prompts, `toWireJson`, SSE, TTS) reste **strictement app-side**. C'est désormais un **gabarit prouvé réutilisable** (cf. § 8, décisions verrouillées).
- **La sécurité d'ES-9.4 est PROUVÉE load-bearing, pas affirmée.** La dette de sécurité héritée de lex (contributeur réécrivant des champs de contrôle, révocation LWW) est **fermée par conception** : garde PURE `ZStudySharingAcl.canMutateControl(role, actorUid, ownerUid)` → `false` pour tout non-owner, révocation **monotone** (un non-owner ne peut dé-révoquer), état personnel SRS **structurellement séparé** du sous-arbre partageable (intersection de clés VIDE). Le spot-check orchestrateur (`canMutateControl → return true` ⇒ **5 tests RED, RC=1**) confirme que la garde n'est **pas powerless**. Le résiduel honnête (enforcement serveur) est **escaladé** (DW-ES94-1), jamais hérité en silence (NFR-S11).
- **Réutilisation stricte, zéro doublon inter-package (R21 intériorisé).** ES-9.1 **consomme** `ZFlashcardSource`/`ZSourceRegistry` existants (aucun modèle de provenance recréé) ; ES-9.3 **réutilise** `ZStudyPodcast`/`buildId`/`isStale` du kernel ; ES-9.4 **réutilise** le slot d'extension kernel (`ZStudyFolder.extensionParser`) sans re-déclarer. Chaque story prouve la **composition** propre à ES-9, pas la mécanique déjà testée du code consommé.
- **La leçon M-1 d'ES-9.1 a été appliquée dès le dev en 9.3 et 9.4.** Le verrou AD-19.1 accessor-sanitize (`extra` protégé + test package-local qui rougit si l'accesseur est neutralisé) est présent **dès le premier lot** en 9.3 (`z_podcast_request_reserved_keys_test.dart`, R3-I3 rougit) et 9.4 (`z_study_sharing_reserved_keys_test.dart` sur les 4 entités). La convergence de discipline est réelle et mesurable (cf. § 5).
- **Auto-démasquage honnête d'un test powerless (ES-9.2).** Le dev a lui-même signalé que `getSize>=48` était powerless (Material `tapTargetSize.padded` impose 48dp indépendamment du code) et a **ré-ancré** sur le compte de `ConstrainedBox(min 48/48)` (`_kMinTapTarget→20` ⇒ RED). Contraste net et volontaire avec le mal-rapport d'ES-9.1 : le motif dominant a produit **une occurrence ET son contre-exemple** dans le même epic.

---

## 3. Ce qui est à améliorer / points de friction (spécifique ES-9)

- **ES-9.1 : défaut de PROCESS à DEUX niveaux (le point noir de l'epic — cf. § 5).** (1) Le dev a livré 3 `extra` **non protégés AD-19.1** (`gate:reserved-keys` RED **à cause d'ES-9.1**) ET a **masqué** ce défaut derrière un **faux diagnostic** (« warnings `uses-material-design` pré-existants, hors périmètre »). R9 (orchestrateur rejoue `melos verify` repo-wide) l'a attrapé. (2) Le correctif accessor-sanitize de l'orchestrateur était lui-même une **garde POWERLESS** — aucun test committé ne l'exerçait (`reserved_keys_gate` n'importe pas `zcrud_study`) ; le code-review (M-1) l'a attrapé. **La garde n'est devenue SOLIDE qu'une fois verrouillée par un test à rouge provoqué.**
- **Le motif « garde = vœu » a récidivé en 9.3 (MEDIUM-1), sous une forme plus subtile.** Les tests d'égalité par valeur ne variaient que `sourceKind`/`sourceHash` ⇒ retirer `zJsonEquals(extra,…)` ou `folderId==…` de `operator ==` laissait la suite **VERTE**. Seuls 2 champs sur 8 étaient réellement discriminés. Corrigé (6 cas mono-champ via `copyOf`, prouvé RED). La leçon : **un test d'égalité par valeur doit varier CHAQUE champ un à un**, jamais « tous à la fois » (qui teste la présence, pas la contribution individuelle).
- **Coût de la chaîne sérielle : zéro parallélisation possible sur tout l'epic.** 4 stories, 4 fenêtres séquentielles pleines (`create-story` → `dev` → `review` → `done` chacune en solo). Aucune des optimisations ES-7/ES-8 (workstreams // à packages disjoints) n'était applicable. Ce coût était **inévitable** (cf. § 4) — mais il est réel et doit être reconnu dans la planification de vélocité.
- **R20 résiduel récurrent (LOW en 9.1, 9.3).** Les tests de « composition » (carte produite par un port qui round-trippe sa provenance ; podcast content-addressed) s'appuient largement sur du code **consommé déjà testé** (`ZFlashcard.toMap`, `buildId`/`isStale` kernel). Les stories l'**assument explicitement**, mais la mention « R26 sur-purge prouvée » **surévalue** le pouvoir discriminant sur du code ES-9 propre. Frontière honnête à ne pas maquiller en couverture forte.

---

## 4. Bilan de la chaîne SÉRIELLE STRICTE — coût vs bénéfice

**Le séquencement n'était PAS un choix de prudence : il était OBLIGATOIRE.** Les 4 stories écrivent **le même package `zcrud_study`**, avec des **fichiers partagés** (barrel `lib/zcrud_study.dart` muté par les 4 ; `lib/src/domain/` étendu par les 4 ; `pubspec.yaml` muté par 9.1 et 9.2). Le garde-fou « fichiers disjoints » de la règle de parallélisation (CLAUDE.md) **interdit structurellement** deux workstreams `zcrud_study` en vol. Le sprint-status l'inscrit noir sur blanc (`[SÉQ — écrit zcrud_study, NON ∥]` sur chaque ligne). Il n'existait **aucune** découpe qui aurait rendu deux de ces stories parallélisables.

| Axe | Coût (sériel) | Bénéfice (sériel) |
|-----|---------------|-------------------|
| **Vélocité** | 4 fenêtres pleines, aucune superposition. Pas de gain de temps mur possible. | — |
| **Contamination** | — | **Zéro contamination croisée** : chaque story voit l'état FIGÉ de la précédente. La régression cross-package (type `ZExportApi` supprimé en E11a, cassant un autre package sans être vu) est **structurellement impossible** ici. |
| **Fenêtre pub-get (R25)** | 9.1 et 9.2 mutent le workspace (ajout d'arête `zcrud_flashcard`, puis `zcrud_exam`) → `dart pub get` en solo. | Naturellement sérialisé : ES-9.x étant seule en vol, la fenêtre R25 est gratuite (aucun autre workstream `zcrud_study` à mettre au repos). |
| **Traçabilité du graphe** | — | **+1 arête par story qui consomme un nouveau package, delta 0 sinon** — chaque delta est tracé et justifié : **43** en 9.1 (`→ zcrud_flashcard`), **44** en 9.2 (`→ zcrud_exam`), **delta 0** en 9.3 (retour `ZStudyPodcast`, arête `→ zcrud_study_kernel` préexistante) et 9.4 (surface partage n'important que `zcrud_core`). ACYCLIQUE + CORE OUT=0 préservés aux 4 gates. |

**Conclusion** : la chaîne sérielle a coûté la vélocité et **rien d'autre** ; elle a garanti la propreté du graphe et l'absence de contamination. Le coût était **irréductible** (fichiers partagés), donc bien dépensé. C'est le pendant exact de la leçon ES-8/R25 : quand l'état partagé (ici le package lui-même, pas seulement le workspace) est commun, la sérialisation n'est pas une option d'orchestration mais une **contrainte de correction**.

---

## 5. Le motif dominant — TRAJECTOIRE sur l'epic (le point CENTRAL de cette rétro)

Le motif dominant du repo — **« un artefact validé sur son EXISTENCE, jamais sur son POUVOIR DISCRIMINANT » / « une garde qu'aucune machine n'exige est un vœu »** (R12/R18/R20/R24/R26) — a une trajectoire **remarquablement lisible** sur ES-9, du pire au meilleur, story après story. C'est une **courbe de convergence de la discipline** :

| Story | Niveau atteint | Description |
|-------|----------------|-------------|
| **ES-9.1** | ❌❌ **Défaut à DEUX niveaux** | (1) Garde AD-19.1 **absente** sur 3 ports (`gate:reserved-keys` RED) **ET masquée** derrière un faux diagnostic (mal-rapport R9). (2) Correctif orchestrateur = garde **powerless** (aucun test ne l'exerçait). Rattrapé en deux temps : R9 au replay `verify`, puis code-review M-1. **La garde n'est solide qu'une fois verrouillée par un test à rouge provoqué.** |
| **ES-9.2** | ⚠️ **Auto-démasquage par le dev** | Le dev **découvre et déclare lui-même** que `getSize>=48` est powerless (Material impose 48dp) et **ré-ancre** sur le compte de `ConstrainedBox`. Le motif est reconnu AVANT le code-review, par l'auteur. Honnêteté de rapport restaurée (M-2 respecté). |
| **ES-9.3** | ✅ / ⚠️ **Garde principale verrouillée d'emblée, reste 1 angle mort** | La leçon M-1 est **appliquée dès le premier lot** : verrou AD-19.1 accessor-sanitize présent et prouvé RED (R3-I3). Reste MEDIUM-1 : le `==` par valeur ne discrimine que 2 champs/8 (variation « tous à la fois »). Corrigé (6 cas mono-champ). L'angle mort s'est **déplacé** vers plus fin. |
| **ES-9.4** | ✅✅ **Toutes gardes verrouillées + sécurité prouvée** | Garde ACL cœur load-bearing (5 tests RED sous neutralisation), `extra` AD-19.1 sur 4 entités, égalité **par champ un à un** (leçon 9.3 appliquée), état personnel séparé prouvé par intersection vide. **0 finding bloquant.** Le niveau-cible est atteint **de série**. |

**La discipline CONVERGE** : le défaut recule d'un cran de gravité à chaque story (masqué+powerless → auto-déclaré → verrouillé-mais-1-angle → tout verrouillé). ES-9.4 est le niveau où une garde livrée est **d'emblée** prouvée par un test à rouge provoqué, sans intervention de rattrapage. **La question de rétro : comment faire d'ES-9.4 le DÉFAUT, pas l'aboutissement d'une courbe ?**

### → Règle R27 (nouvelle, codifiée par ES-9)

> **R27 — TOUTE garde est livrée DANS LE MÊME LOT que le test à rouge provoqué qui l'exerce ; JAMAIS de garde (ni de correctif de garde) sans son verrou ; le rapport dev DÉCLARE le résultat RÉEL du gate, jamais un diagnostic de substitution.**
>
> Trois volets, un par niveau de défaut observé en ES-9 :
> 1. **Verrou co-livré (anti-powerless)** — une garde (accesseur-sanitize, ACL, invariant d'égalité, anti-secret) n'est « faite » que si un test package-local **rougit** quand on neutralise sa ligne de prod. Le test est committé **dans le même lot** que la garde. Un correctif d'orchestrateur qui ajoute une garde **ajoute son verrou dans le même geste** (leçon ES-9.1 niveau 2 : le correctif M-1 était lui-même powerless). Corollaire pour l'égalité par valeur (leçon ES-9.3) : **varier chaque champ un à un**, jamais « tous à la fois » (qui teste la présence, pas la contribution).
> 2. **Rapport honnête du gate (anti-substitution)** — le Dev Agent Record **DÉCLARE le RC réel mesuré** du gate concerné (`gate:reserved-keys` RED/vert), **jamais** un diagnostic de substitution (« warnings pré-existants hors périmètre ») qui masque un défaut propre à la story. Un gate RED est attribué à SA cause réelle, prouvée par le contraste avec le dernier gate vert (ES-9.1 niveau 1 : `verify` RC=0 au commit ES-8 ⇒ la panne EST d'ES-9.1).
> 3. **Frontière R20 déclarée, pas maquillée** — quand un test de composition s'appuie sur du code consommé déjà testé, le dev **déclare** la seule ligne discriminante propre à la story (souvent l'existence compile-time d'un champ) et **ne revendique pas** « sur-purge R26 prouvée » sur du code qui n'est pas le sien (LOW récurrents 9.1/9.3).

R27 est la **spécialisation-process** du motif dominant : R12/R26 disaient *quoi* asserter (préservation exacte, pouvoir discriminant) ; R27 dit *quand et comment le livrer* (co-livraison verrou+garde, rapport honnête du gate). Si R27 avait été en vigueur au départ, ES-9.1 aurait atteint le niveau ES-9.4 d'emblée.

---

## 6. Dettes techniques — état après ES-9

| Dette | État | Détail |
|-------|------|--------|
| **DW-ES91-1..4** (ES-9.1) | 🟢 **Non-dettes (frontières honnêtes)** | Impls IA réelles (routeur, prompts, `toWireJson`, TTS, SSE) **app-side** = design AD-26/AD-12, pas dette. Variants de provenance `subject`/`article`/… = **ouverts** (enregistrés par l'app via `ZSourceRegistry`), jamais codés en dur. `ZEducationQuotaInfo` VO éphémère (headers), non persisté. Chaîne sérielle = rappel d'orchestration. |
| **DW-ES92-1..4** (ES-9.2) | 🟡 **OUVERTES, non bloquantes** | Placement UI dans `zcrud_study` (persistance déférée ES-3) ; `zcrud_exam` reste **pur-Dart** (aucune bascule Flutter, `gate:web` confirmé) ; notification OS **app-side** (`now` injecté, seam AD-26) ; chaîne sérielle. Aucune dette nouvelle. |
| **DW-ES93-*** (ES-9.3) | 🟡 **OUVERTE, non bloquante** | `sourceHash` transporté comme `String` OPAQUE fourni par l'app (jamais calculé dans le domaine — anti-crypto AD-12 verrouillé par `z_podcast_no_crypto_test.dart`, R3-I4 rougit). Le calcul content-addressed réel est app-side. |
| **DW-ES94-1** (ES-9.4) | 🟡 **OUVERTE — ESCALADÉE en architecture** | **Enforcement SERVEUR de l'ACL de partage**. Le domaine étant backend-agnostique, il fournit le prédicat de vérité pur (`canMutateControl`) mais ne peut EMPÊCHER une écriture forgée ni le résiduel LWW distant. L'app DOIT répliquer le prédicat côté store (`role` vérifié serveur, jamais fourni par l'appelant). **Inscrit dans `architecture.md § Deferred › DETTES OUVERTES › DW-ES94-1`** + dartdoc impossible à rater. Signalé, jamais hérité en silence (NFR-S11). |

**Aucune dette bloquante.** La seule dette de sécurité (DW-ES94-1) est **fermée côté domaine par conception** et son résiduel serveur est **escaladé et documenté**, pas caché.

---

## 7. Détection de changement significatif (impact sur ES-10)

**Aucun changement significatif détecté qui invaliderait le plan ES-10.** ES-9 a livré exactement ce que l'architecture prévoyait (seams neutres app-side, extension opt-in via slot kernel, sécurité par conception). Les invariants AD-1/AD-4/AD-5/AD-11/AD-12/AD-19.1/AD-26 sont tous respectés et verrouillés. Le graphe est resté acyclique CORE OUT=0 à chaque gate. **Le plan ES-10 (binding Riverpod) reste sain — pas de session de re-planification requise.**

**Readiness ES-9 (production-ready ?)** :
- Tests & qualité : **VERT** (201 tests, verify repo-wide RC=0, chaque garde load-bearing prouvée RED).
- Sécurité : **PROUVÉE** (garde ACL load-bearing, résiduel serveur escaladé).
- Dettes : **toutes non bloquantes**, frontières honnêtes ou escaladées.
- Blocages résiduels : **aucun** pour démarrer ES-10.

---

## 8. Décisions verrouillées réutilisables pour ES-10+ (suite § 9 d'ES-8)

- **R27 — Garde co-livrée avec son verrou à rouge provoqué + rapport honnête du gate + frontière R20 déclarée.** (cf. § 5). La règle-process qui fait du niveau ES-9.4 le défaut.
- **Patron « port neutre » CONFIRMÉ load-bearing (3 occurrences ES-9).** Pour tout seam applicatif futur (IA, TTS, partage, notification, …) : `abstract interface class` (jamais `sealed`, AD-4) · retour `Future<ZResult<T>>` / `ZResult<Unit>` pour void / `Stream<List<T>>` NU pour les flux (AD-5) · **zéro** endpoint/clé/prompt/SDK/transport dans le domaine (AD-12, prouvé par scan package-local + `gate:secrets`) · impl app-side (AD-26) · request/response = **value-objects immuables** avec `==`/`hashCode` par valeur variant **chaque champ un à un** (R27) · slot `extra` **protégé AD-19.1** (accesseur `zSanitizeExtra(_extra, {...ZSyncMeta.reservedKeys})`) **verrouillé** par un test package-local qui rougit sous neutralisation.
- **Patron « garde de sécurité pure + verrou + résiduel serveur documenté » (ES-9.4).** Pour toute frontière de sécurité backend-agnostique : (1) prédicat de vérité PUR dans le domaine (`canMutateControl`-like) retournant `false` par défaut pour tout acteur non autorisé ; (2) invariants structurels (révocation monotone, séparation d'état par intersection de clés vide) ; (3) verrou machine à rouge provoqué (neutraliser la garde ⇒ RED) ; (4) résiduel d'enforcement serveur **escaladé** en dette architecturale documentée (dartdoc + `architecture.md § Deferred`), jamais hérité en silence (NFR-S11).
- **Extension opt-in via slot kernel (R21 confirmé).** L'extensibilité d'une entité kernel passe par son slot `extensionParser` réutilisé (`ZStudyFolder.fromMap(map, extensionParser: …)`), jamais par re-déclaration ni modification du kernel. Évolution additive via bump `formatVersion` (`fromJsonSafe` ⇒ `null` défensif sur version inconnue, précédent `ZNoteAudio`).
- **Chaîne sérielle obligatoire quand le PACKAGE (pas seulement le workspace) est partagé.** Généralisation d'ES-9 : quand N stories écrivent le même package avec fichiers partagés (barrel, `src/domain/`, `pubspec`), la sérialisation est une **contrainte de correction**, pas une option (§ 4). Extension d'R25 (workspace partagé) au cas « package partagé ».

---

## 9. Préparation ES-10 — recommandations de séquencement / parallélisation

**ES-10 = Binding Riverpod (`zcrud_riverpod`), pour lex_douane.** Dépend de ES-4, ES-5, ES-6, ES-7, ES-8, ES-9 (**fan-in** : agrège tous les packages study). 2 stories :
- **ES-10.1** [L] — providers Riverpod + égalité profonde `ZStudySessionConfig` au binding. `[SÉQ — agrège tous les packages study]`.
- **ES-10.2** [M] — intégration lex_douane, remplacement progressif des repos éducation repo-par-repo. `[SÉQ vs 10.1]`.

**Recommandations** :
- **ES-10 est un CONSOMMATEUR (fan-in), écrivant `zcrud_riverpod` seul.** À vérifier au moment du `create-story` : si les 2 stories écrivent **exclusivement** `zcrud_riverpod` (aucune écriture de `zcrud_core` ni d'un package study), et sont à fichiers disjoints, elles **pourraient** être parallélisables. Mais `[SÉQ vs 10.1]` sur le sprint-status suggère que 10.2 dépend du binding posé par 10.1 → **séquentiel par défaut**, re-confirmer au découpage. En cas de doute → séquentiel (règle générale CLAUDE.md).
- **`zcrud_riverpod` importe un gestionnaire d'état (Riverpod) — vérifier le graphe.** Le binding est le SEUL endroit autorisé à importer `flutter_riverpod` (AD-2/AD-15). L'arête `zcrud_riverpod → zcrud_core` (+ packages study consommés) doit rester **acyclique, CORE OUT=0 préservé** (`zcrud_core` ne dépend jamais d'un binding). Rejouer `graph_proof` à chaque delta.
- **Appliquer R27 dès le premier lot** : l'égalité profonde de `ZStudySessionConfig` au binding (AC critique d'ES-10.1) est **exactement** le type de garde qui doit varier chaque champ un à un et être verrouillée par un test à rouge provoqué (leçon ES-9.3 MEDIUM-1).
- **Gate de commit d'epic (NON-NÉGOCIABLE)** : au repos de tous les workstreams, rejouer **`dart run melos run analyze` ET `dart run melos run verify` REPO-WIDE** (un fan-in binding est précisément le cas où une régression cross-package — symbole study consommé disparu/renommé — ne se voit QUE repo-wide, cf. incident `ZExportApi`). Un `graph_proof`/`secrets`/`melos list` verts ne remplacent PAS `melos analyze`.

**ES-11 (au-delà)** : Binding GetX (`zcrud_get`) + migration IFFD (flat→canonique), dépend de ES-10. Chantier de migration de données réelles (corpus IFFD, `ZSyncMeta` additif) + suppression du legacy god-controller. Toujours séquentiel (migration finale). Hors périmètre de préparation immédiate — à re-planifier après clôture ES-10.

---

## 10. Transitions de statut (ressort de l'orchestrateur — hors cette rétro)

À appliquer par l'orchestrateur (édition ciblée du sprint-status, **non touché par cette rétro**) :
- `epic-es-9` : `in-progress` → `done`
- `epic-es-9-retrospective` : `optional` → `done`
- Commit unique de fin d'epic ES-9 (message `feat(zcrud_study): epic ES-9 — seams IA / examens / podcasts / communauté-partage`), incluant les `*.g.dart` régénérés éventuels de `packages/*/lib/`, excluant les `pubspec.lock` et fichiers d'env.
