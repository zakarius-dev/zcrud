/// Seam de **présentation riche des familles de sélection** (AD-48).
///
/// origine: parité DODLP `awesome_select` (`SmartSelect`) — un présentateur riche
/// (modal/bottom-sheet/chips avec recherche) que l'app peut brancher à la place
/// du rendu natif zcrud des familles `select`/`radio`/`checkbox`/`relation`.
///
/// **Abstraction Material-free au cœur** (patron **strict** de `ZListRenderer`,
/// AD-8) : `zcrud_core` n'expose QUE le contrat + un **DTO neutre**
/// [ZSelectPresentation]. L'implémentation concrète (adossée à `awesome_select`)
/// vit **exclusivement** dans `zcrud_select` (fp-4-1) et est **injectée** via
/// `ZcrudScope.selectPresenter` (défaut `null` → rendu natif conservé). Le cœur
/// n'importe AUCUN paquet de sélection : CORE OUT=0 préservé (AD-1).
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core`
/// (garde `presentation_purity_test.dart`) : AUCUN `awesome_select`, aucune
/// dépendance lourde, aucun gestionnaire d'état.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_field_choice.dart';
import '../../domain/ports/z_relation_crud.dart';
import '../../domain/edition/z_field_spec.dart';

/// **Requête** de chargement d'options adressée à un [ZSelectOptionsLoader]
/// (CR-SELECT-SEAM, 2026-08-09).
///
/// Type **NEUTRE** (Dart pur) : aucun `S2ChoiceLoaderInfo` ni aucun autre type
/// d'un satellite ne franchit la frontière (AD-1/AD-40). Le présentateur
/// traduit ce porte-valeurs vers la forme attendue par son moteur.
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

/// Charge **asynchronement** une page d'options (parité `choiceLoader` DODLP).
///
/// 🔴 **Contrat défensif (AD-10)** : le seam n'exige RIEN de l'hôte. Une `Future`
/// qui **échoue** (`Error` comme `Exception`) ou qui **ne se termine jamais** ne
/// doit pas casser le rendu : c'est au présentateur d'envelopper l'appel et de
/// retomber sur un **rendu dégradé défini** (liste vide + issue de sortie), sans
/// jamais laisser remonter l'exception ni bloquer l'écran.
///
/// 🔴 **AD-2/SM-1** : le chargement ne passe **jamais** par le `ZFormController`
/// et ne doit reconstruire que la surface qui affiche les options — jamais le
/// formulaire.
typedef ZSelectOptionsLoader = Future<List<ZFieldChoice>> Function(
  ZSelectOptionsQuery query,
);

/// Contexte **neutre** d'une option en cours de construction par un
/// [ZSelectChoiceBuilder].
///
/// Porte ce qu'un builder d'option a besoin de **lire** ([choice], [selected],
/// [enabled]) et l'unique action qu'il a le droit d'exercer ([select]).
///
/// 🔴 [select] est indispensable : chez DODLP, tout `choiceBuilder` réel appelle
/// `choice.select!(bool)` depuis son propre contrôle (mesuré : `organigramme`,
/// `users_roles_screen`, `agents_screens`). Un builder **display-only** aurait
/// été une capacité en trompe-l'œil.
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

  /// Sélectionne/désélectionne l'option. Le builder **notifie** — il n'a jamais
  /// accès au `ZFormController` (AD-2).
  final ValueChanged<bool> select;
}

/// Construit le **rendu complet d'une option** (parité `choiceBuilder` DODLP).
///
/// Neutre : ne reçoit qu'un [BuildContext] et un [ZSelectChoiceContext] — aucun
/// type `S2*`, aucun état interne du moteur de sélection (AD-40).
typedef ZSelectChoiceBuilder = Widget Function(
  BuildContext context,
  ZSelectChoiceContext ctx,
);

/// Construit l'**affordance de fin de ligne** d'une option (parité
/// `choiceSecondaryBuilder` DODLP — chez eux, les boutons Modifier/Copier de
/// l'entité liée).
///
/// Retourne `null` pour **ne rien** ajouter à cette option (AD-4 : le slot est
/// alors absent de l'arbre). Même contexte neutre que [ZSelectChoiceBuilder] :
/// l'affordance peut donc aussi sélectionner l'option si elle le souhaite.
typedef ZSelectChoiceSecondaryBuilder = Widget? Function(
  BuildContext context,
  ZSelectChoiceContext ctx,
);

/// DTO **NEUTRE** présenté au seam (AD-48). Ne porte **QUE des données** — jamais
/// le `ZFormController` (AD-2) ni aucun type `awesome_select` (AD-40).
///
/// Suffisant pour `select`/`radio`/`checkbox`/`relation` (fp-4-1) ; extensible
/// **additivement** (aucune montée de version requise).
///
/// ## Élargissement CR-SELECT-SEAM (2026-08-09) — STRICTEMENT ADDITIF
///
/// Trois capacités mesurées comme inatteignables par le lot de fidélité
/// précédent ont été réexaminées ; **deux** ont été ajoutées, **une** ne l'a pas
/// été et **une** n'avait pas lieu d'être :
///
/// | Capacité DODLP | Statut | Motif |
/// |---|---|---|
/// | `field.leading` | ❌ **rien à ajouter** | déjà atteignable : [field] est un `ZFieldSpec` complet, donc `presentation.field.leading` est lisible, et `resolveAdornment` est exporté par le barrel. La mesure « non atteignable » du lot précédent était **fausse**. |
/// | `isLoading` | ✅ ajouté ([isLoading]) | `ZRelationFieldWidget` en dispose réellement (`_isLoading`) et ne le transmettait pas : la règle d'inertie de DODLP était donc irreproductible. |
/// | `choiceBuilder` | ✅ ajouté ([choiceBuilder]) | exprimable **neutrement** via [ZSelectChoiceContext] (l'action `select` incluse). |
/// | `choiceLoader` | ✅ ajouté ([optionsLoader]) | exprimable neutrement via [ZSelectOptionsQuery] — mais cf. la note d'alimentation ci-dessous. |
///
/// 🔴 **Alimentation — ce que les deux sites ont réellement.** `isLoading` est
/// alimenté pour de bon (`relation`). [choiceBuilder] et [optionsLoader] sont
/// des **fermetures** : `ZFieldSpec` est `const`/sérialisable et AD-3/AD-14
/// interdisent d'y loger une closure. Ils sont donc alimentés par un
/// **paramètre de widget** (`ZSelectFieldWidget`/`ZRelationFieldWidget`, tous
/// deux publics), et **pas** par le dispatcher déclaratif : celui-ci exigerait
/// un registre injecté au scope + une clé de config (patron
/// `relationSourceRegistry`/`sourceKey`), surface publique que ce lot n'a pas
/// inventée faute de demande d'un hôte.
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
  /// asynchrone branchée mais silencieuse) — parité `isLoading` DODLP.
  ///
  /// Défaut `false` : un présentateur qui l'ignore rend comme avant.
  ///
  /// 🔴 **Distinct de `options.isEmpty`** : « je n'ai encore rien » et « il n'y
  /// a rien » n'appellent pas le même rendu (indicateur d'attente vs état vide).
  /// C'est précisément la distinction que le seam ne permettait pas de faire.
  final bool isLoading;

  /// Rendu **complet** d'une option, fourni par l'hôte (parité `choiceBuilder`
  /// DODLP). `null` (défaut) ⇒ le présentateur rend l'option lui-même.
  ///
  /// 🔴 Chez DODLP, un `choiceBuilder` **ré-active** le déclencheur même en
  /// lecture seule / en chargement (`choiceBuilder == null && (readOnly ||
  /// isLoading) ? null : showModal`) : le builder est le seul rendu possible de
  /// la donnée, il faut donc pouvoir l'atteindre. Un présentateur fidèle
  /// reproduit cette règle ; sans ce champ elle se réduisait à
  /// `readOnly ⇒ inerte`.
  final ZSelectChoiceBuilder? choiceBuilder;

  /// **Affordance de fin de ligne** d'une option, fournie par l'hôte (parité
  /// `choiceSecondaryBuilder` DODLP). `null` (défaut) ⇒ aucune affordance.
  ///
  /// Complète [choiceBuilder] sans le remplacer : là où [choiceBuilder] REND
  /// l'option entière, celui-ci n'ajoute qu'un widget de fin de ligne au rendu
  /// natif du présentateur (chez DODLP : Modifier / Copier sur l'entité liée).
  final ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder;

  /// Chargeur **asynchrone paginé** d'options (parité `choiceLoader` DODLP).
  /// `null` (défaut) ⇒ [options] est la liste complète, rien n'est chargé.
  ///
  /// 🔴 Quand il est fourni, [options] reste utile : elle sert à résoudre le
  /// **libellé de la sélection courante** avant tout chargement (sans quoi le
  /// déclencheur afficherait le placeholder alors qu'une valeur existe).
  final ZSelectOptionsLoader? optionsLoader;

  /// **CRUD inline** neutre de l'entité liée (port déjà existant du cœur,
  /// `ZRelationCrudHandler` — DP-15/M8, parité `showCrudButton` DODLP).
  /// `null` (défaut) ⇒ aucune action de création/édition dans le sélecteur.
  ///
  /// 🔴 **Pas d'invention** : c'est le port que `ZRelationFieldWidget` résout
  /// déjà au runtime (`ZcrudScope.relationCrudRegistry` +
  /// `ZRelationConfig.crudKey`) et que le rendu NATIF exploite depuis DP-15. Le
  /// seam ne le portait simplement pas, si bien qu'un présentateur riche
  /// **perdait** une capacité que le rendu natif avait — le pire des écarts.
  /// Contrairement à [choiceBuilder]/[optionsLoader], celui-ci est donc alimenté
  /// **de bout en bout, par le dispatcher déclaratif**.
  final ZRelationCrudHandler? crudHandler;
}

/// Seam de **présentation** des familles de sélection (AD-48). Patron `ZListRenderer` :
/// `abstract class` + constructeur `const` + une méthode [present].
///
/// Défaut `null` dans `ZcrudScope` ⇒ le rendu **natif** zcrud est conservé (aucune
/// régression). Une impl concrète (`zcrud_select`) reçoit un [ZSelectPresentation]
/// neutre et retourne le sous-arbre riche.
abstract class ZSelectPresenter {
  /// Constructeur `const` (présentateurs immuables/`const`).
  const ZSelectPresenter();

  /// Construit le widget de sélection pour la [presentation] neutre fournie.
  Widget present(BuildContext context, ZSelectPresentation presentation);
}
