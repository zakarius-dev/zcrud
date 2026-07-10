/// `ZEditionField` — widget hôte **générique** d'un champ d'édition, scellé sur
/// **sa seule tranche** de `ZFormController` (AD-2, OBJECTIF PRODUIT N°1 / SM-1).
///
/// origine: E2-7 a prouvé la garantie de rebuild ciblé au niveau du controller
/// (`ZFieldListenableBuilder`). E3-1 l'industrialise en **widget de champ** :
/// chaque champ est un widget top-level qui n'écoute QUE `fieldListenable(name)`
/// — taper dans un champ ne reconstruit QUE ce champ (jamais un voisin, jamais
/// le formulaire). Corrige par conception le bug historique de rebuild global
/// (jank, perte de focus, saut de curseur).
///
/// INVARIANTS (AD-2, NON-NÉGOCIABLES) :
/// - **Frontière de rebuild = la tranche** : le rendu vit sous
///   [ZFieldListenableBuilder] (helper E2-7 RÉUTILISÉ, jamais réimplémenté) ;
///   seul le changement de la tranche `name` reconstruit ce sous-arbre.
/// - **`TextEditingController` créé UNE SEULE fois** en [State.initState] et
///   libéré en [State.dispose] ; **jamais** recréé au rebuild, **jamais**
///   ré-injecté (`.text = …` INTERDIT dans la voie de frappe). La saisie est à
///   **sens unique** : `onChanged → controller.setValue(name, …)`.
/// - **`FocusNode` stable** détenu par le `State` (créé une fois, `dispose`) :
///   oracle du « le champ a-t-il le focus ? » pour la **synchronisation guardée**
///   (E3-2). Une valeur changée de l'EXTÉRIEUR se reflète dans le `TextField`
///   **quand le champ n'a PAS le focus**, mais n'est **JAMAIS** ré-injectée en
///   écrasant la sélection **quand le champ édite** (FR-1) — priorité absolue à
///   la saisie et au curseur en cours (y compris curseur AU MILIEU).
/// - **Validation ciblée** (E3-2) : rendu par un `TextFormField` **autonome**
///   (sans `Form`/`FormBuilder` global — AD-2) portant
///   `autovalidateMode: AutovalidateMode.onUserInteraction` **par champ** et un
///   `validator` **mémoïsé** (compilé UNE fois depuis `field.validators`,
///   identité stable entre builds — jamais recréé dans `build()`).
/// - **Place stable** : l'assembleur ([DynamicEdition]) pose
///   `key: ValueKey(field.name)` — un rebuild externe (UJ-2) réutilise alors
///   l'`Element`/`State` (état de saisie préservé).
///
/// RENDU **type-agnostique** (E3-1/E3-2) : un `TextFormField` uniforme suffit à
/// prouver SM-1 sur N champs. Le **dispatcher par type** (`ZFieldWidget` texte/
/// nombre/date/booléen/select/relation) + a11y/RTL par-widget relèvent d'**E3-3a**
/// : ce widget est volontairement neutre pour qu'E3-3a échange le rendu interne
/// sans toucher ni la machinerie de tranche, ni le contrat de stabilité, ni la
/// compilation de validateurs.
///
/// Aucun gestionnaire d'état (AD-15) : seules les primitives Flutter
/// (`ChangeNotifier`/`ValueListenable`, `package:flutter/material.dart` autorisé
/// sous `presentation/` depuis E2-8) et `form_builder_validators` (validateurs
/// PURS, jamais un état — E3-2) sont utilisées.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_field_spec.dart';
import '../z_field_listenable_builder.dart';
import '../z_form_controller.dart';
import 'z_validator_compiler.dart';

/// Widget hôte générique d'un **champ** d'édition, scellé sur sa tranche.
///
/// L'assembleur [DynamicEdition] DOIT poser `key: ValueKey(field.name)` (place
/// stable — AD-2) ; sans quoi un rebuild externe pourrait voler l'état d'un
/// voisin ou recréer le `TextEditingController`.
class ZEditionField extends StatefulWidget {
  /// Construit le champ pour [field], lié à la tranche `field.name` du
  /// [controller].
  const ZEditionField({
    required this.controller,
    required this.field,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contrôleur détenant la tranche du champ (créé/possédé par l'hôte ; jamais
  /// recréé dans un `build`).
  final ZFormController controller;

  /// Spécification `const` du champ rendu (`name`/`label`/… — E2-4/E2-5).
  final ZFieldSpec field;

  /// Hook d'instrumentation : appelé UNE FOIS en [State.initState] (preuve UJ-2
  /// « `State`/`TextEditingController` non recréés » via compteur == 1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook d'instrumentation : appelé à chaque (re)build de la **tranche** (dans
  /// le `builder` du slice) — compteur de build par champ pour SM-1 (AC6).
  @visibleForTesting
  final VoidCallback? onBuild;

  @override
  State<ZEditionField> createState() => _ZEditionFieldState();
}

class _ZEditionFieldState extends State<ZEditionField> {
  /// `TextEditingController` interne — créé UNE FOIS, jamais recréé (AD-2). Sa
  /// valeur n'est écrite QUE par la **sync guardée** hors focus (jamais dans la
  /// voie de frappe, jamais pendant l'édition — FR-1).
  late final TextEditingController _text;

  /// `FocusNode` **stable** — créé une fois, `dispose`. Oracle « le champ a le
  /// focus ? » de la sync guardée (AC2/AC6).
  late final FocusNode _focus;

  /// Validateur **mémoïsé** — compilé UNE fois depuis `field.validators`
  /// (identité stable entre builds ; `null` si aucun validateur champ-local).
  late final FormFieldValidator<String>? _validator;

  @override
  void initState() {
    super.initState();
    final initial = widget.controller.valueOf(widget.field.name);
    _text = TextEditingController(text: _stringOf(initial));
    _focus = FocusNode();
    _validator = ZValidatorCompiler.compile(widget.field.validators);
    widget.onInit?.call();
  }

  @override
  void dispose() {
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  /// Représentation textuelle stable d'une valeur de tranche (`null → ''`).
  static String _stringOf(Object? value) => value == null ? '' : '$value';

  @override
  Widget build(BuildContext context) => ZFieldListenableBuilder(
        controller: widget.controller,
        name: widget.field.name,
        // Frontière de rebuild : seul le changement de la tranche reconstruit
        // ce closure.
        builder: (context, value, child) {
          widget.onBuild?.call();

          // SYNC GUARDÉE (AC2/AC6, FR-1) : refléter une valeur EXTERNE dans le
          // champ UNIQUEMENT hors focus. Pendant l'édition (`hasFocus`), priorité
          // ABSOLUE à la saisie/au curseur en cours : AUCUN write-back (sinon on
          // écraserait la sélection — caret sauté). Pendant la frappe locale,
          // `onChanged → setValue` rend `value == _text.text` ⇒ condition fausse
          // ⇒ idempotent (aucune boucle, aucune ré-injection).
          final s = _stringOf(value);
          if (!_focus.hasFocus && _text.text != s) {
            _text.value = TextEditingValue(
              text: s,
              selection: TextSelection.collapsed(offset: s.length),
            );
          }

          return TextFormField(
            controller: _text,
            focusNode: _focus,
            // Validation CIBLÉE PAR CHAMP (AD-2) — jamais de `Form` global.
            autovalidateMode: AutovalidateMode.onUserInteraction,
            validator: _validator,
            decoration: InputDecoration(
              labelText: widget.field.label ?? widget.field.name,
            ),
            onChanged: (v) =>
                widget.controller.setValue(widget.field.name, v),
          );
        },
      );
}
