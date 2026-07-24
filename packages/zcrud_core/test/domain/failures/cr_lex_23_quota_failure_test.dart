// CR-LEX-23 — aucun sous-type `ZFailure` ne pouvait porter un QUOTA ni son
// `retryAfter`. Tout aller-retour par un port zcrud détruisait donc la
// distinction entre « le serveur est en panne » (réessayer) et « votre quota
// est épuisé » (ne pas réessayer, informer l'utilisateur) : l'information était
// aplatie dans le `message` d'un `ZServerFailure`, et l'hôte devait PARSER DU
// TEXTE pour décider — ou traiter les deux cas pareil.
import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

void main() {
  group('🔴 CR-LEX-23 — le quota est un type, plus une chaîne à parser', () {
    test('il est distinguable d\'une panne serveur par le TYPE', () {
      const ZFailure quota = ZQuotaExceededFailure('quota IA épuisé');
      const ZFailure panne = ZServerFailure('502 bad gateway');

      expect(quota, isA<ZQuotaExceededFailure>());
      expect(panne, isNot(isA<ZQuotaExceededFailure>()));
      // C'est cette bascule qui était impossible : l'hôte décide sur le type.
      expect(quota is ZQuotaExceededFailure, isTrue);
    });

    test('il porte `retryAfter` quand le backend le fournit', () {
      const f = ZQuotaExceededFailure(
        'quota épuisé',
        retryAfter: Duration(minutes: 30),
      );
      expect(f.retryAfter, const Duration(minutes: 30));
    });

    test('🔴 `retryAfter` ABSENT ≠ réessayable tout de suite', () {
      // Son absence est le cas courant (peu de backends la fournissent) : elle
      // ne doit jamais être lue comme une autorisation de réessayer.
      const f = ZQuotaExceededFailure('quota épuisé');
      expect(f.retryAfter, isNull);
      expect(f, isA<ZQuotaExceededFailure>(),
          reason: 'le refus reste un refus, même sans délai annoncé');
    });

    test('il traverse un `ZResult` sans perdre son type ni son délai', () {
      // C'est l'aller-retour par un port qui détruisait l'information.
      const ZResult<int> res = Left<ZFailure, int>(
        ZQuotaExceededFailure('épuisé', retryAfter: Duration(hours: 1)),
      );
      final Duration? delai = res.fold(
        (f) => f is ZQuotaExceededFailure ? f.retryAfter : null,
        (_) => null,
      );
      expect(delai, const Duration(hours: 1));
    });
  });

  group('Contrat de valeur (cohérent avec les autres ZFailure)', () {
    test('égalité par valeur, `retryAfter` inclus', () {
      const a = ZQuotaExceededFailure('x', retryAfter: Duration(minutes: 5));
      const b = ZQuotaExceededFailure('x', retryAfter: Duration(minutes: 5));
      const c = ZQuotaExceededFailure('x', retryAfter: Duration(minutes: 6));
      const d = ZQuotaExceededFailure('x');
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c), reason: 'le délai fait partie de l\'identité');
      expect(a, isNot(d));
    });

    test('un quota n\'égale JAMAIS une panne de même message', () {
      const quota = ZQuotaExceededFailure('épuisé');
      const panne = ZServerFailure('épuisé');
      expect(quota, isNot(equals(panne)),
          reason: 'c\'est précisément la confusion que ce type élimine');
    });

    test('`toString` mentionne le délai (diagnostic)', () {
      expect(
        const ZQuotaExceededFailure('x', retryAfter: Duration(minutes: 2))
            .toString(),
        contains('retryAfter'),
      );
    });

    test('c\'est bien un ZFailure — il passe partout où le domaine en attend',
        () {
      const ZFailure f = ZQuotaExceededFailure('x');
      expect(f.message, 'x');
    });
  });
}
