/// `ZcrudGetScope` — scope de binding GetX/get_it (E2-9, AD-6/AD-15).
///
/// origine: équivalent de `ZcrudScope` pour l'idiome DODLP. Il (a) possède un
/// périmètre `get_it` isolé, (b) y crée/scope/dispose le `ZFormController` selon
/// le lifecycle du manager, puis (c) enveloppe l'enfant dans un `ZcrudScope`
/// porteur d'un `ZGetResolver` manager-backed — de sorte que les widgets du cœur
/// continuent d'appeler `ZcrudScope.of(context)` sans jamais connaître GetX.
/// Le binding NE réimplémente PAS la réactivité : il réutilise `ZFormController`
/// (AD-2) tel quel.
library;

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:get_it/get_it.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_get_resolver.dart';

/// Scope Flutter branchant l'injection/lifecycle sur `get_it` (idiome DODLP).
///
/// Monte (ou réutilise) un [GetIt], y enregistre un [ZFormController] possédé
/// par le scope, expose un [ZGetResolver] via un [ZcrudScope], puis désenregistre
/// et `dispose()` le controller au démontage (aucune fuite — prouvé par test).
/// Option [registerInGetX] : enregistre AUSSI le controller dans le conteneur
/// réactif GetX (`Get.put`/`Get.delete`), pour une app GetX qui le résout via
/// `Get.find<ZFormController>()`.
class ZcrudGetScope extends StatefulWidget {
  /// Construit le scope.
  ///
  /// [locator] : locator `get_it` (par défaut une **instance isolée**,
  /// `GetIt.asNewInstance()`, pour ne pas polluer le singleton global — idéal en
  /// test et pour un scoping strict). Une app peut passer son locator applicatif
  /// (ex. celui de DODLP) pour partager ses enregistrements. **Locator partagé**
  /// (plusieurs scopes) : le slot de type `ZFormController` du locator est
  /// occupé par le PREMIER scope ; les scopes suivants NE le réenregistrent pas
  /// (le controller reste résolu directement, pas via le locator). Grâce à la
  /// garde d'appartenance, le `dispose` d'un scope ne désenregistre QUE son
  /// propre enregistrement (jamais celui d'un autre scope encore vivant). Pour
  /// résoudre DEUX `ZFormController` par type sur un locator partagé, isoler
  /// chaque formulaire (locator dédié) ou un scope `get_it` par formulaire.
  /// **`registerInGetX`** (singleton GLOBAL `Get`) suit la même règle : un seul
  /// scope actif « possède » l'enregistrement GetX à la fois (LOW-1).
  /// [createController] : fabrique du `ZFormController` possédé par ce scope
  /// (par défaut un `ZFormController()` vide). [acl] : port d'autorisation
  /// exposé au cœur (défaut permissif). [registerController] : enregistre le
  /// controller dans le locator (défaut vrai). [registerInGetX] : bridge GetX
  /// optionnel (défaut faux — évite tout état global partagé).
  const ZcrudGetScope({
    required this.child,
    this.locator,
    this.createController,
    this.acl = const ZAllowAllAcl(),
    this.registerController = true,
    this.registerInGetX = false,
    super.key,
  });

  /// Sous-arbre applicatif placé sous le `ZcrudScope` manager-backed.
  final Widget child;

  /// Locator `get_it` (défaut : instance isolée créée par le scope).
  final GetIt? locator;

  /// Fabrique du `ZFormController` possédé par le scope (défaut : vide).
  final ZFormController Function()? createController;

  /// Port d'autorisation exposé au cœur (défaut : [ZAllowAllAcl]).
  final ZAcl acl;

  /// Enregistre le controller dans le locator `get_it` si vrai (défaut).
  final bool registerController;

  /// Enregistre AUSSI le controller dans GetX (`Get.put`) si vrai (défaut faux).
  final bool registerInGetX;

  @override
  State<ZcrudGetScope> createState() => _ZcrudGetScopeState();
}

class _ZcrudGetScopeState extends State<ZcrudGetScope> {
  late final GetIt _locator;
  late final ZFormController _controller;
  late final ZGetResolver _resolver;

  // Gardes d'APPARTENANCE (MEDIUM-2) : ce scope ne désenregistre QUE ce qu'il a
  // lui-même enregistré. Indispensable quand le locator get_it (ou le singleton
  // GetX) est PARTAGÉ entre plusieurs scopes (réaliste dès E7-1 : DODLP passe
  // son locator applicatif) — sinon le `dispose` de l'un supprimerait le
  // `ZFormController` enregistré par un autre scope encore vivant.
  var _ownsLocatorRegistration = false;
  var _ownsGetXRegistration = false;

  @override
  void initState() {
    super.initState();
    _locator = widget.locator ?? GetIt.asNewInstance();
    _controller = widget.createController?.call() ?? ZFormController();
    if (widget.registerController &&
        !_locator.isRegistered<ZFormController>()) {
      _locator.registerSingleton<ZFormController>(_controller);
      _ownsLocatorRegistration = true;
    }
    if (widget.registerInGetX && !Get.isRegistered<ZFormController>()) {
      // Bridge GetX (idiome host GetxController) : résoluble via Get.find.
      Get.put<ZFormController>(_controller);
      _ownsGetXRegistration = true;
    }
    _resolver = ZGetResolver(_locator);
  }

  @override
  void dispose() {
    // Lifecycle idiomatique : désenregistre du locator get_it et de GetX, puis
    // dispose le controller possédé par ce scope. Ne désenregistre QUE si CE
    // scope est le propriétaire de l'enregistrement ET que l'instance courante
    // est toujours la sienne (aucune fuite ni suppression du controller d'un
    // autre scope partageant le même locator/singleton — MEDIUM-2/LOW-1).
    if (_ownsLocatorRegistration &&
        _locator.isRegistered<ZFormController>() &&
        identical(_locator.get<ZFormController>(), _controller)) {
      _locator.unregister<ZFormController>();
    }
    if (_ownsGetXRegistration &&
        Get.isRegistered<ZFormController>() &&
        identical(Get.find<ZFormController>(), _controller)) {
      Get.delete<ZFormController>();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ZcrudScope(
        resolver: _resolver,
        acl: widget.acl,
        child: widget.child,
      );
}
