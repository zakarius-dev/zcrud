/// `ZNoteSummarySheet` — feuille de résumé d'une note par IA, et injection
/// Flutter-native du port qui la rend disponible.
///
/// ## Composition, jamais de moteur dupliqué
///
/// - Cycle de vie asynchrone, jeton de fraîcheur, frontière de commit :
///   délégués à [ZNoteSummaryController] (aucun dépôt, aucun store).
/// - Rendu du résumé : **texte brut** par défaut, ou le widget rendu par le
///   slot [ZNoteSummarySheet.summaryBuilder]. `zcrud_study` ne dépend pas d'un
///   moteur de rich-text (invariant AD-1) : une lecture Markdown reste donc
///   possible, mais elle est **fournie par l'application** via ce slot, jamais
///   tirée en dépendance ici.
///
/// ## Réactivité granulaire (invariant AD-2)
///
/// Le `TextEditingController` du contenu est créé une seule fois en
/// `initState` (jamais dans `build`) et vit hors du `ListenableBuilder` du
/// statut : taper n'y reconstruit ni l'aire de revue ni la surface hôte, et ne
/// perd jamais le focus.
///
/// ## Cette feuille n'écrit RIEN
///
/// Les seuls canaux de sortie sont les handoffs
/// [ZNoteSummarySheet.onInsertAtTop] (insertion en tête de la note) et
/// [ZNoteSummarySheet.onCreateNote] (note nouvelle) : c'est l'application qui
/// écrit, par la voie de persistance de son choix. Un échec, un résumé vide ou
/// une fermeture ne remettent rien.
///
/// ## La revue est en LECTURE
///
/// Le texte remis aux handoffs est **exactement** celui rendu par le port :
/// la revue ne l'édite pas. Une application qui veut laisser retoucher le
/// résumé le fait dans sa propre surface, à partir du texte reçu.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

import '../domain/z_note_summary_port.dart';
import 'z_note_summary_controller.dart';

/// Cible de taille interactive minimale (invariant AD-13).
const double _kMinTapTarget = 48.0;

/// Rend le résumé produit. Slot opt-in : `null` ⇒ texte brut thématisé.
///
/// C'est par ici qu'une application branche son moteur de rendu riche
/// (Markdown, HTML…) sans qu'aucune dépendance de rendu n'entre dans ce
/// paquet.
typedef ZNoteSummaryTextBuilder = Widget Function(
  BuildContext context,
  String summary,
);

/// Libellés INJECTÉS de la feuille de résumé (i18n — aucun libellé en dur,
/// FR-26). Tous requis : un défaut dans une langue serait un libellé en dur
/// sans voie de remplacement.
@immutable
class ZNoteSummaryLabels {
  /// Construit les libellés injectés.
  const ZNoteSummaryLabels({
    required this.contentLabel,
    required this.contentHint,
    required this.summarizeLabel,
    required this.summarizingLabel,
    required this.reviewTitle,
    required this.insertAtTopLabel,
    required this.createNoteLabel,
  });

  /// Libellé du champ de contenu à résumer.
  final String contentLabel;

  /// Indice du champ de contenu à résumer.
  final String contentHint;

  /// Libellé du bouton de lancement du résumé.
  final String summarizeLabel;

  /// Libellé affiché pendant le résumé.
  final String summarizingLabel;

  /// Titre de l'aire de revue du résumé produit.
  final String reviewTitle;

  /// Libellé de l'issue « insérer le résumé en tête de la note ».
  final String insertAtTopLabel;

  /// Libellé de l'issue « créer une note à partir du résumé ».
  final String createNoteLabel;
}

/// Feuille de résumé IA d'une note, revue puis remise à l'application.
class ZNoteSummarySheet extends StatefulWidget {
  /// Construit la feuille autour d'un [port] faillible.
  ///
  /// Le résumé validé est remis à [onInsertAtTop] ou à [onCreateNote] — c'est
  /// l'appelant qui écrit.
  const ZNoteSummarySheet({
    required this.port,
    required this.messages,
    required this.labels,
    this.initialContent = '',
    this.onInsertAtTop,
    this.onCreateNote,
    this.summaryBuilder,
    this.maxLength,
    this.languageTag,
    this.requestExtra = const <String, dynamic>{},
    this.reviewHeight,
    super.key,
  });

