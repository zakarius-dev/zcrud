# Rétrospective — Epic E2 : Cœur (contrats, modèle canonique, codegen & bindings d'état)

- **Date** : 2026-07-09
- **Facilitatrice** : Amelia (Developer) · **Participante** : Zakarius (Project Lead)
- **Skill** : `bmad-retrospective` (invoqué via le tool `Skill`, args « retro epic 2 »)
- **Statut epic** : 10/10 stories `done` · Rétro : partie réflexion + préparation E3
- **Couverture** : FR-9, FR-10, FR-11, FR-12, FR-22 · AD-2, AD-3, AD-4, AD-5, AD-6, AD-10, AD-11, AD-14, AD-15, AD-16

---

## 1. Résumé de livraison

| Métrique | Valeur |
|---|---|
| Stories livrées | **10 / 10** (`done`) |
| Ordre intra-épic réel | E2-1 → E2-2 → E2-7 → E2-9 (réactivité/injection) puis E2-3 → E2-4 → E2-5 → E2-6 → E2-8 → E2-10 (codegen + finitions) |
| Blockers durables | 0 (tous les findings rattrapés dans le périmètre des stories) |
| Findings HIGH/MAJEUR | 1 (H1, E2-5) — corrigé avant `done` |
| Findings MEDIUM | 4 (E2-5 M1/M2, E2-9 MEDIUM-1/2) corrigés + 1 (E2-6 MEDIUM-1) déféré/justifié |
| Vérif verte | `analyze` RC=0 · `flutter test` RC=0 (ex. 195 tests zcrud_core à E2-8, 52 tests × 7 familles à E2-10) · gates `prove_gates`/parité/acyclique verts · `melos list`=14 · `g.dart`=0 |

**Jalons atteints :**
- **E2-7 — Objectif produit n°1 (SM-1) prouvé.** `ZFormController` (`ChangeNotifier`) expose une `ValueListenable` par champ ; rebuilds granulaires démontrés (buildsA↑ pendant la frappe, buildsB et global = 1, zéro perte de focus).
- **E2-9 — AD-15 prouvé.** Gate de parité ×4 (Riverpod / GetX / provider / `ZcrudScope` seul) sur un oracle unique figé ; cœur inchangé pour ajouter un manager.
- **E2-5 — Générateur codegen réel.** `toMap/fromMap/copyWith` + `ZFieldSpec[]` + enregistrement, **zéro reflectable**, `copyWith` à sentinelle (reset-null), round-trip testé.
- **E2-10 — Gate rétro-compat sérialisation non décoratif.** 52 tests, 7 familles de documents historiques/tronqués/champs inconnus ; le parent ne casse jamais (AD-10).

---

## 2. Ce qui a bien marché

Amelia (Developer) : « L'ordre intra-épic a payé : brancher réactivité + injection (E2-1/2/7/9) **avant** le codegen complet a débloqué E3 au plus tôt et validé les invariants structurants tôt. »

- **Séquencement piloté par les dépendances**, pas la numérotation — E2-7/E2-9 traités avant E2-4/E2-5.
- **SM-1 (objectif produit n°1) prouvé empiriquement**, pas seulement affirmé : compteurs de builds sous test widget.
- **AD-15 démontré par un harnais de parité dev-only à oracle unique** (corps de test figé, seul le `wrap` varie) → aucun binding ne peut « tricher ». `melos list`=14 préservé (harnais non publié).
- **Frontière de pureté clarifiée PAR COUCHE** (AD-14) : `domain/`+`data/` pur-Dart, `presentation/` autorise Flutter — décision explicite et cohérente plutôt que subie.
- **Discipline des gates** : anti-reflectable, scan secrets, codegen, acyclique (`CORE OUT=0`), rétro-compat — tous verts et rejoués réellement sur disque avant chaque `done`.
- **Décisions de nommage/design tranchées et tracées** : finding #15 (fusion `ZDataRequest`/`ZDataState`, `ZQuery` absorbé), `ZFailure` **abstract** (pas `sealed`, extensibilité inter-package AD-4), registres injectables, `ZModelAdapter` distinct du `ZCodec` rich-text.

## 3. Ce qui a coincé

Charlie (Senior Dev) : « Les vrais enseignements sont dans ce que les gates ont failli laisser passer. »

