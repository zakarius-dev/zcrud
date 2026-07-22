/// Port de **zone de dépôt native** du cœur `zcrud_core` (abstraction pure —
/// AD-57, patron strict de `ZListRenderer`/AD-8).
///
/// `zcrud_core` n'expose QUE cette abstraction. L'implémentation native vit
/// dans le satellite opt-in `zcrud_dnd` (adossé à `super_drag_and_drop`), et
/// **jamais** dans le cœur : ce paquet embarque du code natif et télécharge des
/// binaires précompilés au build. Comme zcrud est distribué en dépendance git —
/// sans étape de publication qui absorberait ce coût — cette contrainte
/// s'imposerait sinon à **toutes** les applications consommatrices, y compris
/// celles qui n'ont aucun besoin de dépôt de fichiers.
///
/// **Défaut zéro-dépendance** ([ZNoDropRegionRenderer]) : sans satellite, la
/// zone rend son contenu inchangé et ne reçoit aucun dépôt. La capacité est
/// **dégradée, jamais absente** — l'hôte conserve ses autres voies d'import
/// (sélecteur de fichiers, presse-papier). C'est l'exigence d'AD-57.
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core`.
library;

import 'package:flutter/widgets.dart';

import 'z_drop_region_request.dart';

/// Abstraction de rendu d'une zone de dépôt à partir d'une
/// [ZDropRegionRequest] **neutre**.
///
/// Injecté via `ZcrudScope.dropRegionRenderer`. Aucun type du backend
/// n'apparaît dans cette signature : c'est ce qui rend les implémentations
/// interchangeables et le socle indépendant du paquet choisi.
///
/// **Contrat que toute implémentation doit tenir** :
/// 1. rendre `request.child` **inchangé** quand aucun glissement n'est en cours ;
/// 2. n'appeler `onDrop` qu'avec des natures présentes dans `request.accepts` ;
/// 3. **AD-10** — un dépôt corrompu, d'un type inattendu ou dont la lecture
///    échoue ne doit JAMAIS lever : il est ignoré, ou remonté en
///    [ZDropKind.unknown] ;
/// 4. ne jamais matérialiser d'office le contenu binaire (cf. `readBytes`).
abstract class ZDropRegionRenderer {
  /// Constructeur `const` pour permettre des renderers immuables/`const`.
  const ZDropRegionRenderer();

  /// Construit la zone de dépôt pour la [request] neutre fournie.
  Widget build(BuildContext context, ZDropRegionRequest request);
}

/// Défaut **zéro-dépendance** : rend le contenu, sans capacité de dépôt.
///
/// Ce n'est pas un bouchon inerte destiné à être remplacé « un jour » : c'est le
/// comportement **garanti** du socle quand aucun satellite n'est installé. Le
/// SDK Flutter n'offre pas de dépôt natif multi-plateforme ; l'honnêteté est
/// donc de rendre le contenu tel quel plutôt que de simuler une zone active qui
/// n'accepterait jamais rien.
///
/// AD-45 — l'absence de capacité est **structurelle** : aucune affordance
/// visuelle n'est rendue (pas de bordure « déposez ici » qui mentirait), et
/// `onHoverChanged` n'est jamais notifié.
class ZNoDropRegionRenderer extends ZDropRegionRenderer {
  /// Construit le renderer de repli.
  const ZNoDropRegionRenderer();

  @override
  Widget build(BuildContext context, ZDropRegionRequest request) =>
      request.child;
}
