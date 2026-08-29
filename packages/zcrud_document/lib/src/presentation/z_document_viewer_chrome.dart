/// Coquille de viewer de document indépendante de tout moteur de rendu.
///
/// L'hôte fournit le contenu, les barres, les vues d'état et les libellés
/// localisés. Cette surface ne connaît donc ni PDF, ni contrôleur de rendu,
/// ni dépendance tierce.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZDomainFailure, ZFailure, ZReferenceProfile, ZcrudTheme, label;

import '../domain/z_document_ocr_port.dart';
import '../domain/z_document_text_extraction_port.dart';
import 'z_document_viewer_reference.dart';

/// État de lecture affiché par [ZDocumentViewerChrome].
enum ZDocumentViewerLoadState {
  /// Le slot [ZDocumentViewerChrome.document] peut être affiché.
  content,

  /// L'hôte charge le document.
  loading,

  /// L'hôte a rencontré une erreur de lecture.
  error,

  /// L'hôte n'a aucun document à afficher.
  empty,
}

/// Navigation de pages fournie et localisée par l'hôte.
///
/// Les callbacks restent au niveau de l'application : la coquille ne possède
/// aucun état de page et ne communique avec aucun moteur de rendu.
class ZDocumentPageNavigation {
  /// Crée une navigation sans libellé implicite.
  const ZDocumentPageNavigation({
    required this.previousPageLabel,
    required this.nextPageLabel,
    this.onPreviousPage,
    this.onNextPage,
  });

  /// Libellé localisé de l'action vers la page précédente.
  final String previousPageLabel;

  /// Libellé localisé de l'action vers la page suivante.
  final String nextPageLabel;

  /// Demande à l'hôte d'afficher la page précédente ; `null` désactive l'action.
  final VoidCallback? onPreviousPage;

  /// Demande à l'hôte d'afficher la page suivante ; `null` désactive l'action.
  final VoidCallback? onNextPage;
}

/// Clé de localisation du geste « reconnaître le texte ».
///
/// Résolue par `ZcrudScope.labels` ; non fournie, la clé elle-même sert de
/// libellé — la coque n'écrit aucun texte en dur.
const String kZDocumentRecognizeTextLabelKey = 'zcrud.document.recognizeText';

/// Chrome composable d'un viewer de document, sans moteur de rendu.
///
/// Chaque slot est optionnel et n'est jamais remplacé par une vue ou un texte
/// implicite. En particulier, [document] absent ne crée aucun sous-arbre de
/// contenu. Les états [loading], [error] et [empty] sont des widgets injectés
/// par l'hôte ; leurs libellés restent donc dans la couche l10n de l'application.
///
/// ## Geste « reconnaître le texte »
///
/// L'action n'est montée que si [ocrPort] est fourni **et** que son
/// `isAvailable` vaut `true` au moment du `build`. Sans port — le cas par
/// défaut — l'arbre produit est exactement celui d'une coque sans OCR : aucun
/// bouton, aucune ligne d'action, aucun `Semantics` supplémentaire.
///
/// Le résultat suit strictement le contrat de [ZDocumentOcrPort] :
///
/// * `Right(ZDocumentText)` — [onTextRecognized] reçoit le texte ;
/// * `Left(ZFailure)` — [onTextRecognized] n'est **pas** appelé,
///   [onTextRecognitionFailed] reçoit l'échec ; ce callback absent, l'échec
///   est relayé à `FlutterError.onError` pour rester observable ;
/// * une exception levée par le port viole son contrat : elle est capturée,
///   enveloppée en [ZDomainFailure] et routée comme un `Left`. La coque ne
///   relaie jamais une levée à l'arbre de widgets (AD-10).
///
/// Le slot [error] et [loadState] ne sont **jamais** modifiés par la coque :
/// l'affichage d'un échec d'OCR reste une décision de l'hôte.
class ZDocumentViewerChrome extends StatefulWidget {
  /// Crée une coquille de viewer optionnelle.
  const ZDocumentViewerChrome({
    this.document,
    this.topBar,
    this.bottomBar,
    this.loadState = ZDocumentViewerLoadState.content,
    this.loading,
    this.error,
    this.empty,
    this.pageNavigation,
    this.documentId = '',
    this.source = '',
    this.ocrPort,
    this.onTextRecognized,
    this.onTextRecognitionFailed,
    this.recognizeTextIcon = Icons.document_scanner_outlined,
    this.recognizeTextLabelKey = kZDocumentRecognizeTextLabelKey,
    this.navigationBarMinHeight,
    this.navigationIconSize,
    super.key,
  });

