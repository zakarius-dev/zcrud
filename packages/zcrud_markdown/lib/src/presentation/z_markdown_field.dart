/// `ZMarkdownField` — champ **rich-text** (éditeur Quill) au controller ISOLÉ,
/// scellé sur **sa seule tranche** de `ZFormController` (AD-2, AD-7, OBJECTIF
/// PRODUIT N°1 / SM-1).
///
/// origine (E6-1) : `ZEditionField` [zcrud_core] est le patron canonique AD-2
/// (`TextEditingController` stable, sync guardée hors focus, saisie à sens
/// unique). `ZMarkdownField` MIROITE exactement ce contrat en remplaçant le
/// `TextEditingController` par un [QuillController] et l'`onChanged` par un
/// **listener** de mutation de document. Taper N caractères ne reconstruit QUE
/// ce champ (rendu sous [ZFieldListenableBuilder], RÉUTILISÉ, jamais
/// réimplémenté) — jamais un voisin, jamais le formulaire — et ne recrée JAMAIS
/// le [QuillController] (focus + sélection/curseur préservés).
///
/// DP-3 ajoute (SANS régresser E6) :
/// - une voie d'intégration **`ctx`-native** ([ZMarkdownField.fromContext])
///   pilotée par un [ZFieldWidgetContext] (`field`/`value`/`onChanged`) — pour
///   le [ZWidgetRegistry] injecté (le builder ne reçoit PAS le `ZFormController`) ;
/// - le respect de `field.readOnly` (rendu **lecteur** non éditable, [ZMarkdownReader]) ;
/// - la distinction de **mode** ([ZMarkdownFieldMode]) : `inline` (éditeur
///   compact + toggle plein-écran) vs `block` (aperçu lecteur + bouton
///   « Rédiger »/« Modifier » ouvrant [ZRichTextFullscreenDialog]).
///
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-2** : [QuillController] + [FocusNode] + [ScrollController] créés UNE
///   SEULE fois en [State.initState], disposés en [State.dispose] ; l'abonnement
///   au flux de **mutations de document** (`document.changes`) est ANNULÉ au
///   dispose (zéro fuite). Saisie à **sens unique**. Aucune ré-injection
///   écrasant la sélection pendant l'édition : la **sync guardée** ne reflète
///   une valeur EXTERNE que **hors focus**. En mode **lecture seule** ET en mode
///   **block**, AUCUNE voie de frappe n'existe (ni controller mutant, ni
///   abonnement, ni `setValue`).
/// - **AD-7/AD-1** : la valeur portée par la tranche est **NEUTRE** (Delta JSON) ;
///   AUCUN type Quill n'apparaît dans la signature publique.
/// - **AD-10** : décodage **défensif** — valeur absente/vide/Delta corrompu →
///   document VIDE utilisable, **jamais** de throw.
/// - **AD-13/FR-26** : directionnel, [Semantics] explicites, cibles ≥ 48 dp,
///   couleurs issues du thème injecté (repli `Theme.of`), **zéro** couleur codée
///   en dur.
///
/// L'assembleur DOIT poser `key: ValueKey(field.name)` (place stable — AD-2) ;
/// sans quoi un rebuild externe pourrait voler l'état d'un voisin ou recréer le
/// [QuillController].
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
// SEULE arête Quill du package (AD-1). Aucun symbole Quill n'est re-exporté par
// le barrel : l'isolation de type est garantie (AC8).
import 'package:flutter_quill/flutter_quill.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/delta_neutral_ops.dart';
import '../data/z_delta_codec.dart';
import '../domain/z_codec.dart';
import 'z_markdown_codec_scope.dart';
import 'z_markdown_reader.dart';
import 'z_media_embed.dart';
import 'z_rich_text_core.dart';
import 'z_rich_text_fullscreen_dialog.dart';
import 'z_rich_text_toolbar_config.dart';

/// Mode de présentation d'un champ rich-text servi par le registre (DP-3, B6).
///
/// - [inline] : éditeur **compact en place** (toolbar minimale, hauteur bornée)
///   + bouton toggle plein-écran. Dérivé de `EditionFieldType.inlineMarkdown`.
/// - [block] : **aperçu lecteur** + bouton « Rédiger »/« Modifier » ouvrant le
///   dialog plein-écran (pas d'édition en place). Dérivé de
///   `EditionFieldType.markdown`/`richText`.
enum ZMarkdownFieldMode {
  /// Éditeur compact en place + toggle plein-écran.
  inline,

