# Changelog

Toutes les modifications notables de `zcrud_study_kernel` sont documentées
dans ce fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 3.29.0 — 2026-08-28

### Ajouté

- **Kernel pédagogique universel, partie 1** (`lib/src/domain/structure/`) : une
  famille d'entités aux responsabilités **distinctes** qui partagent un seul
  **protocole d'interaction** — référençables, scopables, liables, filtrables,
  archivables sans cascade, `ZEntity with ZExtensible`, `extra` filtré par
  `zSanitizeExtra`/`zNormalizeExtra` (avec `ZSyncMeta.reservedKeys`), `fromMap`
  défensif (AD-10), `toMap` sans `null`, `copyWith` à sentinelle, `$…FieldSpecs`
  + registrar généré, `externalRefs` sur chaque entité principale.
- **Primitives transversales** : `ZStudyRef` (référence + instantané
  d'affichage, `sameTarget` sur l'identité seule), `ZExternalRef`,
  `ZStudyBinding` (rattachement daté à propagation), `ZStudyRelation` (arête
  latérale), et le protocole `ZStudyArtifact` (`ownerRef`, `primaryScopeRef`,
  `bindings`) — un mixin partagé, **pas** une racine d'héritage.
- **Tenancy** : `ZStudyWorkspace`, `ZStudyPrincipal`, `ZStudyOrganization`,
  `ZStudyOrgUnit`. **Structure** : `ZStudyProgram`, `ZStudyGroup`,
  `ZStudyVocabulary`(+`ZStudyVocabularyValue`), `ZStudyClassification`
  (historisable, remplace toute facette). **Catalogue** : `ZStudySubject`,
  `ZStudyCourse`, `ZStudyProgramCourse`. **Temps** : `ZStudyCalendar`,
  `ZStudyPeriod`, `ZStudySession` (séance datée — à ne pas confondre avec la
  session de révision `ZStudySessionConfig`).
- **Ontologie en données** : `ZStudyOntology`, `ZStudyKindSpec`,
  `ZStudyContainmentRule`, `ZStudyDisplayRules`, l'alias
  `ZStudyVocabularySpec`, et les primitives pures `zHasCapability`,
  `zValidatePlacement`, `zValidateVocabularyUse`. Le noyau décide par
  **capacité**, jamais sur un type concret ; ontologie `null` ⇒ aucune
  restriction.
- **Préréglages** `ZStudyOntologyPresets` (`lyceeFr`, `universiteLmd`,
  `formationPro`, `primaire`, `personnel`) — seul fichier du paquet autorisé à
  porter du vocabulaire de contexte, garde de source à l'appui.
- **Projections** : `zRecomputeAncestorIds` (générique par `parentId`, cycle ⇒
  `Left`, remontée bornée), `zDepthOf`, et `ZStudyScopeFilter` (filtre pur et
  persistable).
- Toute clé de vocabulaire (`kind`, `role`, `vocabularyKey`, `valueKey`,
  `propagation`, `status`) est une **chaîne opaque** : l'inconnu survit au
  round-trip. Les seules valeurs interprétées par le noyau sont nommées par des
  constantes (`kZStudyPropagation…`, `kZStudyCapability…`, `kZStudyFamily…`,
  `kZStudyStatus…`, `kZStudyRefType…`).

- **Enseignement réel** : `ZStudyOffering` (concrétisation datée d'un cours ;
  ni unité ni intervenant en propre — ce sont des participations),
  `ZStudyOfferingAudience` (offre ↔ groupe, plusieurs-à-plusieurs) et
  `ZStudyParticipation`, qui **unifie** adhésion, inscription et rattachement
  d'intervenant en un seul enregistrement daté `(mandant, cible, rôle)`.
