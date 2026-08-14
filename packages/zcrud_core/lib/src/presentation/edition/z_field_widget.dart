/// `ZFieldWidget` — **dispatcher de champ par type** + hôte scellé sur sa
/// tranche (invariant AD-2). Rend un contrôle **spécifique par famille**
/// (texte/nombre/date/booléen/select/relation), sans jamais élargir la
/// frontière de rebuild.
///
/// L'hôte générique scellé sur sa tranche (`ZFieldListenableBuilder`) porte la
/// place stable, le contrôleur/focus/validateur `late final` et la sync
/// guardée hors focus. Cette machinerie est **réutilisée INTÉGRALEMENT** (helper
/// de slice, `ZValidatorCompiler`, garde de sync) ; seul le **sous-arbre
/// interne** choisi par [familyOf] varie selon le type de champ.
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **Frontière de rebuild = la tranche** (invariant AD-2) : le rendu vit sous
///   [ZFieldListenableBuilder] ; seul le changement de la tranche `name`
///   reconstruit ce sous-arbre. Le dispatch choisit UNIQUEMENT le contrôle
///   interne rendu, jamais la frontière.
/// - **Contrôleur de texte alloué UNIQUEMENT pour les familles clavier** (texte
///   & nombre — [familyUsesTextController]) : créé 1× en [State.initState],
///   `dispose`, jamais recréé ni ré-injecté dans la voie de frappe. Sync guardée
///   hors focus. Les familles non-clavier (date/booléen/select/relation)
///   lisent `value` et écrivent via `controller.setValue` (aucun contrôleur).
/// - **Dispatch exhaustif** : la classification `EditionFieldType → EditionFamily`
///   est un `switch` **exhaustif SANS `default:`** ([familyOf]). `hidden` →
///   `SizedBox.shrink()` ; tout type « ailleurs » → [ZUnsupportedFieldWidget]
///   (repli contrôlé, jamais une exception).
/// - **Place stable** : l'assembleur ([DynamicEdition]) enveloppe la sortie dans
///   `KeyedSubtree(key: ValueKey(field.name))` — non contournable.
///
/// Aucun gestionnaire d'état (invariant AD-15) : primitives Flutter uniquement.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/z_date_range.dart';
import '../../domain/edition/z_derivation.dart';
import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_config.dart';
import '../../domain/edition/z_field_size.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_sub_list_config.dart';
import '../l10n/z_localizations.dart';
import '../z_field_listenable_builder.dart';
import '../z_form_controller.dart';
import '../zcrud_scope.dart';
import 'edition_field_family.dart';
import 'families/z_app_file_field_widget.dart';
// Ornements déclaratifs, label enrichi, fiche de lecture.
import 'families/z_boolean_field_widget.dart';
import 'families/z_color_field_widget.dart';
import 'families/z_color_multi_field_widget.dart';
import 'families/z_date_field_widget.dart';
import 'families/z_date_range_field_widget.dart';
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
import 'z_field_adornment_view.dart';
import 'z_field_label.dart';
import 'z_large_field_card.dart';
import 'z_read_only_field_card.dart';
import 'z_read_only_value.dart';
import 'z_select_choices_resolver.dart';
import 'z_value_emptiness.dart';
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
    this.readMode = false,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contrôleur détenant la tranche du champ (créé/possédé par l'hôte).
  final ZFormController controller;

  /// Spécification `const` du champ rendu (`name`/`type`/`label`/…).
  final ZFieldSpec field;

  /// Mode d'autovalidation transmis aux familles clavier (texte/nombre) —
  /// **additif**. `null` (défaut) ⇒ `onUserInteraction` (comportement
  /// inchangé). Le stepper le force à `always` pour **révéler** les
  /// erreurs des champs invalides d'une étape à une transition bloquée, SANS
  /// jamais introduire un `Form`/`FormBuilder` global (invariant AD-2).
  final AutovalidateMode? autovalidateMode;

  /// **Mode lecture GLOBAL** — drapeau de PRÉSENTATION **additif**
  /// (défaut `false`), signal DISTINCT de `ZFieldSpec.readOnly`. Quand `true` et
  /// que la famille est « fiche-able » ([zReadModeCardable]), le champ est rendu
  /// en **fiche de consultation** ([ZReadOnlyFieldCard]) au lieu du widget
  /// d'édition grisé. Les familles non fiche-ables conservent leur rendu
  /// `readOnly` existant (jamais régressé). Propagé par `DynamicEdition.readOnly`.
  final bool readMode;

  /// Hook d'instrumentation : appelé UNE FOIS en [State.initState] (preuve
  /// « State/contrôleur non recréés » via compteur == 1, invariant AD-2).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook d'instrumentation : appelé à chaque (re)build de la tranche (compteur
  /// de build par champ, invariant AD-2).
  @visibleForTesting
  final VoidCallback? onBuild;

  @override
  State<ZFieldWidget> createState() => _ZFieldWidgetState();
}

