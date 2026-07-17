/// Primitive **UNIQUE** de résolution de Reduce Motion (SU-2, AC3 — NFR-SU3/AD-13).
///
/// ⚠️ **su-2 est le PREMIER usage du repo** (aucun traitement Reduce Motion
/// n'existait — prouvé par grep négatif au moment de la story). Cette primitive
/// **fixe le patron** que su-4 (drag statique) et su-5 (confetti supprimé)
/// réutiliseront : le signal se résout **ICI et nulle part ailleurs**, jamais
/// dispersé dans les `build()` — une seconde lecture du signal divergerait
/// silencieusement (le repo aurait deux politiques d'accessibilité).
///
/// **Pourquoi `disableAnimationsOf` et non `accessibleNavigation`** : le premier
/// est le signal de *réduction d'animations* (« Reduce Motion » iOS / « Supprimer
/// les animations » Android) ; le second désigne la présence d'un **lecteur
/// d'écran**, qui est une préoccupation orthogonale. Les confondre priverait
/// d'animation des utilisateurs qui n'ont rien demandé, et laisserait animés ceux
/// qui l'ont explicitement refusé.
///
/// **Dégradation de l'ANIMATION, jamais de la FONCTION** (AC3) : un appelant qui
/// consulte cette primitive doit rendre l'état final **immédiatement**, jamais
/// annuler l'effet.
library;

import 'package:flutter/widgets.dart';

/// Vrai si l'utilisateur a demandé la **réduction des animations**.
///
/// Voie unique de lecture du signal dans le repo (AC3). S'abonne au
/// `MediaQuery` : un changement de réglage système reconstruit les dépendants.
///
/// ```dart
/// if (zReduceMotionOf(context)) return _face(context, revealed); // instantané
/// ```
bool zReduceMotionOf(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context);