- **Contenu pédagogique** : `ZStudyCurriculum` (progression versionnée et
  datée, indépendante du cours), `ZStudyTopic` (arbre de contenu à profondeur
  libre, `kind` opaque), `ZStudyCompetencyFramework`, `ZStudyCompetency`,
  `ZStudyCompetencyRelation` et `ZStudyTopicCompetency`. Les compétences
  forment un **graphe**, pas un arbre : les cycles sont admis, sauf pour
  `prerequisite` et `contains` — contrôlés **nature par nature** par
  `zValidateCompetencyGraph`, au-dessus de la primitive générique
  `zDetectCycle`.
- **Contenu utilisateur** : `ZStudyFolder` porte désormais le protocole
  `ZStudyArtifact` (`ownerRef`, `primaryScopeRef`, `bindings`) par **canaux
  manuels additifs** ; `ZStudyExplanation` sort l'explication du dossier pour
  qu'il puisse y en avoir plusieurs sans alourdir la map du dossier.
- **Sécurité — des faits, pas des permissions** : `ZStudyRoleBinding` et
  `ZStudyShareGrant` enregistrent qui a quel rôle sur quoi, et ce qui a été
  partagé avec qui. Le noyau n'en **déduit jamais** un droit : l'autorisation
  est calculée par l'hôte (`ZActionKey`, ACL fail-closed). `roleKey` et
  `accessKey` sont opaques, jamais ordonnés.
- **Résolution** : `ZStudyStructureSnapshot` (vue immuable fournie par
  l'appelant), `ZStudyContext` (read model matérialisable, **jamais** une
  source de vérité) et `ZStudyContextResolver`, pur — `resolve` ne peut
  échouer que si l'offre est absente de l'instantané ; tout le reste manquant
  devient vide. `zIsVisibleFrom` porte l'**unique** implémentation de la
  propagation (`exact`/`descendants`/`ancestors`/`members`/`offerings`/`none`,
  valeur inconnue ⇒ comme `exact`), et `zMatchesScopeFilter` applique le filtre
  de portée aux artefacts.
- **Ports** : `ZStudyStructurePort` (composition de `ZRepository<T>` existants,
  chaque accesseur nullable — `null` = entité non servie ; **aucun** contrat de
  dépôt n'est redéfini), `ZStudyStructureImportPort` (+ `ZStudyStructureImport`
  / `ZStudyStructureImportReport`, format neutre) et `ZStudyPrincipalResolver`,
  avec leurs implémentations inertes `const`, qui **refusent explicitement**
  plutôt que de réussir en silence ou de fabriquer une référence.

### Corrigé

- `ZStudyRef.fromMap` confondait **absence** et **chaîne vide** sur les
  métadonnées d'instantané (`label`, `code`, `kind`) : une référence portant un
  libellé vide se relisait avec `null`, donc `toMap` et `fromMap` n'étaient pas
  inverses. La lecture distingue désormais la clé absente (`null`) de la clé
  présente et vide (`''`). Trouvé par la garde de round-trip du contexte.

### Inchangé (prouvé)

- `ZStudyFolder` reste **strictement identique** à v3.28.0 **tant qu'aucun
  rattachement n'est déclaré** : les trois canaux `owner_ref`,
  `primary_scope_ref` et `bindings` n'écrivent aucune clé quand ils sont nuls
  ou vides, et ne sont pas des champs du schéma généré. La garde d'inertie à
  littéral figé du lot précédent est **inchangée et verte**, doublée d'une
  garde symétrique qui prouve que les canaux émettent bien quand ils portent
  quelque chose — sans elle, l'inertie serait satisfaite en n'émettant jamais
  rien.
- `subjectId` du dossier est conservé tel quel, documenté comme **raccourci de
  compatibilité** : ni déprécié, ni dérivé, et sans cohérence imposée avec les
  canaux de rattachement.

### Notes d'intégration

- 23 registrars neufs au total (`registerZStudy…`) et une large surface
  publique s'ajoutent au barrel : une garde de surface d'API en aval le
  signalera — c'est attendu.
