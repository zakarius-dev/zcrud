/// [ZAppBarSearchConfig] — configuration DÉCLARATIVE de la recherche intégrée
/// (SUF-1, AC4–AC8).
///
/// AD-2/AD-15 : le page-shell **détient lui-même** l'état de recherche
/// (`isSearching`/`query`) — aucun gestionnaire d'état, aucun contrôleur externe.
/// Cette config ne porte donc **pas** d'état : elle n'expose qu'un callback
/// d'émission ([onQueryChanged]), un libellé de hint optionnel et une valeur
/// initiale. `search == null` ⇒ aucune recherche possible (AC8).
library;

import 'package:flutter/foundation.dart';

/// Configuration immuable de la recherche d'app-bar.
@immutable
class ZAppBarSearchConfig {
  /// Construit la config. [onQueryChanged] est requis : il reçoit le texte
  /// **exact** saisi (le shell n'accentue/normalise rien — c'est le rôle de
  /// l'app). [hintLabel] surcharge explicitement le libellé résolu par l10n
  /// (`'search'`). [initialQuery] pré-remplit le champ.
  const ZAppBarSearchConfig({
    required this.onQueryChanged,
    this.hintLabel,
    this.initialQuery = '',
  });

  /// Émis à chaque frappe (texte brut) et à la fermeture (chaîne vide).
  final ValueChanged<String> onQueryChanged;

  /// Libellé de placeholder optionnel (prime sur la résolution l10n si fourni).
  final String? hintLabel;

  /// Valeur initiale de la query (par défaut vide).
  final String initialQuery;
}
