/// Test **STAR** d'ES-1.3 (AC2) : le merge Last-Write-Wins fait autorité sur la
/// **méta hors-entité** (`ZSyncMeta.updatedAt`), **JAMAIS** sur le miroir interne
/// `ZStudyFolder.updatedAt` (déprécié, AD-19).
///
/// > ⚠️ **SI CE FICHIER TOMBE, AD-19 EST VIOLÉ** : quelqu'un a rebranché le
/// > moteur de merge sur un `T.updatedAt` interne. Ne « réparez » pas le test —
/// > réparez le moteur (`ZLwwResolver` / `ZSyncEntry.updatedAt`, `zcrud_core`).
///
/// **Méthode adversariale** : chaque entrée porte un miroir d'entité qui
/// **CONTREDIT** frontalement sa méta (miroir « mensonger »). Un résolveur qui
/// lirait le miroir prendrait **systématiquement la décision inverse** — le test
/// n'a donc aucune zone d'ombre.
///
/// **Pur-Dart / JS-safe** (rejoué sous `dart test -p node`, gate `test:js`) :
/// aucun `dart:io`, aucune dépendance Flutter.
library;

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// Horodatages repères — les « miroirs » sont volontairement aberrants.
final _mirrorFuture = DateTime.utc(2030); // miroir mensonger « très récent »
final _mirrorPast = DateTime.utc(1990); // miroir mensonger « très ancien »
final _metaOld = DateTime.utc(2020);
final _metaNew = DateTime.utc(2026);

/// Construit une entrée de sync dont le **miroir** d'entité et la **méta**
/// peuvent diverger (c'est tout le pouvoir discriminant du test).
ZSyncEntry<ZStudyFolder> _entry({
  required String title,
  required DateTime? mirror,
  required DateTime? meta,
  bool isDeleted = false,
}) =>
    ZSyncEntry<ZStudyFolder>(
      entity: ZStudyFolder(
        id: 'folder-1',
        title: title,
        // ignore: deprecated_member_use
        updatedAt: mirror,
      ),
      meta: ZSyncMeta(updatedAt: meta, isDeleted: isDeleted),
    );

