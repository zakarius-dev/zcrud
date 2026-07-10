import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_get/zcrud_get.dart';
import 'package:zcrud_provider/zcrud_provider.dart';
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

/// Mécanisme d'injection sélectionnable (parité AD-15, AC7). Le manager ne vit
/// QUE dans le `wrap` correspondant ; la config de champs et l'écran d'édition
/// restent manager-agnostiques.
enum DemoBinding {
  /// `ZcrudScope` seul (défaut zéro-dépendance).
  scope('ZcrudScope (défaut)'),

  /// Binding GetX + get_it (`ZcrudGetScope`) — cible DODLP.
  get('GetX'),

  /// Binding Riverpod (`ZcrudRiverpodScope`) — cible lex_douane/IFFD.
  riverpod('Riverpod'),

  /// Binding provider (`ZcrudProviderScope`).
  provider('provider');

  const DemoBinding(this.label);

  /// Libellé humain pour le sélecteur.
  final String label;
}

/// Enveloppe [child] dans le scope d'injection du [binding] choisi. Le code
/// spécifique à un manager (get/riverpod/provider) est confiné ICI ; le
/// sous-arbre [child] est IDENTIQUE sous les quatre voies (invariant AD-15).
///
/// MEDIUM-1 (code-review EX-1) : le `ZcrudScope` INTERNE d'un binding ne
/// forwarde que `resolver`/`acl` — il MASQUE donc les seams applicatifs
/// (`filePicker`/`theme`/`labels`/`listRenderer`/…) fournis par le `ZcrudScope`
/// racine (`maybeOf` = plus proche seulement). Sans re-propagation, les familles
/// file/image/document seraient inertes sous get/riverpod/provider. On passe
/// [rootScope] (capté sous le scope racine par l'appelant) et on RE-DÉCLARE ces
/// seams SOUS le scope du binding via [_BindingSeamForwarder], en conservant le
/// `resolver`/`acl` que le binding vient d'injecter.
Widget wrapWithBinding(
  DemoBinding binding,
  Widget child, {
  ZcrudScope? rootScope,
}) {
  Widget forward(Widget inner) =>
      rootScope == null ? inner : _BindingSeamForwarder(root: rootScope, child: inner);
  switch (binding) {
    case DemoBinding.scope:
      // `ZcrudScope` racine (thème/l10n/filePicker) est déjà fourni au-dessus
      // par l'app ; le mode « défaut » n'ajoute aucun manager.
      return child;
    case DemoBinding.get:
      return ZcrudGetScope(child: forward(child));
    case DemoBinding.riverpod:
      return ZcrudRiverpodScope(child: forward(child));
    case DemoBinding.provider:
      return ZcrudProviderScope(child: forward(child));
  }
}

/// Re-déclare, SOUS le `ZcrudScope` du binding, les seams applicatifs du scope
/// racine ([root]) que ce scope interne aurait masqués — tout en conservant le
/// `resolver`/`acl` que le binding vient d'injecter (lus via `ZcrudScope.of`).
/// Ainsi `filePicker`/`theme`/`labels`/`listRenderer`/… restent disponibles pour
/// [child] quelle que soit la voie d'injection (parité AD-15 complète, MEDIUM-1).
class _BindingSeamForwarder extends StatelessWidget {
  const _BindingSeamForwarder({required this.root, required this.child});

  final ZcrudScope root;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Scope interne du binding : porte le resolver/acl manager-backed.
    final bound = ZcrudScope.of(context);
    return ZcrudScope(
      resolver: bound.resolver,
      acl: bound.acl,
      // Seams applicatifs ré-hérités du scope racine (sinon masqués).
      labels: root.labels,
      theme: root.theme,
      widgetRegistry: root.widgetRegistry,
      filePicker: root.filePicker,
      cloudStorage: root.cloudStorage,
      listRenderer: root.listRenderer,
      child: child,
    );
  }
}

/// Sélecteur segmenté de [DemoBinding].
class BindingSelector extends StatelessWidget {
  /// Construit le sélecteur pour la valeur [value].
  const BindingSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Binding actuellement actif.
  final DemoBinding value;

  /// Notifié au changement de binding.
  final ValueChanged<DemoBinding> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12, vertical: 8),
      child: SegmentedButton<DemoBinding>(
        segments: <ButtonSegment<DemoBinding>>[
          for (final b in DemoBinding.values)
            ButtonSegment<DemoBinding>(value: b, label: Text(b.label)),
        ],
        selected: <DemoBinding>{value},
        onSelectionChanged: (selection) => onChanged(selection.first),
        showSelectedIcon: false,
      ),
    );
  }
}
