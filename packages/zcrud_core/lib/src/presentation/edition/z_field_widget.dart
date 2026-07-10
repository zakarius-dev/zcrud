/// `ZFieldWidget` — **dispatcher de champ par type** + hôte scellé sur sa
/// tranche (E3-3a, AD-2 / OBJECTIF PRODUIT N°1). Remplace le rendu **uniforme**
/// d'E3-1/E3-2 par un rendu **spécifique par famille** (texte/nombre/date/
/// booléen/select/relation), sans jamais élargir la frontière de rebuild.
///
/// origine: E3-1 (`ZEditionField`) a livré l'hôte générique scellé sur sa
/// tranche (`ZFieldListenableBuilder`) + place stable ; E3-2 a durci la
/// stabilité (contrôleur/focus/validateur `late final`, sync guardée hors focus).
/// E3-3a **réutilise INTÉGRALEMENT** cette machinerie (helper de slice,
/// `ZValidatorCompiler`, garde de sync) et n'échange que le **sous-arbre interne**
/// choisi par [familyOf].
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **Frontière de rebuild = la tranche** (AD-2) : le rendu vit sous
///   [ZFieldListenableBuilder] ; seul le changement de la tranche `name`
///   reconstruit ce sous-arbre. Le dispatch choisit UNIQUEMENT le contrôle
///   interne rendu, jamais la frontière.
/// - **Contrôleur de texte alloué UNIQUEMENT pour les familles clavier** (texte
///   & nombre — [familyUsesTextController]) : créé 1× en [State.initState],
///   `dispose`, jamais recréé ni ré-injecté dans la voie de frappe. Sync guardée
///   hors focus (FR-1). Les familles non-clavier (date/booléen/select/relation)
///   lisent `value` et écrivent via `controller.setValue` (aucun contrôleur).
/// - **Dispatch exhaustif** : la classification `EditionFieldType → EditionFamily`
///   est un `switch` **exhaustif SANS `default:`** ([familyOf], AC2). `hidden` →
///   `SizedBox.shrink()` ; tout type « ailleurs » → [ZUnsupportedFieldWidget]
///   (repli contrôlé, jamais une exception — AC3).
/// - **Place stable** : l'assembleur ([DynamicEdition]) enveloppe la sortie dans
///   `KeyedSubtree(key: ValueKey(field.name))` (garde L3/AC7) — invariant UJ-2
///   non contournable.
///
/// Aucun gestionnaire d'état (AD-15) : primitives Flutter uniquement.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_field_spec.dart';
import '../z_field_listenable_builder.dart';
import '../z_form_controller.dart';
import '../zcrud_scope.dart';
import 'edition_field_family.dart';
import 'families/z_app_file_field_widget.dart';
import 'families/z_boolean_field_widget.dart';
import 'families/z_color_field_widget.dart';
import 'families/z_date_field_widget.dart';
import 'families/z_dynamic_item_field_widget.dart';
import 'families/z_free_widget_field_widget.dart';
import 'families/z_number_field_widget.dart';
import 'families/z_rating_field_widget.dart';
import 'families/z_relation_field_widget.dart';
import 'families/z_row_chips_field_widget.dart';
import 'families/z_select_field_widget.dart';
import 'families/z_signature_field_widget.dart';
import 'families/z_slider_field_widget.dart';
import 'families/z_sub_list_field_widget.dart';
import 'families/z_tags_field_widget.dart';
import 'families/z_text_field_widget.dart';
import 'families/z_unsupported_field_widget.dart';
import 'z_cross_field_validator.dart';
import 'z_widget_registry.dart';

