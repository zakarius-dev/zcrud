/// `ZMarkdownCodecScope` — défaut d'app pour le [ZCodec] du rich-text (AC4).
///
/// InheritedWidget **LOCAL à `zcrud_markdown`** (JAMAIS via `ZcrudScope`/core :
/// le concept Delta/Markdown/HTML reste cantonné au package rich-text — AD-1).
/// Permet à une app de fixer un codec par défaut pour tous les `ZMarkdownField`
/// d'un sous-arbre, sans le passer champ par champ.
library;

import 'package:flutter/widgets.dart';

import '../domain/z_codec.dart';

/// Fournit le [ZCodec] par défaut aux [ZMarkdownField] descendants.
///
/// Précédence effective dans le champ : `paramètre du champ` >
/// `ZMarkdownCodecScope` > `ZDeltaCodec()`.
///
/// STABILITÉ AU MONTAGE (LOW-1) : chaque [ZMarkdownField] résout son codec UNE
/// FOIS en `initState` (config de persistance statique, SANS dépendance à
/// l'inherited widget). Changer [codec] à CHAUD ne re-seede donc PAS les champs
/// DÉJÀ montés (leur tranche de travail prime) : fournir un codec STABLE sur la
/// durée de vie du sous-arbre, ou remonter les champs (nouvelle `key`) pour un
/// changement effectif.
class ZMarkdownCodecScope extends InheritedWidget {
  /// Diffuse [codec] à tout le sous-arbre [child].
  const ZMarkdownCodecScope({
    required this.codec,
    required super.child,
    super.key,
  });

  /// Codec par défaut hérité par les champs descendants.
  final ZCodec codec;

  /// Retourne le [ZCodec] hérité le plus proche, ou `null` si aucun.
  static ZCodec? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ZMarkdownCodecScope>()
      ?.codec;

  /// Retourne le [ZCodec] hérité le plus proche ; lève une [FlutterError]
  /// DESCRIPTIVE si absent (LOW-2 : jamais un « Null check operator » opaque en
  /// release, où les `assert` sont désactivés).
  static ZCodec of(BuildContext context) {
    final codec = maybeOf(context);
    if (codec == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Aucun ZMarkdownCodecScope trouvé dans le contexte.'),
        ErrorDescription(
          'ZMarkdownCodecScope.of() a été appelé avec un contexte qui ne '
          'descend d\'aucun ZMarkdownCodecScope.',
        ),
        ErrorHint(
          'Enveloppez le sous-arbre dans un ZMarkdownCodecScope, ou utilisez '
          'ZMarkdownCodecScope.maybeOf(context) qui retourne null sans lever.',
        ),
      ]);
    }
    return codec;
  }

  @override
  bool updateShouldNotify(ZMarkdownCodecScope oldWidget) =>
      codec != oldWidget.codec;
}
