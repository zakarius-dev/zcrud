/// **Édition en fenêtre contextuelle rendant une carte de valeurs.**
///
/// Toutes les données à éditer ne sont pas des entités : un bloc de
/// configuration, un filtre avancé, un paramètre d'export n'ont ni dépôt ni
/// modèle typé. Ils ont pourtant un schéma — des [ZFieldSpec] — et méritent le
/// même formulaire, la même validation, la même présentation adaptative.
///
/// [presentFormEdition] ouvre ce formulaire en **page, feuille ou dialogue**
/// (selon la politique de présentation en vigueur) et rend à l'appelant la
/// **carte des valeurs normalisées** — ou `null` si l'utilisateur a renoncé.
///
/// Le **corps** de cette fenêtre se décline en trois formes, sans jamais
/// changer le contrat de sortie :
///
/// | Déclaration | Corps monté |
/// |---|---|
/// | `fields` seuls (défaut) | le formulaire à plat ([ZFormOnly]) |
/// | `fields` + `steps` | l'assistant multi-étapes (`ZStepperEdition`) |
/// | `bodyBuilder` | le corps que vous composez vous-même |
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZConfirmDiscard,
        ZEditionSection,
        ZEditionStep,
        ZFieldSpec,
        ZFormController,
        ZResponsiveSpan,
        ZSectionCollapseStore,
        ZStepperConfig,
        ZStepperEdition,
        kZStepperMaxNestingDepth;
import 'package:zcrud_navigation/zcrud_navigation.dart'
    show
        ZEditionBodyFit,
        ZEditionChrome,
        ZEditionPresentation,
        ZFormWeight,
        ZPresentationPolicy,
        presentEdition;

import 'z_form_only.dart';

/// Fabrique du **corps** d'une fenêtre d'édition de valeurs.
///
/// Reçoit le [ZFormOnlyController] déjà construit par [presentFormEdition] —
/// donc le `ZFormController` sur lequel la soumission validera et normalisera.
/// Tout ce que vous montez doit écrire dans **ce** contrôleur (directement, ou
/// via `ZFormOnly(controller: …)`, `DynamicEdition(controller: controller.form,
/// …)`, `ZStepperEdition(controller: controller.form, …)`) : un second
/// contrôleur ne serait jamais lu au moment d'enregistrer.
typedef ZFormBodyBuilder = Widget Function(
  BuildContext context,
  ZFormOnlyController controller,
);

