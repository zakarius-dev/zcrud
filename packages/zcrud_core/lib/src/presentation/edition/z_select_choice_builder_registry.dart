/// Registre injecté des rendus riches d'options de sélection (AD-4).
///
/// La clé reste dans [ZSelectConfig] (domaine, `const`), tandis que les
/// fermetures de rendu vivent ici, en présentation. Le registre est
/// instanciable, chaînable et injecté par [ZcrudScope] : aucun singleton
/// mutable ne relie les formulaires hôtes.
library;

import '../../domain/registry/z_registry_error.dart';
import 'z_select_presenter.dart';

/// Ensemble immuable des builders riches associés à une même clé de select.
///
/// Chaque membre est optionnel : un hôte peut remplacer le rendu complet,
/// l'affordance secondaire, ou les deux. L'absence des deux est refusée à
/// l'enregistrement afin qu'une clé résolue ne soit jamais une capacité vide.
class ZSelectChoiceBuilders {
  /// Construit les builders riches d'une clé de sélection.
  const ZSelectChoiceBuilders({this.choiceBuilder, this.choiceSecondaryBuilder})
    : assert(choiceBuilder != null || choiceSecondaryBuilder != null);

  /// Rendu complet d'une option.
  final ZSelectChoiceBuilder? choiceBuilder;

  /// Affordance de fin de ligne d'une option.
  final ZSelectChoiceSecondaryBuilder? choiceSecondaryBuilder;
}

/// Registre des [ZSelectChoiceBuilders], indexé par une clé déclarative.
///
/// Un enfant consulte d'abord ses entrées puis son [parent]. Il peut donc
/// ombrer légitimement une clé parent, mais une double inscription locale lève
/// explicitement une [ZDuplicateRegistrationError]. Le lookup défensif
/// retourne `null` pour permettre au widget de retomber sur son rendu natif.
class ZSelectChoiceBuilderRegistry {
  /// Construit un registre localement vide, éventuellement chaîné à [parent].
  ZSelectChoiceBuilderRegistry({this.parent});

  /// Registre consulté lorsqu'aucune entrée locale ne correspond à la clé.
  final ZSelectChoiceBuilderRegistry? parent;

  static const String _name = 'ZSelectChoiceBuilderRegistry';

  final Map<String, ZSelectChoiceBuilders> _builders =
      <String, ZSelectChoiceBuilders>{};

  /// Enregistre [builders] sous [key].
  ///
  /// Une collision locale est une erreur de configuration explicite; une clé
  /// présente seulement dans [parent] est une surcharge enfant légitime.
  void register(String key, ZSelectChoiceBuilders builders) {
    if (_builders.containsKey(key)) {
      throw ZDuplicateRegistrationError(kind: key, registryName: _name);
    }
    _builders[key] = builders;
  }

  /// Indique si [key] est servie localement ou dans la chaîne parent.
  bool isRegistered(String key) =>
      _builders.containsKey(key) || (parent?.isRegistered(key) ?? false);

  /// Clés servies par ce registre et sa chaîne, dédupliquées.
  Iterable<String> get keys => <String>{..._builders.keys, ...?parent?.keys};

  /// Lookup strict, réservé aux erreurs de configuration détectables tôt.
  ZSelectChoiceBuilders buildersFor(String key) {
    final builders = tryBuildersFor(key);
    if (builders == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return builders;
  }

  /// Lookup défensif enfant → parent; `null` si la clé est absente partout.
  ZSelectChoiceBuilders? tryBuildersFor(String key) =>
      _builders[key] ?? parent?.tryBuildersFor(key);
}
