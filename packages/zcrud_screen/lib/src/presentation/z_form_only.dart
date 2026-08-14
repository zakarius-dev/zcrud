/// **Formulaire seul** : le formulaire déclaratif, sans coquille, piloté de
/// l'extérieur.
///
/// [ZCrudScreen] présente un formulaire dans sa propre surface, avec son
/// en-tête et son pied. Il arrive qu'on veuille l'inverse : poser le formulaire
/// **au milieu d'une page** que l'on compose soi-même — un écran de première
/// connexion, un panneau de profil, une étape d'un assistant — et déclencher la
/// validation depuis un bouton qui ne lui appartient pas.
///
/// [ZFormOnly] rend **exactement** cela : les champs, et rien d'autre. Aucun
/// `Scaffold`, aucune barre d'application, aucun bouton d'enregistrement. Le
/// pilotage passe par [ZFormOnlyController], que l'hôte peut détenir pour
/// valider, lire la validité et récupérer les valeurs **normalisées**.
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        DynamicEdition,
        ZEditionSection,
        ZFieldSpec,
        ZFormController,
        ZResponsiveSpan,
        zNormalizeFormValues,
        zValidateFormFields;

/// Pilotage **extérieur** d'un [ZFormOnly] : valider, connaître la validité,
/// obtenir les valeurs normalisées.
///
/// Le contrôleur peut être créé par l'hôte — c'est le cas dès qu'un bouton
/// **hors** du formulaire doit le soumettre :
///
/// ```dart
/// final form = ZFormOnlyController(
///   fields: monSchema,
///   initialValues: <String, Object?>{'nom': 'Awa'},
/// );
/// // …plus tard, depuis le bouton de la page :
/// final valeurs = form.submit();
/// if (valeurs != null) await monDepot.enregistrer(valeurs);
/// ```
///
/// L'hôte qui construit le contrôleur le **libère** ([dispose]) ; celui qui
/// laisse [ZFormOnly] le créer n'a rien à libérer.
///
/// L'état de saisie vit dans un [ZFormController] (rebuilds granulaires,
/// invariant AD-2) : ce contrôleur-ci n'en est que la façade de commande. Un
/// hôte qui détient déjà un [ZFormController] le passe en [form] et le garde
/// sous sa responsabilité.
class ZFormOnlyController {
  /// Construit le pilotage d'un formulaire déclaré par [fields].
  ///
  /// [initialValues] pré-remplit les champs. [form] permet de réutiliser un
  /// [ZFormController] existant — dans ce cas [initialValues] est **ignoré**
  /// (le contrôleur fourni porte déjà son état) et [dispose] ne le libère pas :
  /// il appartient à celui qui l'a créé.
  ///
  /// [conditionContext] alimente les conditions d'affichage de source
  /// `contexte` — les mêmes clés que celles remises au formulaire, pour que
  /// l'affichage et la validation voient toujours la même chose.
  ZFormOnlyController({
    required this.fields,
    Map<String, Object?>? initialValues,
    ZFormController? form,
    this.conditionContext = const <String, Object?>{},
  })  : _ownsForm = form == null,
        form = form ??
            ZFormController(
              initialValues: initialValues,
              visibleFields: <String>[for (final f in fields) f.name],
            );

  /// Schéma du formulaire — source des validateurs, des conditions
  /// d'affichage et de la normalisation.
  final List<ZFieldSpec> fields;

  /// Contrôleur d'état des champs. Exposé pour les usages fins (écouter une
  /// tranche, recharger des valeurs via `reseed`, observer `isDirty`).
  final ZFormController form;

  /// Clés externes lues par les conditions d'affichage de source `contexte`.
  final Map<String, Object?> conditionContext;

  final bool _ownsForm;
  bool _disposed = false;

  /// `true` tant qu'au moins un champ s'écarte de son état initial.
  ValueListenable<bool> get isDirty => form.isDirty;

  /// Valide tous les champs **visibles** et retourne la table
  /// `nom du champ → message` (vide ⇒ formulaire valide).
  ///
  /// Lecture **pure** : aucun message n'est affiché. Pour faire apparaître les
  /// erreurs à l'écran, utilisez [revealErrors] ou [submit].
  Map<String, String> validate() => zValidateFormFields(
        fields: fields,
        controller: form,
        persistedValueOf: form.baselineValueOf,
        contextValueOf: (key) => conditionContext[key],
      );

  /// `true` si aucun champ visible n'est en erreur. N'affiche rien.
  bool get isValid => validate().isEmpty;

  /// Fait **apparaître** les messages d'erreur de tous les champs, y compris
  /// ceux qui ne sont pas des champs de texte. C'est la voie « le bouton de ma
  /// page a été pressé, montre ce qui manque ».
  void revealErrors() => form.revealErrors();

  /// Valeurs **normalisées** du formulaire : types coercés, dates en ISO-8601,
  /// valeurs d'énumération en camelCase.
  ///
  /// Les champs **en lecture seule** et ceux dont la condition d'affichage est
  /// fausse en sont **absents** : ce qui n'était pas modifiable, ou pas
  /// visible, n'a pas été décidé par l'utilisateur.
  ///
  /// Ces valeurs ne sont **pas** validées : `values` répond « qu'y a-t-il dans
  /// le formulaire », [submit] répond « qu'est-ce qui peut être enregistré ».
  Map<String, dynamic> get values => zNormalizeFormValues(
        fields: fields,
        controller: form,
        persistedValueOf: form.baselineValueOf,
        contextValueOf: (key) => conditionContext[key],
      );