/// Présente le formulaire déclaré par [fields] et retourne ses valeurs
/// **validées et normalisées**.
///
/// * L'utilisateur enregistre ⇒ la carte des valeurs (types coercés, dates en
///   ISO-8601, valeurs d'énumération en camelCase). Les champs en lecture seule
///   et ceux qu'une condition d'affichage masque en sont **absents**.
/// * L'utilisateur renonce (bouton d'abandon, retour, barrière) ⇒ `null`.
/// * Un champ est en erreur ⇒ les messages s'affichent et **la fenêtre reste
///   ouverte** : rien n'est rendu tant que la saisie n'est pas complète.
///
/// ```dart
/// final reglages = await presentFormEdition(
///   context,
///   fields: reglagesExportFields,
///   initialValues: <String, Object?>{'format': 'pdf', 'paysage': true},
///   title: 'Réglages d\'export',
/// );
/// if (reglages != null) await monService.exporter(reglages);
/// ```
///
/// Le conteneur (page / feuille / dialogue) est choisi par [policy] à partir de
/// la largeur de fenêtre, comme partout ailleurs dans le socle ; [forcedMode]
/// impose un conteneur pour cet appel précis.
///
/// Le formulaire est monté avec un garde d'abandon : une saisie en cours n'est
/// pas perdue par une fermeture accidentelle dès lors qu'un
/// [onConfirmDiscard] est fourni (à défaut, la fermeture reste immédiate).
///
/// [formController] permet de réutiliser un contrôleur d'état existant — il
/// reste alors sous la responsabilité de l'appelant, qui le libère ; sinon la
/// fonction crée le sien et le libère à la fermeture.
///
/// ## Le formulaire en ÉTAPES ([steps])
///
/// Un formulaire long se présente en assistant : [steps] déclare les étapes,
/// [fields] reste le **catalogue** complet des champs. Les deux se **complètent**
/// — une étape ne porte pas de champs à elle, elle nomme ceux du catalogue
/// qu'elle regroupe :
///
/// ```dart
/// final valeurs = await presentFormEdition(
///   context,
///   fields: dossierFields, // le catalogue COMPLET, toutes étapes confondues
///   steps: const <ZEditionStep>[
///     ZEditionStep(title: 'Navire', fields: <String>['nom', 'pavillon']),
///     ZEditionStep(title: 'Escale', fields: <String>['quai', 'arrivee']),
///   ],
///   title: 'Escale',
/// );
/// ```
///
/// Le **nombre d'étapes peut dépendre des données** : [steps] est une liste
/// ordinaire, construite à l'appel comme n'importe quelle autre — une étape par
/// type de document présent, par exemple :
///
/// ```dart
/// final valeurs = await presentFormEdition(
///   context,
///   fields: <ZFieldSpec>[
///     for (final type in typesPresents)
///       ZFieldSpec(name: 'doc_${type.code}', type: EditionFieldType.text),
///   ],
///   steps: <ZEditionStep>[
///     for (final type in typesPresents)
///       ZEditionStep(title: type.libelle, fields: <String>['doc_${type.code}']),
///   ],
/// );
/// ```
///
/// [stepperConfig] règle la présentation de l'assistant — orientation verticale,
/// toutes les étapes dépliées, accordéon, gate de navigation :
/// `ZStepperConfig(stepsDisplay: ZStepsDisplay.allExpanded)` reproduit un
/// « tout affiché », `ZStepperConfig(orientation: ZStepOrientation.vertical)`
/// une bande verticale.
///
/// **Ce qui ne change pas avec les étapes** : la soumission reste la même — elle
/// valide et normalise le **catalogue entier**, pas seulement l'étape affichée.
/// Un champ invalide dans une étape **jamais visitée** empêche donc
/// l'enregistrement, et les valeurs de **toutes** les étapes sont rendues. Le
/// bouton d'enregistrement du chrome reste disponible à tout moment ; le bouton
/// final de la dernière étape soumet exactement de la même façon.
///
/// ⚠️ Un champ du catalogue qu'**aucune** étape ne nomme n'est jamais affiché,
/// mais reste validé : s'il porte un validateur qui échoue, la fenêtre devient
/// insoumissible. Ce cas est signalé en mode développement.
///
/// ## Le corps composé par l'appelant ([bodyBuilder])
///
/// Quand la présentation sort de ces deux formes — un corps mêlant formulaire
/// et contenu applicatif, un assistant maison, un en-tête de récapitulatif —
/// [bodyBuilder] rend la main : vous montez le corps, le socle garde le
/// conteneur adaptatif, le garde d'abandon, le chrome et le **contrat de
/// sortie**.
///
/// ```dart
/// final valeurs = await presentFormEdition(
///   context,
///   fields: dossierFields,
///   bodyBuilder: (context, controller) => Column(
///     children: <Widget>[
///       const _RappelReglementaire(),
///       Expanded(child: ZFormOnly(controller: controller)),
///     ],
///   ),
/// );
/// ```
///
/// ## Quand plusieurs corps sont déclarés
///
/// [bodyBuilder] et [steps] déclarent deux corps concurrents ; [sections] décrit
/// la mise en page d'un formulaire **à plat** et n'a pas de sens sous des étapes
/// (chaque `ZEditionStep` porte ses propres sections). Ces combinaisons sont
/// **refusées par une assertion** en développement. En production, la
/// **préséance est définie** et jamais une exception (invariant AD-10) :
/// `bodyBuilder` l'emporte sur `steps`, qui l'emporte sur le formulaire à plat ;
/// [sections] et [layout] sont alors ignorés.
///
/// ## [bodyFit] — le corps qui défile
///
/// `null` (défaut) ⇒ **dérivé** : `intrinsic` pour le formulaire à plat et pour
/// un [bodyBuilder] (comportement historique, inchangé), `scrollable` pour un
/// assistant (`ZStepperEdition` défile lui-même et veut une hauteur bornée).
/// Un [bodyBuilder] qui monte un corps défilant déclare
/// `bodyFit: ZEditionBodyFit.scrollable`.
///
/// ## Le repli des sections qui SURVIT ([collapseStore], [formId])
///
/// Une section déclarée `collapsible` se replie ; sans rien de plus, ce repli
/// meurt avec la fenêtre. Sur une fiche ouverte trente fois par jour, replier
/// « Finances » est pourtant une habitude de travail, pas un confort : elle doit
/// tenir d'une ouverture à la suivante, et d'un lancement au suivant.
///
/// [collapseStore] est l'endroit où ce repli est conservé. **Le stockage
/// appartient à l'application** : le socle n'en fournit ni n'en impose aucun
/// (invariant AD-1) — vous branchez le vôtre derrière le contrat
/// `ZSectionCollapseStore`, qui tient en deux méthodes synchrones.
///
/// ```dart
/// class ReplisPersistants extends ZSectionCollapseStore {
///   @override
///   Set<String> loadCollapsed(String? formId) => …; // titres repliés
///   @override
///   void saveCollapsed(String? formId, Set<String> collapsed) => …;
/// }
///
/// await presentFormEdition(
///   context,
///   fields: ficheAgentFields,
///   sections: const <ZEditionSection>[
///     ZEditionSection(
///       title: 'Finances',
///       fields: <String>['salaire', 'prime'],
///       collapsible: true,
///     ),
///   ],
///   collapseStore: ReplisPersistants(),
///   formId: 'fiche-agent',
/// );
/// ```
///
/// [formId] est la **portée** : l'unité persistée étant le *titre* de la
/// section, deux formulaires qui nomment tous deux une section « Finances » se
/// marcheraient dessus sous une portée commune. Un [formId] distinct les
/// isole ; `null` (défaut) ⇒ portée globale, ce qui convient tant qu'un titre
/// ne désigne qu'une seule chose dans l'application. La valeur est **opaque**,
/// transmise telle quelle au store.
///
/// `null` (défaut) ⇒ **rien ne change** : ni lecture, ni écriture, et le repli
/// reste celui de la vie du widget.
///
/// Les deux paramètres suivent le corps réellement monté : le formulaire à plat
/// ([ZFormOnly]) et l'assistant ([steps] — chaque étape reçoit alors **sa
/// propre portée**, dérivée de [formId] et du titre de l'étape). Un
/// [bodyBuilder], lui, compose son corps : c'est à lui de les passer au
/// `ZFormOnly` ou au `DynamicEdition` qu'il monte.
Future<Map<String, dynamic>?> presentFormEdition(
  BuildContext context, {
  required List<ZFieldSpec> fields,
  Map<String, Object?>? initialValues,
  String? title,
  String? submitLabel,
  String? discardLabel,
  ZConfirmDiscard? onConfirmDiscard,
  ZFormController? formController,
  Map<String, Object?> conditionContext = const <String, Object?>{},
  ZPresentationPolicy policy = const ZPresentationPolicy(),
  ZFormWeight formWeight = ZFormWeight.light,
  ZEditionPresentation? forcedMode,
  bool readOnly = false,
  List<ZEditionSection> sections = const <ZEditionSection>[],
  List<ZEditionStep> steps = const <ZEditionStep>[],
  ZStepperConfig stepperConfig = const ZStepperConfig(),
  ZFormBodyBuilder? bodyBuilder,
  ZEditionBodyFit? bodyFit,
  Map<String, ZResponsiveSpan> layout = const <String, ZResponsiveSpan>{},
  EdgeInsetsGeometry? padding,
  ZSectionCollapseStore? collapseStore,
  String? formId,
}) {
  assert(
    bodyBuilder == null || steps.isEmpty,
    'presentFormEdition : `bodyBuilder` et `steps` déclarent deux corps '
    'concurrents. Montez le `ZStepperEdition` vous-même dans le '
    '`bodyBuilder`, ou renoncez au `bodyBuilder`.',
  );
  assert(
    steps.isEmpty || sections.isEmpty,
    'presentFormEdition : `sections` décrit la mise en page d\'un formulaire à '
    'plat et n\'est pas appliqué sous des étapes. Déclarez les sections sur '
    'chaque `ZEditionStep(sections: …)`.',
  );
  assert(
    _assertStepFieldsKnown(fields, steps),
    'presentFormEdition : une étape nomme un champ absent du catalogue.',
  );
  final controller = ZFormOnlyController(
    fields: fields,
    initialValues: initialValues,
    form: formController,
    conditionContext: conditionContext,
  );
  // Le contexte du CORPS, capté au montage : c'est lui qui porte la route de
  // la fenêtre, donc le seul par lequel on peut la refermer en rendant les
  // valeurs. Le contexte d'appel, lui, est au-dessus de la route.
  BuildContext? body;

  void submit() {
    final values = controller.submit();
    // Invalide : les messages viennent d'être révélés, la fenêtre reste
    // ouverte, et rien n'est rendu.
    if (values == null) return;
    final ctx = body;
    if (ctx == null || !ctx.mounted) return;
    // Le garde d'abandon lit l'état « modifié » : le formulaire enregistré ne
    // l'est plus, sinon la fermeture demanderait de confirmer un abandon qui
    // n'a pas lieu.
    controller.form.markPristine();
    Navigator.of(ctx).pop(values);
  }

  // Préséance DÉFINIE (AD-10) : le corps de l'appelant, puis les étapes, puis
  // le formulaire à plat. Les assertions ci-dessus signalent la combinaison en
  // développement ; en production rien ne lève.
  final bool stepped = bodyBuilder == null && steps.isNotEmpty;
  if (stepped) _warnFieldsOutsideSteps(fields, steps);

  return presentEdition<Map<String, dynamic>>(
    context,
    policy: policy,
    formWeight: formWeight,
    forcedMode: forcedMode,
    bodyFit: bodyFit ??
        (stepped ? ZEditionBodyFit.scrollable : ZEditionBodyFit.intrinsic),
    chrome: ZEditionChrome(
      title: title,
      submitLabel: submitLabel,
      discardLabel: discardLabel,
      onSubmit: readOnly ? null : submit,
      formController: controller.form,
      onConfirmDiscard: onConfirmDiscard,
    ),
    builder: (ctx) {
      body = ctx;
      final custom = bodyBuilder;
      if (custom != null) return custom(ctx, controller);
      if (stepped) {
        return ZStepperEdition(
          controller: controller.form,
          // Le CATALOGUE complet : les étapes n'en nomment que des
          // sous-ensembles, et la soumission valide l'ensemble.
          fields: controller.fields,
          steps: steps,
          config: stepperConfig,
          padding: padding,
          readOnly: readOnly,
          layout: layout,
          // Une étape porte ses propres sections repliables : le seam la suit
          // jusque-là. Le stepper donne à chaque étape SA portée (dérivée de
          // `formId`), sinon la dernière étape repliée effacerait le repli des
          // autres.
          collapseStore: collapseStore,
          formId: formId,
          // Le bouton final de la dernière étape soumet par la MÊME voie que le
          // bouton d'enregistrement du chrome — une seconde voie de soumission
          // finirait par diverger de la première.
          onComplete: readOnly ? null : submit,
        );
      }
      return ZFormOnly(
        controller: controller,
        readOnly: readOnly,
        sections: sections,
        layout: layout,
        padding: padding,
        shrinkWrap: true,
        // Relayés tels quels jusqu'à `DynamicEdition`, qui porte le seam.
        collapseStore: collapseStore,
        formId: formId,
      );
    },
  ).whenComplete(controller.dispose);
}