  /// Port de résumé (injecté par l'application hôte).
  final ZNoteSummaryPort port;

  /// Messages d'échec injectés (transmis au contrôleur).
  final ZNoteSummaryMessages messages;

  /// Libellés injectés de la feuille.
  final ZNoteSummaryLabels labels;

  /// Contenu initial du champ à résumer (typiquement le texte de la note,
  /// projeté par l'hôte). Vide ⇒ champ vide.
  final String initialContent;

  /// Handoff « insérer en tête de la note ». `null` ⇒ issue ABSENTE de
  /// l'arbre, jamais un bouton inerte (invariant AD-4).
  final ZNoteSummaryCallback? onInsertAtTop;

  /// Handoff « créer une note ». `null` ⇒ issue ABSENTE de l'arbre.
  final ZNoteSummaryCallback? onCreateNote;

  /// Rendu du résumé en revue. `null` ⇒ texte brut thématisé.
  final ZNoteSummaryTextBuilder? summaryBuilder;

  /// Longueur cible indicative transmise telle quelle à la requête.
  final int? maxLength;

  /// Étiquette de langue BCP-47 transmise telle quelle à la requête.
  final String? languageTag;

  /// Échappatoire non typée transmise telle quelle à la requête.
  ///
  /// Les clés de synchronisation réservées en sont écartées par
  /// `ZNoteSummaryRequest` lui-même, à la lecture (AD-19.1). Ce slot porte
  /// délibérément un nom distinct de `extra` : une surface de présentation
  /// n'est pas un porteur d'`extra` persisté, et n'a donc ni stockage ni
  /// filtre propre — elle ne fait que relayer.
  final Map<String, dynamic> requestExtra;

  /// Hauteur bornée de l'aire de revue. `null` ⇒ la revue prend la hauteur de
  /// son contenu (aucune contrainte imposée).
  final double? reviewHeight;

  @override
  State<ZNoteSummarySheet> createState() => _ZNoteSummarySheetState();
}

class _ZNoteSummarySheetState extends State<ZNoteSummarySheet> {
  // Controller STABLE (créé UNE fois, jamais dans build() — AD-2).
  late final TextEditingController _contentController;

  late final ZNoteSummaryController _summary;

  @override
  void initState() {
    super.initState();
    _contentController = TextEditingController(text: widget.initialContent);
    _summary = ZNoteSummaryController(
      port: widget.port,
      messages: widget.messages,
      onInsertAtTop: widget.onInsertAtTop,
      onCreateNote: widget.onCreateNote,
    );
  }

  @override
  void dispose() {
    _contentController.dispose();
    _summary.dispose();
    super.dispose();
  }

  /// Construit la requête soumise au port. Aucun prompt, aucun endpoint,
  /// aucune clé (invariant AD-12) : seulement le contenu et les préférences
  /// transmises verbatim.
  ZNoteSummaryRequest _buildRequest() => ZNoteSummaryRequest(
        content: _contentController.text,
        maxLength: widget.maxLength,
        languageTag: widget.languageTag,
        extra: widget.requestExtra,
      );

