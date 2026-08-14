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
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZConfirmDiscard, ZEditionSection, ZFieldSpec, ZFormController, ZResponsiveSpan;
import 'package:zcrud_navigation/zcrud_navigation.dart'
    show
        ZEditionChrome,
        ZEditionPresentation,
        ZFormWeight,
        ZPresentationPolicy,
        presentEdition;

import 'z_form_only.dart';

/// Présente le formulaire déclaré par [fields] et retourne ses valeurs
/// **validées et normalisées**.
///
/// * L'utilisateur enregistre ⇒ la carte des valeurs (types coercés, dates en
///   ISO-8601, valeurs d'énumération en camelCase). Les champs en lecture seule
///   et ceux qu'une condition d'affichage masque en sont **absents**.
/// * L'utilisateur renonce (bouton d'abandon, retour, barrière) ⇒ `null`.
/// * Un champ visible est en erreur ⇒ les messages s'affichent et **la fenêtre
///   reste ouverte** : rien n'est rendu tant que la saisie n'est pas complète.
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
  Map<String, ZResponsiveSpan> layout = const <String, ZResponsiveSpan>{},
  EdgeInsetsGeometry? padding,
}) {
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

  return presentEdition<Map<String, dynamic>>(
    context,
    policy: policy,
    formWeight: formWeight,
    forcedMode: forcedMode,
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
      return ZFormOnly(
        controller: controller,
        readOnly: readOnly,
        sections: sections,
        layout: layout,
        padding: padding,
        shrinkWrap: true,
      );
    },
  ).whenComplete(controller.dispose);
}