void main() {
  const resolver = ZLwwResolver();

  group('AD-19 — autorité de merge = ZSyncMeta, jamais le miroir T.updatedAt',
      () {
    test(
        'miroir local MENSONGER (2030) mais méta locale ANCIENNE (2020) ⇒ le '
        'DISTANT gagne (adoptRemoteIntoLocal)', () {
      final local = _entry(
        title: 'local',
        mirror: _mirrorFuture, // ← 2030 : un moteur naïf ferait gagner le local
        meta: _metaOld, // ← 2020 : la MÉTA dit que le local est périmé
      );
      final remote = _entry(
        title: 'remote',
        mirror: _mirrorPast, // ← 1990 : un moteur naïf ferait perdre le distant
        meta: _metaNew, // ← 2026 : la MÉTA dit que le distant est le plus récent
      );

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      expect(
        decision.action,
        ZLwwAction.adoptRemoteIntoLocal,
        reason: 'La méta (2026 > 2020) doit primer ; le miroir (2030 vs 1990) '
            'aurait donné pushLocalToRemote ⇒ AD-19 violé.',
      );
      expect(decision.entry, same(remote));
      // Le gagnant conserve sa méta VERBATIM (l'autorité est transportée).
      expect(decision.entry!.updatedAt, _metaNew);
    });

    test(
        'cas SYMÉTRIQUE : méta locale RÉCENTE (2026), miroir local ANCIEN (1990) '
        '⇒ le LOCAL gagne (pushLocalToRemote)', () {
      final local = _entry(
        title: 'local',
        mirror: _mirrorPast, // 1990
        meta: _metaNew, // 2026
      );
      final remote = _entry(
        title: 'remote',
        mirror: _mirrorFuture, // 2030
        meta: _metaOld, // 2020
      );

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      expect(
        decision.action,
        ZLwwAction.pushLocalToRemote,
        reason: 'La méta (2026 > 2020) doit primer ; le miroir (1990 vs 2030) '
            'aurait donné adoptRemoteIntoLocal ⇒ AD-19 violé.',
      );
      expect(decision.entry, same(local));
      expect(decision.entry!.updatedAt, _metaNew);
    });

    test(
        'ZSyncEntry.updatedAt est DÉRIVÉ de la méta — il ignore totalement le '
        'miroir de l\'entité', () {
      final entry = _entry(
        title: 't',
        mirror: _mirrorFuture,
        meta: _metaOld,
      );
      expect(entry.updatedAt, _metaOld);
      expect(entry.updatedAt, isNot(_mirrorFuture));
      // ignore: deprecated_member_use
      expect(entry.entity.updatedAt, _mirrorFuture);
    });

    test(
        'méta.updatedAt null DES DEUX CÔTÉS ⇒ le miroir NE DÉPARTAGE RIEN '
        '(le LOCAL fait foi, AD-9)', () {
      final local = _entry(title: 'local', mirror: _mirrorPast, meta: null);
      final remote = _entry(title: 'remote', mirror: _mirrorFuture, meta: null);

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      // Un moteur lisant le miroir aurait vu 1990 < 2030 → adoptRemote.
      expect(
        decision.action,
        ZLwwAction.pushLocalToRemote,
        reason: 'Deux métas null = égalité stricte ⇒ le local est autoritaire ; '
            'le miroir (1990 vs 2030) ne doit RIEN départager.',
      );
      expect(decision.entry, same(local));
    });

    test(
        'ASYMÉTRIE de null (L5) : méta LOCALE null, méta DISTANTE datée ⇒ le '
        'DISTANT gagne, même avec un miroir local « futur » (2030)', () {
      // Scénario RÉEL de la faille M2/M3 : la méta locale a été NEUTRALISÉE
      // (`null`) au décodage — p.ex. un `updated_at` legacy en `Timestamp` natif
      // non normalisé. Un moteur lisant le miroir verrait 2030 > 1990 et
      // conserverait le local ⇒ écriture distante PERDUE.
      final local = _entry(title: 'local', mirror: _mirrorFuture, meta: null);
      final remote = _entry(title: 'remote', mirror: _mirrorPast, meta: _metaNew);

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      expect(
        decision.action,
        ZLwwAction.adoptRemoteIntoLocal,
        reason: '`null` = « jamais synchronisé » = le plus ancien : le distant '
            'daté prime. Le miroir local (2030) ne doit RIEN départager.',
      );
      expect(decision.entry, same(remote));
      expect(decision.entry!.updatedAt, _metaNew);
    });

    test(
        'ASYMÉTRIE de null (L5, symétrique) : méta LOCALE datée, méta DISTANTE '
        'null ⇒ le LOCAL gagne, même avec un miroir distant « futur » (2030)',
        () {
      final local = _entry(title: 'local', mirror: _mirrorPast, meta: _metaOld);
      final remote = _entry(title: 'remote', mirror: _mirrorFuture, meta: null);

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      expect(
        decision.action,
        ZLwwAction.pushLocalToRemote,
        reason: 'La méta distante `null` est la plus ancienne ; le miroir '
            'distant (2030) ne doit RIEN départager.',
      );
      expect(decision.entry, same(local));
      expect(decision.entry!.updatedAt, _metaOld);
    });

    test(
        'métas null des deux côtés + états IDENTIQUES ⇒ noop (le miroir '
        'divergent ne crée AUCUNE écriture)', () {
      final local = _entry(title: 'même', mirror: _mirrorPast, meta: null);
      final remote = _entry(title: 'même', mirror: _mirrorPast, meta: null);

      expect(
        resolver.resolve<ZStudyFolder>(local, remote).action,
        ZLwwAction.noop,
      );
    });

    test(
        'tombstone : la méta porte le soft-delete (is_deleted), pas l\'entité — '
        'la méta la plus récente gagne', () {
      final local = _entry(
        title: 'vivant',
        mirror: _mirrorFuture, // miroir mensonger « très récent »
        meta: _metaOld,
      );
      final remote = _entry(
        title: 'supprimé',
        mirror: _mirrorPast,
        meta: _metaNew,
        isDeleted: true,
      );

      final decision = resolver.resolve<ZStudyFolder>(local, remote);

      expect(decision.action, ZLwwAction.adoptRemoteIntoLocal);
      expect(decision.entry!.isDeleted, isTrue);
      // L'entité NE déclare AUCUN champ is_deleted (AD-16) : il vit dans la méta.
      expect(decision.entry!.entity.toMap().containsKey('is_deleted'), isFalse);
    });
  });
}
