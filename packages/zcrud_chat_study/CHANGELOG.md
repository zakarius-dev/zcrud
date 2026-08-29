# Changelog

Toutes les modifications notables de `zcrud_chat_study` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.30.0 — 2026-08-29

### Ajouté

- `lib/src/domain/routing/` : **adaptateurs par route** des six ports de
  génération d'étude. Le transport « une route par intention de génération »
  devient de première classe sans que les ports d'étude cessent d'être
  neutres — une route y reste une **donnée**, jamais une URL.
  - `ZChatRoutedMindmapGenerationPort`, `ZChatRoutedNoteSummaryPort`,
    `ZChatRoutedAiExplanationPort`, `ZChatRoutedAiExplanationStreamPort`,
    `ZChatRoutedPodcastGenerationPort`,
    `ZChatRoutedFlashcardGenerationPort` — chacun `implements` le port
    d'étude existant, aucun contrat n'est redéclaré.
  - `zResolveRoutedStudyPort` : la mécanique commune (catalogue → résolution
    → gate → identités `handlerId` / route effective / `routeName` → repli →
    `ZNotFoundFailure` unique). Le port par défaut n'est **jamais** inventé.
  - `buildRoutedStudyPorts` + `ZRoutedStudyPorts` + `ZRoutedStudyTaskKeys` :
    le câblage hôte des six ports en **une seule expression**.
- Arête `zcrud_mindmap` déclarée : `ZMindmapNode` doit être nommé pour
  redéclarer la signature de `generateMindmap`. **Zéro poids nouveau** —
  le paquet était déjà dans la fermeture via `zcrud_study`.

### Notes de contrat

- Trois requêtes transportent un `routeId` (mindmap, explication one-shot et
  progressive) : le choix explicite de l'appelant prime, sinon la route
  résolue y est estampillée verbatim. Trois n'en transportent pas (résumé de
  note, podcast, flashcards) : la route vient entièrement de la
  **configuration** et la requête est déléguée verbatim — aucune route n'est
  injectée dans un `extra`.
- Le gate **refuse** par défaut (`ZDenyAllChatRouteGate`) : une route
  gouvernée doit être ouverte explicitement. Un refus rend le
  `ZChatProviderFailure` de code `upgradeRequired` du kernel, sans appeler ni
  le handler ni le repli.
- Aucune constante de clé de tâche n'est publiée : `taskKey` est **requis**
  sur les six adaptateurs — le vocabulaire appartient à l'hôte.

### Tests

- `test/z_routed_study_ports_test.dart` (27 cas) : mocks à compteur pour
  chaque famille — route inconnue ⇒ `Left` unique et 0 appel ; gate refusé ⇒
  0 appel ; route résolue ⇒ 1 appel et `routeId` verbatim ; repli utilisé
  seulement quand la route ne résout pas ; flux transparent et annulation
  propagée en amont ; AD-10 sur un port qui lève.
- `test/z_routing_source_policy_test.dart` : AD-1 mesuré sur le
  `pubspec.yaml` réel de `zcrud_study` (avec contrôle discriminant prouvant
  que l'extracteur voit une arête chat quand il y en a une), frontière de
  couche (aucun import de `zcrud_chat`), pureté (ni URL, ni client HTTP, ni
  `dart:io`, ni widget), et absence de constante de tâche.
- `test/z_no_duplicate_seam_test.dart` affiné : la garde interdisait tout
  `class …GenerationPort`, y compris une **implémentation**. Elle vise
  désormais le second **contrat** (`abstract`/`interface`), et une garde
  compensatoire exige que tout port concret déclaré ici porte une clause
  `implements Z…Port`.

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (gabarit de la charte documentaire) : aperçu,
  installation, démarrage rapide, concepts clés, API principale, cas limites
  et invariants.
- Fiche `docs/site/paquets/zcrud_chat_study.md` (rôle, quand l'utiliser,
  types clés).
- `analysis_options.yaml` (absent jusqu'ici), avec `public_member_api_docs`
  activé : l'exhaustivité de la documentation de l'API publique devient un
  invariant vérifié par l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  lot, des comparaisons nominatives à une application legacy et des emoji de
  journal — conservation des invariants, cas limites et avertissements de
  contrat (estampillage défensif de la provenance, dédoublonnage du pool,
  soft-delete). Aucun changement de code — la revue ne porte que sur des
  commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_chat_study/`.