  /// Soumet le formulaire **depuis l'extérieur** : valide, et
  ///
  /// * si un champ visible est en erreur ⇒ affiche les messages et retourne
  ///   `null` — **aucune donnée n'est rendue**, jamais une demi-soumission ;
  /// * sinon ⇒ retourne les [values] normalisées.
  ///
  /// N'enregistre rien et ne ferme rien : la suite appartient à l'hôte.
  Map<String, dynamic>? submit() {
    if (validate().isNotEmpty) {
      revealErrors();
      return null;
    }
    return values;
  }

  /// Libère le [ZFormController] **si** ce contrôleur l'a créé. Un contrôleur
  /// fourni par l'hôte n'est jamais libéré ici. Appel idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_ownsForm) form.dispose();
  }
}

/// Le formulaire déclaratif **nu** : les champs de [fields], et rien d'autre.
///
/// Aucune coquille n'est montée — ni `Scaffold`, ni barre d'application, ni
/// bouton d'enregistrement : c'est la page hôte qui les fournit, ou pas.
///
/// ```dart
/// class PremiereConnexion extends StatefulWidget { … }
///
/// final _form = ZFormOnlyController(fields: motDePasseFields);
///
/// Scaffold(
///   appBar: AppBar(title: const Text('Bienvenue')),
///   body: ZFormOnly(controller: _form),
///   bottomNavigationBar: FilledButton(
///     onPressed: () async {
///       final valeurs = _form.submit();
///       if (valeurs == null) return; // erreurs affichées, rien à enregistrer
///       await monService.changerMotDePasse(valeurs);
///     },
///     child: const Text('Valider'),
///   ),
/// );
/// ```
///
/// Fournissez soit un [controller] (l'hôte pilote et libère), soit [fields]
/// (le formulaire crée son pilotage et le libère lui-même).
class ZFormOnly extends StatefulWidget {
  /// Construit un formulaire nu.
  ///
  /// [controller] et [fields] ne peuvent pas être `null` tous les deux. Quand
  /// [controller] est fourni, il fait autorité : [fields], [initialValues] et
  /// [conditionContext] sont alors lus **sur lui** — un schéma déclaré à deux
  /// endroits finirait par diverger.
  ZFormOnly({
    super.key,
    this.controller,
    this.fields,
    this.initialValues,
    this.conditionContext = const <String, Object?>{},
    this.readOnly = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
    this.sections = const <ZEditionSection>[],
    this.layout = const <String, ZResponsiveSpan>{},
    this.interFieldGap,
  }) : assert(
          controller != null || fields != null,
          'ZFormOnly : fournissez `controller` (pilotage détenu par la page) '
          'ou `fields` (le formulaire crée son propre pilotage).',
        );

  /// Pilotage fourni par l'hôte. `null` ⇒ le formulaire en crée un depuis
  /// [fields] / [initialValues] / [conditionContext], et le libère.
  final ZFormOnlyController? controller;

  /// Schéma des champs. Requis quand [controller] est `null`, ignoré sinon.
  final List<ZFieldSpec>? fields;

  /// Valeurs de départ. Ignorées quand [controller] est fourni.
  final Map<String, Object?>? initialValues;

  /// Contexte des conditions d'affichage. Ignoré quand [controller] est fourni.
  final Map<String, Object?> conditionContext;

  /// Rend tous les champs en consultation (aucune saisie possible).
  final bool readOnly;

  /// `shrinkWrap` de la liste de champs — à activer pour imbriquer le
  /// formulaire dans une page qui défile déjà.
  final bool shrinkWrap;

  /// Physique de défilement de la liste de champs.
  final ScrollPhysics? physics;

  /// Marge autour des champs. `null` ⇒ l'aération du thème.
  final EdgeInsetsGeometry? padding;

  /// Sections visuelles (en-têtes, repliage). Vide ⇒ liste plate.
  final List<ZEditionSection> sections;

  /// Grille responsive : largeur de chaque champ par nom. Vide ⇒ pleine
  /// largeur.
  final Map<String, ZResponsiveSpan> layout;

  /// Espacement entre deux champs. `null` ⇒ le jeton d'aération du thème.
  final double? interFieldGap;

  @override
  State<ZFormOnly> createState() => _ZFormOnlyState();
}

class _ZFormOnlyState extends State<ZFormOnly> {
  late final ZFormOnlyController _controller = widget.controller ??
      ZFormOnlyController(
        fields: widget.fields!,
        initialValues: widget.initialValues,
        conditionContext: widget.conditionContext,
      );

  /// `true` quand le pilotage a été créé ici — c'est alors, et seulement
  /// alors, qu'il est libéré au démontage.
  bool get _owned => widget.controller == null;

  @override
  void dispose() {
    if (_owned) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DynamicEdition(
        controller: _controller.form,
        fields: _controller.fields,
        conditionContext: _controller.conditionContext,
        sections: widget.sections,
        layout: widget.layout,
        interFieldGap: widget.interFieldGap,
        padding: widget.padding,
        shrinkWrap: widget.shrinkWrap,
        physics: widget.physics,
        readOnly: widget.readOnly,
      );
}
