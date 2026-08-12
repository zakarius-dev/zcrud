# Changelog

Toutes les modifications notables de `zcrud_screen` sont documentées dans ce
fichier. Le format suit [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/).

## 0.92.0 — 2026-08-12

### Ajouté

- Création du paquet (réponse au CR DODLP « écran CRUD assemblé »,
  2026-08-12) : `ZCrudScreen<T>`, écran CRUD **assemblé et déclaratif** —
  liste + recherche + création + édition + sauvegarde + corbeille à partir
  d'une déclaration (`title` + `source`), câblée sur les briques publiques
  existantes (`DynamicList`/`ZTabbedList`, `ZRowAction`, `presentEdition`/
  `ZPresentationPolicy`, `DynamicEdition`/`ZFormController`, `ZRepository`/
  `ZDataRequest.deletedScope`).
- `ZCrudSource<T>` : source déclarative — `.repository(ZRepository<T>)`
  (voie nominale) ou `.items(List<T>, onSave/onSoftDelete/onRestore/isDeleted)`
  (cohabitation ; sans callbacks = lecture seule effective).
- Dérivation depuis le `ZcrudRegistry` : champs de liste et de formulaire
  (`kindOf<T>` → `fieldSpecsFor`, champs `isId` exclus du formulaire),
  projection en cellules (`encode`), reconstruction d'entité (`decode` sur
  valeurs fusionnées — identité conservée). Chaque dérivation surchargeable
  (`listFields`, `formFields`, `cellsOf`, `editionBuilder`).
- Cas exprimables par déclaration : `canCreate: false`,
  `trash: ZTrashMode.none`, `readOnly: true`, ACL refusante (masquage par
  défaut, `actionAclMode` grisable).
- Corbeille voie repository via `ZDeletedScope.deletedOnly` (décorateur de
  requête interne — recherche et pagination inchangées en vue corbeille) ;
  voie items via partition `isDeleted` + fabriques `softDeleteWith`/
  `restoreWith`.
- Mode onglets (`tabs`) : corps `ZTabbedList`, création héritant du contexte
  (`defaultItemBuilder`) et de l'autorisation (`canCreate`) de l'onglet actif.
- `public_member_api_docs` activé (exhaustivité dartdoc vérifiée par
  l'analyse) ; README au gabarit de la charte documentaire ; fiche
  `docs/site/paquets/zcrud_screen.md`.
