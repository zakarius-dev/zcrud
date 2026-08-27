// Les deux PORTS du composer avancé : mesure du texte, persistance du
// brouillon. Trois propriétés, et rien d'autre :
//   (1) 🔴 les ports sont INERTES par défaut — aucune implémentation ⇒ rien
//       ne lève, rien n'est approximé, aucun chemin d'exception à écrire ;
//   (2) le socle NE COMPTE PAS : sans port, la mesure vaut `null`, jamais 0 ;
//   (3) une mesure est un CONSTAT, jamais un refus (AD-5 : absence ≠ panne).
//
// R3 (rouge par ASSERTION) :
//  • faire compter `text.length` au port inerte ⇒ (2) rougit ;
//  • faire rendre un `Left` au store inerte sur `read` ⇒ (1) rougit ;
//  • borner `remaining` à 0 ⇒ (3) rougit ;
//  • conserver un brouillon vide en mémoire ⇒ la garde d'effacement rougit.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('ZChatTextMeasurePort — le socle ne compte pas, il demande', () {
    test('🔴 sans port, la mesure vaut `null` — jamais un chiffre approximatif',
        () {
      const ZChatTextMeasurePort port = ZChatUnavailableTextMeasure();
      expect(port.measure(''), isNull);
      expect(port.measure('un texte de quarante et quelques caracteres'),
          isNull,
          reason: 'un compteur branché ici doit rester MUET, pas afficher 0');
    });

    test('la mesure rend ce que le port a dit, unité comprise', () {
      final ZChatTextMeasurement m = _FixedMeasure(units: 120, limit: 1000)
          .measure('peu importe')!;
      expect(m.units, 120);
      expect(m.unitKey, 'tokens');
      expect(m.limit, 1000);
      expect(m.hasLimit, isTrue);
      expect(m.remaining, 880);
      expect(m.isOverLimit, isFalse);
    });

    test('sans plafond déclaré, le socle n\'en invente aucun', () {
      final ZChatTextMeasurement m = ZChatTextMeasurement(units: 42);
      expect(m.limit, isNull);
      expect(m.hasLimit, isFalse);
      expect(m.remaining, isNull, reason: 'pas de plafond ⇒ pas de reste');
      expect(m.isOverLimit, isFalse);
      expect(m.unitKey, isNull);
    });

    test('🔴 un dépassement est un CONSTAT : le reste devient négatif et le '
        'socle ne refuse rien', () {
      final ZChatTextMeasurement m =
          ZChatTextMeasurement(units: 1200, limit: 1000);
      expect(m.isOverLimit, isTrue);
      expect(m.remaining, -200,
          reason: 'le dépassement est MESURÉ, pas écrasé à 0');
      // Exactement au plafond : pas de dépassement.
      expect(ZChatTextMeasurement(units: 1000, limit: 1000).isOverLimit,
          isFalse);
    });

    test('valeurs aberrantes d\'un port fautif : repli, jamais d\'exception',
        () {
      final ZChatTextMeasurement negatif =
          ZChatTextMeasurement(units: -5, limit: -1);
      expect(negatif.units, 0, reason: 'repli documenté');
      expect(negatif.limit, isNull, reason: 'plafond négatif ⇒ absent');
      expect(negatif.remaining, isNull);
      expect(negatif.isOverLimit, isFalse);
    });

    test('égalité par VALEUR (une mesure relue est la même mesure)', () {
      expect(ZChatTextMeasurement(units: 3, unitKey: 'w', limit: 9),
          ZChatTextMeasurement(units: 3, unitKey: 'w', limit: 9));
      expect(ZChatTextMeasurement(units: 3), isNot(ZChatTextMeasurement(units: 4)));
    });
  });

  group('ZChatDraftStore — le socle ne persiste pas, il délègue', () {
    test('🔴 le store inerte ne conserve rien et n\'échoue JAMAIS', () async {
      const ZChatDraftStore store = ZChatNullDraftStore();
      final ZResult<ZChatDraft?> lu = await store.read('c1');
      expect(lu.isRight(), isTrue, reason: 'absence ≠ panne (AD-5)');
      expect(lu.getOrElse(() => const ZChatDraft(text: 'sentinelle')), isNull);
      expect((await store.write('c1', const ZChatDraft(text: 'x'))).isRight(),
          isTrue);
      expect((await store.read('c1')).getOrElse(
              () => const ZChatDraft(text: 'sentinelle')),
          isNull,
          reason: 'écrire dans l\'inerte reste sans effet, sans erreur');
      expect((await store.clear('c1')).isRight(), isTrue);
    });

    test('effacer ce qui n\'existe pas RÉUSSIT', () async {
      final ZChatInMemoryDraftStore store = ZChatInMemoryDraftStore();
      expect((await store.clear('jamais-vue')).isRight(), isTrue);
      expect((await store.read('jamais-vue'))
              .getOrElse(() => const ZChatDraft(text: 'sentinelle')),
          isNull);
    });

    test('mémoire : aller-retour cloisonné par conversation', () async {
      final ZChatInMemoryDraftStore store = ZChatInMemoryDraftStore();
      const ZChatDraft a =
          ZChatDraft(text: 'bonjour', attachmentIds: <String>['p1']);
      const ZChatDraft b = ZChatDraft(text: 'autre');
      await store.write('c1', a);
      await store.write('c2', b);
      expect((await store.read('c1'))
          .getOrElse(() => const ZChatDraft()), a);
      expect((await store.read('c2'))
          .getOrElse(() => const ZChatDraft()), b);
      await store.clear('c1');
      expect((await store.read('c1'))
              .getOrElse(() => const ZChatDraft(text: 'sentinelle')),
          isNull);
      expect((await store.read('c2'))
          .getOrElse(() => const ZChatDraft()), b,
          reason: 'l\'effacement de c1 ne touche pas c2');
    });

    test('un brouillon VIDE efface : une saisie effacée ne ressuscite pas',
        () async {
      final ZChatInMemoryDraftStore store = ZChatInMemoryDraftStore();
      await store.write('c1', const ZChatDraft(text: 'tape puis efface'));
      await store.write('c1', const ZChatDraft());
      expect((await store.read('c1'))
              .getOrElse(() => const ZChatDraft(text: 'sentinelle')),
          isNull);
      // Un brouillon sans texte mais AVEC pièce jointe reste un brouillon.
      await store.write('c1', const ZChatDraft(attachmentIds: <String>['p1']));
      expect((await store.read('c1'))
              .getOrElse(() => const ZChatDraft())!
              .attachmentIds,
          <String>['p1']);
    });
  });
}

class _FixedMeasure implements ZChatTextMeasurePort {
  _FixedMeasure({required this.units, this.limit});
  final int units;
  final int? limit;

  @override
  ZChatTextMeasurement? measure(String text) =>
      ZChatTextMeasurement(units: units, unitKey: 'tokens', limit: limit);
}
