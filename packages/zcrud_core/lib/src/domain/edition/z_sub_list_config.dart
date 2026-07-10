/// Config additive `const` des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`) — E3-3b-2 (mini-CRUD imbriqué, AD-2/AD-4).
///
/// origine: un champ `subItems` porte une **liste d'items** ; chaque item est un
/// `Map<String, dynamic>` édité par un **sous-formulaire imbriqué** (réutilise le
/// dispatcher `ZFieldWidget`). Le **sous-schéma** de l'item est décrit ici par un
/// `List<ZFieldSpec>` **pur-données `const`** ([itemFields]) — jamais une closure
/// ni un widget (couche `domain`, garde `domain_purity_test.dart`). Le champ
/// `dynamicItem` réutilise la même config (cardinalité ≤ 1).
///
/// **Point d'extension AD-4** : `const`, additif (sous-classe de [ZFieldConfig]),
/// jamais `sealed`. L'interprétation (schéma → widgets imbriqués) est E3-3b-2
/// (`ZSubListFieldWidget`/`ZDynamicItemFieldWidget`) ; ici on ne porte que la
/// **donnée** du sous-schéma.
///
/// Recoupement E4-5 (`ZSubListScreen`) : cette config décrit le **champ**
/// d'édition imbriqué (dans un formulaire) ; l'écran de sous-liste autonome
/// (mini-CRUD de niveau liste) est E4-5. Le sous-schéma `const` est la brique
/// commune réutilisable (à factoriser côté E4-5, pas dupliquée ici).
library;

import 'z_field_config.dart';
import 'z_field_spec.dart';

/// Config triviale pur-cœur des champs **sous-liste** (`subItems`) et **item
/// dynamique** (`dynamicItem`) — E3-3b-2.
///
/// [itemFields] est le **sous-schéma `const`** d'un item (chaque item est édité
/// par un sous-formulaire imbriqué). [reorderable] active le réordonnancement
/// (monter/descendre) de la sous-liste ; sans effet pour `dynamicItem`
/// (cardinalité ≤ 1).
class ZSubListConfig extends ZFieldConfig {
  /// Construit une config de sous-liste `const`.
  const ZSubListConfig({
    this.itemFields = const <ZFieldSpec>[],
    this.reorderable = true,
  });

  /// Sous-schéma `const` d'un item (projeté 1:1 en sous-formulaire imbriqué).
  final List<ZFieldSpec> itemFields;

  /// Autorise le réordonnancement (monter/descendre) des items (`subItems`).
  final bool reorderable;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSubListConfig &&
          runtimeType == other.runtimeType &&
          reorderable == other.reorderable &&
          _listEquals(itemFields, other.itemFields);

  @override
  int get hashCode =>
      Object.hash(runtimeType, reorderable, Object.hashAll(itemFields));
}

/// Égalité **profonde** de deux listes (pur-Dart — évite `package:collection`,
/// AD-1 out-degree 0).
bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
