/// `ZWidgetRegistry` — **registre de widgets d'édition** injecté (E3-3b-1, AD-4).
///
/// origine: le repli `ZUnsupportedFieldWidget` (E3-3a) désignait explicitement
/// E3-3b comme responsable de le remplacer par un **registre de widgets**. Ce
/// registre associe un `kind` (`String`) à un **builder de widget** que le
/// dispatcher `ZFieldWidget` rend **dans** la frontière de rebuild existante
/// (`ZFieldListenableBuilder`, value-in-slice) pour les types dont le widget
/// vit **hors du cœur** (markdown → E6 ; géo/tél → E11a ; `custom` → app hôte).
///
/// **RECLASSEMENT (Contexte E3-3b)** : ce registre est **DISTINCT** de
/// `ZTypeRegistry` (domaine, pur-Dart) qui enregistre des **codecs**
/// `fromJson`/`toJson` — PAS des `Widget`. Un registre de widgets a besoin de
/// Flutter → il vit en couche `presentation/`. La convention de `kind` est
/// **alignée** sur `ZTypeRegistry` (nom d'`EditionFieldType` pour les types
/// enum ; discriminant `custom` pour `EditionFieldType.custom`) : une app hôte
/// enregistre **codec + widget sous le même `kind`**.
///
/// **AD-4** : le registre est **INSTANCIABLE** et injecté via
/// `ZcrudScope.widgetRegistry` — **jamais** un singleton statique mutable. Le
/// cœur reste **agnostique** des widgets externes (aucun import markdown/géo/
/// tél ; graphe OUT=0 inchangé) : le widget réel est fourni par le package
/// satellite / l'app.
library;

import 'package:flutter/widgets.dart';

import '../../domain/edition/z_field_spec.dart';
import '../../domain/registry/z_registry_error.dart';

/// Contexte passé à un [ZFieldWidgetBuilder] : la spec du champ, la valeur
/// COURANTE de sa tranche et le callback d'écriture. Le builder **lit** [value]
/// et **écrit** via [onChanged] — l'appel reste **dans** la frontière de rebuild
/// du dispatcher (AD-2 : aucune souscription élargie).
@immutable
class ZFieldWidgetContext {
  /// Construit le contexte d'un champ servi par le registre.
  const ZFieldWidgetContext({
    required this.field,
    required this.value,
    required this.onChanged,
  });

  /// Spécification `const` du champ rendu (`name`/`type`/`label`/`config`…).
  final ZFieldSpec field;

  /// Valeur COURANTE de la tranche `field.name` (lue par le builder hôte).
  final Object? value;

  /// Écrit une nouvelle valeur dans la tranche (branché sur `setValue`).
  final ValueChanged<Object?> onChanged;
}

/// Construit le widget d'édition d'un champ à partir de son [ZFieldWidgetContext].
///
/// Fourni par un package satellite / l'app hôte (jamais par le cœur). Si le
/// widget nécessite un contrôleur isolé (cas rich-text E6, AD-7), c'est **sa**
/// responsabilité — le cœur ne gère pas sa stabilité.
typedef ZFieldWidgetBuilder = Widget Function(
  BuildContext context,
  ZFieldWidgetContext ctx,
);

/// Registre **instanciable** de builders de widgets d'édition, discriminés par
/// `kind` (`String`). Injecté via `ZcrudScope.widgetRegistry` (AD-4 — jamais un
/// singleton statique mutable).
///
/// API alignée sur `ZTypeRegistry`/`ZOpenRegistry` (register/isRegistered/kinds
/// + lookup strict/défensif) : `builderFor` **throw** [ZUnregisteredTypeError]
/// si absent (bug de configuration, AD-3) ; `tryBuilderFor` retourne `null`
/// (chemin défensif utilisé par le dispatcher pour retomber sur le repli).
class ZWidgetRegistry {
  /// Construit un registre de widgets vide.
  ZWidgetRegistry();

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZWidgetRegistry';

  final Map<String, ZFieldWidgetBuilder> _builders = <String, ZFieldWidgetBuilder>{};

  /// Enregistre le [builder] de [kind]. Collision → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux, AD-3).
  void register(String kind, ZFieldWidgetBuilder builder) {
    if (_builders.containsKey(kind)) {
      throw ZDuplicateRegistrationError(kind: kind, registryName: _name);
    }
    _builders[kind] = builder;
  }

  /// `true` si un builder est enregistré pour [kind].
  bool isRegistered(String kind) => _builders.containsKey(kind);

  /// Les `kind` actuellement enregistrés.
  Iterable<String> get kinds => _builders.keys;

  /// Lookup **strict** : le builder de [kind], ou **`throw`**
  /// [ZUnregisteredTypeError] si absent (AD-3).
  ZFieldWidgetBuilder builderFor(String kind) {
    final builder = _builders[kind];
    if (builder == null) {
      throw ZUnregisteredTypeError(kind: kind, registryName: _name);
    }
    return builder;
  }

  /// Lookup **défensif** : le builder de [kind], ou `null` si absent (AD-10) —
  /// utilisé par le dispatcher pour retomber sur `ZUnsupportedFieldWidget`.
  ZFieldWidgetBuilder? tryBuilderFor(String kind) => _builders[kind];
}
