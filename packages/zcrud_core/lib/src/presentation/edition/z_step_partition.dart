/// **G1 — stepper *data-driven inline*** : l'adaptateur qui transforme une
/// **liste plate** de `ZFieldSpec` annotés en `List<ZEditionStep>`, sans rien
/// changer à [ZStepperEdition] qui les consomme.
///
/// ## Le besoin, mesuré
///
/// (CR d'exploration DODLP du 2026-08-06, §3 G1.) DODLP déclare le stepper
/// comme un **type de champ** dans une liste plate ; ses enfants portent
/// `stepIndex`/`stepTitle`/`stepSubtitle` et le moteur **regroupe tout seul**
/// (`dynamic_stepper.dart`, sniffing de `stepIndex`). zcrud, lui, exige un
/// `List<ZEditionStep>` où **chaque étape énumère nommément ses champs**.
/// Porter un formulaire stepper DODLP imposait donc de **restructurer à la
/// main** la liste plate — non-1:1, source d'erreurs. C'est le point qui a
/// stoppé le pilote de l'écran agent.
///
/// Cet adaptateur rétablit le 1:1 : la déclaration reste **plate et locale au
/// champ**, le regroupement est **dérivé**.
///
/// ## Ce que ce fichier N'EST PAS
///
/// 🔴 **`EditionFieldType.stepper` reste `EditionFamily.unsupported`.** Ce
/// n'est pas un oubli, c'est l'invariant DP-9/AC13 : le dispatcher mappe un
/// `kind` → **widget-feuille** porteur d'UNE tranche de valeur, alors qu'un
/// stepper est un **regroupement** qui doit rester le **single writer** de
/// `controller.visibleFields`. Le router par le registre casserait ce
/// single-writer (dartdoc de [ZStepperEdition]). L'adaptateur est donc un
/// **helper de construction**, jamais un type servi — et il ne déplace aucune
/// frontière existante.
///
/// ## Pureté et totalité (AD-10)
///
/// [zPartitionFieldsIntoSteps] est **PURE** (aucun `BuildContext`, aucun état,
/// aucun effet de bord — testable en test unitaire nu) et **TOTALE** : aucune
/// entrée ne la fait lever. Index non contigus, index négatifs, titres absents,
/// liste vide, champ unique, annotations contradictoires : tout a une image.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData;

import '../../domain/edition/z_condition.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_spec.dart';
import 'z_stepper_edition.dart';

/// Appartenance d'un champ à une **étape**, portée par le champ lui-même
/// (`ZFieldSpec.config`) — la traduction zcrud des `stepIndex`/`stepTitle`/
/// `stepSubtitle`/`stepIcon` de DODLP.
///
/// ### Pourquoi en PRÉSENTATION et non dans le domaine
///
/// Même arbitrage que [ZStepperConfig] : [icon] est un `IconData`, donc un type
/// **Flutter** — AD-1 interdit de le faire entrer dans `domain/`. C'est
/// exactement pourquoi `ZTextConfig.keyboardType` y est une `String` opaque.
/// Le précédent est établi (`ZFlashcardFieldConfig`, `zcrud_flashcard`).
///
/// ### ⚠️ Le slot `config` est EXCLUSIF — limite MESURÉE
///
/// `ZFieldSpec.config` est un **slot unique**, lu par ~19 sites de la forme
/// `field.config is ZTextConfig` / `is ZSelectConfig` / … Annoter un champ
/// texte avec une appartenance d'étape lui **retire donc** sa `ZTextConfig`
/// (`minLines`, `maxLines`, `capitalization`, `textTransform`) — silencieusement.
///
/// Deux réponses, aucune ne cassant l'existant :
/// * pour un champ **sans** config de type (le cas courant : les champs
///   annotés d'étape chez DODLP sont des conteneurs sans config propre),
///   l'annotation par `config` suffit ;
/// * pour un champ qui a **déjà** une config de type, l'hôte passe un résolveur
///   [ZStepOf] à [zPartitionFieldsIntoSteps] (par nom, par convention, par
///   table…). Le canal reste **pur** et n'occupe pas le slot.
///
/// 🔴 Un slot `step:` **additif** sur `ZFieldSpec` lèverait la limite pour de
/// bon ; c'est une décision de **schéma canonique** qui n'appartient pas à ce
/// lot — elle est remontée dans le rapport, pas prise ici.
@immutable
class ZStepFieldConfig extends ZFieldConfig {
  /// Déclare l'appartenance d'un champ à l'étape [index].
  ///
  /// [title]/[subtitle]/[icon] décrivent **l'étape**, pas le champ : il suffit
  /// qu'UN champ de l'étape les porte (le **premier** dans l'ordre de
  /// déclaration l'emporte — cf. [zPartitionFieldsIntoSteps]).
  const ZStepFieldConfig({
    required this.index,
    this.title,
    this.subtitle,
    this.icon,
    this.condition,
    this.optional = false,
  });