class _ZFieldWidgetState extends State<ZFieldWidget> {
  /// Famille de rendu résolue UNE FOIS (le `type` d'un champ ne change pas).
  late final EditionFamily _family;

  /// `true` si ce champ est rendu en **fiche de lecture** : `readMode`
  /// global ET famille fiche-able. Aucun contrôleur de texte n'est alloué dans
  /// ce cas (pas de clavier — invariant AD-2). Résolu UNE FOIS.
  late final bool _readModeCard;

  /// `TextEditingController` interne — alloué UNIQUEMENT pour les familles
  /// clavier (texte/nombre). Créé 1×, jamais recréé (invariant AD-2) ; sa
  /// valeur n'est écrite que par la sync guardée hors focus (jamais dans la
  /// voie de frappe).
  TextEditingController? _text;

  /// `FocusNode` **stable** — alloué pour les familles clavier (oracle de la
  /// sync guardée).
  FocusNode? _focus;

  /// Validateur **mémoïsé** — compilé 1× depuis `field.validators` : champ-local
  /// **+** inter-champs (closures capturant le controller). Identité
  /// stable ; `null` si aucun. Compilé pour **TOUTES** les familles afin que
  /// les non-texte puissent révéler leur message.
  FormFieldValidator<String>? _validator;

  /// Tranches des champs **référencés** par un validateur inter-champs (`refKey`)
  /// — abonnement CIBLÉ : un changement de la valeur référencée re-évalue
  /// CE champ, sans jamais passer par le `notifyListeners()` global (invariant
  /// AD-2).
  final List<Listenable> _refListenables = <Listenable>[];

  /// Listenable fusionné observé PAR-DESSUS la tranche du champ : canal de
  /// révélation ([controller.reveal]) + tranches référencées ([_refListenables]).
  /// Ne change QUE sur une soumission (révélation) ou un changement de champ
  /// référencé — jamais sur une frappe dans CE champ ou un champ tiers
  /// (invariant AD-2).
  late final Listenable _revealAndRefs;

