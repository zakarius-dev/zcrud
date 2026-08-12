/// Barrel d'API publique de `zcrud_screen`.
///
/// Écran CRUD **assemblé et déclaratif** : [ZCrudScreen] est à `DynamicList`
/// ce que `DynamicEdition` est aux champs — la pièce qui prend une déclaration
/// (`title` + [ZCrudSource]) et rend un écran fonctionnel : liste + recherche
/// + création + édition (présentée via `presentEdition`) + sauvegarde +
/// corbeille, chaque geste gouverné par l'ACL.
///
/// **Dépendances (invariant AD-1)** : ce package dépend de `zcrud_core` et de
/// `zcrud_navigation` (arêtes SORTANTES uniquement — l'assemblage ne monte pas
/// dans le cœur, `presentEdition`/`ZPresentationPolicy` vivant dans
/// `zcrud_navigation`). Aucun gestionnaire d'état, aucun Syncfusion, aucun
/// backend.
///
/// **Dérivation (objectif « déclarer, jamais recoudre »)** : quand le type est
/// enregistré au `ZcrudRegistry`, les champs de liste et de formulaire, la
/// projection en cellules et la reconstruction d'entité se dérivent du schéma
/// généré (`kindOf` → `fieldSpecsFor` / `encode` / `decode`) ; l'ACL vient du
/// `ZcrudScope` ambiant. Chaque dérivation reste remplaçable par un paramètre.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_crud_screen.dart';
export 'src/presentation/z_crud_source.dart';
