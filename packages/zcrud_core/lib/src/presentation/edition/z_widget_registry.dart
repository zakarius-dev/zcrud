/// `ZWidgetRegistry` — **registre de widgets d'édition** injecté (invariant
/// AD-4).
///
/// Le repli `ZUnsupportedFieldWidget` est remplacé, pour les types couverts,
/// par un **registre de widgets**. Ce registre associe un `kind` (`String`) à
/// un **builder de widget** que le dispatcher `ZFieldWidget` rend **dans** la
/// frontière de rebuild existante (`ZFieldListenableBuilder`, value-in-slice)
/// pour les types dont le widget vit **hors du cœur** (markdown, géo/tél,
/// `custom` → app hôte).
///
/// Ce registre est **DISTINCT** de `ZTypeRegistry` (domaine, pur-Dart) qui
/// enregistre des **codecs** `fromJson`/`toJson` — PAS des `Widget`. Un
/// registre de widgets a besoin de Flutter → il vit en couche
/// `presentation/`. La convention de `kind` est **alignée** sur
/// `ZTypeRegistry` (nom d'`EditionFieldType` pour les types enum ;
/// discriminant `custom` pour `EditionFieldType.custom`) : une app hôte
/// enregistre **codec + widget sous le même `kind`**.
///
/// **Invariant AD-4** : le registre est **INSTANCIABLE** et injecté via
/// `ZcrudScope.widgetRegistry` — **jamais** un singleton statique mutable. Le
/// cœur reste **agnostique** des widgets externes (aucun import markdown/géo/
/// tél ; graphe OUT=0 inchangé) : le widget réel est fourni par le package
/// satellite / l'app.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_condition_evaluator.dart' show ZValueOf;
import '../../domain/edition/z_field_spec.dart';
import '../../domain/registry/z_registry_error.dart';