- Les extensions générées (`…Zcrud`) sont masquées par le barrel : la
  (dé)sérialisation passe par l'API d'instance, jamais par l'extension (qui
  remettrait `extra`/`extension` et les canaux manuels à leurs défauts).

## 3.28.0 — 2026-08-28

### Ajouté

- `ZStudyFolder.subjectId` : lien typé, optionnel, vers la matière d'un
  dossier. Identifiant opaque résolu par l'application — le noyau n'introduit
  ni entité matière ni port de résolution. Champ `@ZcrudField(label: 'Matière')`
  : il apparaît donc dans `$ZStudyFolderFieldSpecs` (et dans le formulaire
  dérivé) sans action du consommateur.
- `ZStudySubjectRef` : référence d'affichage légère (`id` opaque + `label` et
  `colorKey` optionnels), exportée par le barrel. Décodage défensif (AD-10) :
  tout champ d'un type inattendu retombe sur `null` (`id` sur `''`) sans lever ;
  `toMap()` omet les métadonnées absentes. Égalité structurelle sur les trois
  champs.

### Inertie (hôte n'utilisant pas la matière)

- `subject_id` est ABSENT de `toMap()` tant que `subjectId` est `null` : la map
  persistée d'un dossier existant est strictement identique à celle d'avant ce
  lot, clé pour clé. Garde d'égalité stricte à la map littérale complète.
- `subject_id` entre dans `_reservedKeys` (dérivées du schéma généré) : elle ne
  peut plus atterrir dans `extra` par aucune voie — y compris le constructeur
  `const`, seule voie incapable de filtrer, dont l'accesseur `extra` porte la
  garde. Un hôte qui rangeait sa propre matière sous la clé `subject_id` dans
  `extra` la voit désormais promue en champ first-class : elle est lue par
  `fromMap` et n'est plus rendue par `extra`.

### Tests

- 9 gardes neuves, chacune prouvée par une injection de la régression exacte
  qu'elle surveille (rouge par assertion, restauration par copie, SHA-256
  identique avant/après) : inertie absolue de `toMap()`, round-trip et identité
  structurelle de `subjectId`, type invalide retombant sur `null` sans polluer
  `extra`, sentinelle de `copyWith` (omis ≠ `null` explicite), filtrage de la
  clé réservée depuis `extra`, égalité STRICTE entre les noms du schéma et les
  clés de `toMap()` (mord dans les deux sens), puis round-trip, décodage
  défensif et égalité discriminante de `ZStudySubjectRef`.

## 3.6.0 — 2026-08-23

### Corrigé
- Octet NUL brut dans un littéral Dart remplacé par `\u0000` (un `grep` sans `-a` voyait un fichier binaire ; `git diff` aussi).

## [0.86.0] — Chantier documentation

### Ajouté

- `README.md` du paquet (absent jusqu'ici), au gabarit de la charte
  documentaire : aperçu, installation, démarrage rapide, concepts clés, API
  principale, cas limites et invariants.
- Fiche `docs/site/paquets/zcrud_study_kernel.md` (rôle, quand l'utiliser,
  types clés).
- `public_member_api_docs` activé dans `analysis_options.yaml` : l'exhaustivité
  de la documentation de l'API publique devient un invariant vérifié par
  l'analyse statique.
- `CHANGELOG.md` (ce fichier).

### Modifié

- Normalisation de la dartdoc de l'ensemble de l'API publique exportée par le
  barrel : première phrase autonome, invariants d'architecture cités par leur
  nom stable (`docs/site/concepts/invariants.md`). Purge des références de
  story et d'epic, des emoji de journal, des codenames de remédiation internes
  et des comparatifs à des applications legacy utilisés comme justification —
  conservation des invariants, cas limites et avertissements de contrat.
  Aucun changement de code — la revue ne porte que sur des commentaires.

Historique antérieur : voir `git log` sur `packages/zcrud_study_kernel/`.
