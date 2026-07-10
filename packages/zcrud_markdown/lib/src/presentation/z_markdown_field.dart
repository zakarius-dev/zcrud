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
/// INVARIANTS (NON-NÉGOCIABLES) :
/// - **AD-2** : [QuillController] + [FocusNode] + [ScrollController] créés UNE
///   SEULE fois en [State.initState], disposés en [State.dispose] ; l'abonnement
///   au flux de **mutations de document** (`document.changes`) est ANNULÉ au
///   dispose (zéro fuite). Saisie à **sens unique**
///   (`document change → controller.setValue`). Le flux `document.changes`
///   n'émet QUE sur changement de CONTENU (jamais sur un simple déplacement de
///   curseur/sélection) : aucun encodage O(taille doc) superflu au déplacement
///   du caret. Aucune ré-injection écrasant la sélection pendant l'édition : la
///   **sync guardée** ne reflète une valeur EXTERNE dans l'éditeur que **hors
///   focus** et si elle diffère.
/// - **AD-7/AD-1** : la valeur portée par la tranche est **NEUTRE** (Delta JSON
///   = `List<Map<String, dynamic>>` JSON-safe) ; AUCUN type Quill
///   ([QuillController]/[Document]/`Delta`) n'apparaît dans la signature
///   publique ni dans la valeur du form. La conversion Delta↔JSON minimale passe
///   par l'API native de Quill ([Document.fromJson] / `document.toDelta().toJson()`).
///   Le `ZCodec` pluggable (format persisté Delta/Markdown/HTML — E6-2) opère
///   **à la couture de (dé)sérialisation** : la tranche `ZFormController` RESTE
///   TOUJOURS le Delta JSON neutre pendant l'édition (chemin chaud INCHANGÉ) ;
///   le codec normalise la valeur INITIALE (seed) et expose la valeur PERSISTÉE
///   (`codec.encode`) pour le `toMap` de l'app — jamais dans le flux de frappe.
/// - **AD-10** : décodage **défensif** — valeur absente/vide/Delta corrompu →
///   document VIDE utilisable, **jamais** de throw.
/// - **AD-13** : rendu directionnel (`Directionality`), [Semantics] explicites,
///   cibles interactives de la toolbar ≥ 48 dp ; couleurs issues du thème injecté
///   via `ZcrudScope` (repli `Theme.of`), **zéro** couleur codée en dur.
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
import 'z_latex_embed.dart';
import 'z_markdown_codec_scope.dart';
import 'z_table_embed.dart';

/// Fenêtre de test (AD-2 anti-fuite / efficacité MED-1) exposant l'état interne
/// VÉRIFIABLE du champ, SANS divulguer le [State] privé ni un type Quill.
///
/// Récupérée en test via
/// `tester.state<State<ZMarkdownField>>(...) as ZMarkdownFieldDebug`.
@visibleForTesting
abstract interface class ZMarkdownFieldDebug {
  /// Nombre de fois où le listener de **mutation de document** a effectivement
  /// tourné (⇒ un encodage neutre). N'augmente JAMAIS sur un simple
  /// déplacement de curseur/sélection : le flux `document.changes` n'émet que
  /// sur changement de CONTENU (preuve directe de MED-1).
  int get debugDocChangeCount;

  /// `true` tant que l'abonnement au flux `document.changes` est actif ;
  /// repasse à `false` après [State.dispose] — preuve DIRECTE du retrait de
  /// l'abonnement (anti-fuite AC3, LOW-1).
  bool get debugDocSubscriptionActive;

  /// Valeur PERSISTÉE courante = `codec.encode(<tranche Delta neutre>)` (E6-2,
  /// AC6), calculée depuis le **document vivant** — hook de TEST uniquement.
  ///
  /// La voie de persistance de PRODUCTION est la méthode publique (non-debug)
  /// [ZMarkdownField.persistedValueOf], à appeler au `toMap`/`onSubmit` de l'app.
  /// Le codec n'entre PAS dans le chemin chaud : cette valeur n'est calculée qu'à
  /// la demande (persistance), jamais à chaque frappe.
  Object? get debugPersistedValue;
}

