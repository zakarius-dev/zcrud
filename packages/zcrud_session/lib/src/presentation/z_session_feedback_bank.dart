/// Banques de messages de feedback **FR/EN par défaut**, **surchargeables
/// INTÉGRALEMENT** (SU-5, AC5 — FR-SU9/NFR-SU4).
///
/// ## 🔴 D5 — pourquoi la banque vit ICI et non dans `zcrud_core`
///
/// Contrainte DURE : les tables `_frLabels`/`_enLabels` du cœur
/// (`zcrud_core/lib/src/presentation/l10n/z_localizations.dart`) sont **fermées
/// et hors périmètre** de cette story (le PRD réserve l'écriture de `zcrud_core`
/// à E-MULTI-EDIT). Or le patron `label(context, key, fallback:)` ne porte
/// qu'**UNE** langue de repli, alors que FR-SU9 exige **FR *et* EN par défaut**.
/// La banque embarque donc **ses deux tables** dans `zcrud_session`.
///
/// ## Chaîne de résolution — le scope de l'app garde la PRIORITÉ
///
/// `label()` compose (vérifié sur disque, `z_localizations.dart:288`) :
/// `ZcrudScope.labels` → table de la locale (delegate) → `_enLabels` du cœur →
/// `fallback`. Les clés `zcrud.session.feedback.*` étant **absentes du cœur**
/// (grep **RC=1** — espace de clés libre), le texte rendu par défaut est bien
/// celui de **notre** banque ; et une app qui injecte `ZcrudScope(labels:)`
/// **gagne** — sans que cette story ne touche au cœur.
///
/// ## Portée de la garde de libellés (lue — ne pas la « corriger » à tort)
///
/// `z_widgets_hardcode_scan_test.dart` vise les **puits RÉELLEMENT RENDUS**
/// (1ᵉʳ argument de `Text(`, `errorText:`, `semanticLabel:`…). Les littéraux de
/// ce fichier sont des **valeurs de map** (`'zcrud.…': 'Bravo !'`) — **pas** un
/// puits de rendu — et `fallback:` est le patron **SANCTIONNÉ**. La garde ne
/// rougit donc pas ici, et **il n'y a rien à y taire** : on ne la modifie pas.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Banque de messages de feedback : **clé l10n → texte**, par `languageCode`.
///
/// Slot de **surcharge INTÉGRALE** (FR-SU9/AC5) : une banque injectée
/// **REMPLACE** la banque par défaut — elle ne s'y superpose pas. Une app qui
/// n'en fournit qu'une partie ne « complète » donc pas [ZDefaultFeedbackBank] :
/// c'est délibéré (une banque hybride rendrait un mélange de tons imprévisible).
abstract class ZFeedbackBank {
  /// Résout le texte de [key] pour [languageCode], ou `null` si absent.
  ///
  /// **Jamais de throw** (AD-10) : une clé inconnue rend `null`, et l'appelant
  /// retombe sur la chaîne de `label()`.
  String? maybeResolve(String key, String languageCode);
}

/// Banque par défaut **FR/EN**, EMBARQUÉE dans `zcrud_session` (D5).
///
/// Couvre les 4 seaux de `ZFeedbackTier` (`motivation`/`neutral`/
/// `encouragement`/`exceptional`) dans les deux langues. Locale inconnue →
/// repli **EN** (jamais une clé brute, jamais une exception).
class ZDefaultFeedbackBank implements ZFeedbackBank {
  /// Construit la banque par défaut (`const` : aucun état).
  const ZDefaultFeedbackBank();

  /// Messages **français** (`languageCode: 'fr'`).
  static const Map<String, String> _fr = <String, String>{
    'zcrud.session.feedback.motivation':
        'Ne lâchez rien — c\'est en butant sur une carte qu\'on l\'apprend.',
    'zcrud.session.feedback.neutral':
        'Bonne réponse. Encore un tour et elle sera acquise.',
    'zcrud.session.feedback.encouragement':
        'Bravo, cette carte est maîtrisée !',
    'zcrud.session.feedback.exceptional':
        'Exceptionnel — juste, sans indice et en un éclair !',
  };

  /// Messages **anglais** (`languageCode: 'en'`) — aussi le **repli** de toute
  /// locale inconnue.
  static const Map<String, String> _en = <String, String>{
    'zcrud.session.feedback.motivation':
        'Keep going — a card you stumble on is a card you are learning.',
    'zcrud.session.feedback.neutral':
        'Correct. One more round and it will stick.',
    'zcrud.session.feedback.encouragement': 'Well done, this card is mastered!',
    'zcrud.session.feedback.exceptional':
        'Outstanding — right, hint-free and in a flash!',
  };

  /// Tables par `languageCode` (baseline `fr`/`en`, comme le cœur).
  static const Map<String, Map<String, String>> _tables =
      <String, Map<String, String>>{'fr': _fr, 'en': _en};

  @override
  String? maybeResolve(String key, String languageCode) =>
      (_tables[languageCode] ?? _en)[key];
}

/// Résout le **texte** d'une clé de feedback pour le contexte courant (AC5).
///
/// - [bank] **injectée** ⇒ elle **REMPLACE INTÉGRALEMENT** la banque par défaut
///   (`bank ?? const ZDefaultFeedbackBank()` — jamais une fusion) ;
/// - la langue vient de `Localizations.localeOf(context).languageCode` ;
/// - le tout est passé en `fallback:` de `label()` ⇒ `ZcrudScope.labels` de
///   l'app **prime** (chaîne de composition du cœur).
///
/// Une clé absente **de partout** rend la chaîne vide (jamais la clé brute :
/// afficher `zcrud.session.feedback.neutral` à un apprenant serait pire que
/// rien) — AD-10, jamais de throw.
String zFeedbackText(
  BuildContext context,
  String key, {
  ZFeedbackBank? bank,
}) {
  final resolved = bank ?? const ZDefaultFeedbackBank();
  final languageCode = Localizations.localeOf(context).languageCode;
  return label(context, key, fallback: resolved.maybeResolve(key, languageCode) ?? '');
}

/// Rend le message de feedback d'une clé — widget PUR (AD-2/AD-15).
///
/// Le message est un **`Text` nu** : il porte sa sémantique **implicite**, et
/// c'est **délibéré**. Un `Semantics(label:)` explicite par-dessus
/// **FUSIONNERAIT** avec le `Text` enfant et ferait annoncer le message DEUX
/// fois — le défaut exact mesuré sur `_StatTile` et `_ActionButton` (code-review
/// su-5, D1). Le texte reste le canal — jamais la couleur seule (AD-13).
///
/// Rien n'est rendu si la clé ne résout nulle part (chaîne vide) : un nœud vide
/// serait annoncé « en blanc » par un lecteur d'écran.
///
/// ⚠️ **Rectification (code-review su-5)** : ce dartdoc promettait un
/// « `Semantics` explicite » que le `build` ne rend pas. **Le code avait raison,
/// la prose avait tort** — c'est la prose qui est corrigée.
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

  /// Banque **injectée** — remplace INTÉGRALEMENT la banque par défaut (AC5).
  final ZFeedbackBank? bank;

  /// Alignement du message (directionnel : `start`/`end` seuls — AD-13).
  final TextAlign textAlign;

  /// [ValueKey] du texte rendu (testabilité, AC5).
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
