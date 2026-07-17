/// 🎯 AC5 (SU-5) — banques **FR/EN par défaut**, **surchargeables intégralement**
/// (FR-SU9/NFR-SU4).
///
/// 🔴 **Interdit ici** (défaut « preuve creuse » de su-4) : assérer
/// `text.isNotEmpty` **seul**. Cette assertion serait **vraie quoi qu'il
/// arrive** — y compris si les deux locales rendaient le **même** texte anglais,
/// ce qui est précisément le défaut que FR-SU9 interdit. On assère donc le
/// **texte ATTENDU** (littéral, écrit à la main) **et** la **différence FR≠EN**.
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_session/zcrud_session.dart';

/// Monte le message sous une locale donnée, **avec le delegate du cœur** (comme
/// en prod : c'est lui qui rend `Localizations.localeOf` significatif).
///
/// ⚠️ **Écart de harnais MESURÉ, consigné.** Le premier jet montait un
/// `MaterialApp(locale: Locale('fr'))` — le patron `wrapApp` du repo. Il
/// **échoue** : `DefaultMaterialLocalizations.delegate` ne supporte **que
/// `en`**, et `MaterialApp` lève « This application's locale, fr, is not
/// supported by all of its localization delegates ». C'était bien le **HARNAIS**
/// qui avait tort, jamais le code (mesuré : le même widget rend correctement le
/// FR sous `Localizations`). On monte donc `Localizations` **directement** — la
/// primitive EXACTE de contrôle de locale — plutôt que d'affaiblir le test pour
/// contourner l'erreur.
Future<void> _pumpIn(
  WidgetTester tester,
  String languageCode, {
  required String feedbackKey,
  ZFeedbackBank? bank,
  ZcrudLabels? scopeLabels,
}) async {
  Widget tree = Localizations(
    locale: Locale(languageCode),
    delegates: const <LocalizationsDelegate<dynamic>>[
      ZcrudLocalizationsDelegate(),
      DefaultWidgetsLocalizations.delegate,
    ],
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Material(
        child: ZSessionFeedbackText(feedbackKey: feedbackKey, bank: bank),
      ),
    ),
  );
  if (scopeLabels != null) {
    tree = ZcrudScope(labels: scopeLabels, child: tree);
  }
  await tester.pumpWidget(tree);
  await tester.pump();
}

/// Lit le texte **RÉELLEMENT RENDU** (jamais une valeur déduite de la banque).
String _renderedText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(ZSessionFeedbackText.textKey)).data!;

/// Banque témoin : **elle seule** doit parler quand elle est injectée.
class _WitnessBank implements ZFeedbackBank {
  const _WitnessBank();

  /// Texte témoin — introuvable dans la banque par défaut, dans les deux sens.
  static const String text = 'TÉMOIN-SURCHARGE';

  @override
  String? maybeResolve(String key, String languageCode) => text;
}

/// Banque témoin **partielle** : ne connaît AUCUNE clé (`null` partout).
class _EmptyBank implements ZFeedbackBank {
  const _EmptyBank();

  @override
  String? maybeResolve(String key, String languageCode) => null;
}

