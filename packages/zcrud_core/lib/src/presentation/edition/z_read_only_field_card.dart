/// `ZReadOnlyFieldCard` — décorateur **fiche de lecture** (DP-13, parité DODLP
/// `readOnlyWidget` `edition_screen.dart:974-1040`) : une `Card` `label`
/// au-dessus / `valeur` en dessous, avec **copie presse-papier** (appui long +
/// action explicite accessible).
///
/// AD-2/SM-1 : widget **statique** (n'écoute AUCUNE tranche) — l'hôte
/// (`ZFieldWidget`) le monte SOUS `ZFieldListenableBuilder` et lui passe le
/// [label] (déjà résolu l10n), le Widget [value] et le [copyText] (texte copiable,
/// `null` si non copiable — placeholder / valeur-Widget, parité DODLP `value is
/// Widget → onLongPress no-op`).
///
/// FR-26 : fond/bordure **dérivés du `ColorScheme`** (aucune couleur en dur) ;
/// mesures depuis les tokens `read*`/`input*` de `ZcrudTheme`. AD-13 : insets
/// **directionnels**, `Semantics` conteneur (« label : valeur »), cible copie
/// ≥ 48 dp. AD-1 : `package:flutter/services.dart` (`Clipboard`) +
/// `package:flutter/semantics.dart` (`SemanticsService`) sont des **services
/// Flutter natifs** admis (aucun gestionnaire d'état, aucune dépendance lourde).
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/services.dart' show Clipboard, ClipboardData;

// Préfixé : le helper l10n `label(...)` est masqué par le champ `label` de la
// fiche — on l'appelle donc via `l10n.label(...)`.
import '../l10n/z_localizations.dart' as l10n;
import '../theme/z_theme.dart';

/// Fiche de consultation d'un champ en mode lecture (label/valeur + copie).
class ZReadOnlyFieldCard extends StatelessWidget {
  /// Construit la fiche portant [label] au-dessus de [value]. [copyText] `null`
  /// ⇒ aucune affordance de copie (placeholder « — » / valeur-Widget).
  const ZReadOnlyFieldCard({
    required this.label,
    required this.value,
    this.copyText,
    super.key,
  });

  /// Libellé du champ (déjà résolu l10n par l'hôte).
  final String label;

  /// Widget de rendu de la valeur (texte, placeholder, ou pastille couleur).
  final Widget value;

  /// Représentation textuelle **copiable** ; `null` ⇒ copie désactivée.
  final String? copyText;

  bool get _copyable => copyText != null && copyText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final tokens = ZcrudTheme.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle =
        tokens.readLabelTextStyle ?? theme.textTheme.labelMedium;

    final content = Padding(
      padding: tokens.readPadding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            // Label + valeur visibles exclus de la sémantique : le conteneur
            // `Semantics` ci-dessous porte « label : valeur » (pas de double
            // annonce — AD-13). Le bouton copie reste HORS de l'exclusion.
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(label, style: labelStyle, textAlign: TextAlign.start),
                  SizedBox(height: tokens.readLabelGap),
                  DefaultTextStyle.merge(
                    style: tokens.readValueTextStyle,
                    child: value,
                  ),
                ],
              ),
            ),
          ),
          if (_copyable) _copyButton(context),
        ],
      ),
    );

    return Semantics(
      container: true,
      label: label,
      value: copyText,
      child: Padding(
        padding: tokens.readCardMargin,
        child: Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(tokens.inputRadius),
            side: BorderSide(
              color: scheme.outline,
              width: tokens.inputBorderWidth,
            ),
          ),
          child: InkWell(
            // Parité DODLP `onLongPress` : copie la valeur textuelle. No-op si
            // non copiable (placeholder / valeur-Widget).
            onLongPress: _copyable ? () => _copy(context) : null,
            borderRadius: BorderRadius.all(tokens.inputRadius),
            child: content,
          ),
        ),
      ),
    );
  }

  /// Action de copie **explicite** et accessible (≥ 48 dp — AD-13) : ce que
  /// DODLP n'offrait pas (seul l'appui long). Tooltip/`Semantics` localisés.
  Widget _copyButton(BuildContext context) {
    final tooltip = l10n.label(context, 'copy', fallback: 'Copier');
    return IconButton(
      icon: const Icon(Icons.copy_outlined),
      tooltip: tooltip,
      // IconButton porte nativement une cible ≥ 48 dp (Material tap target).
      onPressed: () => _copy(context),
    );
  }

  /// Copie [copyText] dans le presse-papier + retour utilisateur **best-effort
  /// sans dépendance** (AD-10) : annonce sémantique + SnackBar si un
  /// `ScaffoldMessenger` est disponible (sinon aucun throw).
  void _copy(BuildContext context) {
    final text = copyText;
    if (text == null || text.isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    final message = l10n.label(
      context,
      'copied',
      fallback: 'Valeur copiée dans le presse-papier',
    );
    // Annonce lecteur d'écran (a11y AD-13) via le service natif — variante
    // multi-fenêtres de `announce` (évite l'API dépréciée).
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    );
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(message)));
  }
}