  /// Aperçu lecteur + édition en dialog plein-écran.
  block,
}

/// Fenêtre de test (AD-2 anti-fuite / efficacité MED-1) exposant l'état interne
/// VÉRIFIABLE du champ, SANS divulguer le [State] privé ni un type Quill.
///
/// Récupérée en test via
/// `tester.state<State<ZMarkdownField>>(...) as ZMarkdownFieldDebug`.
@visibleForTesting
abstract interface class ZMarkdownFieldDebug {
  /// Nombre de fois où le listener de **mutation de document** a effectivement
  /// tourné (⇒ un encodage neutre). N'augmente JAMAIS sur un simple
  /// déplacement de curseur/sélection.
  int get debugDocChangeCount;

  /// `true` tant que l'abonnement au flux `document.changes` est actif ;
  /// repasse à `false` après [State.dispose] — preuve DIRECTE du retrait de
  /// l'abonnement (anti-fuite). Toujours `false` en lecture seule / mode block
  /// (aucune voie de frappe).
  bool get debugDocSubscriptionActive;

  /// Valeur PERSISTÉE courante = `codec.encode(<tranche Delta neutre>)`.
  Object? get debugPersistedValue;
}

/// Champ d'édition **rich-text** (Quill) scellé sur la tranche `field.name`.
///
/// Expose/consomme une **valeur neutre** (Delta JSON `List<Map<String, dynamic>>`)
/// — jamais un type Quill (AD-1/AD-7).
class ZMarkdownField extends StatefulWidget {
  /// Construit le champ rich-text (voie **`controller`** — E6-1, INCHANGÉE) pour
  /// [field], lié à la tranche `field.name` du [controller].
  ///
  /// Rendu par DÉFAUT : éditeur pleine-toolbar (mode « legacy » — le mode
  /// inline/block ne s'applique qu'à la voie `ctx`/registre). `field.readOnly`
  /// est honoré (rendu lecteur). L'assembleur DOIT poser `key: ValueKey(field.name)`.
  const ZMarkdownField({
    required ZFormController this.controller,
    required this.field,
    this.showToolbar = true,
    this.toolbarConfig,
    this.codec,
    this.onInit,
    this.onBuild,
    super.key,
  })  : ctx = null,
        mode = ZMarkdownFieldMode.inline;

  /// Construit le champ rich-text (voie **`ctx`**/registre — DP-3) piloté par un
  /// [ZFieldWidgetContext] (`field`/`value`/`onChanged`), SANS `ZFormController`.
  ///
  /// [mode] fixe la présentation (`inline` compact vs `block` aperçu+dialog).
  /// `ctx.field.readOnly` est honoré (rendu lecteur, prioritaire sur le mode).
  /// L'assembleur (dispatcher) rend ce widget DANS sa frontière de rebuild
  /// value-in-slice : le `State` persiste (place stable) ⇒ le [QuillController]
  /// n'est jamais recréé (SM-1/AD-2).
  ZMarkdownField.fromContext({
    required ZFieldWidgetContext this.ctx,
    required this.mode,
    this.toolbarConfig,
    this.codec,
    this.onInit,
    this.onBuild,
    super.key,
  })  : controller = null,
        field = ctx.field,
        showToolbar = true;

  /// Contrôleur détenant la tranche (voie `controller`) — `null` en voie `ctx`.
  final ZFormController? controller;

  /// Contexte value-in-slice (voie `ctx`/registre) — `null` en voie `controller`.
  final ZFieldWidgetContext? ctx;

  /// Spécification `const` du champ rendu.
  final ZFieldSpec field;

  /// Mode de présentation (voie `ctx`). Ignoré en voie `controller` (legacy).
  final ZMarkdownFieldMode mode;

  /// Affiche la **toolbar** Quill presets (voie `controller` ; défaut `true`).
  final bool showToolbar;