  /// Clé de l'étape. **Clé d'ordre, pas position** : les valeurs peuvent être
  /// non contiguës (`0, 2, 5`) ou négatives ; l'ordre rendu est l'ordre
  /// croissant des clés présentes.
  final int index;

  /// Titre de l'étape (clé l10n ou littéral — résolu côté hôte). `null` ⇒ voir
  /// `titleFallback` de [zPartitionFieldsIntoSteps].
  final String? title;

  /// Sous-titre de l'étape (affiché ssi `ZStepperConfig.showSubtitles`).
  final String? subtitle;

  /// Icône de l'étape (consommée en `ZStepStyle.icons`).
  ///
  /// 🟢 MESURÉ côté DODLP : leur `stepIcon` est **déclaré et jamais lu**
  /// (`grep -rn "stepIcon" lib` → 2 occurrences, toutes deux dans la
  /// déclaration du modèle). Ici il est réellement honoré par
  /// [ZStepperEdition] via [ZEditionStep.icon].
  final IconData? icon;

  /// Condition d'**existence de l'étape** ([ZEditionStep.condition]) — même
  /// arbre `ZCondition` que les champs, aucun second langage.
  ///
  /// ⚠️ Elle porte sur l'ÉTAPE, pas sur le champ qui la déclare : c'est donc,
  /// comme [title], une métadonnée d'étape, et le **premier non-`null`** de
  /// l'étape gagne.
  final ZCondition? condition;

  /// Étape **optionnelle** ([ZEditionStep.optional]) : le gate de navigation ne
  /// s'y applique pas. Métadonnée d'étape ⇒ un `true` porté par N'IMPORTE quel
  /// champ de l'étape suffit (ce n'est pas une propriété du champ).
  final bool optional;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZStepFieldConfig &&
          runtimeType == other.runtimeType &&
          index == other.index &&
          title == other.title &&
          subtitle == other.subtitle &&
          icon == other.icon &&
          condition == other.condition &&
          optional == other.optional;

  @override
  int get hashCode => Object.hash(
        runtimeType,
        index,
        title,
        subtitle,
        icon,
        condition,
        optional,
      );

  @override
  String toString() => 'ZStepFieldConfig(index: $index, title: $title, '
      'subtitle: $subtitle, icon: $icon, '
      'conditional: ${condition != null}, optional: $optional)';
}

/// Résolveur d'appartenance : rend l'étape d'un champ, ou `null` s'il
/// n'appartient à aucune. **Doit être pur et total** (contrat identique à
/// `ZTextConfig.textTransform`).
typedef ZStepOf = ZStepFieldConfig? Function(ZFieldSpec field);

/// Repli de titre pour une étape dont **aucun** champ ne porte de titre.
///
/// [index] est la clé déclarée, [position] le rang d'affichage (0-based) parmi
/// les étapes réellement présentes — les deux diffèrent dès que les index sont
/// non contigus, et c'est [position] qu'un libellé « Étape n » doit utiliser.
typedef ZStepTitleFallback = String Function(int index, int position);