/// Champ d'édition **rich-text** (Quill) scellé sur la tranche `field.name` du
/// [controller].
///
/// Expose/consomme une **valeur neutre** (Delta JSON `List<Map<String, dynamic>>`)
/// — jamais un type Quill (AD-1/AD-7). Le `ZCodec` pluggable (E6-2), les embeds
/// LaTeX (E6-3) et tableau (E6-4) sont hors périmètre E6-1.
class ZMarkdownField extends StatefulWidget {
  /// Construit le champ rich-text pour [field], lié à la tranche `field.name`
  /// du [controller].
  ///
  /// L'assembleur DOIT poser `key: ValueKey(field.name)` (place stable — AD-2).
  const ZMarkdownField({
    required this.controller,
    required this.field,
    this.showToolbar = true,
    this.codec,
    this.onInit,
    this.onBuild,
    super.key,
  });

  /// Contrôleur détenant la tranche du champ (créé/possédé par l'hôte ; jamais
  /// recréé dans un `build`).
  final ZFormController controller;

  /// Spécification `const` du champ rendu (`name`/`label`/… — E2-4/E2-5).
  final ZFieldSpec field;

  /// Affiche la **toolbar** Quill presets (activable ; défaut `true`). `false`
  /// pour un rendu compact (l'éditeur reste pleinement fonctionnel).
  final bool showToolbar;

  /// `ZCodec` de (dé)sérialisation du **format persisté** (E6-2, AD-7).
  ///
  /// Précédence de résolution : ce paramètre > [ZMarkdownCodecScope] hérité >
  /// `ZDeltaCodec()` (défaut rétrocompatible E6-1). Le codec opère UNIQUEMENT à
  /// la couture de persistance (seed + `debugPersistedValue`), jamais dans le
  /// chemin chaud de frappe — la tranche `ZFormController` reste le Delta neutre.
  final ZCodec? codec;

  /// Hook d'instrumentation : appelé UNE FOIS en [State.initState] (preuve de
  /// non-recréation du [QuillController]/`State` via compteur == 1).
  @visibleForTesting
  final VoidCallback? onInit;

  /// Hook d'instrumentation : appelé à chaque (re)build de la **tranche** (dans
  /// le `builder` du slice) — compteur de build par champ pour SM-1 (AC2).
  @visibleForTesting
  final VoidCallback? onBuild;