  /// Configuration GRANULAIRE par bouton de la toolbar (DP-22, M20).
  ///
  /// RÉTRO-COMPAT : `null` (défaut) ⇒ comportement E6-1/DP-3 INCHANGÉ — préset
  /// [ZRichTextToolbarConfig.full] pour la voie `controller`/plein-écran,
  /// [ZRichTextToolbarConfig.minimal] pour le mode `inline`. Fournie ⇒ pilote
  /// chaque bouton (natif + custom LaTeX/table/image/vidéo). `showToolbar`
  /// (voie `controller`) reste prioritaire pour AFFICHER/MASQUER toute la barre.
  final ZRichTextToolbarConfig? toolbarConfig;

  /// `ZCodec` de (dé)sérialisation du **format persisté** (E6-2, AD-7).
  ///
  /// Précédence : ce paramètre > [ZMarkdownCodecScope] hérité > `ZDeltaCodec()`.
  final ZCodec? codec;

  /// Hook d'instrumentation : appelé UNE FOIS en [State.initState].
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook d'instrumentation : appelé à chaque (re)build de la **tranche**.
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Valeur PERSISTÉE (format du [codec]) de la tranche [name] portée par
  /// [controller] — **voie de persistance PUBLIQUE** (AC6, AD-7).
  ///
  /// Le codec n'intervient QU'ICI (couture de persistance), jamais dans le
  /// chemin chaud de frappe. Robuste au type de la tranche (décode
  /// défensivement — AD-10 — puis encode).
  static Object? persistedValueOf(
    ZFormController controller,
    String name, {
    ZCodec codec = _kDefaultPersistedCodec,
  }) {
    final ops = codec.decode(controller.valueOf(name));
    return codec.encode(ops);
  }

  @override
  State<ZMarkdownField> createState() => _ZMarkdownFieldState();
}

/// Ce que le champ DOIT rendre, dérivé de `field.readOnly` + voie + mode.
enum _RenderMode {
  /// `field.readOnly == true` (voie `controller` OU `ctx`) → lecteur exclusif.
  reader,

  /// Voie `controller` éditable → éditeur pleine-toolbar (E6-1 legacy).
  fullEditor,

  /// Voie `ctx` `inline` éditable → éditeur compact + toggle plein-écran.
  inlineEditor,

  /// Voie `ctx` `block` éditable → aperçu lecteur + bouton « Rédiger »/« Modifier ».
  blockPreview,
}