void main() {
  final String neutralKey = zFeedbackKeyFor(ZFeedbackTier.neutral);
  final String exceptionalKey = zFeedbackKeyFor(ZFeedbackTier.exceptional);

  group('🎯 AC5 — FR et EN rendent leur PROPRE texte (jamais le même)', () {
    testWidgets('🔴 `fr` rend le texte FRANÇAIS attendu (littéral)',
        (tester) async {
      await _pumpIn(tester, 'fr', feedbackKey: neutralKey);
      expect(
        _renderedText(tester),
        'Bonne réponse. Encore un tour et elle sera acquise.',
        reason: '🔴 attendu LITTÉRAL : jamais `isNotEmpty`, jamais une valeur '
            'relue de la banque (le test s\'appellerait lui-même)',
      );
    });

    testWidgets('🔴 `en` rend le texte ANGLAIS attendu (littéral)',
        (tester) async {
      await _pumpIn(tester, 'en', feedbackKey: neutralKey);
      expect(
        _renderedText(tester),
        'Correct. One more round and it will stick.',
      );
    });

    testWidgets(
        '🎯 R3 — les deux locales rendent des textes DIFFÉRENTS et non vides',
        (tester) async {
      await _pumpIn(tester, 'fr', feedbackKey: neutralKey);
      final fr = _renderedText(tester);
      await _pumpIn(tester, 'en', feedbackKey: neutralKey);
      final en = _renderedText(tester);

      expect(fr, isNotEmpty);
      expect(en, isNotEmpty);
      expect(
        fr,
        isNot(en),
        reason: '🔴 R3 : si la banque FR devient IDENTIQUE à EN, ce test '
            'ROUGIT. FR-SU9 exige FR *et* EN par défaut — une banque qui ne '
            'parle qu\'anglais serait « verte » sous un simple `isNotEmpty`',
      );
    });

    testWidgets('les 4 seaux ont un texte FR ET un texte EN, tous DISTINCTS',
        (tester) async {
      final fr = <String>[];
      final en = <String>[];
      for (final tier in ZFeedbackTier.values) {
        await _pumpIn(tester, 'fr', feedbackKey: zFeedbackKeyFor(tier));
        fr.add(_renderedText(tester));
        await _pumpIn(tester, 'en', feedbackKey: zFeedbackKeyFor(tier));
        en.add(_renderedText(tester));
      }
      // Aucun seau muet, aucune traduction oubliée…
      expect(fr.where((t) => t.isEmpty), isEmpty);
      expect(en.where((t) => t.isEmpty), isEmpty);
      // …aucune langue recopiée sur l'autre…
      for (var i = 0; i < fr.length; i++) {
        expect(fr[i], isNot(en[i]),
            reason: 'le seau ${ZFeedbackTier.values[i].name} rend le MÊME '
                'texte en FR et en EN');
      }
      // …et aucun message recopié d'un seau à l'autre (4 messages distincts :
      // un feedback qui ne varie pas avec le seau n'est pas un feedback).
      expect(fr.toSet(), hasLength(ZFeedbackTier.values.length));
      expect(en.toSet(), hasLength(ZFeedbackTier.values.length));
    });

    testWidgets('une locale INCONNUE retombe sur EN (jamais la clé brute)',
        (tester) async {
      await _pumpIn(tester, 'de', feedbackKey: neutralKey);
      expect(_renderedText(tester), 'Correct. One more round and it will stick.');
    });
  });

  group('🎯 AC5 — une banque injectée SURCHARGE INTÉGRALEMENT', () {
    testWidgets('🔴 la banque témoin parle SEULE — en `fr` comme en `en`',
        (tester) async {
      for (final lang in <String>['fr', 'en']) {
        await _pumpIn(
          tester,
          lang,
          feedbackKey: neutralKey,
          bank: const _WitnessBank(),
        );
        expect(
          _renderedText(tester),
          _WitnessBank.text,
          reason: '🔴 en `$lang`, la banque par DÉFAUT parle encore ⇒ la '
              'surcharge n\'est pas INTÉGRALE (AC5)',
        );
      }
    });

    testWidgets(
        '🔴 la surcharge REMPLACE, elle ne COMPLÈTE pas : une banque qui ne '
        'connaît AUCUNE clé ne laisse PAS reparler le défaut', (tester) async {
      await _pumpIn(
        tester,
        'fr',
        feedbackKey: neutralKey,
        bank: const _EmptyBank(),
      );
      // Rien à rendre ⇒ aucun texte (et surtout PAS le message français par
      // défaut : ce serait une fusion, pas un remplacement).
      expect(find.byKey(ZSessionFeedbackText.textKey), findsNothing);
    });

    testWidgets('la banque témoin surcharge TOUS les seaux', (tester) async {
      for (final tier in ZFeedbackTier.values) {
        await _pumpIn(
          tester,
          'fr',
          feedbackKey: zFeedbackKeyFor(tier),
          bank: const _WitnessBank(),
        );
        expect(_renderedText(tester), _WitnessBank.text);
      }
    });
  });

  group('🎯 AC5 — `ZcrudScope.labels` de l\'APP garde la PRIORITÉ', () {
    testWidgets(
        '🔒 un libellé injecté au scope l\'emporte sur la banque par défaut',
        (tester) async {
      await _pumpIn(
        tester,
        'fr',
        feedbackKey: neutralKey,
        scopeLabels: ZcrudLabels(<String, String>{
          'zcrud.session.feedback.neutral': 'LIBELLÉ DU SCOPE',
        }),
      );
      expect(
        _renderedText(tester),
        'LIBELLÉ DU SCOPE',
        reason: '🔴 la chaîne de `label()` doit rester : scope → locale → en → '
            'fallback(banque). Passer la banque AILLEURS qu\'en `fallback:` '
            'volerait la priorité à l\'app',
      );
    });

    testWidgets('une clé NON surchargée au scope garde le texte de la banque',
        (tester) async {
      await _pumpIn(
        tester,
        'fr',
        feedbackKey: exceptionalKey,
        scopeLabels: ZcrudLabels(<String, String>{
          'zcrud.session.feedback.neutral': 'LIBELLÉ DU SCOPE',
        }),
      );
      expect(
        _renderedText(tester),
        'Exceptionnel — juste, sans indice et en un éclair !',
      );
    });
  });

  group('🎯 AC5/AD-10 — robustesse : jamais de throw, jamais de clé brute', () {
    testWidgets('une clé INCONNUE ne rend RIEN (jamais la clé technique)',
        (tester) async {
      await _pumpIn(tester, 'fr', feedbackKey: 'zcrud.session.feedback.inconnu');
      expect(find.byKey(ZSessionFeedbackText.textKey), findsNothing);
      expect(find.textContaining('zcrud.session.'), findsNothing,
          reason: 'afficher une clé technique à un apprenant serait pire que '
              'de ne rien afficher');
      expect(tester.takeException(), isNull);
    });

    test('la banque par défaut ne throw sur aucune entrée (AD-10)', () {
      const bank = ZDefaultFeedbackBank();
      for (final lang in <String>['fr', 'en', 'de', '', 'zz']) {
        expect(() => bank.maybeResolve('zcrud.session.feedback.neutral', lang),
            returnsNormally);
        expect(() => bank.maybeResolve('clé.absente', lang), returnsNormally);
      }
      expect(bank.maybeResolve('clé.absente', 'fr'), isNull);
    });
  });
}
