/// `ZcrudRiverpodScope` + provider auto-dispose du `ZFormController` (E2-9).
///
/// origine: équivalent de `ZcrudScope` pour l'idiome Riverpod (cible E8). Le
/// scope (a) possède un `ProviderContainer` (monté via `UncontrolledProviderScope`,
/// équivalent d'un `ProviderScope`), (b) expose le `ZFormController` par un
/// provider AUTO-DISPOSE (`ref.onDispose(controller.dispose)`), puis (c) enveloppe
/// l'enfant dans un `ZcrudScope` porteur d'un `ZRiverpodResolver` manager-backed.
/// Le binding NE réimplémente PAS la réactivité : il réutilise `ZFormController`
/// (AD-2) tel quel.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zcrud_core/zcrud_core.dart';

import 'z_riverpod_resolver.dart';

/// Provider AUTO-DISPOSE exposant un [ZFormController].
///
/// `create` fabrique le controller et branche son `dispose()` sur
/// `ref.onDispose` : dès que plus personne n'écoute le provider (ou que le
/// `ProviderContainer` est disposé), le controller est libéré — aucune fuite.
/// Une app/un test peut surcharger ce provider (`overrideWith`) pour injecter un
/// controller pré-configuré tout en conservant l'auto-dispose.
final zFormControllerProvider = Provider.autoDispose<ZFormController>((ref) {
  final controller = ZFormController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Scope Flutter branchant l'injection/lifecycle sur Riverpod.
class ZcrudRiverpodScope extends StatefulWidget {
  /// Construit le scope.
  ///
  /// [overrides] : surcharges de providers (ex. injecter un controller de test).
  /// [seams] : registre `Type → provider` consommé par [ZRiverpodResolver] pour
  /// répondre à `resolve<T>()`. [acl] : port d'autorisation exposé au cœur.
  const ZcrudRiverpodScope({
    required this.child,
    this.overrides = const [],
    this.seams = const {},
    this.acl = const ZAllowAllAcl(),
    super.key,
  });

  /// Sous-arbre applicatif placé sous le `ZcrudScope` manager-backed.
  final Widget child;

  /// Surcharges de providers appliquées au `ProviderContainer` du scope.
  final List<Override> overrides;

  /// Registre `Type → provider` pour la résolution des seams.
  final Map<Type, ProviderListenable<Object?>> seams;

  /// Port d'autorisation exposé au cœur (défaut : [ZAllowAllAcl]).
  final ZAcl acl;

  @override
  State<ZcrudRiverpodScope> createState() => _ZcrudRiverpodScopeState();
}

class _ZcrudRiverpodScopeState extends State<ZcrudRiverpodScope> {
  late final ProviderContainer _container;
  late final ZRiverpodResolver _resolver;

  @override
  void initState() {
    super.initState();
    _container = ProviderContainer(overrides: widget.overrides);
    _resolver = ZRiverpodResolver(_container, widget.seams);
  }

  @override
  void dispose() {
    // Dispose le conteneur → tous les providers auto-dispose (dont le
    // ZFormController) exécutent leur `ref.onDispose` : aucune fuite.
    _container.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => UncontrolledProviderScope(
        container: _container,
        child: ZcrudScope(
          resolver: _resolver,
          acl: widget.acl,
          child: widget.child,
        ),
      );
}