class _ZMarkdownFieldState extends State<ZMarkdownField>
    implements ZMarkdownFieldDebug {
  /// Controller Quill **isolé** — créé UNE FOIS, jamais recréé (AD-2). `null`
  /// pour les rendus SANS voie d'édition en place (lecteur / block).
  QuillController? _quill;

  /// `FocusNode` **stable** — oracle « le champ a le focus ? » de la sync guardée.
  FocusNode? _focus;

  /// `ScrollController` stable de l'éditeur.
  ScrollController? _scroll;

  /// JSON canonique de la dernière valeur neutre **synchronisée**.
  String _lastValueJson = '[]';

  /// Garde de ré-entrance pendant l'application d'une valeur EXTERNE.
  bool _applyingExternal = false;

  /// Abonnement au flux de **mutations de document** — ANNULÉ au [dispose].
  StreamSubscription<DocChange>? _docChangesSub;

  /// Compteur d'invocations effectives du listener de mutation.
  int _documentChangeCount = 0;

  /// Codec de (dé)sérialisation du format persisté (E6-2). Résolu UNE FOIS.
  late final ZCodec _codec;

  /// Config de toolbar STABLE (SM-1/AD-2) — construite UNE FOIS si édition.
  QuillSimpleToolbarConfig? _toolbarConfig;

  /// Ce que le champ rend, calculé UNE FOIS en [initState].
  late final _RenderMode _renderMode;

  @override
  int get debugDocChangeCount => _documentChangeCount;

  @override
  bool get debugDocSubscriptionActive => _docChangesSub != null;

  @override
  Object? get debugPersistedValue {
    final q = _quill;
    if (q != null) {
      return _codec.encode(DeltaNeutralOps.encodeNeutral(q.document));
    }
    // Lecteur / block : pas de controller mutant → dérive de la valeur courante.
    return _codec.encode(_codec.decode(_readValue()));
  }

  ZFieldSpec get _field => widget.field;

  String get _name => _field.name;

  /// Lit la valeur COURANTE de la tranche (voie `controller` OU `ctx`).
  Object? _readValue() => widget.controller != null
      ? widget.controller!.valueOf(_name)
      : widget.ctx!.value;

  /// Écrit une nouvelle valeur (sens unique — voie `controller` OU `ctx`).
  void _write(Object? value) {
    if (widget.controller != null) {
      widget.controller!.setValue(_name, value);
    } else {
      widget.ctx!.onChanged(value);
    }
  }

  /// Résout le [_RenderMode] : `readOnly` prioritaire, puis voie + mode.
  _RenderMode _resolveRenderMode() {
    if (_field.readOnly) return _RenderMode.reader;
    if (widget.controller != null) return _RenderMode.fullEditor;
    return widget.mode == ZMarkdownFieldMode.inline
        ? _RenderMode.inlineEditor
        : _RenderMode.blockPreview;
  }

  bool get _needsEditingController =>
      _renderMode == _RenderMode.fullEditor ||
      _renderMode == _RenderMode.inlineEditor;

  /// Config de toolbar EFFECTIVE pilotant chaque bouton (DP-22, M20).
  ///
  /// RÉTRO-COMPAT (NON-NÉGOCIABLE) : si aucune [ZRichTextToolbarConfig] n'est
  /// fournie, on retombe EXACTEMENT sur le comportement E6-1/DP-3 —
  /// [ZRichTextToolbarConfig.full] pour la voie `controller`/plein-écran
  /// (`fullEditor`), [ZRichTextToolbarConfig.minimal] pour le mode `inline`
  /// (`inlineEditor`). Fournie ⇒ elle pilote intégralement les boutons.
  ZRichTextToolbarConfig get _effectiveToolbarConfig {
    final provided = widget.toolbarConfig;
    if (provided != null) return provided;
    return _renderMode == _RenderMode.inlineEditor
        ? ZRichTextToolbarConfig.minimal
        : ZRichTextToolbarConfig.full;
  }

  /// Résout le [ZCodec] effectif. Lecture de l'inherited scope SANS créer de
  /// dépendance ([BuildContext.getElementForInheritedWidgetOfExactType]).
  ZCodec _resolveCodec() {
    final fromParam = widget.codec;
    if (fromParam != null) return fromParam;
    final element =
        context.getElementForInheritedWidgetOfExactType<ZMarkdownCodecScope>();
    final fromScope = (element?.widget as ZMarkdownCodecScope?)?.codec;
    return fromScope ?? const ZDeltaCodec();
  }

  @override
  void initState() {
    super.initState();
    _codec = _resolveCodec();
    _renderMode = _resolveRenderMode();
    if (_needsEditingController) {
      _initEditingController();
    }
    widget.onInit?.call();
  }

  /// Crée la voie d'édition (QuillController + focus + scroll + abonnement +
  /// toolbar). Appelé UNIQUEMENT pour `fullEditor`/`inlineEditor`.
  void _initEditingController() {
    final initial = _readValue();
    final seededOps = _codec.decode(initial);
    final document = DeltaNeutralOps.decodeDefensiveDocument(seededOps);
    final quill = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _quill = quill;
    _focus = FocusNode();
    _scroll = ScrollController();
    final neutralSeed = DeltaNeutralOps.encodeNeutral(document);
    _lastValueJson = jsonEncode(neutralSeed);
    _subscribeToDocumentChanges();
    _normalizeSliceIfNeeded(seededOps, neutralSeed, initial);
    _toolbarConfig = buildZToolbarConfig(
      onInsertLatex: () =>
          insertZLatex(context, quill, isMounted: () => mounted),
      onInsertTable: () =>
          insertZTable(context, quill, isMounted: () => mounted),
      onInsertImage: () => insertZMedia(context, quill,
          kind: ZMediaKind.image, isMounted: () => mounted),
      onInsertVideo: () => insertZMedia(context, quill,
          kind: ZMediaKind.video, isMounted: () => mounted),
      config: _effectiveToolbarConfig,
    );
  }

  /// MEDIUM-1 — Normalise la tranche vers la forme Delta NEUTRE (`List<Map>`).
  void _normalizeSliceIfNeeded(
    List<Map<String, dynamic>> seededOps,
    List<Map<String, dynamic>> neutralSeed,
    Object? initial,
  ) {
    if (seededOps.isEmpty) return;
    final alreadyNeutral = initial is List &&
        jsonEncode(DeltaNeutralOps.decodeDefensiveOps(initial)) ==
            jsonEncode(neutralSeed);
    if (alreadyNeutral) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _write(neutralSeed);
    });
  }

  @override
  void dispose() {
    // Anti-fuite : annuler l'abonnement AVANT de disposer le controller.
    unawaited(_docChangesSub?.cancel());
    _docChangesSub = null;
    _quill?.dispose();
    _focus?.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  /// (Ré)abonne le listener au flux `document.changes` du document COURANT.
  void _subscribeToDocumentChanges() {
    final q = _quill;
    if (q == null) return;
    unawaited(_docChangesSub?.cancel());
    _docChangesSub = q.document.changes.listen((_) => _onQuillChanged());
  }

  /// Listener de mutation de CONTENU : pousse la valeur **neutre** courante dans
  /// la tranche (sens unique).
  void _onQuillChanged() {
    _documentChangeCount++;
    if (_applyingExternal) return;
    final q = _quill;
    if (q == null) return;
    final neutral = DeltaNeutralOps.encodeNeutral(q.document);
    final neutralJson = jsonEncode(neutral);
    if (neutralJson == _lastValueJson) return;
    _lastValueJson = neutralJson;
    _write(neutral);
  }

  @override
  Widget build(BuildContext context) {
    switch (_renderMode) {
      case _RenderMode.reader:
        // Lecture seule : lecteur exclusif (aucune voie d'édition).
        if (widget.controller != null) {
          return ZFieldListenableBuilder(
            controller: widget.controller!,
            name: _name,
            builder: (context, value, child) {
              widget.onBuild?.call();
              return _buildReader(value);
            },
          );
        }
        widget.onBuild?.call();
        return _buildReader(widget.ctx!.value);
      case _RenderMode.fullEditor:
        // Voie `controller` (E6-1) : frontière de rebuild value-in-slice.
        return ZFieldListenableBuilder(
          controller: widget.controller!,
          name: _name,
          builder: (context, value, child) {
            widget.onBuild?.call();
            _syncFromExternal(value);
            return _buildEditor(context, withFullscreenToggle: false);
          },
        );
      case _RenderMode.inlineEditor:
        // Voie `ctx` : la frontière value-in-slice est déjà posée par le
        // dispatcher ⇒ on lit `ctx.value` directement.
        widget.onBuild?.call();
        _syncFromExternal(widget.ctx!.value);
        return _buildEditor(context, withFullscreenToggle: true);
      case _RenderMode.blockPreview:
        widget.onBuild?.call();
        return _buildBlockPreview(widget.ctx!.value);
    }
  }

  /// SYNC GUARDÉE (AC10, FR-1) : reflète une valeur EXTERNE dans l'éditeur
  /// UNIQUEMENT hors focus et si elle diffère. Pendant l'édition, priorité
  /// ABSOLUE à la saisie/au curseur (aucune ré-injection).
  void _syncFromExternal(Object? value) {
    final q = _quill;
    final f = _focus;
    if (q == null || f == null) return;
    if (f.hasFocus) return;
    final incomingOps = _codec.decode(value);
    final incoming = DeltaNeutralOps.decodeDefensiveDocument(incomingOps);
    final incomingJson = jsonEncode(DeltaNeutralOps.encodeNeutral(incoming));
    if (incomingJson == _lastValueJson) return;
    _applyingExternal = true;
    q.document = incoming;
    _subscribeToDocumentChanges();
    _lastValueJson = incomingJson;
    _applyingExternal = false;
  }

  /// Applique EXPLICITEMENT une valeur neutre au document local (retour du
  /// dialog plein-écran) — swap SANS recréer le controller (AD-2), indépendant
  /// du focus (action utilisateur, pas une sync passive).
  void _forceApplyNeutral(Object? value) {
    final q = _quill;
    if (q == null) return;
    _applyingExternal = true;
    final doc = DeltaNeutralOps.decodeDefensiveDocument(_codec.decode(value));
    q.document = doc;
    _subscribeToDocumentChanges();
    _lastValueJson = jsonEncode(DeltaNeutralOps.encodeNeutral(doc));
    _applyingExternal = false;
  }

  /// Valeur neutre la plus fraîche pour pré-remplir le dialog : le document
  /// local vivant (édition en place) ou la valeur de tranche (block).
  Object? _currentValueForDialog() {
    final q = _quill;
    return q != null
        ? DeltaNeutralOps.encodeNeutral(q.document)
        : _readValue();
  }

  /// Ouvre le dialog plein-écran ; à la validation, écrit la valeur éditée
  /// (sens unique) et ré-hydrate l'éditeur en place s'il existe (inline).
  Future<void> _openFullscreen() async {
    final Object? result = await showZRichTextFullscreenDialog(
      context,
      initialValue: _currentValueForDialog(),
      title: _field.label ?? _field.name,
      codec: _codec,
    );
    if (result == null || !mounted) return;
    _write(result);
    _forceApplyNeutral(result);
  }

  Widget _buildReader(Object? value) => ZMarkdownReader(
        value: value,
        codec: _codec,
        label: _field.label ?? _field.name,
      );

  Widget _buildEditor(
    BuildContext context, {
    required bool withFullscreenToggle,
  }) {
    final zTheme = ZcrudTheme.of(context);
    final borderColor =
        zTheme.fieldBorderColor ?? Theme.of(context).colorScheme.outline;
    final label = _field.label ?? _field.name;

    final editor = Semantics(
      textField: true,
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.all(zTheme.radiusM),
        ),
        child: Padding(
          padding: zTheme.fieldPadding,
          child: QuillEditor(
            controller: _quill!,
            focusNode: _focus!,
            scrollController: _scroll!,
            config: const QuillEditorConfig(
              scrollable: false,
              padding: EdgeInsetsDirectional.zero,
              embedBuilders: kZEmbedBuilders,
            ),
          ),
        ),
      ),
    );

    // Toolbar : montrée pour l'éditeur compact (inline) TOUJOURS ; pour la voie
    // `controller` (legacy) selon `showToolbar` (parité E6-1 STRICTE).
    final bool showToolbar = _renderMode == _RenderMode.inlineEditor
        ? true
        : widget.showToolbar;

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (showToolbar)
          Semantics(
            container: true,
            label: '$label toolbar',
            child: Row(
              children: <Widget>[
                Expanded(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(minHeight: kZMinTapTarget),
                    child: QuillSimpleToolbar(
                      controller: _quill!,
                      config: _toolbarConfig!,
                    ),
                  ),
                ),
                if (withFullscreenToggle) _fullscreenToggleButton(label),
              ],
            ),
          ),
        editor,
      ],
    );

    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
      ],
      child: column,
    );
  }

  /// Bouton toggle plein-écran (mode inline) — cible ≥ 48 dp, `Semantics`.
  Widget _fullscreenToggleButton(String label) => Semantics(
        button: true,
        label: 'Agrandir',
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kZMinTapTarget,
            minHeight: kZMinTapTarget,
          ),
          child: IconButton(
            key: const Key('z-markdown-fullscreen-toggle'),
            icon: const Icon(Icons.fullscreen),
            tooltip: 'Agrandir',
            onPressed: _openFullscreen,
          ),
        ),
      );

  /// Mode block : aperçu lecteur + bouton « Rédiger »/« Modifier ».
  Widget _buildBlockPreview(Object? value) {
    final bool empty = _isValueEmpty(value);
    final String actionLabel = empty ? 'Rédiger' : 'Modifier';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _buildReader(value),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Semantics(
            button: true,
            label: actionLabel,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: kZMinTapTarget),
              child: OutlinedButton.icon(
                key: const Key('z-markdown-block-edit'),
                icon: Icon(empty ? Icons.edit_note : Icons.edit),
                label: Text(actionLabel),
                onPressed: _openFullscreen,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// `true` si la valeur (neutre / format persisté) rend un document VIDE.
  bool _isValueEmpty(Object? value) {
    final doc = DeltaNeutralOps.decodeDefensiveDocument(_codec.decode(value));
    return doc.toPlainText().trim().isEmpty;
  }
}

/// Codec de persistance par DÉFAUT (identité Delta JSON) de
/// [ZMarkdownField.persistedValueOf].
const ZCodec _kDefaultPersistedCodec = ZDeltaCodec();