- **H1 (E2-5, HIGH/AD-10)** : `fromMap` d'un sous-objet à clés non-`String` cassait le parent. Non exposé sur le chemin `jsonDecode`/Firestore (clés toujours `String`), mais réel sur la voie **Hive / documents forgés / étrangers** (offline-first AD-9). AD-10 étant catégorique, traité en MAJEUR → helper défensif partagé (`_$asStringMap`) + test de non-régression.
- **Faux-négatifs de gates** : le gate de parité E2-9 était **aveugle aux consommateurs de `ZcrudScope`** (ne comptait que les widgets écoutant le `ZFormController`), ce qui a masqué MEDIUM-1 (resolver recréé à chaque build). E2-8 a dû **durcir les gardes** style/directionnelles. Rappel du gate E1-3.
- **Asymétrie inter-binding (E2-9 MEDIUM-1)** : `ZProviderResolver` recréé à chaque build → identité instable → sur-rebuild des consommateurs de seams. Corrigé.
- **Lifecycle GetX à locator partagé (E2-9 MEDIUM-2)** : un `dispose` pouvait désenregistrer le `ZFormController` d'autrui ; cas double-scope global non testé — sera exercé en conditions réelles à **E7-1**.
- **Variance analyzer ^8 vs ^7 (E2-5 M1)** : le manifeste `gate:compat` épinglait `analyzer ^7` avec une justification périmée alors que le codegen tourne sous `^8` → fausse confiance FR-25. Manifeste réconcilié.
- **Inflexions architecturales assumées** : E2-7 a introduit le SDK Flutter dans `zcrud_core` (`ChangeNotifier`/`ValueListenable`/`InheritedWidget`) ; E2-8 a élargi `presentation/` à `material.dart` (mandaté par FR-26 : `ThemeExtension`/`Theme.of` n'ont pas de chemin material-free). Confinées et justifiées, mais elles créent une **dette de contexte** (voir action item zcrud_kernel).

## 4. Leçons clés

1. **Le code-review adversarial est le filet qui capte ce que les gates verts ratent.** H1 (brèche AD-10 empiriquement prouvée) et les faux-négatifs de parité/gardes n'auraient pas été vus par la seule vérif verte. La politique « MEDIUM corrigés par défaut, report justifié par écrit » a fonctionné.
2. **Un gate ne vaut que ce qu'il mesure réellement.** Prouver la toolchain réelle (analyzer ^8), compter les bons widgets (consommateurs de seams, pas seulement les champs), exercer la vraie voie de corruption (clés non-`String`). « Vert » ≠ « exercé ».
3. **Les inflexions architecturales se gèrent en les nommant, en les confinant et en les rattachant à un AD** (Flutter par couche AD-14, Material par FR-26) — jamais en les laissant se diffuser silencieusement.
4. **Séquencer par le graphe de dépendances, pas par les numéros**, débloque l'aval (E3) et fait tomber les invariants structurants tôt.

---

## 5. Préparation de l'epic suivant — E3 (Moteur DynamicEdition à rebuilds granulaires)

E3 consomme directement les fondations E2 : `ZFormController`, `ZFieldSpec`, `ZFieldListenableBuilder`, seams `ZcrudScope`, thème/l10n injectables. **Aucune découverte E2 n'invalide le plan E3** — pas de « significant discovery » exigeant une re-planification. Points de vigilance à porter dans les stories E3 :
- SM-1 doit rester le critère d'acceptation dur (100 caractères → seul le champ courant rebuild, zéro perte de focus).
- La stabilité des consommateurs de `ZcrudScope` (trou de couverture E2-9 MEDIUM-1) doit être certifiée quand E3 monte de vrais champs résolvant des seams.

---

## 6. Action items

| # | Action | Catégorie | Rattachement | Owner | Statut |
|---|---|---|---|---|---|
| AI-1 | Porter la **voie de décodage défensive au niveau registre/adaptateur** (E2-6 MEDIUM-1 déféré) : `decodeSafe` additif OU rétention d'adaptateur exposant `fromMapSafe` via `ZcrudRegistry`. À intégrer dès le `create-story`. | Technique / dette tracée | **E5** (create-story) | Dev | open |
| AI-2 | Exercer **`ZcrudGetScope` locator partagé / double-scope** (E2-9 MEDIUM-2) en conditions réelles ; documenter « GetX global = un seul scope actif » ou scoper proprement. | Technique | **E7-1** | Dev | open |
| AI-3 | Ajouter au **harnais de parité un compteur sur un consommateur de seam `ZcrudScope.of(context)`** pour certifier la stabilité du resolver sous les 4 configs (referme le trou de faux-négatif E2-9). | Qualité / gates | **E3** (moteur) puis harnais partagé | Dev | open |
| AI-4 | **Example-app / formulaire de référence** absent (readiness #5) : créer l'app de démo servant de banc SM-1 et de vitrine d'intégration. | Documentation / infra | **E3–E7** | Dev | open |
| AI-5 | **Suivi E1-5 groupe B (révocation clé Google Maps)** en attente d'attestation de l'Owner (Zakarius) — `e1-5` reste `ready-for-dev`, epic E1 non formellement clôturé. Obtenir l'attestation. | Sécurité / process | **E1** (clôture) | Owner (Zakarius) | open |
| AI-6 | Évaluer un **`zcrud_kernel` pur-Dart** pour découpler `zcrud_annotations` du Flutter transitif tiré par l'inflexion Material/SDK dans `zcrud_core` (réduit la dette de contexte des inflexions E2-7/E2-8). | Architecture (spike) | **Backlog / pré-E5** | Architecte | open |

---

## 7. Évaluation de readiness E2

| Dimension | État |
|---|---|
| Qualité / tests | ✅ Verts rejoués sur disque (analyze RC=0, flutter test RC=0, gates verts) |
| Découvertes significatives | Aucune — plan E3 intact |
| Findings bloquants restants | 0 (H1 corrigé ; MEDIUM corrigés sauf E2-6 MEDIUM-1 justifié/déféré → AI-1) |
| Dette tracée | E2-6 MEDIUM-1 (→E5), E2-9 MEDIUM-2 (→E7-1), faux-négatif harnais (→AI-3), inflexions Flutter/Material (→AI-6) |
| Réserve process | E1-5 groupe B en attente d'attestation Owner (→AI-5) — E1 non clôturé |

**Verdict** : Epic E2 complet côté stories et prêt pour E3, sous réserve du suivi des action items ci-dessus (aucun n'est bloquant pour démarrer E3).
