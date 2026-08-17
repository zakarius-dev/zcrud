/// Seam de **présentation riche des familles de sélection**.
///
/// Un présentateur riche (modal/bottom-sheet/chips avec recherche) que
/// l'application peut brancher à la place du rendu natif zcrud des familles
/// `select`/`radio`/`checkbox`/`relation`.
///
/// **Abstraction Material-free au cœur** (même patron que `ZListRenderer`,
/// invariant AD-8) : `zcrud_core` n'expose QUE le contrat + un **DTO neutre**
/// [ZSelectPresentation]. Une implémentation concrète (adossée par exemple à
/// `awesome_select`) vit **exclusivement** dans un paquet satellite et est
/// **injectée** via `ZcrudScope.selectPresenter` (défaut `null` → rendu natif
/// conservé). Le cœur n'importe aucun paquet de sélection (invariant AD-1).
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core` :
/// aucune dépendance lourde, aucun gestionnaire d'état.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_field_choice.dart';
import '../../domain/ports/z_relation_crud.dart';
import '../../domain/edition/z_field_spec.dart';

/// **Requête** de chargement d'options adressée à un [ZSelectOptionsLoader].
///
/// Type **NEUTRE** (Dart pur) : aucun type d'un satellite (par exemple un
/// `S2ChoiceLoaderInfo` d'un moteur de sélection concret) ne franchit la
/// frontière (invariant AD-1). Le présentateur traduit ce porte-valeurs vers
/// la forme attendue par son moteur.
@immutable
class ZSelectOptionsQuery {
  /// Construit une requête de page d'options.
  const ZSelectOptionsQuery({this.search, this.page = 1, this.limit});

  /// Texte de recherche saisi par l'utilisateur, `null` si aucun filtre.
  final String? search;

  /// Numéro de page demandé, **1-based** (`1` = première page).
  final int page;

  /// Taille de page souhaitée, `null` si le présentateur n'en impose aucune.
  final int? limit;
}

/// Charge **asynchronement** une page d'options.
///
/// **Contrat défensif (invariant AD-10)** : le seam n'exige RIEN de l'hôte.
/// Une `Future` qui **échoue** ou qui **ne se termine jamais** ne doit pas
/// casser le rendu : c'est au présentateur d'envelopper l'appel et de retomber
/// sur un **rendu dégradé défini** (liste vide + issue de sortie), sans
/// jamais laisser remonter l'exception ni bloquer l'écran.
///
/// **Réactivité granulaire (invariant AD-2)** : le chargement ne passe
/// **jamais** par le `ZFormController` et ne doit reconstruire que la
/// surface qui affiche les options — jamais le formulaire.
typedef ZSelectOptionsLoader = Future<List<ZFieldChoice>> Function(
  ZSelectOptionsQuery query,
);

/// Contexte **neutre** d'une option en cours de construction par un
/// [ZSelectChoiceBuilder].
///
/// Porte ce qu'un builder d'option a besoin de **lire** ([choice], [selected],
/// [enabled]) et l'unique action qu'il a le droit d'exercer ([select]).
///
/// [select] est indispensable : un builder de rendu d'option a presque
/// toujours besoin de déclencher lui-même la sélection depuis son propre
/// contrôle — un builder strictement lecture-seule serait une capacité en
/// trompe-l'œil.
@immutable
class ZSelectChoiceContext {
  /// Construit le contexte d'une option servie à un builder hôte.
  const ZSelectChoiceContext({
    required this.choice,
    required this.selected,
    required this.enabled,
    required this.select,
  });

  /// L'option **neutre** rendue.
  final ZFieldChoice choice;

  /// `true` si l'option fait partie de la sélection courante.
  final bool selected;

  /// `false` si l'option n'est pas actionnable (lecture seule ou
  /// `ZFieldChoice.disabled`).
  final bool enabled;

  /// Sélectionne/désélectionne l'option. Le builder **notifie** — il n'a
  /// jamais accès au `ZFormController` (invariant AD-2).
  final ValueChanged<bool> select;
}

/// Construit le **rendu complet d'une option**.
///
/// Neutre : ne reçoit qu'un [BuildContext] et un [ZSelectChoiceContext] —
/// aucun état interne du moteur de sélection concret.
typedef ZSelectChoiceBuilder = Widget Function(
  BuildContext context,
  ZSelectChoiceContext ctx,
);

/// Construit l'**affordance de fin de ligne** d'une option (par exemple des
/// boutons Modifier/Copier sur l'entité liée).
///
/// Retourne `null` pour **ne rien** ajouter à cette option (invariant AD-4 :
/// le slot est alors absent de l'arbre). Même contexte neutre que
/// [ZSelectChoiceBuilder] : l'affordance peut donc aussi sélectionner
/// l'option si elle le souhaite.
typedef ZSelectChoiceSecondaryBuilder = Widget? Function(
  BuildContext context,
  ZSelectChoiceContext ctx,
);

/// DTO **NEUTRE** présenté au seam. Ne porte **QUE des données** — jamais le
/// `ZFormController` (invariant AD-2) ni aucun type d'un présentateur
/// concret.
///
/// Suffisant pour `select`/`radio`/`checkbox`/`relation` ; extensible
/// **additivement** (aucune montée de version requise).
///
/// **Où vivent [choiceBuilder] et [optionsLoader]** : `ZFieldSpec` est
/// `const`/sérialisable et les invariants AD-3/AD-14 interdisent d'y loger une
/// closure. Ils sont donc alimentés par un **paramètre de widget**
/// (`ZSelectFieldWidget`/`ZRelationFieldWidget`, tous deux publics), et pas
/// par le dispatcher déclaratif : celui-ci exigerait un registre injecté au
/// scope + une clé de configuration, surface publique que ce seam n'expose
/// pas en l'absence de besoin démontré.
@immutable
class ZSelectPresentation {
  /// Construit le contrat neutre transmis au présentateur.
  ///
  /// [isLoading], [choiceBuilder] et [optionsLoader] sont **additifs** : leurs
  /// défauts (`false`/`null`/`null`) restituent **exactement** le contrat
  /// antérieur, et un présentateur qui les ignore rend à l'identique.
  const ZSelectPresentation({
    required this.field,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.multiple,
    required this.searchable,
    required this.readOnly,
    this.label,
    this.isLoading = false,
    this.choiceBuilder,
    this.choiceSecondaryBuilder,
    this.optionsLoader,
    this.crudHandler,
  });

  /// Spécification `const` du champ rendu (déjà neutre : `name`/`type`/…).
  final ZFieldSpec field;

  /// Options **effectives** résolues (statiques ou dynamiques cross-champ).
  final List<ZFieldChoice> options;

  /// Valeur(s) courante(s) de la tranche : scalaire en mono, `List<Object?>` en
  /// multi ([multiple]).
  final Object? selected;

  /// Écrit la sélection dans la tranche (scalaire en mono, `List` en multi). Le
  /// présentateur n'a JAMAIS accès au controller : il ne fait que **notifier**.
  final ValueChanged<Object?> onChanged;

  /// Mode **multi** (`checkbox`/`select` multi) vs **mono** (`select`/`radio`).
  final bool multiple;

  /// Recherche activable (modal filtrant).
  final bool searchable;

  /// Champ en lecture seule (le présentateur désactive l'édition).
  final bool readOnly;

  /// Libellé **déjà résolu** (l10n) du champ, `null` si aucun.
  final String? label;

  /// `true` tant que les options **ne sont pas encore connues** (source
  /// asynchrone branchée mais silencieuse).
  ///
  /// Défaut `false` : un présentateur qui l'ignore rend comme avant.
  ///
  /// **Distinct de `options.isEmpty`** : « je n'ai encore rien » et « il n'y
  /// a rien » n'appellent pas le même rendu (indicateur d'attente vs état vide).
  final bool isLoading;

  /// Rendu **complet** d'une option, fourni par l'hôte. `null` (défaut) ⇒ le
  /// présentateur rend l'option lui-même.
  ///
  /// Quand [choiceBuilder] est fourni, il reste le seul rendu possible de la
  /// donnée même en lecture seule ou en chargement : un présentateur fidèle
  /// laisse le builder atteignable dans ces états plutôt que de le neutraliser
  /// silencieusement.
  final ZSelectChoiceBuilder? choiceBuilder;

  /// **Affordance de fin de ligne** d'une option, fournie par l'hôte. `null`
  /// (défaut) ⇒ aucune affordance.
  ///
  /// Complète [choiceBuilder] sans le remplacer : là où [choiceBuilder] REND
  /// l'option entière, celui-ci n'ajoute qu'un widget de fin de ligne au rendu
  /// natif du présentateur.
  final ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder;

  /// Chargeur **asynchrone paginé** d'options. `null` (défaut) ⇒ [options] est
  /// la liste complète, rien n'est chargé.
  ///
  /// Quand il est fourni, [options] reste utile : elle sert à résoudre le
  /// **libellé de la sélection courante** avant tout chargement (sans quoi le
  /// déclencheur afficherait le placeholder alors qu'une valeur existe).
  final ZSelectOptionsLoader? optionsLoader;

  /// **CRUD inline** neutre de l'entité liée (port déjà existant du cœur,
  /// `ZRelationCrudHandler`). `null` (défaut) ⇒ aucune action de
  /// création/édition dans le sélecteur.
  ///
  /// C'est le port que `ZRelationFieldWidget` résout déjà au runtime
  /// (`ZcrudScope.relationCrudRegistry` + `ZRelationConfig.crudKey`) et que le
  /// rendu natif exploite. Contrairement à [choiceBuilder]/[optionsLoader],
  /// celui-ci est donc alimenté **de bout en bout, par le dispatcher
  /// déclaratif** — un présentateur riche ne doit pas perdre une capacité que
  /// le rendu natif possède déjà.
  ///
  /// 🔴 **Un handler non `null` n'autorise pas les trois gestes.** Depuis que
  /// le port les gouverne séparément, un présentateur DOIT gouverner chaque
  /// affordance par `offersCreate` / `offersEdit` / `offersCopy`
  /// (`ZRelationCrudOffer`, lecture défensive AD-10) — jamais par le seul
  /// `crudHandler != null`, qui rendrait des boutons que l'ACL de l'hôte
  /// refuse. Un geste refusé est **absent**, jamais grisé :
  ///
  /// ```dart
  /// if (presentation.crudHandler case final crud? when crud.offersCreate)
  ///   monBoutonCreer(),
  /// ```
  final ZRelationCrudHandler? crudHandler;
}

/// Seam de **présentation** des familles de sélection. Même patron que
/// `ZListRenderer` : `abstract class` + constructeur `const` + une méthode
/// [present].
///
/// Défaut `null` dans `ZcrudScope` ⇒ le rendu **natif** zcrud est conservé
/// (aucune régression). Une implémentation concrète reçoit un
/// [ZSelectPresentation] neutre et retourne le sous-arbre riche.
abstract class ZSelectPresenter {
  /// Constructeur `const` (présentateurs immuables/`const`).
  const ZSelectPresenter();

  /// Construit le widget de sélection pour la [presentation] neutre fournie.
  Widget present(BuildContext context, ZSelectPresentation presentation);
}
