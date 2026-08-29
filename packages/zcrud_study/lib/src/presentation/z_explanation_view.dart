/// `ZExplanationView` — surface de lecture d'une explication IA : rendu de la
/// version courante, barre de traitements, sélecteur de versions.
///
/// ## Composition, jamais de moteur dupliqué
///
/// - Cycle asynchrone, jeton de fraîcheur, historique : délégués à
///   [ZExplanationController].
/// - Rendu du texte : **texte brut** par défaut, ou le widget rendu par le
///   slot [ZExplanationView.contentBuilder]. `zcrud_study` ne dépend d'aucun
///   moteur de rich-text (invariant AD-1) : une lecture Markdown reste donc
///   possible, mais elle est **fournie par l'application** via ce slot, jamais
///   tirée en dépendance ici.
/// - Choix du style : délégué à `ZActionMenu` (couture de menu partagée),
///   jamais un menu reconstruit sur place.
///
/// ## Rendu progressif SANS reconstruire la surface
///
/// Pendant une génération progressive, le texte cumulé est rendu par un
/// `ValueListenableBuilder` branché sur `ZExplanationController.streamingText`.
/// Chaque fragment reconstruit **ce sous-arbre et lui seul** : ni la barre de
/// traitements, ni le sélecteur de versions, ni la surface hôte au-dessus ne
/// sont réveillés (invariant AD-2).
///
/// ## Rien n'est écrit ici
///
/// Aucun dépôt n'est importé. Le seul canal de sortie est le handoff
/// [ZExplanationView.onPersist], qui remet une `ZStudyExplanation` **construite
/// mais jamais enregistrée** : c'est l'application qui écrit, par la voie de
/// persistance de son choix. `null` ⇒ la commande est ABSENTE de l'arbre,
/// jamais un bouton inerte (invariant AD-4).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;
import 'package:zcrud_menu/zcrud_menu.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZStudyExplanation;

import '../domain/z_ai_explanation_stream_port.dart';
import 'z_explanation_controller.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Rend le texte d'explication. Slot opt-in : `null` ⇒ texte brut thématisé.
///
/// C'est par ici qu'une application branche son moteur de rendu riche
/// (Markdown, HTML…) sans qu'aucune dépendance de rendu n'entre dans ce
/// paquet. Le même slot sert au texte en cours de génération et au texte
/// final : le rendu ne change pas de nature quand le flux se termine.
typedef ZExplanationTextBuilder = Widget Function(
  BuildContext context,
  String text,
);

/// Handoff de matérialisation : remet une explication **construite** à
/// l'appelant, qui décide de l'écrire.
typedef ZExplanationPersistCallback = void Function(
  ZStudyExplanation explanation,
);

/// Une option de style offerte à l'utilisateur.
///
/// [key] est la clé **opaque** transmise verbatim au port ; [label] est son
/// libellé localisé. Ce paquet ne connaît aucune des deux : la liste vient
/// entièrement de l'application.
@immutable
class ZExplanationStyleOption {
  /// Construit une option de style.
  const ZExplanationStyleOption({required this.key, required this.label});

  /// Clé opaque du style (vocabulaire de l'hôte).
  final String key;

  /// Libellé localisé affiché.
  final String label;
}

/// Libellés INJECTÉS de la vue (i18n — aucun libellé en dur, FR-26). Tous
/// requis : un défaut dans une langue serait un libellé en dur sans voie de
/// remplacement.
@immutable
class ZExplanationLabels {
  /// Construit les libellés injectés.
  const ZExplanationLabels({
    required this.generatingLabel,
    required this.summarizeLabel,
    required this.regenerateLabel,
    required this.elaborateLabel,
    required this.restyleLabel,
    required this.previousVersionLabel,
    required this.nextVersionLabel,
    required this.versionPosition,
    required this.persistLabel,
  });

  /// Annonce affichée pendant une génération.
  final String generatingLabel;

  /// Libellé de la commande de condensation.
  final String summarizeLabel;

  /// Libellé de la commande de régénération.
  final String regenerateLabel;

  /// Libellé de la commande de développement.
  final String elaborateLabel;

  /// Libellé du déclencheur de choix de style.
  final String restyleLabel;

  /// Libellé de la commande « version précédente ».
  final String previousVersionLabel;

  /// Libellé de la commande « version suivante ».
  final String nextVersionLabel;