/// Contexte passé à un [ZFieldWidgetBuilder] : la spec du champ, la valeur
/// COURANTE de sa tranche, le callback d'écriture et un **lecteur nommé**
/// ([valueOf]) des autres champs du même formulaire. Le builder **lit** [value]
/// et **écrit** via [onChanged] — l'appel reste **dans** la frontière de rebuild
/// du dispatcher (invariant AD-2 : aucune souscription élargie).
///
/// ## Lire un AUTRE champ du même formulaire ([valueOf])
///
/// Un widget hôte peut dépendre d'un champ voisin (afficher une action selon
/// qu'un mot de passe a été saisi, résumer une date choisie plus haut…).
/// [valueOf] donne cette lecture **par nom**, sans exposer le contrôleur :
///
/// ```dart
/// registre.register('reauth', (context, ctx) {
///   final ancien = ctx.valueOf?.call('ancienMotDePasse');
///   return Text(ancien == null || '$ancien'.isEmpty ? '' : 'Réauthentifier');
/// });
/// ```
///
/// Ce que [valueOf] **garantit** :
/// - **lecture nommée** de la valeur courante d'une tranche du MÊME formulaire,
///   telle qu'elle s'y trouve (aucune conversion, aucune projection) ;
/// - **abonnement ciblé** : le socle observe les noms que le builder a
///   réellement lus et reconstruit ce champ — et lui seul — quand l'une de ces
///   valeurs change. Un champ jamais lu ne provoque aucun rebuild
///   (invariant AD-2) ;
/// - **défensivité** (invariant AD-10) : un nom inconnu rend `null`, jamais une
///   exception.
///
/// Ce que [valueOf] **ne fait pas** :
/// - il **n'écrit rien** — c'est une lecture ; l'écriture passe par [onChanged],
///   et un ornement (voir ci-dessous) n'écrit jamais ;
/// - il **n'expose pas l'état complet** du formulaire : ni la liste des champs,
///   ni le `ZFormController`, ni les canaux de validation/soumission. La
///   surface se limite à une valeur par nom ;
/// - il **ne traverse pas** les formulaires imbriqués : la lecture porte sur le
///   formulaire qui rend le champ.
///
/// [valueOf] peut être `null` lorsque le widget est rendu **hors** d'un
/// formulaire (composition manuelle, prévisualisation) : le builder doit donc
/// l'appeler avec `?.call(...)` et prévoir le repli.
///
/// ## Ornements (`ZFieldAdornment.widget`)
///
/// Le même contexte sert les ornements `leading`/`prefix`/`suffix` de type
/// `.widget`. Ils reçoivent [value] (la valeur du champ qu'ils ornent) et
/// [valueOf], mais leur [onChanged] est **inerte** : un ornement est un
/// affichage. Lire n'est pas écrire.
///
/// ## Champ custom à valeur **STRUCTURÉE**
///
/// Un champ composite (ex. `ressource → opérations autorisées`) n'a **rien de
/// spécial** à obtenir : le socle le porte déjà de bout en bout.
///
/// 1. **Écrire une `Map`** — [onChanged] est un `ValueChanged<Object?>`, pas un
///    `ValueChanged<String>`. `ctx.onChanged({'agent': ['read','update']})`
///    dépose la map **telle quelle** dans la tranche ; `controller.valueOf` la
///    rend inchangée. Aucune sérialisation intermédiaire, aucun encodage.
/// 2. **Requis** — un `ZValidatorSpec.required` **mord sur une map vide**. Le
///    dispatcher projette la valeur par `zValidationText` (règle unique
///    `zIsEmptyValue` : `null`, chaîne, `Iterable` et **`Map`** vides comptent
///    comme vides), puis affiche l'erreur sous le widget custom via la surface
///    accessible `Semantics(liveRegion:)` — la famille registre n'est pas une
///    famille clavier, elle passe donc par cette surface et non par
///    `TextFormField.errorText`. La soumission et le gate d'étape appliquent
///    la MÊME règle, via la MÊME projection : trois voies, une seule source
///    de vérité.
/// 3. **Rebuild granulaire (invariant AD-2)** — le widget custom est monté DANS
///    le `ZFieldListenableBuilder` de sa tranche : changer une entrée de la map
///    ne reconstruit **que ce champ**. Corollaire à respecter côté hôte :
///    écrire une **nouvelle** map (copie) plutôt que muter celle reçue — une
///    mutation en place ne notifie rien.
/// 4. **Validation métier au-delà du requis** — elle ne s'exprime pas dans
///    `validators` (qui compile des `FormFieldValidator<String>` sur la
///    projection texte). Deux voies : soit le widget custom refuse d'écrire un
///    état invalide (la tranche ne contient alors que du valide), soit la règle
///    se pose en **inter-champs** (`ZCrossFieldValidator`).
///
/// **Lecture seule** : la famille registre n'est PAS « fiche-able » — un champ
/// custom rend lui-même son état `ctx.field.readOnly`. Le socle ne devinera pas
/// la présentation lisible d'une structure qu'il ne connaît pas.
///
/// **Sérialisation** : la map vit dans la tranche puis dans le `Map` soumis ;
/// sa (dé)sérialisation est celle du modèle (invariant AD-3), sa **relecture
/// défensive** celle de l'invariant AD-10 (une entrée absente/corrompue ne
/// fait jamais échouer le parent). Le cœur ne s'interpose pas.
///
/// Ce qui reste **hors du socle** : l'éditeur lui-même. Un tableau de
/// permissions est une décision **métier** de l'application — le socle fournit
/// le moyen (tranche typée `Object?`, requis, granularité), jamais l'écran.
@immutable
class ZFieldWidgetContext {
  /// Construit le contexte d'un champ servi par le registre.
  const ZFieldWidgetContext({
    required this.field,
    required this.value,
    required this.onChanged,
    this.valueOf,
  });

  /// Spécification `const` du champ rendu (`name`/`type`/`label`/`config`…).
  final ZFieldSpec field;

  /// Valeur COURANTE de la tranche `field.name` (lue par le builder hôte).
  final Object? value;

  /// Écrit une nouvelle valeur dans la tranche (branché sur `setValue`).
  ///
  /// **Inerte pour un ornement** `ZFieldAdornment.widget` : un ornement est un
  /// affichage, il ne modifie jamais la tranche qu'il orne.
  final ValueChanged<Object?> onChanged;

  /// Lecteur **nommé** des autres champs du même formulaire — `null` hors
  /// formulaire.
  ///
  /// Rend la valeur courante de la tranche demandée (`null` si le nom est
  /// inconnu, jamais d'exception — invariant AD-10) et **abonne** ce champ aux
  /// seules tranches réellement lues : changer un champ que le builder ne lit
  /// pas ne le reconstruit pas (invariant AD-2). Lecture seule : aucune
  /// écriture, aucun accès à l'état complet du formulaire (voir la
  /// documentation de [ZFieldWidgetContext]).
  final ZValueOf? valueOf;
}

