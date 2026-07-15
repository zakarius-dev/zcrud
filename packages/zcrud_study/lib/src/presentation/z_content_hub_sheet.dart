/// `ZContentHubSheet` — feuille d'ajout de contenu PARAMÉTRIQUE (ES-5.3, AD-25).
///
/// Remplace les monolithes IFFD `folder_content_creating_buttons.dart` (241 l.) /
/// `folder_content_add_dialog_widget.dart` (550 l.) par une projection présentation
/// paramétrée par une `List<ZContentHubEntry>` : icône/label/hint sont INJECTÉS
/// (i18n, AD-13/FR-26), jamais codés en dur. **Entrée désactivée** (`enabled ==
/// false`) **OU sans callback** (`onTap == null`) ⇒ **non actionnable** (AD-4 —
/// capacité absente, jamais un no-op silencieux).
///
/// Invariants (AD-2/AD-13/AD-15) : AUCUN gestionnaire d'état (réactivité
/// Flutter-native pure) ; `ListView.builder` ; directionnel ; `Semantics`
/// explicites (état désactivé signalé) ; cibles ≥ 48 dp ; thème injecté
/// (`ZcrudTheme.of`, repli `Theme.of`).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZcrudTheme;

/// Cible de taille interactive minimale (AD-13/NFR-S6).
const double _kMinTapTarget = 48.0;

/// Une entrée du hub d'ajout — data-class de présentation immuable (`const`).
///
/// [icon]/[label] sont INJECTÉS (jamais un glyphe/libellé codé en dur). [enabled]
/// `false` OU [onTap] `null` ⇒ entrée NON actionnable (AD-4).
@immutable
class ZContentHubEntry {
  /// Construit une entrée du hub.
  const ZContentHubEntry({
    required this.icon,
    required this.label,
    this.enabled = true,
    this.hint,
    this.onTap,
  });

  /// Glyphe INJECTÉ de l'entrée (jamais codé en dur).
  final IconData icon;

  /// Libellé LOCALISÉ INJECTÉ (i18n, AD-13/FR-23).
  final String label;

  /// Entrée actionnable (défaut `true`). `false` ⇒ tuile désactivée.
  final bool enabled;

  /// Aide/indice LOCALISÉ INJECTÉ (optionnel).
  final String? hint;

  /// Callback d'activation. `null` ⇒ entrée NON actionnable (AD-4).
  final VoidCallback? onTap;

  /// `true` SSI l'entrée est activée ET porte un callback (AD-4).
  bool get isActionable => enabled && onTap != null;
}

/// Feuille d'ajout de contenu paramétrique.
///
/// Testable en isolation (widget nu) ou présentée en modale via [show].
class ZContentHubSheet extends StatelessWidget {
  /// Construit la feuille à partir des entrées (ordre préservé).
  const ZContentHubSheet({required this.entries, super.key});

  /// Entrées du hub, dans l'ordre d'affichage voulu (aucun tri implicite).
  final List<ZContentHubEntry> entries;

  /// Présente la feuille en modale (`showModalBottomSheet`) et se résout à sa
  /// fermeture. Les [entries] (icônes/labels INJECTÉS) sont fournies par
  /// l'appelant — jamais de contenu codé en dur ici.
  static Future<void> show(
    BuildContext context, {
    required List<ZContentHubEntry> entries,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (context) => ZContentHubSheet(entries: entries),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ZcrudTheme.of(context);
    return Semantics(
      container: true,
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsetsDirectional.symmetric(vertical: theme.gapS),
        itemCount: entries.length,
        itemBuilder: (context, index) {
          final entry = entries[index];
          final actionable = entry.isActionable;
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kMinTapTarget),
            child: Semantics(
              button: true,
              enabled: actionable,
              label: entry.label,
              hint: entry.hint,
              child: ListTile(
                leading: Icon(entry.icon),
                title: Text(entry.label, textAlign: TextAlign.start),
                subtitle: entry.hint == null
                    ? null
                    : Text(entry.hint!, textAlign: TextAlign.start),
                enabled: actionable,
                // AD-4 — entrée non actionnable ⇒ AUCUN effet au tap (onTap null).
                onTap: actionable ? entry.onTap : null,
              ),
            ),
          );
        },
      ),
    );
  }
}