/// Résultat de [zPartitionFieldsIntoSteps] : les étapes **et** ce qui n'y est
/// pas entré.
///
/// 🔴 [unassigned] existe pour ne PAS reproduire le défaut mesuré côté DODLP :
/// quand au moins une étape existe, leur `DynamicStepper` **laisse tomber
/// silencieusement** les champs frères non annotés (`dynamic_stepper.dart` ne
/// collecte que `field.stepIndex != null`). Ici la perte est **rendue
/// visible** : l'hôte choisit — les rendre hors stepper, les rattacher, ou
/// asserter que la liste est vide.
@immutable
class ZStepPartition {
  /// Construit une partition (usage interne à [zPartitionFieldsIntoSteps]).
  const ZStepPartition({required this.steps, required this.unassigned});

  /// Partition **vide** — aucune étape, aucun champ orphelin.
  static const ZStepPartition empty = ZStepPartition(
    steps: <ZEditionStep>[],
    unassigned: <String>[],
  );

  /// Étapes, par **ordre croissant de clé** déclarée.
  final List<ZEditionStep> steps;

  /// Noms des champs **non annotés**, dans l'ordre de déclaration.
  final List<String> unassigned;

  /// `true` ssi aucune étape n'a été trouvée — l'hôte rend alors son
  /// formulaire normalement (aucun stepper à monter).
  bool get isEmpty => steps.isEmpty;

  @override
  String toString() =>
      'ZStepPartition(steps: ${steps.length}, unassigned: $unassigned)';
}

/// Regroupe une **liste plate** de [fields] en étapes, d'après l'annotation
/// [ZStepFieldConfig] portée par chaque champ (ou d'après [stepOf] si l'hôte
/// fournit son propre canal).
///
/// ## Règles — toutes assertées par `z_step_partition_test.dart`
///
/// 1. **Une étape par clé distincte**, ordonnée par clé **croissante**. Les
///    clés sont des clés d'ordre : `0, 2, 5` donne trois étapes ; un index
///    **négatif** se place naturellement avant `0` (aucune entrée n'est
///    rejetée — AD-10).
/// 2. **À l'intérieur d'une étape, l'ordre de DÉCLARATION est préservé**, et
///    lui seul. Il ne suit ni les clés, ni l'ordre alphabétique. C'est ce qui
///    rend le portage 1:1 : l'auteur lit son formulaire dans l'ordre où il
///    l'a écrit. (Le tri des étapes n'y touche pas : les clés étant uniques,
///    aucune comparaison n'est ambiguë — l'instabilité de `List.sort` ne peut
///    pas se manifester.)
/// 3. **Titre/sous-titre/icône : le PREMIER non-`null` de l'étape gagne**, dans
///    l'ordre de déclaration. Un champ qui ne les porte pas n'efface donc rien,
///    et il suffit de les écrire une fois.
/// 4. **Aucun champ annoté ⇒ [ZStepPartition.empty]** (pas d'étape fabriquée).
///    L'hôte rend son formulaire tel quel.
/// 5. **Aucun titre nulle part ⇒ [titleFallback], à défaut la chaîne vide.**
///    🔴 Le repli DODLP (`'Étape ${i + 1}'`) n'est **PAS** reproduit : ce
///    serait un littéral français codé en dur dans le cœur (l10n). Une étape
///    sans titre reste lisible — l'indicateur `numbered` affiche « k/N » quoi
///    qu'il arrive.
/// 6. **Totalité** : si [stepOf] ou [titleFallback] — code de l'hôte — lève,
///    l'exception est absorbée et l'on retombe respectivement sur « champ non
///    annoté » et sur la chaîne vide. Un libellé ne fait pas échouer un rendu
///    (AD-10).
///
/// ```dart
/// // Déclaration PLATE, façon DODLP — le regroupement est dérivé :
/// const fields = <ZFieldSpec>[
///   ZFieldSpec(name: 'nom', type: EditionFieldType.text,
///       config: ZStepFieldConfig(index: 0, title: 'identity')),
///   ZFieldSpec(name: 'matricule', type: EditionFieldType.text,
///       config: ZStepFieldConfig(index: 0)),
///   ZFieldSpec(name: 'poste', type: EditionFieldType.text,
///       config: ZStepFieldConfig(index: 1, title: 'affectation')),
/// ];
/// final partition = zPartitionFieldsIntoSteps(fields);
/// // → ZStepperEdition(controller: c, fields: fields, steps: partition.steps)
/// ```
ZStepPartition zPartitionFieldsIntoSteps(
  List<ZFieldSpec> fields, {
  ZStepOf? stepOf,
  ZStepTitleFallback? titleFallback,
}) {
  // Insertion-ordonné par PREMIÈRE apparition de la clé : l'ordre interne des
  // champs est donc l'ordre de déclaration, sans dépendre d'un tri.
  final Map<int, _StepDraft> drafts = <int, _StepDraft>{};
  final List<String> unassigned = <String>[];

  for (final ZFieldSpec field in fields) {
    final ZStepFieldConfig? membership = _membershipOf(field, stepOf);
    if (membership == null) {
      unassigned.add(field.name);
      continue;
    }
    (drafts[membership.index] ??= _StepDraft(membership.index))
        .absorb(field.name, membership);
  }

  if (drafts.isEmpty) {
    return ZStepPartition(
      steps: const <ZEditionStep>[],
      unassigned: List<String>.unmodifiable(unassigned),
    );
  }

  final List<int> keys = drafts.keys.toList()..sort();
  final List<ZEditionStep> steps = <ZEditionStep>[];
  for (int position = 0; position < keys.length; position++) {
    steps.add(drafts[keys[position]]!.build(position, titleFallback));
  }

  return ZStepPartition(
    steps: List<ZEditionStep>.unmodifiable(steps),
    unassigned: List<String>.unmodifiable(unassigned),
  );
}