/// Construit le widget d'édition d'un champ à partir de son [ZFieldWidgetContext].
///
/// Fourni par un package satellite / l'app hôte (jamais par le cœur). Si le
/// widget nécessite un contrôleur isolé (cas rich-text, invariant AD-7),
/// c'est **sa** responsabilité — le cœur ne gère pas sa stabilité.
typedef ZFieldWidgetBuilder = Widget Function(
  BuildContext context,
  ZFieldWidgetContext ctx,
);

/// Registre **instanciable** de builders de widgets d'édition, discriminés par
/// `kind` (`String`). Injecté via `ZcrudScope.widgetRegistry` (invariant
/// AD-4 — jamais un singleton statique mutable).
///
/// API alignée sur `ZTypeRegistry`/`ZOpenRegistry` (register/isRegistered/kinds
/// + lookup strict/défensif) : `builderFor` **throw** [ZUnregisteredTypeError]
/// si absent (bug de configuration, invariant AD-3) ; `tryBuilderFor` retourne
/// `null` (chemin défensif utilisé par le dispatcher pour retomber sur le
/// repli).
///
/// ## Chaînage parent (surcharge locale sans recopie)
///
/// `ZWidgetRegistry(parent: ambiant)` crée un registre **enfant** dont le
/// lookup, lorsqu'un `kind` manque localement, **remonte la chaîne** vers le
/// parent. La surcharge locale d'un scope dérivé
/// (`ZcrudScope.derive(widgetRegistry: …)`) s'écrit alors sans recopier — donc
/// sans **oublier** — les builders ambiants :
///
/// ```dart
/// final registre = ZWidgetRegistry(parent: ambiant)
///   ..register('widget', monBuilder);
/// ```
///
/// La chaîne est **vivante** : un builder enregistré sur le parent **APRÈS**
/// la création de l'enfant est visible de l'enfant (contrairement à une copie
/// figée). Elle est **acyclique par construction** : [parent] est `final`,
/// fourni au constructeur — un registre ne peut pas se précéder lui-même dans
/// sa propre chaîne.
class ZWidgetRegistry {
  /// Construit un registre de widgets, vide localement, chaîné sur un
  /// éventuel [parent] (lookup en cascade enfant → parent).
  ZWidgetRegistry({this.parent});

  /// Registre **parent** consulté quand un `kind` manque localement (`null` ⇒
  /// registre racine, comportement historique inchangé). La chaîne reflète les
  /// ajouts **ultérieurs** du parent.
  final ZWidgetRegistry? parent;

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZWidgetRegistry';

  final Map<String, ZFieldWidgetBuilder> _builders = <String, ZFieldWidgetBuilder>{};

  /// Enregistre le [builder] de [kind]. Collision **locale** → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux,
  /// invariant AD-3). Enregistrer un `kind` déjà servi par le [parent] est en
  /// revanche **permis** : c'est l'**ombrage** (enfant > parent), la raison
  /// d'être du chaînage.
  void register(String kind, ZFieldWidgetBuilder builder) {
    if (_builders.containsKey(kind)) {
      throw ZDuplicateRegistrationError(kind: kind, registryName: _name);
    }
    _builders[kind] = builder;
  }

  /// `true` si un builder est enregistré pour [kind] — localement **ou** dans
  /// la chaîne parent.
  bool isRegistered(String kind) =>
      _builders.containsKey(kind) || (parent?.isRegistered(kind) ?? false);

  /// Les `kind` actuellement servis : **union** des kinds locaux et de la
  /// chaîne parent (dédupliquée — un `kind` ombré par l'enfant n'apparaît
  /// qu'une fois, et c'est le builder **enfant** que le lookup rend).
  Iterable<String> get kinds =>
      <String>{..._builders.keys, ...?parent?.kinds};

  /// Lookup **strict** : le builder de [kind] (enfant d'abord, puis chaîne
  /// parent), ou **`throw`** [ZUnregisteredTypeError] si absent partout
  /// (invariant AD-3).
  ZFieldWidgetBuilder builderFor(String kind) {
    final builder = tryBuilderFor(kind);
    if (builder == null) {
      throw ZUnregisteredTypeError(kind: kind, registryName: _name);
    }
    return builder;
  }

  /// Lookup **défensif** : le builder de [kind] (enfant d'abord — **ombrage**
  /// enfant > parent —, puis chaîne parent), ou `null` si absent partout
  /// (invariant AD-10) — utilisé par le dispatcher pour retomber sur
  /// `ZUnsupportedFieldWidget`.
  ZFieldWidgetBuilder? tryBuilderFor(String kind) =>
      _builders[kind] ?? parent?.tryBuilderFor(kind);
}