  /// Rend la position courante dans l'historique (`index` est **1-basé**,
  /// `total` est le nombre de versions) — la ponctuation et l'ordre des deux
  /// nombres appartiennent à la langue, jamais à ce paquet.
  final String Function(int index, int total) versionPosition;

  /// Libellé de la commande de matérialisation.
  final String persistLabel;
}

/// Vue d'explication IA : version courante, traitements, historique.
class ZExplanationView extends StatelessWidget {
  /// Construit la vue autour d'un [controller].
  const ZExplanationView({
    required this.controller,
    required this.labels,
    this.contentBuilder,
    this.styleOptions = const <ZExplanationStyleOption>[],
    this.onPersist,
    this.folderId = '',
    this.relatedTopics = const <String>[],
    super.key,
  });

  /// Contrôleur d'explication (créé et disposé par l'appelant).
  final ZExplanationController controller;

  /// Libellés injectés.
  final ZExplanationLabels labels;

  /// Rendu du texte. `null` ⇒ texte brut thématisé.
  final ZExplanationTextBuilder? contentBuilder;

  /// Styles offerts. Vide ⇒ le déclencheur de style est ABSENT de l'arbre,
  /// même si le contrôleur porte une clé d'opération `restyle`.
  final List<ZExplanationStyleOption> styleOptions;

  /// Handoff de matérialisation. `null` ⇒ commande ABSENTE de l'arbre.
  final ZExplanationPersistCallback? onPersist;

  /// Dossier auquel rattacher l'explication matérialisée.
  final String folderId;