  @override
  void initState() {
    super.initState();
    _family = familyOf(widget.field.type);
    _readModeCard = widget.readMode && zReadModeCardable(_family);
    // Validateur combiné (champ-local + inter-champs) pour toutes les familles.
    _validator =
        ZCrossFieldValidator.compileField(widget.field, widget.controller);
    // Abonnement CIBLÉ aux champs référencés (inter-champs) — jamais global.
    for (final refKey in ZCrossFieldValidator.refKeysOf(widget.field.validators)) {
      _refListenables.add(widget.controller.fieldListenable(refKey));
    }
    // Abonnement CIBLÉ aux `filterKeys` d'une relation dynamique — même canal
    // que refKeys (jamais global) : une frappe dans un filterKey recompute le
    // `filterContext` de CE champ relation (ré-abonnement du flux), sans
    // reconstruire le formulaire. `filterKeys` vide ⇒ aucun abonnement.
    if (_family == EditionFamily.relation &&
        widget.field.config is ZRelationConfig) {
      final relCfg = widget.field.config! as ZRelationConfig;
      for (final k in relCfg.filterKeys) {
        _refListenables.add(widget.controller.fieldListenable(k));
      }
    }
    // Abonnement CIBLÉ aux choix dynamiques cross-champ d'un `select` —
    // `choicesFromKey` (tranche portant les options) + `filterKeys` d'une
    // `ZChoicesSource` calculée. Même canal que refKeys/filterKeys relation
    // (jamais global) : un changement d'un champ source recompute UNIQUEMENT
    // ce champ select. Config absente ⇒ aucun abonnement (repli statique).
    // `rowChips` reçoit les MÊMES choix effectifs que `select` (il EST le
    // « select en mode chips ») : sans l'ajouter ici, le canal dynamique
    // serait résolu une fois puis jamais réévalué — une capacité câblée mais
    // inerte.
    if ((_family == EditionFamily.select ||
            _family == EditionFamily.rowChips) &&
        widget.field.config is ZSelectConfig) {
      final selCfg = widget.field.config! as ZSelectConfig;
      final fromKey = selCfg.choicesFromKey;
      if (fromKey != null) {
        _refListenables.add(widget.controller.fieldListenable(fromKey));
      }
      for (final k in selCfg.filterKeys) {
        _refListenables.add(widget.controller.fieldListenable(k));
      }
    }
    // Choix DÉRIVÉS D'AUTRES CHAMPS (`ZFieldSpec.choicesResolver`) : abonnement
    // CIBLÉ aux tranches que le résolveur LIT — découvertes par un premier
    // appel TRAÇANT (le `valueOf` passé enregistre les noms lus). Un changement
    // d'une tranche lue reconstruit UNIQUEMENT ce champ (jamais le formulaire —
    // invariant AD-2/SM-1) ; une tranche jamais lue ne déclenche rien. Le jeu
    // d'abonnements est FIGÉ au montage (première branche du résolveur) —
    // les dépendances d'un résolveur doivent être STABLES, comme les `sources`
    // d'une `ZDerivation`. Résolveur en erreur ⇒ aucun abonnement, le rendu
    // repliera (invariant AD-10).
    if ((_family == EditionFamily.select ||
            _family == EditionFamily.rowChips) &&
        widget.field.choicesResolver != null) {
      final read = <String>{};
      try {
        widget.field.choicesResolver!((name) {
          read.add(name);
          return widget.controller.valueOf(name);
        });
      } catch (_) {
        // Invariant AD-10 : les noms déjà lus avant l'erreur restent abonnés.
      }
      for (final name in read) {
        _refListenables.add(widget.controller.fieldListenable(name));
      }
    }
    // Options DÉRIVÉES : le moteur publie dans une tranche dédiée
    // `ZDerivationChannels.optionsKey(name)`. SANS cet abonnement, la tranche
    // changerait sans que ce champ le voie. Abonnement CIBLÉ : seul ce champ
    // recompute. Indépendant de `ZSelectConfig`, car un champ peut dériver ses
    // options sans porter de config de select.
    if (widget.field.derivedFrom?.options != null) {
      _refListenables.add(
        widget.controller
            .fieldListenable(ZDerivationChannels.optionsKey(widget.field.name)),
      );
    }
    _revealAndRefs = Listenable.merge(<Listenable>[
      widget.controller.reveal,
      ..._refListenables,
    ]);
    // Invariant AD-2 : aucun `TextEditingController`/`FocusNode` alloué pour un
    // champ rendu en fiche de lecture (pas de saisie, pas de clavier).
    if (familyUsesTextController(_family) && !_readModeCard) {
      final initial = widget.controller.valueOf(widget.field.name);
      _text = TextEditingController(text: _stringOf(initial));
      _focus = FocusNode();
      // Re-seed DIFFÉRÉ : une valeur externe survenue PENDANT le focus
      // (jamais écrasée alors) est reflétée à la PERTE de focus.
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
  /// EXTERNE (write-back différé) sans jamais toucher une saisie en cours
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
    // `hidden` : widget zéro-taille, aucune souscription de tranche.
    if (_family == EditionFamily.hidden) {
      widget.onBuild?.call();
      return const SizedBox.shrink();
    }
    // Repli contrôlé : type « ailleurs », aucune souscription requise.
    if (_family == EditionFamily.unsupported) {
      widget.onBuild?.call();
      return ZUnsupportedFieldWidget(field: widget.field);
    }
    // Mode lecture global + famille fiche-able → fiche de consultation
    // (label/valeur + copie) SOUS la tranche (reflète une écriture externe). Aucun
    // controller/focus (garde en `initState`) ; frontière = la tranche
    // (invariant AD-2).
    if (_readModeCard) {
      return ZFieldListenableBuilder(
        controller: widget.controller,
        name: widget.field.name,
        builder: (context, value, child) {
          widget.onBuild?.call();
          return _buildReadCard(context, value);
        },
      );
    }
    // Mini-CRUD imbriqué (invariant AD-2 — POINT DE VIGILANCE) : monté AVANT
    // la souscription à la tranche parente. Le conteneur écoute un canal
    // STRUCTUREL (add/remove/reorder) et agrège la tranche parente hors de la
    // voie de rebuild → taper dans un sous-champ ne reconstruit PAS cet hôte.
    // Valeur initiale lue une fois via `valueOf`.
    // Mini-CRUD imbriqués : hors de la tranche de valeur (canal structurel). Le
    // write-back externe les re-amorce en re-lisant `valueOf` sur incrément de
    // `reseedRevision` (re-clé) — jamais pendant une frappe (le canal ne
    // change que sur reset/reseed).
    if (_family == EditionFamily.subList) {
      return _withCollectionError(_reseedable((context) {
        widget.onBuild?.call();
        // ACL de ligne : l'ACL du `ZcrudScope` ambiant gouverne les actions
        // d'item du mode compact, avec ou sans `aclCollectionId` déclaré (ce
        // dernier ne fait que discriminer la collection interrogée). En
        // l'absence de scope, le repli est **refusant** — le câblage est laissé
        // à `ZSubListFieldWidget`, qui porte la même règle.
        final subCfg = widget.field.config;
        final aclCid =
            subCfg is ZSubListConfig ? subCfg.aclCollectionId : null;
        return ZSubListFieldWidget(
          field: widget.field,
          initialValue: widget.controller.valueOf(widget.field.name),
          collectionId: aclCid,
          onChanged: (list) =>
              widget.controller.setValue(widget.field.name, list),
        );
      }));
    }
    if (_family == EditionFamily.dynamicItem) {
      return _withCollectionError(_reseedable((context) {
        widget.onBuild?.call();
        return ZDynamicItemFieldWidget(
          field: widget.field,
          initialValue: widget.controller.valueOf(widget.field.name),
          onChanged: (item) =>
              widget.controller.setValue(widget.field.name, item),
        );
      }));
    }
    // Frontière de rebuild (invariant AD-2) : la tranche du champ (frappe)
    // reconstruit le closure INTERNE ; le canal [_revealAndRefs] (révélation +
    // champs référencés) enveloppe SANS élargir la frontière à une frappe
    // tierce.
    final reactive = ListenableBuilder(
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
    // La variante `large` enveloppe le RÉSULTAT du builder réactif dans une
    // Card (label au-dessus) — le wrapper est STATIQUE (monté hors de la voie
    // de frappe), il ne déplace JAMAIS la frontière de rebuild (invariant
    // AD-2). `normal` (défaut) : aucun wrapper, rendu inline inchangé.
    if (widget.field.fieldSize == ZFieldSize.large) {
      final resolvedLabel = label(
        context,
        widget.field.label ?? widget.field.name,
        fallback: widget.field.label ?? widget.field.name,
      );
      // Label enrichi (astérisque requis) + slots leading/suffix résolus
      // (statiquement, hors frontière de rebuild). Le `label` String reste porté
      // pour la sémantique conteneur de la Card (a11y).
      return ZLargeFieldCard(
        label: resolvedLabel,
        labelWidget: ZFieldLabel(field: widget.field, large: true),
        leading:
            resolveAdornment(context, widget.field.leading, field: widget.field),
        suffix:
            resolveAdornment(context, widget.field.suffix, field: widget.field),
        child: reactive,
      );
    }
    return reactive;
  }

  /// Rend la **fiche de lecture** : formate la [value] de la tranche
  /// (défensif, invariant AD-10) et compose [ZReadOnlyFieldCard] (label +
  /// valeur + copie).
  Widget _buildReadCard(BuildContext context, Object? value) {
    final resolvedLabel = label(
      context,
      widget.field.label ?? widget.field.name,
      fallback: widget.field.label ?? widget.field.name,
    );
    final rov = zReadOnlyValueOf(context, widget.field, value);
    final valueWidget = rov.widget ??
        Text(rov.text ?? '', textAlign: TextAlign.start);
    return ZReadOnlyFieldCard(
      label: resolvedLabel,
      value: valueWidget,
      copyText: rov.copyable ? rov.text : null,
    );
  }

  /// Enveloppe un sous-arbre à **buffer interne** (mini-CRUD/signature) dans un
  /// re-amorçage clé-de-révision : sur incrément de [ZFormController.reseedRevision]
  /// (reset/reseed), le sous-arbre est re-clé ⇒ re-lit `valueOf`. Le canal
  /// ne change JAMAIS sur une frappe (invariant AD-2 préservé).
  Widget _reseedable(WidgetBuilder builder) => ValueListenableBuilder<int>(
        valueListenable: widget.controller.reseedRevision,
        builder: (context, rev, _) => KeyedSubtree(
          key: ValueKey<String>('reseed:${widget.field.name}:$rev'),
          child: builder(context),
        ),
      );

  /// Rend le contrôle de la famille puis, pour les familles **non-texte**,
  /// ajoute la surface d'erreur révélée : les familles clavier portent
  /// NATIVEMENT l'erreur via `TextFormField.errorText`.
  Widget _dispatch(BuildContext context, Object? value, bool revealed) {
    final control = _buildControl(context, value, revealed);
    if (_family == EditionFamily.text || _family == EditionFamily.number) {
      return control;
    }
    return _wrapError(control, value, revealed);
  }

  /// Surface d'erreur des **mini-CRUD imbriqués** (`subItems`/`dynamicItem`).
  ///
  /// Ces deux familles sont montées **avant** la souscription à la tranche
  /// (canal structurel) et ne passent donc pas par [_wrapError]. Sans cette
  /// surface dédiée, une sous-liste **requise et vide** bloquerait la
  /// soumission et le gate d'étape **sans afficher le moindre message** — un
  /// refus muet, pire qu'un refus.
  ///
  /// L'invariant AD-2 est préservé par **deux** propriétés :
  /// 1. le conteneur est **construit hors** de la voie de valeur (il arrive
  ///    déjà bâti en paramètre) et transite par `child:` — la souscription à la
  ///    tranche n'élargit donc pas la frontière de rebuild. Construire le
  ///    conteneur *dans* le builder de tranche reconstruirait le mini-CRUD à
  ///    chaque agrégation. (Le `child:` seul n'est qu'une optimisation : c'est
  ///    le **lieu de construction** qui protège.)
  /// 2. la **forme de l'arbre est STABLE**. Réutiliser [_wrapError] ici ferait
  ///    alterner `Column(conteneur, erreur)` et `conteneur` selon la présence
  ///    du message — ce **reparentage** détruirait l'élément du mini-CRUD
  ///    (compteur de création 1 → 2), donc l'état de ses items en cours
  ///    d'édition. La place de l'erreur est ici **toujours occupée**
  ///    (`SizedBox.shrink()` quand il n'y a rien à dire), exactement comme la
  ///    « place stable » exigée des champs conditionnels.
  Widget _withCollectionError(Widget container) {
    if (_validator == null) return container;
    return ListenableBuilder(
      listenable: _revealAndRefs,
      builder: (context, _) {
        final revealed = widget.autovalidateMode == AutovalidateMode.always ||
            widget.controller.reveal.value > 0;
        return ZFieldListenableBuilder(
          controller: widget.controller,
          name: widget.field.name,
          child: container,
          builder: (context, value, child) {
            final error =
                revealed ? _validator!(zValidationText(value)) : null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                child!,
                if (error == null)
                  const SizedBox.shrink()
                else
                  Semantics(
                    liveRegion: true,
                    container: true,
                    child: Padding(
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
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
          },
        );
      },
    );
  }

  /// Adjoint une surface d'erreur **accessible** (`Semantics(liveRegion)` + `Text`)
  /// sous [child] lorsque la révélation est active et que le validateur combiné
  /// (champ-local + inter-champs) échoue — sans jamais monter de `Form` global
  /// (AD-2). Message uniforme issu du validateur mémoïsé.
  Widget _wrapError(Widget child, Object? value, bool revealed) {
    if (!revealed || _validator == null) return child;
    // Projection de VALIDATION (une collection/map VIDE ⇒ `''`), et non
    // `_stringOf` (qui rendrait `"[]"`, non vide ⇒ `required` accepterait un
    // champ obligatoire NON rempli).
    final error = _validator!(zValidationText(value));
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
    // En `large`, les familles décor-portantes rendent leur `InputDecoration`
    // en mode « bare » (le décor est porté par la Card).
    final bare = field.fieldSize == ZFieldSize.large;
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
          bare: bare,
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
          bare: bare,
          onChanged: (parsed) => widget.controller.setValue(field.name, parsed),
        );
      case EditionFamily.date:
        // Seul point du cœur détenant le `ZFormController` : il résout les
        // bornes (littéral > cross-champ) via des fermetures pur-Dart injectées
        // au widget, évaluées AU TAP — aucun abonnement réactif cross-champ,
        // aucun rebuild global (invariant AD-2). Le widget reste
        // `StatelessWidget` pur, sans `ZFormController`.
        final dateCfg =
            field.config is ZDateConfig ? field.config! as ZDateConfig : null;
        return ZDateFieldWidget(
          field: field,
          value: value,
          onChanged: (iso) => widget.controller.setValue(field.name, iso),
          firstDate: () =>
              _resolveDateBound(dateCfg?.minDateIso, dateCfg?.firstDateKey),
          lastDate: () =>
              _resolveDateBound(dateCfg?.maxDateIso, dateCfg?.lastDateKey),
          // Croix d'effacement UNIQUEMENT pour un champ non requis et
          // éditable (retour à `null`). Un champ requis ne l'affiche pas.
          onCleared: (field.isRequired || field.readOnly)
              ? null
              : () => widget.controller.setValue(field.name, null),
        );
      case EditionFamily.dateRange:
        // Plage de dates (AD-47) : même chemin `ZFieldListenableBuilder`/
        // `setValue` que la famille date. Widget `StatelessWidget` pur (ne reçoit
        // jamais le `ZFormController`) ; `showDateRangePicker` = SDK (CORE OUT=0).
        //
        // Ce point est le SEUL à détenir à la fois la déclaration du champ et
        // l'écriture de la tranche : il y honore les DEUX familles de
        // contraintes de `ZDateConfig` — les bornes (OÙ la plage se situe,
        // résolues paresseusement comme pour la famille date sœur) et
        // l'amplitude (QUELLE LARGEUR elle peut avoir, vérifiée au retour du
        // sélecteur). Les deux se cumulent sans se contredire.
        final rangeCfg =
            field.config is ZDateConfig ? field.config! as ZDateConfig : null;
        return ZDateRangeFieldWidget(
          field: field,
          value: value,
          onChanged: (range) => _commitDateRange(context, field, rangeCfg, range),
          firstDate: () =>
              _resolveDateBound(rangeCfg?.minDateIso, rangeCfg?.firstDateKey),
          lastDate: () =>
              _resolveDateBound(rangeCfg?.maxDateIso, rangeCfg?.lastDateKey),
          // Croix d'effacement UNIQUEMENT pour un champ non requis et
          // éditable (retour à `null`).
          onCleared: (field.isRequired || field.readOnly)
              ? null
              : () => widget.controller.setValue(field.name, null),
        );
      case EditionFamily.boolean:
        // `boolean` consulte le MÊME seam de registre que les familles
        // routées (`registryOrFallback`, `freeWidget`) — `kind ==
        // field.type.name`, contexte `ZFieldWidgetContext`, écriture
        // `onChanged → setValue`. Aucune seconde convention. PRIORITÉ : un
        // builder enregistré GAGNE ; aucun builder ⇒ rendu NATIF ci-dessous.
        final custom = _tryRegistryWidget(context, field, value);
        if (custom != null) return custom;
        return ZBooleanFieldWidget(
          field: field,
          value: value,
          onChanged: (b) => widget.controller.setValue(field.name, b),
        );
      case EditionFamily.select:
        // Résout la config select + les **choix effectifs** (dynamiques
        // cross-champ) selon la priorité `choicesSourceKey` → `choicesFromKey`
        // → `field.choices` (défensif invariant AD-10). Sans `ZSelectConfig`
        // ⇒ comportement strict sur `field.choices`.
        final selCfg =
            field.config is ZSelectConfig ? field.config! as ZSelectConfig : null;
        return ZSelectFieldWidget(
          field: field,
          value: value,
          choices: _resolveSelectChoices(context, field, selCfg),
          searchable: selCfg?.searchable ?? false,
          modalThreshold: selCfg?.modalThreshold,
          multiple: field.multiple,
          bare: bare,
          // `radio` en modal (option config) + bouton reset (→ null) pour
          // un select/radio MONO non requis et éditable (jamais en multi).
          radioAsModal: selCfg?.radioAsModal ?? false,
          onCleared: (field.multiple || field.isRequired || field.readOnly)
              ? null
              : () => widget.controller.setValue(field.name, null),
          onChanged: (sel) => widget.controller.setValue(field.name, sel),
        );
      case EditionFamily.relation:
        // Résout la source dynamique NEUTRE (via le registre injecté au
        // scope + `sourceKey`) et bâtit le `filterContext` (snapshot des
        // `filterKeys`). Aucun `ZRelationConfig`/registre/source → `source: null`
        // ⇒ repli statique STRICT sur `choices`. Aucun backend dans le cœur :
        // seule l'abstraction est résolue ici (invariants AD-1/AD-5).
        final relCfg =
            field.config is ZRelationConfig ? field.config! as ZRelationConfig : null;
        final sourceKey = relCfg?.sourceKey;
        final source = sourceKey == null
            ? null
            : ZcrudScope.maybeOf(context)
                ?.relationSourceRegistry
                ?.trySourceFor(sourceKey);
        final filterContext = <String, Object?>{};
        if (relCfg != null) {
          for (final k in relCfg.filterKeys) {
            filterContext[k] = widget.controller.valueOf(k);
          }
        }
        // Résout le handler **CRUD inline** neutre (via le registre injecté
        // au scope + `crudKey`). Aucun `crudKey`/registre/handler →
        // `crudHandler: null` (repli strict, aucun bouton).
        final crudKey = relCfg?.crudKey;
        final crudHandler = crudKey == null
            ? null
            : ZcrudScope.maybeOf(context)
                ?.relationCrudRegistry
                ?.trySourceFor(crudKey);
        return ZRelationFieldWidget(
          field: field,
          value: value,
          options: field.choices,
          source: source,
          filterContext: filterContext,
          multiple: field.multiple,
          searchable: relCfg?.searchable ?? false,
          crudHandler: crudHandler,
          onChanged: (sel) => widget.controller.setValue(field.name, sel),
        );
      case EditionFamily.tags:
        return ZTagsFieldWidget(
          field: field,
          value: value,
          onChanged: (tags) => widget.controller.setValue(field.name, tags),
        );
      case EditionFamily.rowChips:
        // `rowChips` EST le « select en mode chips ». Il reçoit donc la MÊME
        // résolution de choix effectifs que la famille `select` (sans
        // `ZSelectConfig` ni `derivedFrom.options`, `_resolveSelectChoices`
        // rend exactement `field.choices`), et la multiplicité vient de
        // `ZFieldSpec.multiple`.
        final chipsCfg =
            field.config is ZSelectConfig ? field.config! as ZSelectConfig : null;
        return ZRowChipsFieldWidget(
          field: field,
          value: value,
          choices: _resolveSelectChoices(context, field, chipsCfg),
          multiple: field.multiple,
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
        // Dispatch conditionnel simple/multiple. Un `ZColorConfig.multiple`
        // (⇒ `multiple == true`) monte le widget multi-sélection (valeur
        // `List<int>` ARGB) ; sinon le champ mono reste strictement intact
        // (valeur `int` ARGB — rétro-compat).
        final colorCfg = field.config;
        if (colorCfg is ZColorConfig && colorCfg.multiple) {
          return ZColorMultiFieldWidget(
            field: field,
            value: value,
            onChanged: (list) => widget.controller.setValue(field.name, list),
          );
        }
        return ZColorFieldWidget(
          field: field,
          value: value,
          onChanged: (argb) => widget.controller.setValue(field.name, argb),
        );
      case EditionFamily.signature:
        // Value-in-slice à propriété locale : `value` amorce le tracé une fois
        // (State persistant à travers les rebuilds du slice — invariant AD-2).
        // Re-clé sur `reseedRevision` pour re-amorcer le tracé sur reset/reseed.
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
        // Famille fichier : value-in-slice, seams picker/storage injectés
        // via `ZcrudScope` (défaut `null` → dégradation propre).
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
        // STRUCTUREL, pas la tranche de valeur (invariant AD-2).
        return const SizedBox.shrink();
    }
  }

  /// Résout les **choix effectifs** d'un `select` — **délègue** à
  /// `zResolveSelectChoices` (source unique, cf. `z_select_choices_resolver.dart`).
  /// La priorité et les replis y sont documentés ; ce paquet n'en garde qu'UNE
  /// copie, partagée avec la projection d'affichage du résumé de sous-liste.
  List<ZFieldChoice> _resolveSelectChoices(
    BuildContext context,
    ZFieldSpec field,
    ZSelectConfig? selCfg,
  ) =>
      zResolveSelectChoices(context, widget.controller, field, selCfg);

  /// Résout une borne de date : le **littéral** [iso] (ISO-8601 parsé)
  /// prime ; à défaut, la valeur **cross-champ** du champ [key] lue via
  /// `ZFormController.valueOf` (String ISO parsée ou `DateTime` accepté tel
  /// quel). Toute valeur absente/non parsable ⇒ `null` (le widget repliera sur
  /// 1900/2100). **Jamais de throw** (invariant AD-10).
  /// Écrit la plage retenue dans la tranche — **sauf** si son amplitude sort de
  /// ce que le champ déclare ([ZDateConfig.maxDays]/[ZDateConfig.minDays]).
  ///
  /// Le refus a lieu **à la sélection**, au retour du sélecteur : la plage
  /// n'est pas écrite (la tranche conserve donc sa valeur précédente, et le
  /// champ continue d'afficher la période d'avant), et le motif est présenté et
  /// **annoncé** sur le champ concerné. Aucun report à la validation du
  /// formulaire : l'utilisateur n'a pas à deviner quel champ corriger.
  ///
  /// Sans amplitude déclarée, le chemin est celui d'avant : écriture directe.
  void _commitDateRange(
    BuildContext context,
    ZFieldSpec field,
    ZDateConfig? config,
    ZDateRange range,
  ) {
    final String? refusal = zDateSpanRefusalMessage(context, config, range);
    if (refusal == null) {
      widget.controller.setValue(field.name, range);
      return;
    }
    zShowDateSpanRefusal(context, refusal);
  }

  DateTime? _resolveDateBound(String? iso, String? key) {
    final literal = iso != null ? DateTime.tryParse(iso) : null;
    if (literal != null) return literal;
    if (key != null) {
      final v = widget.controller.valueOf(key);
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
    }
    return null;
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
  ) =>
      _tryRegistryWidget(context, field, value) ??
      ZUnsupportedFieldWidget(field: field);

  /// Lookup **défensif** du seam de registre (invariant AD-10) : le widget hôte
  /// du champ s'il est enregistré, sinon `null` — **le** point unique où la
  /// convention de `kind` et la construction du `ZFieldWidgetContext` sont
  /// écrites. Deux appelants : [_dispatchRegistry] (repli
  /// `ZUnsupportedFieldWidget`) et la famille `boolean` (repli **natif**).
  ///
  /// Résolution du `kind` : le **discriminant déclaré** `field.widgetKind` est
  /// consulté d'abord (deux champs `widget`/`custom` d'un même formulaire
  /// peuvent porter deux builders distincts) ; s'il est absent — ou qu'aucun
  /// builder n'est enregistré sous ce discriminant —, repli **inchangé** sur
  /// `field.type.name` (défensif, invariant AD-10).
  Widget? _tryRegistryWidget(
    BuildContext context,
    ZFieldSpec field,
    Object? value,
  ) {
    final registry = ZcrudScope.maybeOf(context)?.widgetRegistry;
    final wk = field.widgetKind;
    final builder = (wk == null ? null : registry?.tryBuilderFor(wk)) ??
        registry?.tryBuilderFor(field.type.name);
    if (builder == null) return null;
    return builder(
      context,
      ZFieldWidgetContext(
        field: field,
        value: value,
        onChanged: (v) => widget.controller.setValue(field.name, v),
      ),
    );
  }

  /// SYNC GUARDÉE : refléter une valeur EXTERNE dans le champ clavier
  /// UNIQUEMENT hors focus. Pendant l'édition (`hasFocus`), priorité
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
