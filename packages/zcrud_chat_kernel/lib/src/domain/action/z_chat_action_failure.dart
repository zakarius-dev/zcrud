/// L'**unique** failure créée par CHAT-0b (décision **D9**).
///
/// 🚫 Aucune autre failure n'est déclarée dans ce dossier. Les besoins déjà
/// couverts sont **réutilisés**, jamais redéclarés (garde **G-R2**) :
///
/// | Besoin | Type EXISTANT |
/// |---|---|
/// | Quota IA dépassé | `ZQuotaExceededFailure` (+ `retryAfter`) |
/// | Verbe non supporté par l'hôte | `ZUnsupportedOperationFailure(operation:)` |
/// | Règle métier violée | `ZDomainFailure` |
///
/// Les familles d'erreurs IA (modération, contexte trop long, réponse vide,
/// modèle indisponible) et le mapping status-code → `ZFailure` appartiennent à
/// **CHAT-1**.
library;

import 'package:zcrud_core/domain.dart';

/// L'action **exigeait** une confirmation et ne l'a pas obtenue : l'exécution
/// est **refusée**, l'executor n'a **pas** été touché.
///
/// ## Pourquoi un type dédié plutôt qu'un `ZDomainFailure` nu
///
/// Le dartdoc de `ZQuotaExceededFailure` et de `ZUnsupportedOperationFailure`
/// nomme le défaut à ne pas rejouer : aplatir une distinction dans le `message`
/// force l'hôte à **parser du texte** pour décider. Or « refusé faute de
/// confirmation » et « échec pour une panne » appellent **deux réactions
/// opposées** — rouvrir le dialogue de confirmation *vs* remonter l'erreur.
/// [verb] permet le diagnostic sans parsing.
class ZChatActionNotConfirmedFailure extends ZFailure {
  /// Construit le refus, en nommant le [verb] refusé.
  const ZChatActionNotConfirmedFailure({required this.verb})
      : super('chat action requires an explicit user confirmation');

  /// Verbe technique refusé (ex. `'delete'`).
  final String verb;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZChatActionNotConfirmedFailure &&
          other.message == message &&
          other.verb == verb;

  @override
  int get hashCode => Object.hash(runtimeType, message, verb);

  @override
  String toString() =>
      'ZChatActionNotConfirmedFailure($message, verb: $verb)';
}
