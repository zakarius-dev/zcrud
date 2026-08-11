/// Enregistrement des widgets d'édition flashcard dans un `ZWidgetRegistry`
/// et fabriques de `ZFieldSpec`.
///
/// Positionnement : widgets additifs rendus dans `DynamicEdition` du cœur —
/// jamais un second moteur d'édition, jamais un modèle concurrent. Le cœur
/// route un champ `EditionFieldType.custom` vers le registre de widgets
/// injecté par le nom d'enum (`'custom'`). On enregistre donc un unique
/// builder sous ce `kind` qui discrimine le sous-widget flashcard via
/// [ZFlashcardFieldConfig.editorKind] (aucun singleton statique mutable ;
/// aucune édition de `zcrud_core`). Les libellés et messages sont
/// paramétrables par closure (invariant AD-4) — aucune référence en dur à un
/// modèle applicatif particulier.
///
/// Les champs texte (énoncé/réponse/explication/indice) et tags utilisent
/// les familles du cœur (`multiline`/`text`/`tags`) : les fabriques de
/// [ZFlashcardEditionFields] en fournissent les specs prêtes à l'emploi.
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_flashcard_choices_field_widget.dart';
import 'z_flashcard_edition_validator.dart';
import 'z_flashcard_editor_config.dart';
import 'z_flashcard_true_false_field_widget.dart';
import 'z_flashcard_type_field_widget.dart';

/// `kind` du registre sous lequel les éditeurs flashcard sont servis — aligné
/// sur `EditionFieldType.custom.name` (convention du dispatcher du cœur).
final String kZFlashcardEditorKindName = EditionFieldType.custom.name;

/// Enregistre le builder d'édition flashcard dans [registry] (sous le `kind`
/// `custom`). Le builder monte le sous-widget adéquat selon
/// [ZFlashcardFieldConfig.editorKind] porté par le champ.
///
/// Paramètres (capturés par closure, invariant AD-4) : [typeLabelResolver]
/// (libellés des six types), [trueLabel]/[falseLabel] (vrai/faux),
/// [messages] (erreurs d'éditeur), [addChoiceLabel]. Un champ `custom` sans
/// [ZFlashcardFieldConfig] (ou avec une configuration étrangère) retombe sur
/// un widget vide inoffensif (jamais une exception — invariant AD-10).
void registerZFlashcardEditors(
  ZWidgetRegistry registry, {
  ZFlashcardTypeLabel? typeLabelResolver,
  String trueLabel = 'Vrai',
  String falseLabel = 'Faux',
  ZFlashcardEditionMessages messages =
      ZFlashcardEditionValidator.defaultMessages,
  String addChoiceLabel = 'Ajouter un choix',
}) {
  registry.register(
    kZFlashcardEditorKindName,
    (context, ctx) {
      final config = ctx.field.config;
      final kind =
          config is ZFlashcardFieldConfig ? config.editorKind : null;
      switch (kind) {
        case ZFlashcardEditorKind.type:
          return ZFlashcardTypeFieldWidget(
            ctx: ctx,
            labelResolver: typeLabelResolver,
          );
        case ZFlashcardEditorKind.choices:
          return ZChoicesFieldWidget(
            ctx: ctx,
            messages: messages,
            addChoiceLabel: addChoiceLabel,
          );
        case ZFlashcardEditorKind.trueFalse:
          return ZTrueFalseFieldWidget(
            ctx: ctx,
            trueLabel: trueLabel,
            falseLabel: falseLabel,
          );
        case null:
          // Défensif (invariant AD-10) : config manquante/étrangère → widget
          // inoffensif.
          return const SizedBox.shrink();
      }
    },
  );
}

/// Fabriques de [ZFieldSpec] d'un formulaire d'édition flashcard standard.
/// Les specs des trois champs flashcard-spécifiques (type/QCM/vrai-faux)
/// portent une [ZFlashcardFieldConfig] sur `EditionFieldType.custom` ; les
/// champs texte/tags utilisent les familles du cœur.
abstract final class ZFlashcardEditionFields {
  /// Champ sélecteur de type (`custom` + config `type`).
  static ZFieldSpec type({String name = 'type', String? label}) => ZFieldSpec(
        name: name,
        type: EditionFieldType.custom,
        label: label ?? 'Type',
        config: const ZFlashcardFieldConfig(ZFlashcardEditorKind.type),
      );

  /// Champ éditeur QCM (`custom` + config `choices`). La règle « au moins 2
  /// choix, au moins 1 correct » est portée par [ZFlashcardEditionValidator],
  /// pas par un `ZValidatorSpec` (chaîne-orienté), afin d'éviter tout
  /// message du cœur sur une valeur `List<ZChoice>` stringifiée.
  static ZFieldSpec choices({String name = 'choices', String? label}) =>
      ZFieldSpec(
        name: name,
        type: EditionFieldType.custom,
        label: label ?? 'Choix (QCM)',
        config: const ZFlashcardFieldConfig(ZFlashcardEditorKind.choices),
      );

  /// Champ vrai/faux (`custom` + config `trueFalse`).
  static ZFieldSpec trueFalse({String name = 'is_true', String? label}) =>
      ZFieldSpec(
        name: name,
        type: EditionFieldType.custom,
        label: label ?? 'Vrai / Faux',
        config: const ZFlashcardFieldConfig(ZFlashcardEditorKind.trueFalse),
      );

  /// Champ énoncé (`multiline`, requis — validateur du cœur `required`).
  static ZFieldSpec question({String name = 'question', String? label}) =>
      ZFieldSpec(
        name: name,
        type: EditionFieldType.multiline,
        label: label ?? 'Question',
        validators: const <ZValidatorSpec>[ZValidatorSpec.required()],
      );

  /// Champ réponse libre (`multiline`).
  static ZFieldSpec answer({String name = 'answer', String? label}) =>
      ZFieldSpec(
        name: name,
        type: EditionFieldType.multiline,
        label: label ?? 'Réponse',
      );

  /// Champ explication (`multiline`).
  static ZFieldSpec explanation({String name = 'explanation', String? label}) =>
      ZFieldSpec(
        name: name,
        type: EditionFieldType.multiline,
        label: label ?? 'Explication',
      );

  /// Champ indice (`text`).
  static ZFieldSpec hint({String name = 'hint', String? label}) => ZFieldSpec(
        name: name,
        type: EditionFieldType.text,
        label: label ?? 'Indice',
      );

  /// Champ tags (`tags` — famille du cœur).
  static ZFieldSpec tags({String name = 'tag_ids', String? label}) => ZFieldSpec(
        name: name,
        type: EditionFieldType.tags,
        label: label ?? 'Étiquettes',
      );

  /// Catalogue complet d'un formulaire d'édition flashcard standard.
  static List<ZFieldSpec> all() => <ZFieldSpec>[
        question(),
        type(),
        choices(),
        trueFalse(),
        answer(),
        explanation(),
        hint(),
        tags(),
      ];
}