  /// Thèmes opaques portés par l'explication matérialisée.
  final List<String> relatedTopics;

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Column(
          key: const ValueKey<String>('z-explanation-view'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildContent(context, theme),
            _buildMessage(theme),
            _buildVersionSelector(theme),
            _buildOperations(theme),
          ],
        );
      },
    );
  }

  /// Aire de texte. En génération, seule cette aire écoute la tranche
  /// cumulative : un fragment ne reconstruit rien d'autre.
  Widget _buildContent(BuildContext context, ZcrudTheme theme) {
    if (controller.isGenerating) {
      return ValueListenableBuilder<String>(
        key: const ValueKey<String>('z-explanation-stream'),
        valueListenable: controller.streamingText,
        builder: (context, text, _) => _renderText(context, text),
      );
    }
    return _renderText(context, controller.currentText);
  }

  Widget _renderText(BuildContext context, String text) =>
      contentBuilder?.call(context, text) ??
      Text(
        text,
        key: const ValueKey<String>('z-explanation-text'),
        textAlign: TextAlign.start,
      );

  /// Annonce NON bloquante : génération en cours, échec ou résultat vide sont
  /// annoncés (`liveRegion`) sans quitter la surface.
  Widget _buildMessage(ZcrudTheme theme) {
    final String? message;
    final Key key;
    switch (controller.status) {
      case ZExplanationStatus.generating:
        message = labels.generatingLabel;
        key = const ValueKey<String>('z-explanation-generating');
      case ZExplanationStatus.failed:
        message = controller.errorMessage;
        key = const ValueKey<String>('z-explanation-error');
      case ZExplanationStatus.empty:
        message = controller.errorMessage;
        key = const ValueKey<String>('z-explanation-empty');
      case ZExplanationStatus.idle:
      case ZExplanationStatus.ready:
        return const SizedBox.shrink();
    }
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapM),
      child: Semantics(
        liveRegion: true,
        child: Text(message, key: key, textAlign: TextAlign.start),
      ),
    );
  }

  /// Sélecteur de versions — ABSENT tant qu'il n'y a pas au moins deux
  /// versions : un sélecteur à une seule entrée n'est pas un choix.
  Widget _buildVersionSelector(ZcrudTheme theme) {
    final total = controller.versions.length;
    if (total < 2) return const SizedBox.shrink();
    final busy = controller.isGenerating;
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapM),
      child: Row(
        key: const ValueKey<String>('z-explanation-versions'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _action(
            key: const ValueKey<String>('z-explanation-previous'),
            label: labels.previousVersionLabel,
            onPressed: !busy && controller.canUndo ? controller.undo : null,
          ),
          Padding(
            padding: EdgeInsetsDirectional.symmetric(horizontal: theme.gapM),
            child: Text(
              labels.versionPosition(controller.currentIndex + 1, total),
              key: const ValueKey<String>('z-explanation-position'),
              textAlign: TextAlign.start,
            ),
          ),
          _action(
            key: const ValueKey<String>('z-explanation-next'),
            label: labels.nextVersionLabel,
            onPressed: !busy && controller.canRedo ? controller.redo : null,
          ),
        ],
      ),
    );
  }

  /// Barre de traitements — chaque commande est ABSENTE tant que sa clé
  /// d'opération n'est pas injectée (invariant AD-4), et la barre entière
  /// disparaît quand aucune ne l'est.
  Widget _buildOperations(ZcrudTheme theme) {
    final busy = controller.isGenerating;
    final hasVersion = controller.current != null;
    final showRestyle = controller.canRestyle && styleOptions.isNotEmpty;
    final showPersist = onPersist != null;
    if (!controller.canSummarize &&
        !controller.canRegenerate &&
        !controller.canElaborate &&
        !showRestyle &&
        !showPersist) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(top: theme.gapL),
      child: Wrap(
        key: const ValueKey<String>('z-explanation-operations'),
        spacing: theme.gapM,
        runSpacing: theme.gapS,
        children: <Widget>[
          if (controller.canSummarize)
            _action(
              key: const ValueKey<String>('z-explanation-summarize'),
              label: labels.summarizeLabel,
              onPressed:
                  !busy && hasVersion ? controller.summarize : null,
            ),
          if (controller.canElaborate)
            _action(
              key: const ValueKey<String>('z-explanation-elaborate'),
              label: labels.elaborateLabel,
              onPressed:
                  !busy && hasVersion ? controller.elaborate : null,
            ),
          if (controller.canRegenerate)
            _action(
              key: const ValueKey<String>('z-explanation-regenerate'),
              label: labels.regenerateLabel,
              onPressed: busy ? null : controller.regenerate,
            ),
          if (showRestyle)
            ConstrainedBox(
              key: const ValueKey<String>('z-explanation-restyle'),
              constraints: const BoxConstraints(minHeight: _kMinTapTarget),
              child: ZActionMenu(
                trigger: ZMenuTrigger.widget(
                  child: Text(labels.restyleLabel, textAlign: TextAlign.start),
                  semanticLabel: labels.restyleLabel,
                ),
                entries: <ZMenuEntry>[
                  for (final option in styleOptions)
                    ZMenuEntry(
                      id: option.key,
                      label: option.label,
                      onSelected: busy || !hasVersion
                          ? null
                          : () => controller.restyle(option.key),
                    ),
                ],
              ),
            ),
          if (showPersist)
            _action(
              key: const ValueKey<String>('z-explanation-persist'),
              label: labels.persistLabel,
              onPressed: !busy && hasVersion ? _persist : null,
            ),
        ],
      ),
    );
  }

  /// Construit l'explication et la remet au handoff — **sans rien écrire**.
  void _persist() {
    final version = controller.current;
    final callback = onPersist;
    if (version == null || callback == null) return;
    callback(
      ZStudyExplanation(
        folderId: folderId,
        content: version.text,
        style: version.style,
        operation: version.operation,
        relatedTopics: relatedTopics,
      ),
    );
  }

  Widget _action({
    required Key key,
    required String label,
    required VoidCallback? onPressed,
  }) =>
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _kMinTapTarget),
        child: OutlinedButton(
          key: key,
          onPressed: onPressed,
          child: Text(label, textAlign: TextAlign.center),
        ),
      );
}

/// Injection Flutter-native d'un port progressif OPTIONNEL (AD-2/AD-15).
///
/// `InheritedWidget` PUR (aucun état mutable). Les surfaces qui offrent
/// l'explication y lisent le port : **absent** ⇒ la voie one-shot est prise,
/// inchangée.
class ZExplanationStreamScope extends InheritedWidget {
  /// Injecte [port] (éventuellement `null`) dans le sous-arbre [child].
  const ZExplanationStreamScope({
    required this.port,
    required super.child,
    super.key,
  });

  /// Port progressif injecté (ou `null` = progressif indisponible).
  final ZAiExplanationStreamPort? port;

  /// Port du plus proche ancêtre, ou `null` si aucun.
  static ZAiExplanationStreamPort? maybePortOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZExplanationStreamScope>()
      ?.port;

  @override
  bool updateShouldNotify(ZExplanationStreamScope oldWidget) =>
      !identical(port, oldWidget.port);
}