/// Lit l'appartenance d'un champ — canal de l'hôte ([stepOf]) s'il est fourni,
/// sinon le slot `config`. Absorbe toute exception du code hôte (AD-10).
ZStepFieldConfig? _membershipOf(ZFieldSpec field, ZStepOf? stepOf) {
  if (stepOf == null) {
    final ZFieldConfig? config = field.config;
    return config is ZStepFieldConfig ? config : null;
  }
  try {
    return stepOf(field);
  } catch (_) {
    // Un résolveur d'hôte qui lève ne doit pas empêcher le formulaire de se
    // construire : le champ est simplement traité comme non annoté.
    return null;
  }
}

/// Accumulateur d'étape — champs dans l'ordre de déclaration, métadonnées au
/// PREMIER non-`null`.
class _StepDraft {
  _StepDraft(this.index);

  final int index;
  final List<String> fields = <String>[];
  String? title;
  String? subtitle;
  IconData? icon;
  ZCondition? condition;
  bool optional = false;

  void absorb(String name, ZStepFieldConfig membership) {
    fields.add(name);
    title ??= membership.title;
    subtitle ??= membership.subtitle;
    icon ??= membership.icon;
    condition ??= membership.condition;
    // `optional` est un OU : un seul champ suffit à déclarer l'étape
    // optionnelle (le défaut `false` d'un champ ne peut donc pas ANNULER le
    // `true` d'un autre — un défaut de valeur n'exprime aucune intention).
    optional = optional || membership.optional;
  }

  ZEditionStep build(int position, ZStepTitleFallback? fallback) {
    return ZEditionStep(
      title: title ?? _fallbackTitle(position, fallback),
      fields: List<String>.unmodifiable(fields),
      icon: icon,
      subtitle: subtitle,
      condition: condition,
      optional: optional,
    );
  }

  String _fallbackTitle(int position, ZStepTitleFallback? fallback) {
    if (fallback == null) return '';
    try {
      return fallback(index, position);
    } catch (_) {
      // Un repli de LIBELLÉ qui lève ne fait pas échouer un rendu (AD-10).
      return '';
    }
  }
}