  /// Valeur PERSISTÉE (format du [codec]) de la tranche du champ [name] portée
  /// par [controller] — **voie de persistance PUBLIQUE** (AC6, AD-7), à appeler
  /// au `toMap`/`onSubmit` de l'app pour sérialiser le champ rich-text.
  ///
  /// Contrairement à `ZMarkdownFieldDebug.debugPersistedValue`
  /// (`@visibleForTesting`, réservé aux tests), cette API vise le CODE DE
  /// PRODUCTION — l'appeler ne déclenche donc AUCUN lint
  /// `invalid_use_of_visible_for_testing_member`.
  ///
  /// Le codec n'intervient QU'ICI (couture de persistance), jamais dans le
  /// chemin chaud de frappe (AD-2/SM-1 préservés). L'implémentation est ROBUSTE
  /// au type de la tranche : elle `decode` d'abord DÉFENSIVEMENT (AD-10) la
  /// valeur — que la tranche soit déjà du Delta neutre (`List<Map>`, cas nominal
  /// après montage/frappe) ou un seed persisté non encore normalisé (ex. `String`
  /// Markdown) — PUIS `encode` vers le format persisté. Jamais de `TypeError`
  /// (contrairement à un `codec.encode(tranche)` naïf sur un seed `String`).
  ///
  /// [codec] DOIT être le même que celui du champ (paramètre `codec` ou
  /// `ZMarkdownCodecScope`) ; défaut identité (format persisté = Delta JSON).
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

class _ZMarkdownFieldState extends State<ZMarkdownField>
    implements ZMarkdownFieldDebug {
  /// Controller Quill **isolé** — créé UNE FOIS, jamais recréé (AD-2). Son
  /// document n'est réécrit QUE par la sync guardée hors focus (jamais dans la
  /// voie de frappe).
  late final QuillController _quill;

  /// `FocusNode` **stable** — oracle « le champ a le focus ? » de la sync
  /// guardée (AC2/AC10).
  late final FocusNode _focus;

  /// `ScrollController` stable de l'éditeur.
  late final ScrollController _scroll;

  /// JSON canonique de la dernière valeur neutre **synchronisée** (poussée par
  /// la frappe OU appliquée depuis l'extérieur). Sert à (a) éviter les
  /// notifications superflues sur changement de sélection seule et (b) rendre la
  /// sync guardée idempotente (jamais de ré-injection en boucle).
  late String _lastValueJson;

  /// Garde de ré-entrance : `true` pendant l'application d'une valeur EXTERNE
  /// (`_quill.document = …`) pour NE PAS re-pousser dans le form (sens unique
  /// préservé).
  bool _applyingExternal = false;

  /// Abonnement au flux de **mutations de document** (`document.changes`) —
  /// n'émet QUE sur changement de CONTENU (jamais sur déplacement de curseur).
  /// ANNULÉ au [dispose] (anti-fuite). Ré-abonné après remplacement du document
  /// par la sync guardée (`_quill.document = …` ne transfère PAS l'abonnement).
  StreamSubscription<DocChange>? _docChangesSub;

  /// Compteur d'invocations effectives du listener de mutation (⇒ encodages) —
  /// preuve MED-1 (inchangé sur sélection seule) et wiring anti-fuite.
  int _documentChangeCount = 0;

  /// Codec de (dé)sérialisation du format persisté (E6-2). Résolu UNE FOIS en
  /// [initState] selon la précédence `paramètre > ZMarkdownCodecScope > défaut`.
  /// Config de persistance statique ⇒ lecture SANS dépendance d'inherited widget
  /// (pas de re-seed au changement de scope : la tranche de travail prime).
  late final ZCodec _codec;

  /// Config de toolbar STABLE (SM-1/AD-2) — construite UNE FOIS en [initState].
  /// Non-`const` car ses `customButtons` référencent les méthodes d'instance
  /// [_promptAndInsertLatex] / [_promptAndInsertTable] ; HISSÉE en champ pour NE
  /// PAS ré-allouer à chaque (re)build de tranche (aucune allocation dans le
  /// chemin chaud de frappe).
  late final QuillSimpleToolbarConfig _toolbarConfig;

  @override
  int get debugDocChangeCount => _documentChangeCount;

  @override
  bool get debugDocSubscriptionActive => _docChangesSub != null;

  @override
  Object? get debugPersistedValue =>
      _codec.encode(DeltaNeutralOps.encodeNeutral(_quill.document));

  String get _name => widget.field.name;

  /// Résout le [ZCodec] effectif (AC4). Lecture de l'inherited scope SANS créer
  /// de dépendance ([BuildContext.getElementForInheritedWidgetOfExactType]) —
  /// autorisée en [initState], adaptée à une config de persistance statique.
  ZCodec _resolveCodec() {
    final fromParam = widget.codec;
    if (fromParam != null) return fromParam;
    final element = context
        .getElementForInheritedWidgetOfExactType<ZMarkdownCodecScope>();
    final fromScope = (element?.widget as ZMarkdownCodecScope?)?.codec;
    return fromScope ?? const ZDeltaCodec();
  }

  @override
  void initState() {
    super.initState();
    _codec = _resolveCodec();
    final initial = widget.controller.valueOf(_name);
    // COUTURE DE SEED (AC6) : le format persisté initial (Delta JSON OU String
    // Markdown selon le codec) est normalisé en ops Delta neutres via le codec,
    // PUIS décodé défensivement en Document (AD-10). Pour `ZDeltaCodec` (défaut),
    // `decode` est l'identité défensive ⇒ comportement STRICTEMENT identique à
    // E6-1.
    final seededOps = _codec.decode(initial);
    final document = DeltaNeutralOps.decodeDefensiveDocument(seededOps);
    _quill = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _focus = FocusNode();
    _scroll = ScrollController();
    // Forme Delta NEUTRE canonique du seed (celle qu'une frappe produirait) —
    // sert de référence de dédup ET de valeur de normalisation de tranche.
    final neutralSeed = DeltaNeutralOps.encodeNeutral(document);
    _lastValueJson = jsonEncode(neutralSeed);
    // Abonnement au flux de mutations de CONTENU (AD-2, MED-1) : saisie à sens
    // unique. `document.changes` n'émet PAS sur déplacement de curseur ⇒ aucun
    // encodage O(taille doc) au seul mouvement du caret.
    _subscribeToDocumentChanges();
    // MEDIUM-1 : rend le TYPE de la tranche INVARIANT (`List<Map>`) dès le
    // montage lorsqu'elle a été seedée au format persisté (ex. `String` Markdown).
    _normalizeSliceIfNeeded(seededOps, neutralSeed, initial);
    // Config toolbar STABLE (E6-3/E6-4, AC8/SM-1) : boutons d'insertion/édition
    // de formule LaTeX (E6-3) et de tableau (E6-4) branchés sur les méthodes
    // d'instance (références figées).
    _toolbarConfig = QuillSimpleToolbarConfig(
      toolbarSize: _kMinTapTarget,
      multiRowsDisplay: false,
      showAlignmentButtons: true,
      customButtons: <QuillToolbarCustomButtonOptions>[
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.functions),
          tooltip: 'Insérer une formule',
          onPressed: _promptAndInsertLatex,
        ),
        QuillToolbarCustomButtonOptions(
          icon: const Icon(Icons.grid_on),
          tooltip: 'Insérer un tableau',
          onPressed: _promptAndInsertTable,
        ),
      ],
    );
    widget.onInit?.call();
  }

  /// MEDIUM-1 — Normalise la tranche vers la forme Delta NEUTRE (`List<Map>`)
  /// pour que son TYPE soit INVARIANT (`List<Map>`) AVANT comme APRÈS la 1re
  /// frappe : la voie de persistance publique ([ZMarkdownField.persistedValueOf])
  /// et tout lecteur de la tranche voient TOUJOURS des ops neutres, jamais un
  /// seed persisté brut (`String` Markdown) qui ferait échouer un `encode` naïf
  /// ou renverrait un type incohérent (String avant / `List` après édition).
  ///
  /// N'écrit la tranche QUE si sa représentation courante DIFFÈRE de la forme
  /// neutre (seed au format persisté `String`). Un seed déjà en Delta neutre
  /// (défaut `ZDeltaCodec` / parité E6-1 STRICTE) ou vide/corrompu n'est PAS
  /// retouché — aucune régression E6-1, aucun re-seed superflu. L'écriture est
  /// DIFFÉRÉE en POST-FRAME : on ne notifie jamais une tranche pendant le build
  /// de montage (interdiction Flutter du `setState`/notify pendant `build`).
  void _normalizeSliceIfNeeded(
    List<Map<String, dynamic>> seededOps,
    List<Map<String, dynamic>> neutralSeed,
    Object? initial,
  ) {
    // Seed vide/corrompu ⇒ rien à normaliser (la tranche reste telle quelle).
    if (seededOps.isEmpty) return;
    // Seed DÉJÀ en Delta neutre équivalent ⇒ ne pas retoucher (parité E6-1).
    final alreadyNeutral = initial is List &&
        jsonEncode(DeltaNeutralOps.decodeDefensiveOps(initial)) ==
            jsonEncode(neutralSeed);
    if (alreadyNeutral) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // La tranche devient la forme neutre canonique (== `_lastValueJson`) ⇒ le
      // rebuild induit passe par `_syncFromExternal` en no-op (aucun swap de
      // document, aucune boucle) ; chemin chaud INCHANGÉ (SM-1/AD-2 préservés).
      widget.controller.setValue(_name, neutralSeed);
    });
  }

  @override
  void dispose() {
    // Anti-fuite (AC3, AI-E5-4, LOW-1) : annuler l'abonnement AVANT de disposer
    // le controller (qui ferme le flux `document.changes`). `_docChangesSub` est
    // remis à `null` ⇒ preuve directe du retrait (debugDocSubscriptionActive).
    unawaited(_docChangesSub?.cancel());
    _docChangesSub = null;
    _quill.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// (Ré)abonne le listener au flux `document.changes` du document COURANT.
  /// Requis après un remplacement de document (`_quill.document = …`), car le
  /// setter Quill swappe l'instance de [Document] sans transférer l'abonnement.
  void _subscribeToDocumentChanges() {
    unawaited(_docChangesSub?.cancel());
    _docChangesSub =
        _quill.document.changes.listen((_) => _onQuillChanged());
  }

  /// Listener de mutation de CONTENU : pousse la valeur **neutre** courante dans
  /// la tranche (sens unique). N'est appelé QUE sur changement de contenu (le
  /// flux `document.changes` n'émet pas sur déplacement de curseur — MED-1).
  /// Ignore (a) les émissions pendant l'application d'une valeur externe
  /// (garde), et (b) une valeur neutre identique (dédup) — pas de setValue
  /// superflu.
  void _onQuillChanged() {
    _documentChangeCount++;
    if (_applyingExternal) return;
    final neutral = DeltaNeutralOps.encodeNeutral(_quill.document);
    final neutralJson = jsonEncode(neutral);
    if (neutralJson == _lastValueJson) return;
    _lastValueJson = neutralJson;
    widget.controller.setValue(_name, neutral);
  }

  @override
  Widget build(BuildContext context) => ZFieldListenableBuilder(
        controller: widget.controller,
        name: _name,
        // Frontière de rebuild : seul le changement de la tranche reconstruit ce
        // closure (cœur de SM-1).
        builder: (context, value, child) {
          widget.onBuild?.call();
          _syncFromExternal(value);
          return _buildEditor(context);
        },
      );

  /// SYNC GUARDÉE (AC10, FR-1) : reflète une valeur EXTERNE dans l'éditeur
  /// UNIQUEMENT hors focus et si elle diffère de l'état courant. Pendant
  /// l'édition (`hasFocus`), priorité ABSOLUE à la saisie/au curseur : AUCUNE
  /// ré-injection (sinon sélection écrasée / caret sauté). Pendant la frappe
  /// locale, `value` égale déjà `_lastValueJson` ⇒ no-op (idempotent).
  void _syncFromExternal(Object? value) {
    if (_focus.hasFocus) return;
    // Sync guardée = reflet d'une valeur EXTERNE. Elle passe par `_codec.decode`
    // pour accepter INDIFFÉREMMENT une tranche déjà Delta neutre (cas nominal, la
    // frappe pousse du Delta) OU une valeur au format persisté du codec (seed /
    // hydratation `fromMap`, ex. String Markdown). HORS chemin chaud : gardée par
    // `!hasFocus` ⇒ jamais invoquée pendant la frappe (SM-1/AD-2 préservés). Pour
    // `ZDeltaCodec` (défaut), `decode` est l'identité défensive ⇒ parité E6-1.
    final incomingOps = _codec.decode(value);
    final incoming = DeltaNeutralOps.decodeDefensiveDocument(incomingOps);
    final incomingJson = jsonEncode(DeltaNeutralOps.encodeNeutral(incoming));
    if (incomingJson == _lastValueJson) return;
    _applyingExternal = true;
    // API native Quill : remplace le document SANS recréer le controller (AD-2).
    // Le setter swappe l'instance de Document ⇒ il faut se ré-abonner au flux
    // `document.changes` du NOUVEAU document (l'ancien abonnement deviendrait
    // sourd aux frappes suivantes).
    _quill.document = incoming;
    _subscribeToDocumentChanges();
    _lastValueJson = incomingJson;
    _applyingExternal = false;
  }

  Widget _buildEditor(BuildContext context) {
    final zTheme = ZcrudTheme.of(context);
    final borderColor = zTheme.fieldBorderColor ??
        Theme.of(context).colorScheme.outline;
    final label = widget.field.label ?? widget.field.name;

    // LOW-3 (a11y AD-13) — INTENTIONNEL : ce nœud sémantique n'apporte QUE
    // l'étiquette de champ (association label ↔ zone d'édition) et le rôle
    // `textField`. `QuillEditor` fournit en dessous ses propres nœuds d'édition
    // (navigation/sélection du contenu) : on ne les EXCLUT PAS (pas de
    // `excludeSemantics`) pour préserver la lecture du contenu par le lecteur
    // d'écran. Rendu vérifié sans exception (test « Semantics explicites »).
    // Une passe TalkBack/VoiceOver réelle relève de la QA a11y d'intégration.
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
            controller: _quill,
            focusNode: _focus,
            scrollController: _scroll,
            config: const QuillEditorConfig(
              // Non-scrollable : l'éditeur prend sa hauteur intrinsèque, l'hôte
              // gère le défilement du formulaire (place stable AD-2).
              scrollable: false,
              padding: EdgeInsetsDirectional.zero,
              // E6-3/E6-4 (AC2/AC8) : rendu des embeds LaTeX + tableau en
              // édition ET lecture. Liste `const` STABLE (canonicalisée) ⇒ MÊME
              // instance à chaque build de tranche : zéro allocation dans le
              // chemin chaud (SM-1), les `EmbedBuilder` n'entrent jamais dans le
              // flux `document.changes`.
              embedBuilders: _kEmbedBuilders,
            ),
          ),
        ),
      ),
    );

    final column = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.showToolbar)
          Semantics(
            container: true,
            label: '$label toolbar',
            // Cible interactive ≥ 48 dp (AD-13) : la toolbar occupe au moins la
            // hauteur de cible minimale, et ses boutons sont dimensionnés à
            // `_kMinTapTarget` via `toolbarSize`.
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              child: QuillSimpleToolbar(
                controller: _quill,
                config: _toolbarConfig,
              ),
            ),
          ),
        editor,
      ],
    );

    // Injecte les localisations Quill requises (QuillEditor/QuillSimpleToolbar
    // exigent `FlutterQuillLocalizations`) en s'ajoutant aux délégués hérités de
    // l'app hôte (Material/Widgets restent disponibles). Rend le champ
    // auto-suffisant sans imposer une config au consommateur.
    return Localizations.override(
      context: context,
      delegates: const <LocalizationsDelegate<dynamic>>[
        FlutterQuillLocalizations.delegate,
      ],
      child: column,
    );
  }

  // ───────────────────────────── Embed LaTeX (E6-3) ──────────────────────────

  /// Ouvre le dialogue de saisie/édition d'une formule LaTeX puis insère (ou
  /// remplace) l'op embed `{insert:{latex:...}}` au point d'insertion courant
  /// (AC3). Si le caret est sur/juste après un embed LaTeX existant, le dialogue
  /// est PRÉ-REMPLI et l'op est REMPLACÉE (édition) ; sinon insertion neuve.
  ///
  /// L'insertion passe par l'API native `replaceText` (le controller n'est jamais
  /// recréé — AD-2) : la mutation de document déclenche `_onQuillChanged` qui
  /// pousse l'op neutre dans la tranche (sens unique). Aucune (dé)sérialisation
  /// custom : l'op est déjà Delta JSON neutre et opaque (round-trip E6-2 intact).
  Future<void> _promptAndInsertLatex() async {
    final _LatexEmbedHit? existing = _latexEmbedAtSelection();
    final String? source =
        await showZLatexDialog(context, initial: existing?.source ?? '');
    // Annulation (null) ⇒ aucune mutation. Widget démonté ⇒ on n'écrit pas.
    if (source == null || !mounted) return;
    if (existing != null) {
      // ÉDITION : remplace l'embed existant (longueur 1) par le nouveau.
      _quill.replaceText(
        existing.index,
        1,
        ZLatexEmbed(source),
        TextSelection.collapsed(offset: existing.index + 1),
      );
      return;
    }
    // INSERTION : au point d'insertion courant (repli en fin de document si la
    // sélection est invalide). Une sélection ÉTENDUE est remplacée par l'embed.
    // (`sel` n'est lu QUE sur ce chemin d'insertion — F4.)
    final TextSelection sel = _quill.selection;
    final int index =
        sel.isValid ? sel.start : (_quill.document.length - 1).clamp(0, 1 << 30);
    final int length = sel.isValid ? sel.end - sel.start : 0;
    _quill.replaceText(
      index,
      length,
      ZLatexEmbed(source),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  /// Détecte un embed LaTeX sous/juste-avant le caret (pour l'édition, AC3).
  ///
  /// Parcourt les ops NEUTRES du document (longueur d'un embed = 1) et renvoie
  /// l'index + la source si le caret couvre l'embed (`caret == index` ou
  /// `caret == index + 1`), sinon `null`. DÉFENSIF : sélection invalide → `null`.
  _LatexEmbedHit? _latexEmbedAtSelection() {
    final TextSelection sel = _quill.selection;
    if (!sel.isValid) return null;
    final int caret = sel.baseOffset;
    final List<Map<String, dynamic>> ops =
        DeltaNeutralOps.encodeNeutral(_quill.document);
    var index = 0;
    for (final Map<String, dynamic> op in ops) {
      final Object? insert = op['insert'];
      if (insert is Map && insert[kLatexEmbedType] is String) {
        if (caret == index || caret == index + 1) {
          return _LatexEmbedHit(index, insert[kLatexEmbedType] as String);
        }
        index += 1;
      } else {
        index += insert is String ? insert.length : 1;
      }
    }
    return null;
  }

  // ───────────────────────────── Embed tableau (E6-4) ────────────────────────

  /// Ouvre le dialogue de saisie/édition d'un tableau puis insère (ou remplace)
  /// l'op embed `{insert:{table:...}}` au point d'insertion courant (AC3). Si le
  /// caret est sur/juste après un embed tableau existant, le dialogue est
  /// PRÉ-REMPLI et l'op est REMPLACÉE (édition) ; sinon insertion neuve.
  ///
  /// MIROIR EXACT de [_promptAndInsertLatex] : l'insertion passe par l'API native
  /// `replaceText` (le controller n'est jamais recréé — AD-2) ; l'op est déjà
  /// Delta JSON neutre et opaque (round-trip E6-2 intact).
  Future<void> _promptAndInsertTable() async {
    final _TableEmbedHit? existing = _tableEmbedAtSelection();
    final Map<String, dynamic>? structure =
        await showZTableDialog(context, initial: existing?.structure);
    // Annulation (null) ⇒ aucune mutation. Widget démonté ⇒ on n'écrit pas.
    if (structure == null || !mounted) return;
    if (existing != null) {
      // ÉDITION : remplace l'embed existant (longueur 1) par le nouveau.
      _quill.replaceText(
        existing.index,
        1,
        ZTableEmbed(structure),
        TextSelection.collapsed(offset: existing.index + 1),
      );
      return;
    }
    // INSERTION : au point d'insertion courant (repli en fin de document si la
    // sélection est invalide). Une sélection ÉTENDUE est remplacée par l'embed.
    final TextSelection sel = _quill.selection;
    final int index =
        sel.isValid ? sel.start : (_quill.document.length - 1).clamp(0, 1 << 30);
    final int length = sel.isValid ? sel.end - sel.start : 0;
    _quill.replaceText(
      index,
      length,
      ZTableEmbed(structure),
      TextSelection.collapsed(offset: index + 1),
    );
  }

  /// Détecte un embed tableau sous/juste-avant le caret (pour l'édition, AC3).
  ///
  /// Parcourt les ops NEUTRES du document (longueur d'un embed = 1) et renvoie
  /// l'index + la structure si le caret couvre l'embed (`caret == index` ou
  /// `caret == index + 1`), sinon `null`. DÉFENSIF : sélection invalide → `null`.
  _TableEmbedHit? _tableEmbedAtSelection() {
    final TextSelection sel = _quill.selection;
    if (!sel.isValid) return null;
    final int caret = sel.baseOffset;
    final List<Map<String, dynamic>> ops =
        DeltaNeutralOps.encodeNeutral(_quill.document);
    var index = 0;
    for (final Map<String, dynamic> op in ops) {
      final Object? insert = op['insert'];
      if (insert is Map && insert[kTableEmbedType] is Map) {
        if (caret == index || caret == index + 1) {
          return _TableEmbedHit(
            index,
            Map<String, dynamic>.from(insert[kTableEmbedType] as Map),
          );
        }
        index += 1;
      } else {
        index += insert is String ? insert.length : 1;
      }
    }
    return null;
  }

  // ─────────────────────────── Conversion neutre + défensif ──────────────────
  //
  // La normalisation neutre + le décodage défensif (AD-10) sont FACTORISÉS dans
  // `DeltaNeutralOps` (`lib/src/data/delta_neutral_ops.dart`), PARTAGÉS avec les
  // codecs E6-2 (`ZDeltaCodec`) SANS changer le comportement prouvé d'E6-1.
}

/// Localisation d'un embed LaTeX dans le document (index Delta + source) pour
/// l'édition ciblée d'un embed existant (E6-3, AC3).
class _LatexEmbedHit {
  const _LatexEmbedHit(this.index, this.source);

  /// Offset Delta de l'op embed (longueur 1).
  final int index;

  /// Source LaTeX courante (pré-remplit le dialogue d'édition).
  final String source;
}

/// Localisation d'un embed tableau dans le document (index Delta + structure)
/// pour l'édition ciblée d'un embed existant (E6-4, AC3).
class _TableEmbedHit {
  const _TableEmbedHit(this.index, this.structure);

  /// Offset Delta de l'op embed (longueur 1).
  final int index;

  /// Structure JSON-safe courante (pré-remplit le dialogue d'édition).
  final Map<String, dynamic> structure;
}

/// Cible de tap minimale (AD-13) — dimensionne les boutons de la toolbar et sa
/// hauteur minimale.
const double _kMinTapTarget = 48;

/// `EmbedBuilder`s branchés sur `QuillEditorConfig.embedBuilders` (E6-3/E6-4, AC2).
///
/// Liste `const` (donc CANONICALISÉE → instance UNIQUE partagée par tous les
/// builds) : la référence est STABLE, aucune allocation à chaque (re)build de
/// tranche (SM-1/AD-2). MÊME liste pour LaTeX (E6-3) ET tableau (E6-4). Définie
/// HORS de la région publique de `ZMarkdownField` (après la classe `State`) :
/// n'introduit aucun nom de type Quill/math dans la surface publique scannée par
/// le test d'isolation de signature (AC7).
const List<EmbedBuilder> _kEmbedBuilders = <EmbedBuilder>[
  ZLatexEmbedBuilder(),
  ZTableEmbedBuilder(),
];

/// Codec de persistance par DÉFAUT (identité Delta JSON) de
/// [ZMarkdownField.persistedValueOf]. Défini HORS de la région publique de
/// `ZMarkdownField` (test d'isolation AC8 : substring `Delta`) — la surface
/// publique n'expose aucun nom de type Quill/Delta en clair.
const ZCodec _kDefaultPersistedCodec = ZDeltaCodec();