  void _submit() => _summary.generate(_buildRequest());

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    final labels = widget.labels;
    return ListenableBuilder(
      listenable: _summary,
      builder: (context, _) {
        if (_summary.status == ZNoteSummaryStatus.reviewing) {
          return _buildReview(theme, labels);
        }
        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // Champ de contenu — controller STABLE, hors des tranches
              // réactives : taper ne reconstruit rien d'autre que lui-même.
              TextField(
                key: const ValueKey<String>('z-note-summary-content'),
                controller: _contentController,
                textAlign: TextAlign.start,
                minLines: 2,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: labels.contentLabel,
                  hintText: labels.contentHint,
                ),
              ),
              SizedBox(height: theme.gapL),
              _buildActionArea(labels),
              _buildResultArea(theme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionArea(ZNoteSummaryLabels labels) {
    final busy = _summary.status == ZNoteSummaryStatus.summarizing;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _kMinTapTarget),
      child: ElevatedButton(
        key: const ValueKey<String>('z-note-summary-submit'),
        // Anti-double-soumission : le contrôleur ignore toute soumission
        // pendant `summarizing` — le bouton reflète l'état.
        onPressed: busy ? null : _submit,
        child: Text(
          busy ? labels.summarizingLabel : labels.summarizeLabel,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  /// Aire de résultat NON bloquante : échec et résultat vide sont annoncés
  /// (`liveRegion`) sans quitter la feuille — la saisie reste intacte.
  Widget _buildResultArea(ZcrudTheme theme) {
    switch (_summary.status) {
      case ZNoteSummaryStatus.failed:
      case ZNoteSummaryStatus.empty:
        final message = _summary.errorMessage ?? '';
        final key = _summary.status == ZNoteSummaryStatus.failed
            ? const ValueKey<String>('z-note-summary-error')
            : const ValueKey<String>('z-note-summary-empty');
        return Padding(
          padding: EdgeInsetsDirectional.only(top: theme.gapM),
          child: Semantics(
            liveRegion: true,
            child: Text(message, key: key, textAlign: TextAlign.start),
          ),
        );
      case ZNoteSummaryStatus.idle:
      case ZNoteSummaryStatus.summarizing:
      case ZNoteSummaryStatus.reviewing:
        return const SizedBox.shrink();
    }
  }

  /// Aire de REVUE : le résumé rendu (texte brut, ou slot injecté), puis les
  /// issues remises à l'application. Une issue sans handoff est ABSENTE de
  /// l'arbre — jamais un bouton qui ne fait rien (invariant AD-4).
  Widget _buildReview(ZcrudTheme theme, ZNoteSummaryLabels labels) {
    final text = _summary.summary;
    final rendered = widget.summaryBuilder?.call(context, text) ??
        Text(
          text,
          key: const ValueKey<String>('z-note-summary-text'),
          textAlign: TextAlign.start,
        );
    final height = widget.reviewHeight;
    return SingleChildScrollView(
      child: Column(
        key: const ValueKey<String>('z-note-summary-review'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(labels.reviewTitle, textAlign: TextAlign.start),
          SizedBox(height: theme.gapS),
          if (height == null)
            rendered
          else
            SizedBox(
              height: height,
              child: SingleChildScrollView(child: rendered),
            ),
          SizedBox(height: theme.gapL),
          Wrap(
            spacing: theme.gapM,
            runSpacing: theme.gapS,
            children: <Widget>[
              if (widget.onInsertAtTop != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _kMinTapTarget),
                  child: ElevatedButton(
                    key: const ValueKey<String>('z-note-summary-insert'),
                    onPressed: _summary.insertAtTop,
                    child: Text(
                      labels.insertAtTopLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (widget.onCreateNote != null)
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _kMinTapTarget),
                  child: OutlinedButton(
                    key: const ValueKey<String>('z-note-summary-create'),
                    onPressed: _summary.createNote,
                    child: Text(
                      labels.createNoteLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Injection Flutter-native d'un [ZNoteSummaryPort] OPTIONNEL (AD-2/AD-15).
///
/// `InheritedWidget` PUR (aucun état mutable). Les surfaces qui offrent le
/// résumé y lisent le port : **absent** ⇒ l'action est ABSENTE de l'arbre,
/// jamais grisée.
class ZNoteSummaryScope extends InheritedWidget {
  /// Injecte [port] (éventuellement `null`) dans le sous-arbre [child].
  const ZNoteSummaryScope({
    required this.port,
    required super.child,
    super.key,
  });

  /// Port injecté (ou `null` = résumé indisponible).
  final ZNoteSummaryPort? port;

  /// Port du plus proche ancêtre, ou `null` si aucun.
  static ZNoteSummaryPort? maybePortOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ZNoteSummaryScope>()?.port;

  @override
  bool updateShouldNotify(ZNoteSummaryScope oldWidget) =>
      !identical(port, oldWidget.port);
}
