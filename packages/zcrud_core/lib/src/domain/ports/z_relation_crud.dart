/// `ZRelationCrudHandler` — **port neutre** du **CRUD inline** d'une entité liée
/// pour le champ `relation` (DP-15/M8, parité `showCrudButton`/`onCrud`
/// create/update/copy DODLP `edition_screen.dart:3223-3311`) + son registre
/// instanciable `ZRelationCrudRegistry` (AD-4).
///
/// origine: depuis le sélecteur DODLP, l'utilisateur peut **créer / modifier /
/// copier** l'entité liée ; à la résolution, l'option créée/éditée est
/// **auto-sélectionnée**. Ici le mécanisme est **généralisé en port pur** : le
/// cœur ne connaît NI le form d'édition, NI un repository, NI Firestore/Hive — il
/// **n'affiche que les boutons** (Créer dans le modal ; Modifier/Copier par
/// option) et **appelle le handler**, puis auto-sélectionne l'option résultante.
///
/// **NEUTRALITÉ (NON-NÉGOCIABLE, AD-1/AD-5)** : ce fichier est **pur-Dart**
/// (`dart:async` autorisé, AUCUN import Flutter/`cloud_firestore`/Hive/gestionnaire
/// d'état). **Aucune implémentation concrète ne vit dans le cœur** : l'app/le
/// binding (app DODLP E7, `zcrud_firestore`) implémente `ZRelationCrudHandler` —
/// le **form d'édition** (dialog) **+ le repository** create/update/copy vivent
/// entièrement là-bas — et l'enregistre au runtime via
/// `ZcrudScope(relationCrudRegistry: registry)`.
///
/// **Contrat de retour (AD-5/AD-10)** : chaque opération retourne un
/// `Future<ZFieldChoice?>` = l'**option résultante** à auto-sélectionner, ou
/// `null` si annulé/échec. Le `Future` peut aussi être **en erreur** : le widget
/// le capture défensivement (aucune écriture, aucun crash — équivalent du
/// `try/catch (_) {}` DODLP).
library;

import 'dart:async';

import '../edition/z_field_choice.dart';
import '../registry/z_registry_error.dart';

/// Port **abstrait** (neutre) du CRUD inline d'une entité liée (`relation`).
/// Aucune impl concrète dans `zcrud_core` (form + repository → binding/app E7).
///
/// Chaque opération retourne l'**option résultante** (`ZFieldChoice`) à
/// sélectionner, ou `null` si l'utilisateur annule / l'opération échoue.
abstract class ZRelationCrudHandler {
  /// Constructeur `const` (impl concrètes immuables si possible).
  const ZRelationCrudHandler();

  /// **Créer** une nouvelle entité liée. [context] = snapshot du filtre
  /// cross-champ (mêmes clés que `ZRelationConfig.filterKeys`) pour pré-remplir
  /// le form côté binding. Retourne l'option créée (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> create(Map<String, Object?> context);

  /// **Modifier** l'entité identifiée par [value] (valeur opaque de l'option).
  /// Retourne l'option mise à jour (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> edit(Object? value);

  /// **Copier** (dupliquer) l'entité identifiée par [value]. Retourne l'option
  /// copiée (auto-sélectionnée) ou `null`.
  Future<ZFieldChoice?> copy(Object? value);
}

/// Registre **instanciable** de handlers CRUD de relation, discriminés par une
/// clé `String` (portée par `ZRelationConfig.crudKey`). Injecté via
/// `ZcrudScope.relationCrudRegistry` (AD-4 — **jamais** un singleton statique
/// mutable).
///
/// API alignée sur `ZRelationSourceRegistry`/`ZChoicesSourceRegistry`
/// (register/isRegistered/keys + lookup strict/défensif) : `sourceFor` **throw**
/// [ZUnregisteredTypeError] si absent (bug de configuration, AD-3) ;
/// `trySourceFor` retourne `null` (chemin défensif : aucun bouton CRUD, AD-10).
class ZRelationCrudRegistry {
  /// Construit un registre de handlers vide.
  ZRelationCrudRegistry();

  /// Nom logique du registre (messages d'erreur actionnables).
  static const String _name = 'ZRelationCrudRegistry';

  final Map<String, ZRelationCrudHandler> _handlers =
      <String, ZRelationCrudHandler>{};

  /// Enregistre le [handler] sous [key]. Collision → **`throw`**
  /// [ZDuplicateRegistrationError] (jamais un « last-wins » silencieux, AD-3).
  void register(String key, ZRelationCrudHandler handler) {
    if (_handlers.containsKey(key)) {
      throw ZDuplicateRegistrationError(kind: key, registryName: _name);
    }
    _handlers[key] = handler;
  }

  /// `true` si un handler est enregistré pour [key].
  bool isRegistered(String key) => _handlers.containsKey(key);

  /// Les clés actuellement enregistrées.
  Iterable<String> get keys => _handlers.keys;

  /// Lookup **strict** : le handler de [key], ou **`throw`**
  /// [ZUnregisteredTypeError] si absent (AD-3).
  ZRelationCrudHandler sourceFor(String key) {
    final handler = _handlers[key];
    if (handler == null) {
      throw ZUnregisteredTypeError(kind: key, registryName: _name);
    }
    return handler;
  }

  /// Lookup **défensif** : le handler de [key], ou `null` si absent (AD-10) —
  /// utilisé par le dispatcher pour n'afficher AUCUN bouton CRUD (rétro-compat).
  ZRelationCrudHandler? trySourceFor(String key) => _handlers[key];
}
