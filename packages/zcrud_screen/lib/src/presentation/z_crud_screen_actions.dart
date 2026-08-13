/// `ZCrudScreenActions` — **le cycle d'édition de l'écran, ouvrable depuis
/// n'importe quelle carte**.
///
/// Une carte métier passée à `ZCrudScreen.itemBuilder` a besoin d'ouvrir
/// l'édition de son élément. Sans point d'accès public, elle ne peut le faire
/// qu'avec un rappel capturé par fermeture — un **court-circuit** qui ne
/// bénéficie ni de la politique de présentation déclarée sur l'écran, ni de
/// son poids de formulaire, ni de sa voie de sauvegarde, ni de son mode, ni de
/// ses titres. Ce scope supprime ce court-circuit : la carte demande à
/// l'écran, l'écran ouvre **sa** surface.
///
/// ```dart
/// class MaCarte extends StatelessWidget {
///   const MaCarte(this.consignataire, {super.key});
///   final Consignataire consignataire;
///
///   @override
///   Widget build(BuildContext context) {
///     // `null` ⇒ le geste n'est pas possible : on ne dessine pas le bouton,
///     // plutôt que d'en dessiner un mort.
///     final ouvrir = zCrudEditionOpener(context, consignataire);
///     return Card(
///       child: ListTile(
///         title: Text(consignataire.nom),
///         onTap: ouvrir,
///         trailing: ouvrir == null
///             ? null
///             : IconButton(
///                 icon: const Icon(Icons.edit_outlined),
///                 tooltip: 'Modifier',
///                 onPressed: ouvrir,
///               ),
///       ),
///     );
///   }
/// }
/// ```
///
/// **Deux scopes, deux endroits de l'arbre.** `ZCrudEditionScope` est posé
/// **autour de la surface présentée** (dialogue, feuille ou page) : il dit au
/// formulaire qu'il est rendu en consultation. Celui-ci est posé **autour du
/// corps de l'écran** : il dit aux tuiles ce que l'écran sait ouvrir. Une carte
/// de la liste n'est jamais un descendant de la surface d'édition — les fondre
/// en un seul scope les rendrait mutuellement inatteignables.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZEntity, ZFilter, ZSort;

/// Ouverture d'une surface de l'écran, déjà liée à son élément.
///
/// Obtenue par [ZCrudScreenActions.editionOpener],
/// [ZCrudScreenActions.updateOpener] ou
/// [ZCrudScreenActions.creationOpener] — toutes trois rendent `null` quand le
/// geste n'est **pas** possible, pour qu'un appelant puisse ne rien dessiner
/// plutôt que de dessiner un bouton inerte.
typedef ZCrudOpener = Future<void> Function();

/// Les gestes d'ouverture qu'un `ZCrudScreen` expose à ses descendants.
///
/// Chaque geste existe en **trois formes**, qui répondent à trois besoins
/// distincts d'une carte :
///
/// | Forme | Usage |
/// |---|---|
/// | `canOpenX(entity)` | interroger la capacité **avant de rendre** |
/// | `openX(entity)` | ouvrir — **inerte** si le geste est refusé |
/// | `xOpener(entity)` | le rappel prêt à poser, ou `null` si refusé |
///
/// **Aucun de ces membres ne lève** (invariant AD-10) : un geste impossible
/// est un `false`, un `null` ou un `Future` qui ne fait rien — jamais une
/// exception. Une entité d'un autre type que celui de l'écran est traitée
/// comme un refus.
///
/// **Le `Future` rendu par une ouverture se complète à la FERMETURE de la
/// surface**, pas à son affichage — c'est celui de la présentation elle-même.
/// Un geste refusé se complète immédiatement. Ne l'attendez donc que si vous
/// voulez enchaîner *après* que l'utilisateur a refermé le formulaire.
///
/// La capacité conjugue **trois** conditions, dans cet ordre : le geste est
/// *voulu* (mode de l'écran, déclaration), *possible* (un formulaire existe,
/// la source sait écrire) et *autorisé* (`ZAcl`, interrogée avec l'entité
/// comme cible — le filtrage est donc par ligne, pas par écran).
abstract interface class ZCrudScreenActions {
  /// La capacité d'ouvrir la surface **nominale** de [entity] : celle que la
  /// ligne offrirait d'elle-même.
  ///
  /// C'est la **fiche en lecture seule** (permission `ZCrudAction.view`) dès
  /// que la consultation est offerte — mode `ZScreenMode.details`, ou mode
  /// `ZScreenMode.full` déclaré `detailsEnabled: true` ; c'est l'**édition**
  /// sinon (mêmes conditions que [canOpenUpdate]). En mode
  /// `ZScreenMode.locked`, ou en vue corbeille, c'est toujours `false`.
  bool canOpenEdition(ZEntity entity);