  /// Contenu rendu par le moteur choisi par l'hôte.
  final Widget? document;

  /// Slot de barre supérieure fourni par l'hôte.
  final Widget? topBar;

  /// Slot de barre inférieure fourni par l'hôte.
  final Widget? bottomBar;

  /// État de lecture piloté par l'hôte.
  final ZDocumentViewerLoadState loadState;

  /// Vue de chargement injectée par l'hôte.
  final Widget? loading;

  /// Vue d'erreur injectée par l'hôte.
  final Widget? error;

  /// Vue vide injectée par l'hôte.
  final Widget? empty;

  /// Navigation sans connaissance du moteur, ou `null` si absente.
  final ZDocumentPageNavigation? pageNavigation;

  /// Identifiant opaque du document, transmis tel quel au port d'OCR.
  final String documentId;

  /// Référence source opaque, transmise telle quelle au port d'OCR ; le port
  /// seul sait la résoudre (chemin de stockage, URI, jeton…).
  final String source;

  /// Port d'OCR fourni par l'hôte, ou `null` pour ne monter aucune action.
  ///
  /// Un port dont `isAvailable` vaut `false` équivaut à l'absence de port :
  /// l'action n'est pas montée et le port n'est jamais appelé.
  final ZDocumentOcrPort? ocrPort;

  /// Reçoit le texte uniquement quand le port rend un `Right`.
  final ValueChanged<ZDocumentText>? onTextRecognized;

  /// Reçoit l'échec quand le port rend un `Left` — ou qu'il lève.
  ///
  /// Absent, l'échec est relayé à `FlutterError.onError` : il n'est jamais
  /// avalé en silence, et jamais propagé à l'arbre de widgets.
  final ValueChanged<ZFailure>? onTextRecognitionFailed;

  /// Icône de l'action d'OCR, remplaçable par l'hôte.
  final IconData recognizeTextIcon;

  /// Clé de libellé résolue par `ZcrudScope.labels` ; par défaut
  /// [kZDocumentRecognizeTextLabelKey].
  final String recognizeTextLabelKey;

  /// Hauteur **minimale** de la barre de navigation de pages.
  ///
  /// `null` ⇒ la référence auditée
  /// ([ZDocumentViewerReference.barHeight]) sous profil
  /// `ZReferenceProfile.legacy`, aucune contrainte sous
  /// `ZReferenceProfile.neutral`. C'est un plancher : la barre grandit
  /// librement au-delà, et une cible interactive n'y est jamais comprimée.
  final double? navigationBarMinHeight;

  /// Taille des glyphes des actions de navigation de pages.
  ///
  /// `null` ⇒ la référence auditée
  /// ([ZDocumentViewerReference.barIconSize]) sous profil
  /// `ZReferenceProfile.legacy`, la taille par défaut de `Icon` sous
  /// `ZReferenceProfile.neutral`.
  final double? navigationIconSize;

  @override
  State<ZDocumentViewerChrome> createState() => _ZDocumentViewerChromeState();
}