/// Dispatcher de champ par type + hôte scellé sur la tranche `field.name`.
///
/// L'assembleur [DynamicEdition] pose la place stable (`KeyedSubtree` /
/// `ValueKey(field.name)`) ; ce widget ne la pose pas lui-même.
class ZFieldWidget extends StatefulWidget {
  /// Construit le champ pour [field], lié à la tranche `field.name` du
  /// [controller].
  const ZFieldWidget({
    required this.controller,
    required this.field,
    this.autovalidateMode,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contrôleur détenant la tranche du champ (créé/possédé par l'hôte).
  final ZFormController controller;

  /// Spécification `const` du champ rendu (`name`/`type`/`label`/…).
  final ZFieldSpec field;

  /// Mode d'autovalidation transmis aux familles clavier (texte/nombre) —
  /// **additif** (E3-5). `null` (défaut) ⇒ `onUserInteraction` (comportement
  /// E3-2/E3-3a inchangé). Le stepper le force à `always` pour **révéler** les
  /// erreurs des champs invalides d'une étape à une transition bloquée, SANS
  /// jamais introduire un `Form`/`FormBuilder` global (AD-2).
  final AutovalidateMode? autovalidateMode;

  /// Hook d'instrumentation : appelé UNE FOIS en [State.initState] (preuve
  /// UJ-2/SM-1 « State/contrôleur non recréés » via compteur == 1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook d'instrumentation : appelé à chaque (re)build de la tranche (compteur
  /// de build par champ pour SM-1).
  @visibleForTesting
  final VoidCallback? onBuild;

  @override
  State<ZFieldWidget> createState() => _ZFieldWidgetState();
}

class _ZFieldWidgetState extends State<ZFieldWidget> {
  /// Famille de rendu résolue UNE FOIS (le `type` d'un champ ne change pas).
  late final EditionFamily _family;

  /// `TextEditingController` interne — alloué UNIQUEMENT pour les familles
  /// clavier (texte/nombre). Créé 1×, jamais recréé (AD-2) ; sa valeur n'est
  /// écrite que par la sync guardée hors focus (jamais dans la voie de frappe).
  TextEditingController? _text;

  /// `FocusNode` **stable** — alloué pour les familles clavier (oracle de la
  /// sync guardée).
  FocusNode? _focus;

  /// Validateur **mémoïsé** — compilé 1× depuis `field.validators` : champ-local
  /// (E3-2) **+** inter-champs (E3-6, closures capturant le controller). Identité
  /// stable ; `null` si aucun. Compilé pour **TOUTES** les familles (E3-6) afin
  /// que les non-texte puissent révéler leur message (report a / MEDIUM-1 E3-5).
  FormFieldValidator<String>? _validator;

  /// Tranches des champs **référencés** par un validateur inter-champs (`refKey`)
  /// — abonnement CIBLÉ (AC12) : un changement de la valeur référencée re-évalue
  /// CE champ, sans jamais passer par le `notifyListeners()` global (SM-1).
  final List<Listenable> _refListenables = <Listenable>[];

  /// Listenable fusionné observé PAR-DESSUS la tranche du champ : canal de
  /// révélation ([controller.reveal]) + tranches référencées ([_refListenables]).
  /// Ne change QUE sur une soumission (révélation) ou un changement de champ
  /// référencé — jamais sur une frappe dans CE champ ou un champ tiers (SM-1).
  late final Listenable _revealAndRefs;

  @override
  void initState() {
    super.initState();
    _family = familyOf(widget.field.type);
    // Validateur combiné (champ-local + inter-champs) pour toutes les familles.
    _validator =
        ZCrossFieldValidator.compileField(widget.field, widget.controller);
    // Abonnement CIBLÉ aux champs référencés (inter-champs) — jamais global.
    for (final refKey in ZCrossFieldValidator.refKeysOf(widget.field.validators)) {
      _refListenables.add(widget.controller.fieldListenable(refKey));
    }
    _revealAndRefs = Listenable.merge(<Listenable>[
      widget.controller.reveal,
      ..._refListenables,
    ]);
    if (familyUsesTextController(_family)) {
      final initial = widget.controller.valueOf(widget.field.name);
      _text = TextEditingController(text: _stringOf(initial));
      _focus = FocusNode();
      // Re-seed DIFFÉRÉ (AC13, FR-1) : une valeur externe survenue PENDANT le
      // focus (jamais écrasée alors) est reflétée à la PERTE de focus.
      _focus!.addListener(_onFocusChange);
    }
    widget.onInit?.call();
  }

  @override
  void dispose() {
    _focus?.removeListener(_onFocusChange);
    _focus?.dispose();
    _text?.dispose();
    super.dispose();
  }

  /// À la perte de focus d'un champ clavier : reflète une éventuelle valeur
  /// EXTERNE (write-back différé, AC13) sans jamais toucher une saisie en cours
  /// (ce handler n'agit qu'une fois `hasFocus == false`).
  void _onFocusChange() {
    if (_focus == null || _text == null || _focus!.hasFocus) return;
    final s = _stringOf(widget.controller.valueOf(widget.field.name));
    if (_text!.text != s) {
      _text!.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }

  /// Représentation textuelle stable d'une valeur de tranche (`null → ''`).
  static String _stringOf(Object? value) => value == null ? '' : '$value';

  @override
  Widget build(BuildContext context) {
    // `hidden` : widget zéro-taille, aucune souscription de tranche (AC4).
    if (_family == EditionFamily.hidden) {
      widget.onBuild?.call();
      return const SizedBox.shrink();
    }
    // Repli contrôlé : type « ailleurs », aucune souscription requise (AC3).
    if (_family == EditionFamily.unsupported) {
      widget.onBuild?.call();
      return ZUnsupportedFieldWidget(field: widget.field);
    }
    // Mini-CRUD imbriqué (E3-3b-2, AD-2 — POINT DE VIGILANCE N°1) : monté AVANT
    // la souscription à la tranche parente. Le conteneur écoute un canal
    // STRUCTUREL (add/remove/reorder) et agrège la tranche parente hors de la
    // voie de rebuild → taper dans un sous-champ ne reconstruit PAS cet hôte
    // (SM-1 imbriqué). Valeur initiale lue une fois via `valueOf`.
    // Mini-CRUD imbriqués : hors de la tranche de valeur (canal structurel). Le
    // write-back externe (AC13) les re-amorce en re-lisant `valueOf` sur
    // incrément de `reseedRevision` (re-clé) — jamais pendant une frappe (le
    // canal ne change que sur reset/reseed).
    if (_family == EditionFamily.subList) {
      return _reseedable((context) {
        widget.onBuild?.call();
        return ZSubListFieldWidget(
          field: widget.field,
          initialValue: widget.controller.valueOf(widget.field.name),
          onChanged: (list) =>
              widget.controller.setValue(widget.field.name, list),
        );
      });
    }
    if (_family == EditionFamily.dynamicItem) {
      return _reseedable((context) {
        widget.onBuild?.call();
        return ZDynamicItemFieldWidget(
          field: widget.field,
          initialValue: widget.controller.valueOf(widget.field.name),
          onChanged: (item) =>
              widget.controller.setValue(widget.field.name, item),
        );
      });
    }
    // Frontière de rebuild (AD-2) : la tranche du champ (frappe) reconstruit le
    // closure INTERNE ; le canal [_revealAndRefs] (révélation + champs référencés)
    // enveloppe SANS élargir la frontière à une frappe tierce (SM-1).
    return ListenableBuilder(
      listenable: _revealAndRefs,
      builder: (context, _) {
        final revealed = widget.autovalidateMode == AutovalidateMode.always ||
            widget.controller.reveal.value > 0;
        return ZFieldListenableBuilder(
          controller: widget.controller,
          name: widget.field.name,
          builder: (context, value, child) {
            widget.onBuild?.call();
            return _dispatch(context, value, revealed);
          },
        );
      },
    );
  }

  /// Enveloppe un sous-arbre à **buffer interne** (mini-CRUD/signature) dans un
  /// re-amorçage clé-de-révision : sur incrément de [ZFormController.reseedRevision]
  /// (reset/reseed), le sous-arbre est re-clé ⇒ re-lit `valueOf` (AC13). Le canal
  /// ne change JAMAIS sur une frappe (SM-1 imbriqué préservé).
  Widget _reseedable(WidgetBuilder builder) => ValueListenableBuilder<int>(
        valueListenable: widget.controller.reseedRevision,
        builder: (context, rev, _) => KeyedSubtree(
          key: ValueKey<String>('reseed:${widget.field.name}:$rev'),
          child: builder(context),
        ),
      );

  /// Rend le contrôle de la famille puis, pour les familles **non-texte**,
  /// ajoute la surface d'erreur révélée (report a / MEDIUM-1 E3-5) : les familles
  /// clavier portent NATIVEMENT l'erreur via `TextFormField.errorText`.
  Widget _dispatch(BuildContext context, Object? value, bool revealed) {
    final control = _buildControl(context, value, revealed);
    if (_family == EditionFamily.text || _family == EditionFamily.number) {
      return control;
    }
    return _wrapError(control, value, revealed);
  }

  /// Adjoint une surface d'erreur **accessible** (`Semantics(liveRegion)` + `Text`)
  /// sous [child] lorsque la révélation est active et que le validateur combiné
  /// (champ-local + inter-champs) échoue — sans jamais monter de `Form` global
  /// (AD-2). Message uniforme issu du validateur mémoïsé.
  Widget _wrapError(Widget child, Object? value, bool revealed) {
    if (!revealed || _validator == null) return child;
    final error = _validator!(_stringOf(value));
    if (error == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        Semantics(
          liveRegion: true,
          container: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
            child: Text(
              error,
              textAlign: TextAlign.start,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControl(BuildContext context, Object? value, bool revealed) {
    final field = widget.field;
    final autovalidate = revealed
        ? AutovalidateMode.always
        : (widget.autovalidateMode ?? AutovalidateMode.onUserInteraction);
    switch (_family) {
      case EditionFamily.text:
        _syncText(value);
        return ZTextFieldWidget(
          field: field,
          controller: _text!,
          focusNode: _focus!,
          validator: _validator,
          autovalidateMode: autovalidate,
          onChanged: (v) => widget.controller.setValue(field.name, v),
        );
      case EditionFamily.number:
        _syncText(value);
        return ZNumberFieldWidget(
          field: field,
          controller: _text!,
          focusNode: _focus!,
          validator: _validator,
          autovalidateMode: autovalidate,
          onChanged: (parsed) => widget.controller.setValue(field.name, parsed),
        );
      case EditionFamily.date:
        return ZDateFieldWidget(
          field: field,
          value: value,
          onChanged: (iso) => widget.controller.setValue(field.name, iso),
        );
      case EditionFamily.boolean:
        return ZBooleanFieldWidget(
          field: field,
          value: value,
          onChanged: (b) => widget.controller.setValue(field.name, b),
        );
      case EditionFamily.select:
        return ZSelectFieldWidget(
          field: field,
          value: value,
          onChanged: (sel) => widget.controller.setValue(field.name, sel),
        );
      case EditionFamily.relation:
        return ZRelationFieldWidget(
          field: field,
          value: value,
          onChanged: (sel) => widget.controller.setValue(field.name, sel),
        );
      case EditionFamily.tags:
        return ZTagsFieldWidget(
          field: field,
          value: value,
          onChanged: (tags) => widget.controller.setValue(field.name, tags),
        );
      case EditionFamily.rowChips:
        return ZRowChipsFieldWidget(
          field: field,
          value: value,
          onChanged: (sel) => widget.controller.setValue(field.name, sel),
        );
      case EditionFamily.rating:
        return ZRatingFieldWidget(
          field: field,
          value: value,
          onChanged: (n) => widget.controller.setValue(field.name, n),
        );
      case EditionFamily.slider:
        return ZSliderFieldWidget(
          field: field,
          value: value,
          onChanged: (n) => widget.controller.setValue(field.name, n),
        );
      case EditionFamily.color:
        return ZColorFieldWidget(
          field: field,
          value: value,
          onChanged: (argb) => widget.controller.setValue(field.name, argb),
        );
      case EditionFamily.signature:
        // Value-in-slice à propriété locale : `value` amorce le tracé une fois
        // (State persistant à travers les rebuilds du slice — AD-2). Re-clé sur
        // `reseedRevision` pour re-amorcer le tracé sur reset/reseed (AC13).
        return ZSignatureFieldWidget(
          key: ValueKey<String>(
              'sig:${field.name}:${widget.controller.reseedRevision.value}'),
          field: field,
          initialValue: value,
          onChanged: (encoded) =>
              widget.controller.setValue(field.name, encoded),
        );
      case EditionFamily.freeWidget:
        // Widget libre host-fourni via le MÊME seam de registre (repli si non
        // enregistré) — value-in-slice, `onChanged → setValue`.
        return ZFreeWidgetFieldWidget(
          field: field,
          value: value,
          onChanged: (v) => widget.controller.setValue(field.name, v),
        );
      case EditionFamily.file:
        // Famille fichier (E3-3c) : value-in-slice, seams picker/storage
        // injectés via `ZcrudScope` (défaut `null` → dégradation propre).
        return ZAppFileField(
          field: field,
          value: value,
          liveValue: () => widget.controller.valueOf(field.name),
          onChanged: (v) => widget.controller.setValue(field.name, v),
        );
      case EditionFamily.registryOrFallback:
        return _dispatchRegistry(context, field, value);
      case EditionFamily.subList:
      case EditionFamily.dynamicItem:
      case EditionFamily.hidden:
      case EditionFamily.unsupported:
        // Traités AVANT la souscription au slice (jamais atteints ici) : les
        // mini-CRUD imbriqués (subList/dynamicItem) écoutent un canal
        // STRUCTUREL, pas la tranche de valeur (SM-1 imbriqué, AD-2).
        return const SizedBox.shrink();
    }
  }

  /// Résout un type servi **ailleurs** (markdown/géo/tél/`icon`/`custom`) via le
  /// [ZWidgetRegistry] injecté (`ZcrudScope.widgetRegistry`) : si le `kind` est
  /// enregistré, rend le widget hôte **dans** la tranche (value-in-slice,
  /// `onChanged → setValue`) ; sinon repli contrôlé [ZUnsupportedFieldWidget].
  ///
  /// Convention `kind` (alignée sur `ZTypeRegistry`) : le **nom de l'enum**
  /// (`field.type.name` ; `'custom'` pour `EditionFieldType.custom`). Le cœur
  /// n'importe AUCUN package satellite : le widget réel est fourni par l'app.
  Widget _dispatchRegistry(
    BuildContext context,
    ZFieldSpec field,
    Object? value,
  ) {
    final registry = ZcrudScope.maybeOf(context)?.widgetRegistry;
    final builder = registry?.tryBuilderFor(field.type.name);
    if (builder == null) {
      return ZUnsupportedFieldWidget(field: field);
    }
    return builder(
      context,
      ZFieldWidgetContext(
        field: field,
        value: value,
        onChanged: (v) => widget.controller.setValue(field.name, v),
      ),
    );
  }

  /// SYNC GUARDÉE (E3-2, FR-1) : refléter une valeur EXTERNE dans le champ
  /// clavier UNIQUEMENT hors focus. Pendant l'édition (`hasFocus`), priorité
  /// ABSOLUE à la saisie/au curseur — aucun write-back (sinon caret sauté).
  void _syncText(Object? value) {
    final s = _stringOf(value);
    if (!_focus!.hasFocus && _text!.text != s) {
      _text!.value = TextEditingValue(
        text: s,
        selection: TextSelection.collapsed(offset: s.length),
      );
    }
  }
}
