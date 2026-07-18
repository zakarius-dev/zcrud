/// Seam de **présentation riche des familles de sélection** (AD-48).
///
/// origine: parité DODLP `awesome_select` (`SmartSelect`) — un présentateur riche
/// (modal/bottom-sheet/chips avec recherche) que l'app peut brancher à la place
/// du rendu natif zcrud des familles `select`/`radio`/`checkbox`/`relation`.
///
/// **Abstraction Material-free au cœur** (patron **strict** de `ZListRenderer`,
/// AD-8) : `zcrud_core` n'expose QUE le contrat + un **DTO neutre**
/// [ZSelectPresentation]. L'implémentation concrète (adossée à `awesome_select`)
/// vit **exclusivement** dans `zcrud_select` (fp-4-1) et est **injectée** via
/// `ZcrudScope.selectPresenter` (défaut `null` → rendu natif conservé). Le cœur
/// n'importe AUCUN paquet de sélection : CORE OUT=0 préservé (AD-1).
///
/// Imports limités à `package:flutter/widgets.dart` + types `zcrud_core`
/// (garde `presentation_purity_test.dart`) : AUCUN `awesome_select`, aucune
/// dépendance lourde, aucun gestionnaire d'état.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_field_choice.dart';
import '../../domain/edition/z_field_spec.dart';

/// DTO **NEUTRE** présenté au seam (AD-48). Ne porte **QUE des données** — jamais
/// le `ZFormController` (AD-2) ni aucun type `awesome_select` (AD-40).
///
/// Suffisant pour `select`/`radio`/`checkbox`/`relation` (fp-4-1) ; extensible
/// **additivement** plus tard (aucune montée de version requise ici).
@immutable
class ZSelectPresentation {
  /// Construit le contrat neutre transmis au présentateur.
  const ZSelectPresentation({
    required this.field,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.multiple,
    required this.searchable,
    required this.readOnly,
    this.label,
  });

  /// Spécification `const` du champ rendu (déjà neutre : `name`/`type`/…).
  final ZFieldSpec field;

  /// Options **effectives** résolues (statiques ou dynamiques cross-champ).
  final List<ZFieldChoice> options;

  /// Valeur(s) courante(s) de la tranche : scalaire en mono, `List<Object?>` en
  /// multi ([multiple]).
  final Object? selected;

  /// Écrit la sélection dans la tranche (scalaire en mono, `List` en multi). Le
  /// présentateur n'a JAMAIS accès au controller : il ne fait que **notifier**.
  final ValueChanged<Object?> onChanged;

  /// Mode **multi** (`checkbox`/`select` multi) vs **mono** (`select`/`radio`).
  final bool multiple;

  /// Recherche activable (modal filtrant).
  final bool searchable;

  /// Champ en lecture seule (le présentateur désactive l'édition).
  final bool readOnly;

  /// Libellé **déjà résolu** (l10n) du champ, `null` si aucun.
  final String? label;
}

/// Seam de **présentation** des familles de sélection (AD-48). Patron `ZListRenderer` :
/// `abstract class` + constructeur `const` + une méthode [present].
///
/// Défaut `null` dans `ZcrudScope` ⇒ le rendu **natif** zcrud est conservé (aucune
/// régression). Une impl concrète (`zcrud_select`) reçoit un [ZSelectPresentation]
/// neutre et retourne le sous-arbre riche.
abstract class ZSelectPresenter {
  /// Constructeur `const` (présentateurs immuables/`const`).
  const ZSelectPresenter();

  /// Construit le widget de sélection pour la [presentation] neutre fournie.
  Widget present(BuildContext context, ZSelectPresentation presentation);
}