  /// Ouvre la surface **nominale** de [entity] — voir [canOpenEdition].
  ///
  /// **Inerte** si la capacité est refusée : aucune surface n'est présentée,
  /// aucune exception n'est levée.
  Future<void> openEdition(ZEntity entity);

  /// Le rappel d'ouverture nominale de [entity], ou `null` si le geste est
  /// refusé — la forme à préférer quand la carte doit décider **si** elle
  /// dessine son geste.
  ZCrudOpener? editionOpener(ZEntity entity);

  /// La capacité d'ouvrir la **fiche de détail** de [entity], explicitement :
  /// le formulaire entier, tous ses champs, rendu en lecture seule.
  ///
  /// C'est le pendant de [canOpenUpdate] pour la consultation, et il est
  /// gouverné par `ZCrudAction.view` — lire une fiche n'est pas la modifier.
  ///
  /// `false` tant que la consultation n'est pas **offerte par l'écran** : mode
  /// `ZScreenMode.details`, ou mode `ZScreenMode.full` déclaré
  /// `detailsEnabled: true`. `false` aussi en `ZScreenMode.locked`, en vue
  /// corbeille, et sans formulaire disponible.
  bool canOpenDetails(ZEntity entity);

  /// Ouvre la **fiche de détail** de [entity] — voir [canOpenDetails]. Inerte
  /// si refusé.
  Future<void> openDetails(ZEntity entity);

  /// Le rappel d'ouverture de la fiche de [entity], ou `null` si le geste est
  /// refusé — la forme à préférer pour poser la consultation sur le **tap**
  /// d'une carte métier d'un écran par ailleurs complet :
  ///
  /// ```dart
  /// // Un écran qui crée, met à la corbeille et restaure, ET dont le tap
  /// // ouvre la fiche : les deux ne sont pas exclusifs.
  /// final consulter = zCrudDetailsOpener(context, convocation);
  /// return ListTile(title: Text(convocation.objet), onTap: consulter);
  /// ```
  ZCrudOpener? detailsOpener(ZEntity entity);

  /// La capacité d'ouvrir [entity] **en édition**, explicitement.
  ///
  /// C'est le « retour vers l'édition » depuis une fiche de détail : en mode
  /// `ZScreenMode.details`, il n'est offert que si l'ACL autorise
  /// `ZCrudAction.update`. Une entité **éphémère** (sans identité) relève de
  /// la création : c'est alors `ZCrudAction.create` qui gouverne, puisque
  /// l'enregistrer la crée.
  ///
  /// `false` en mode `ZScreenMode.locked`, en vue corbeille, et dès que la
  /// source ne sait pas écrire.
  bool canOpenUpdate(ZEntity entity);

  /// Ouvre [entity] **en édition** — voir [canOpenUpdate]. Inerte si refusé.
  Future<void> openUpdate(ZEntity entity);

  /// Le rappel d'édition de [entity], ou `null` si le geste est refusé.
  ZCrudOpener? updateOpener(ZEntity entity);

  /// La capacité d'ouvrir une **création** — exactement celle du bouton « + »
  /// de l'écran : même déclaration (`canCreate`, onglet actif), même
  /// permission (`ZCrudAction.create`), même chemin d'édition.
  bool get canOpenCreation;

  /// Ouvre une **création** — voir [canOpenCreation]. Inerte si refusé.
  ///
  /// L'entité initiale est celle que le bouton « + » aurait semée : le
  /// `defaultItemBuilder` de l'onglet actif, sinon celui de l'écran.
  Future<void> openCreation();

  /// Le rappel de création, ou `null` si le geste est refusé.
  ZCrudOpener? creationOpener();

