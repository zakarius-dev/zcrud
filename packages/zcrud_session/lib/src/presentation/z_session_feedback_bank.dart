/// Banques de messages de feedback FR/EN par défaut, surchargeables
/// intégralement.
///
/// ## Pourquoi la banque vit ici et non dans `zcrud_core`
///
/// Les tables de libellés du cœur (`zcrud_core`) sont fermées et hors
/// périmètre de ce paquet. Or le patron `label(context, key, fallback:)` ne
/// porte qu'une seule langue de repli, alors que ce paquet veut couvrir le
/// français et l'anglais par défaut. La banque embarque donc ses deux
/// tables directement dans `zcrud_session`.
///
/// ## Chaîne de résolution — le scope de l'application garde la priorité
///
/// `label()` compose : `ZcrudScope.labels` → table de la locale (delegate)
/// → table anglaise du cœur → `fallback`. Les clés `zcrud.session.feedback.*`
/// étant absentes du cœur (espace de clés propre à ce paquet), le texte
/// rendu par défaut est bien celui de cette banque ; et une application qui
/// injecte `ZcrudScope(labels:)` gagne, sans que ce paquet ne touche au
/// cœur.
///
/// ## Portée de la garde de libellés
///
/// La garde anti-libellé-en-dur du paquet vise les puits réellement rendus
/// (premier argument de `Text(`, `errorText:`, `semanticLabel:`…). Les
/// littéraux de ce fichier sont des valeurs de map (`'zcrud.…': 'Bravo !'`),
/// pas un puits de rendu, et `fallback:` est le patron attendu ici.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Banque de messages de feedback : clé l10n → texte, par `languageCode`.
///
/// Slot de surcharge intégrale : une banque injectée remplace la banque par
/// défaut, elle ne s'y superpose pas. Une application qui n'en fournit
/// qu'une partie ne « complète » donc pas [ZDefaultFeedbackBank] — c'est
/// délibéré, une banque hybride rendrait un mélange de tons imprévisible.
abstract class ZFeedbackBank {
  /// Résout le texte de [key] pour [languageCode], ou `null` si absent.
  ///
  /// Jamais de `throw` (invariant AD-10) : une clé inconnue rend `null`, et
  /// l'appelant retombe sur la chaîne de `label()`.
  String? maybeResolve(String key, String languageCode);
}

/// Banque par défaut FR/EN, embarquée dans `zcrud_session`.
///
/// Couvre **tous** les seaux de `ZFeedbackTier` (`motivation`/`neutral`/
/// `encouragement`/`exceptional`/`skipped`) dans les deux langues. Locale
/// inconnue → repli anglais (jamais une clé brute, jamais une exception).
class ZDefaultFeedbackBank implements ZFeedbackBank {
  /// Construit la banque par défaut (`const` : aucun état).
  const ZDefaultFeedbackBank();

  /// Messages français (`languageCode: 'fr'`).
  static const Map<String, String> _fr = <String, String>{
    'zcrud.session.feedback.motivation':
        'Ne lâchez rien — c\'est en butant sur une carte qu\'on l\'apprend.',
    'zcrud.session.feedback.neutral':
        'Bonne réponse. Encore un tour et elle sera acquise.',
    'zcrud.session.feedback.encouragement':
        'Bravo, cette carte est maîtrisée !',
    'zcrud.session.feedback.exceptional':
        'Exceptionnel — juste, sans indice et en un éclair !',
    // Ton distinct de `motivation` : la carte n'a pas été ratée, elle n'a pas
    // été tentée. Reprocher une erreur à qui n'a rien répondu serait faux.
    'zcrud.session.feedback.skipped':
        'Carte passée — vous la reverrez bientôt, sans pénalité de plus.',
  };

  /// Messages anglais (`languageCode: 'en'`) — aussi le repli de toute
  /// locale inconnue.
  static const Map<String, String> _en = <String, String>{
    'zcrud.session.feedback.motivation':
        'Keep going — a card you stumble on is a card you are learning.',
    'zcrud.session.feedback.neutral':
        'Correct. One more round and it will stick.',
    'zcrud.session.feedback.encouragement': 'Well done, this card is mastered!',
    'zcrud.session.feedback.exceptional':
        'Outstanding — right, hint-free and in a flash!',
    'zcrud.session.feedback.skipped':
        'Card skipped — it will come back soon, no extra penalty.',
  };

  /// Tables par `languageCode` (baseline `fr`/`en`, comme le cœur).
  static const Map<String, Map<String, String>> _tables =
      <String, Map<String, String>>{'fr': _fr, 'en': _en};

  @override
  String? maybeResolve(String key, String languageCode) =>
      (_tables[languageCode] ?? _en)[key];
}

/// Résout le texte d'une clé de feedback pour le contexte courant.
///
/// - [bank] injectée : elle remplace intégralement la banque par défaut
///   (`bank ?? const ZDefaultFeedbackBank()`, jamais une fusion) ;
/// - la langue vient de `Localizations.localeOf(context).languageCode` ;
/// - le tout est passé en `fallback:` de `label()`, si bien que
///   `ZcrudScope.labels` de l'application garde la priorité.
///
/// Une clé absente de partout rend la chaîne vide (jamais la clé brute :
/// afficher `zcrud.session.feedback.neutral` à un apprenant serait pire que
/// rien) — invariant AD-10, jamais de `throw`.
String zFeedbackText(
  BuildContext context,
  String key, {
  ZFeedbackBank? bank,
}) {
  final resolved = bank ?? const ZDefaultFeedbackBank();
  final languageCode = Localizations.localeOf(context).languageCode;
  return label(context, key, fallback: resolved.maybeResolve(key, languageCode) ?? '');
}

/// Rend le message de feedback d'une clé — widget pur (invariants AD-2/AD-15).
///
/// Le message est un `Text` nu : il porte sa sémantique implicite, et c'est
/// délibéré. Un `Semantics(label:)` explicite par-dessus fusionnerait avec
/// le `Text` enfant et ferait annoncer le message deux fois. Le texte reste
/// le canal — jamais la couleur seule (invariant AD-13).
///
/// Rien n'est rendu si la clé ne résout nulle part (chaîne vide) : un nœud
/// vide serait annoncé « en blanc » par un lecteur d'écran.
class ZSessionFeedbackText extends StatelessWidget {
  /// Construit le message de [feedbackKey], résolu via [bank] (ou la banque par
  /// défaut) puis par la chaîne de `label()`.
  const ZSessionFeedbackText({
    required this.feedbackKey,
    this.bank,
    this.textAlign = TextAlign.start,
    super.key,
  });

  /// Clé l10n du message (= `zFeedbackKeyFor(tier)`).
  final String feedbackKey;

  /// Banque injectée — remplace intégralement la banque par défaut.
  final ZFeedbackBank? bank;

  /// Alignement du message (directionnel : `start`/`end` seuls, invariant
  /// AD-13).
  final TextAlign textAlign;

  /// [ValueKey] du texte rendu, pour la testabilité.
  static const ValueKey<String> textKey =
      ValueKey<String>('zSessionFeedbackText');

  @override
  Widget build(BuildContext context) {
    final text = zFeedbackText(context, feedbackKey, bank: bank);
    if (text.isEmpty) return const SizedBox.shrink();
    return Text(
      text,
      key: textKey,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