/// `true` si chaque nom cité par une étape existe dans le catalogue.
///
/// Un nom inconnu ne lève rien côté `ZStepperEdition` : le champ est
/// simplement absent de l'étape. Le défaut est donc **silencieux** — une faute
/// de frappe rend une étape vide sans le moindre signal. L'assertion le nomme.
bool _assertStepFieldsKnown(
  List<ZFieldSpec> fields,
  List<ZEditionStep> steps,
) {
  if (steps.isEmpty) return true;
  final known = <String>{for (final f in fields) f.name};
  final unknown = <String>[
    for (final step in _flatten(steps))
      for (final name in step.fields)
        if (!known.contains(name)) '${step.title}/$name',
  ];
  if (unknown.isEmpty) return true;
  debugPrint(
    'presentFormEdition — étape(s) citant un champ absent du catalogue '
    '`fields` : ${unknown.join(', ')}. Ces champs ne seront pas affichés.',
  );
  return false;
}

/// Signale, en développement, les champs du catalogue qu'**aucune** étape ne
/// nomme et qui portent un validateur.
///
/// Ces champs ne sont jamais montés, mais la soumission les valide comme tous
/// les autres (c'est ce qui fait qu'une étape non visitée ne peut pas laisser
/// passer une saisie invalide). Un validateur qui échoue sur un champ hors
/// étapes rend donc la fenêtre **insoumissible sans message visible** : le cas
/// est nommé plutôt que laissé à l'observation.
void _warnFieldsOutsideSteps(
  List<ZFieldSpec> fields,
  List<ZEditionStep> steps,
) {
  assert(() {
    final covered = <String>{
      for (final step in _flatten(steps)) ...step.fields,
    };
    final orphans = <String>[
      for (final f in fields)
        if (f.validators.isNotEmpty && !covered.contains(f.name)) f.name,
    ];
    if (orphans.isEmpty) return true;
    debugPrint(
      'presentFormEdition — champ(s) validés mais hors de toute étape : '
      '${orphans.join(', ')}. Ils ne seront jamais affichés alors que la '
      'soumission les valide : ajoutez-les à une étape, ou retirez leurs '
      'validateurs.',
    );
    return true;
  }());
}

/// Toutes les étapes, sous-étapes imbriquées comprises.
///
/// La descente est **plafonnée** ([kZStepperMaxNestingDepth], le même plafond
/// que celui du stepper) : `ZEditionStep.nestedSteps` est une liste mutable,
/// donc un hôte peut en construire un cycle. Un parcours sans plafond
/// récurserait sans fin (invariant AD-10 : repli défini, jamais d'exception).
Iterable<ZEditionStep> _flatten(List<ZEditionStep> steps, [int depth = 0]) sync* {
  if (depth >= kZStepperMaxNestingDepth) return;
  for (final step in steps) {
    yield step;
    final nested = step.nestedSteps;
    if (nested != null) yield* _flatten(nested, depth + 1);
  }
}