  /// **Trie** le listing de l'écran par les clés données, dans l'ordre.
  ///
  /// C'est le tri *demandé* : il **remplace** le tri par défaut déclaré sur
  /// l'écran (`ZListQueryPolicy.sort`) — deux points de vue empilés ne veulent
  /// rien dire. Une liste vide **rend la main** au tri par défaut.
  ///
  /// Destiné aux vues que l'application pose sous l'écran (en-tête de tri,
  /// menu de colonnes) : elles obtiennent le tri sans construire de contrôleur
  /// de liste, donc sans quitter la déclaration.
  void sortBy(List<ZSort> sort);

  /// **Filtre** le listing de l'écran par les prédicats donnés.
  ///
  /// Ce sont les filtres *demandés* : ils **s'ajoutent** aux filtres
  /// permanents de l'écran (`ZListQueryPolicy.baseFilters`), qui restent
  /// présents dans toutes les requêtes — un appelant ne peut pas lever une
  /// règle du listing en filtrant. Une liste vide retire les seuls filtres
  /// demandés.
  void filterBy(List<ZFilter> filters);
}

/// Contexte posé par `ZCrudScreen` autour de son corps, portant les gestes
/// que l'écran sait ouvrir.
///
/// Hors d'un `ZCrudScreen`, [maybeOf] rend `null` — un widget métier reste
/// donc montable seul, dans une galerie de composants ou une garde, sans rien
/// casser (invariant AD-10).
class ZCrudScreenScope extends InheritedWidget {
  /// Pose les [actions] de l'écran autour de [child].
  const ZCrudScreenScope({
    required this.actions,
    required this.signature,
    required super.child,
    super.key,
  });

  /// Les gestes de l'écran englobant.
  final ZCrudScreenActions actions;

  /// Empreinte des capacités **structurelles** de l'écran (mode, vue courante,
  /// disponibilité de l'édition, de la fiche et de la création).
  ///
  /// Elle sert d'unique critère de notification : deux empreintes égales
  /// signifient que les mêmes gestes restent offerts, et les descendants ne
  /// sont pas reconstruits. Les capacités **par ligne** (filtrage ACL sur une
  /// entité) n'y figurent pas : elles sont recalculées à chaque interrogation.
  final Object signature;

  /// Les gestes de l'écran le plus proche, ou `null` hors d'un `ZCrudScreen`.
  static ZCrudScreenActions? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZCrudScreenScope>()
      ?.actions;

  @override
  bool updateShouldNotify(ZCrudScreenScope oldWidget) =>
      !identical(oldWidget.actions, actions) ||
      oldWidget.signature != signature;
}

/// Le rappel qui ouvre la surface **nominale** de [entity] sur l'écran
/// englobant, ou `null` si le geste n'est pas possible — hors écran, écran
/// verrouillé, vue corbeille, source en lecture seule, ou permission refusée.
///
/// Raccourci de `ZCrudScreenScope.maybeOf(context)?.editionOpener(entity)`,
/// destiné au cas courant : une carte qui décide, **avant de rendre**, si elle
/// dessine son geste d'ouverture.
ZCrudOpener? zCrudEditionOpener(BuildContext context, ZEntity entity) =>
    ZCrudScreenScope.maybeOf(context)?.editionOpener(entity);

/// Le rappel qui ouvre la **fiche de détail** de [entity] sur l'écran
/// englobant, ou `null` si la consultation n'est pas offerte — hors écran,
/// écran verrouillé ou non déclaré consultable, vue corbeille, aucun
/// formulaire, ou `ZCrudAction.view` refusé sur cette ligne.
///
/// Raccourci de `ZCrudScreenScope.maybeOf(context)?.detailsOpener(entity)`.
/// C'est la **forme de geste de ligne** de la fiche : elle s'utilise sur un
/// écran `ZScreenMode.full` — qui continue de créer, de mettre à la corbeille
/// et de restaurer — sans avoir à basculer l'écran entier en mode
/// consultation.
ZCrudOpener? zCrudDetailsOpener(BuildContext context, ZEntity entity) =>
    ZCrudScreenScope.maybeOf(context)?.detailsOpener(entity);