class _ZDocumentViewerChromeState extends State<ZDocumentViewerChrome> {
  bool _recognizing = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = _bodyForState();
    final port = widget.ocrPort;
    final ZReferenceProfile? profile =
        ZcrudTheme.of(context).referenceProfile;
    // Épaisseur du filet : la référence sous `legacy`, le défaut du SDK
    // (`null`) sous `neutral` — la HAUTEUR, elle, valait déjà 1 dp dans les
    // deux profils, donc elle ne bouge pas.
    final double? dividerThickness = zDocumentLegacyOrNeutral<double?>(
      profile,
      ZDocumentViewerReference.dividerThickness,
      null,
    );
    return ColoredBox(
      color: scheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.topBar case final topBar?) topBar,
          if (widget.topBar case final _?)
            Divider(
              height: ZDocumentViewerReference.dividerThickness,
              thickness: dividerThickness,
              color: scheme.outlineVariant,
            ),
          // Le geste n'existe QUE si l'hôte a fourni un port disponible : sans
          // port, aucun widget n'est ajouté à la colonne (inertie absolue).
          if (port != null && port.isAvailable)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: ZDocumentViewerReference.minTouchTarget,
                  minHeight: ZDocumentViewerReference.minTouchTarget,
                ),
                child: IconButton(
                  tooltip: label(context, widget.recognizeTextLabelKey),
                  icon: Icon(widget.recognizeTextIcon),
                  onPressed: _recognizing ? null : _recognizeText,
                ),
              ),
            ),
          if (body != null) Expanded(child: body),
          if (widget.pageNavigation != null)
            _PageNavigationBar(
              navigation: widget.pageNavigation!,
              minHeight: widget.navigationBarMinHeight ??
                  zDocumentLegacyOrNeutral<double?>(
                    profile,
                    ZDocumentViewerReference.barHeight,
                    null,
                  ),
              iconSize: widget.navigationIconSize ??
                  zDocumentLegacyOrNeutral<double?>(
                    profile,
                    ZDocumentViewerReference.barIconSize,
                    null,
                  ),
            ),
          if (widget.bottomBar case final _?)
            Divider(
              height: ZDocumentViewerReference.dividerThickness,
              thickness: dividerThickness,
              color: scheme.outlineVariant,
            ),
          if (widget.bottomBar case final bottomBar?) bottomBar,
        ],
      ),
    );
  }

  Widget? _bodyForState() {
    switch (widget.loadState) {
      case ZDocumentViewerLoadState.content:
        return widget.document;
      case ZDocumentViewerLoadState.loading:
        return widget.loading;
      case ZDocumentViewerLoadState.error:
        return widget.error;
      case ZDocumentViewerLoadState.empty:
        return widget.empty;
    }
  }

  Future<void> _recognizeText() async {
    final port = widget.ocrPort;
    if (port == null || !port.isAvailable || _recognizing) return;
    setState(() => _recognizing = true);
    try {
      final result = await port.recognize(
        ZDocumentOcrRequest(
          documentId: widget.documentId,
          source: widget.source,
        ),
      );
      result.fold(
        _reportFailure,
        (text) => widget.onTextRecognized?.call(text),
      );
    } catch (error, stack) {
      // Un port qui LÈVE viole son contrat (`Left` attendu). La coque ne
      // laisse jamais l'exception remonter dans l'arbre : elle la relaie
      // toujours à `FlutterError.onError` (avec sa pile, seul endroit où elle
      // reste débogable) puis la présente à l'hôte comme un échec ordinaire.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          library: 'zcrud_document',
          context: ErrorDescription(
            'levée par ZDocumentOcrPort.recognize. Le contrat du port exige '
            'un Left(ZFailure) : la coque a converti la levée en échec et '
            'poursuit son rendu (AD-10).',
          ),
        ),
      );
      _reportFailure(const ZDomainFailure('document OCR port threw'));
    } finally {
      if (mounted) setState(() => _recognizing = false);
    }
  }

  void _reportFailure(ZFailure failure) {
    final onFailed = widget.onTextRecognitionFailed;
    if (onFailed != null) {
      onFailed(failure);
      return;
    }
    // Sans canal d'hôte, l'échec resterait invisible : il part au rapporteur
    // d'erreurs de Flutter plutôt que d'être avalé.
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: failure,
        library: 'zcrud_document',
        context: ErrorDescription(
          'rendu par ZDocumentOcrPort.recognize. Fournir '
          'onTextRecognitionFailed pour traiter cet échec dans l\'hôte.',
        ),
      ),
    );
  }
}

class _PageNavigationBar extends StatelessWidget {
  const _PageNavigationBar({
    required this.navigation,
    required this.minHeight,
    required this.iconSize,
  });

  final ZDocumentPageNavigation navigation;

  /// Plancher de hauteur, ou `null` pour n'en poser aucun.
  final double? minHeight;

  /// Taille de glyphe, ou `null` pour le défaut du SDK.
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget bar = Padding(
      padding: const EdgeInsetsDirectional.all(8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _PageAction(
            icon: Icons.chevron_left,
            label: navigation.previousPageLabel,
            onPressed: navigation.onPreviousPage,
            iconSize: iconSize,
          ),
          _PageAction(
            icon: Icons.chevron_right,
            label: navigation.nextPageLabel,
            onPressed: navigation.onNextPage,
            iconSize: iconSize,
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(color: scheme.surfaceContainerLow),
      // Plancher, jamais hauteur imposée : une hauteur fixe à la valeur de
      // référence (56) écraserait deux cibles de 48 dp entourées de 8 dp de
      // marge, et AD-13 prime sur la fidélité. Sans plancher (`neutral`),
      // aucun nœud n'est ajouté.
      child: minHeight == null
          ? bar
          : ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight!),
              child: bar,
            ),
    );
  }
}

class _PageAction extends StatelessWidget {
  const _PageAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.iconSize,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double? iconSize;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: ZDocumentViewerReference.minTouchTarget,
        minHeight: ZDocumentViewerReference.minTouchTarget,
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize),
        label: Text(label, textAlign: TextAlign.start),
      ),
    ),
  );
}
