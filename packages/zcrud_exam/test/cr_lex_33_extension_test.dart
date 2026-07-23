// CR-LEX-33 — un lecteur SANS `extensionParser` DÉTRUISAIT le slot `extension`
// d'un autre hôte.
//
// Mécanisme : `extension` est une clé CONNUE de l'entité, donc exclue du canal
// opaque `extra` ; mais son décodage dépendait d'un paramètre OPTIONNEL du
// lecteur. Un hôte sans parser lisait `null`, la clé brute n'était recueillie
// NULLE PART, et la première réécriture l'effaçait — du store local, puis du
// cloud à la synchronisation suivante.
//
// La destruction se produisait AU DÉCODAGE, avant qu'une seule ligne de code
// applicatif ne s'exécute. C'est exactement ce que le slot d'extension AD-4
// existe pour éviter — et `extension`, le slot VERSIONNÉ, en était le seul
// exclu.
//
// PORTÉE : le motif était identique dans **13 entités** du dépôt. Lex n'en
// avait mesuré qu'une.
import 'dart:convert';

import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_exam/zcrud_exam.dart';

/// Payload d'un AUTRE hôte : nous n'avons aucune raison d'en connaître le
/// schéma, et c'est précisément pourquoi nous ne devons pas le détruire.
const Map<String, dynamic> kPayloadAutreHote = <String, dynamic>{
  'format_version': 3,
  'iffd_flag': true,
  'imbrique': <String, dynamic>{'a': 1, 'b': <int>[1, 2]},
};

Map<String, dynamic> _mapAvecExtension() => <String, dynamic>{
      'id': 'e1',
      'folder_id': 'f1',
      'title': 'Examen',
      'extension': kPayloadAutreHote,
      'cle_inconnue': 'valeur',
    };

void main() {
  group('🔴 CR-LEX-33 — le slot `extension` SURVIT sans parser', () {
    test('un hôte SANS parser ne détruit plus le payload', () {
      final exam = ZExam.fromMap(_mapAvecExtension());
      expect(exam.extension, isNotNull,
          reason: 'le payload doit être PRÉSERVÉ, pas effacé');
      expect(exam.toMap()['extension'], kPayloadAutreHote,
          reason: 'il doit être réémis VERBATIM');
    });

    test('🔴 il survit à un round-trip JSON RÉEL (store → cloud)', () {
      // Un test contre un store sans aller-retour JSON serait un faux vert :
      // c'est la sérialisation qui détruit, pas la structure en mémoire.
      final exam = ZExam.fromMap(_mapAvecExtension());
      final Map<String, dynamic> relu =
          jsonDecode(jsonEncode(exam.toMap())) as Map<String, dynamic>;
      final ZExam apres = ZExam.fromMap(relu);
      expect(apres.toMap()['extension'], kPayloadAutreHote);
    });

    test('stable sur TROIS cycles — aucune érosion', () {
      var map = _mapAvecExtension();
      for (var cycle = 0; cycle < 3; cycle++) {
        map = jsonDecode(jsonEncode(ZExam.fromMap(map).toMap()))
            as Map<String, dynamic>;
        expect(map['extension'], kPayloadAutreHote, reason: 'cycle $cycle');
      }
    });

    test('le canal `extra` continue de fonctionner (contrôle positif)', () {
      // Sans ce contrôle, un test vert ne prouverait rien : il faut établir que
      // la garde SAIT détecter la survie d'une clé.
      expect(ZExam.fromMap(_mapAvecExtension()).extra['cle_inconnue'], 'valeur');
    });

    test('la clé n\'est PAS émise deux fois', () {
      // Piège principal du correctif : préserver via `extra` ET via `extension`
      // aurait produit une double émission, donc un round-trip non idempotent.
      final Map<String, dynamic> out = ZExam.fromMap(_mapAvecExtension()).toMap();
      expect(out['extension'], isNotNull);
      expect(ZExam.fromMap(_mapAvecExtension()).extra.containsKey('extension'),
          isFalse,
          reason: '`extension` ne doit pas transiter AUSSI par `extra`');
    });
  });

  group('Le typage de l\'hôte garde la priorité', () {
    test('un parser qui SAIT typer l\'emporte sur la préservation opaque', () {
      final exam = ZExam.fromMap(
        _mapAvecExtension(),
        extensionParser: (m) => _ExtensionTypee(m['format_version'] as int),
      );
      expect(exam.extension, isA<_ExtensionTypee>());
      expect(exam.extension, isNot(isA<ZOpaqueExtension>()));
    });

    test('un parser qui rend `null` ne DÉTRUIT plus pour autant', () {
      // Version future, sous-schéma inconnu : l'hôte ne sait pas typer, mais
      // ce n'est pas une raison pour effacer.
      final exam = ZExam.fromMap(
        _mapAvecExtension(),
        extensionParser: (_) => null,
      );
      expect(exam.extension, isA<ZOpaqueExtension>());
      expect(exam.toMap()['extension'], kPayloadAutreHote);
    });

    test('AD-10 — un parser qui LÈVE ne coûte pas la donnée', () {
      final exam = ZExam.fromMap(
        _mapAvecExtension(),
        extensionParser: (_) => throw StateError('parser hôte défaillant'),
      );
      expect(exam.toMap()['extension'], kPayloadAutreHote,
          reason: 'un parser défaillant ne doit pas détruire le payload');
    });
  });

  group('Bornes — ne rien inventer', () {
    test('aucune clé `extension` ⇒ `null`, pas d\'extension fantôme', () {
      final exam = ZExam.fromMap(<String, dynamic>{
        'id': 'e1',
        'folder_id': 'f1',
        'title': 'T',
      });
      expect(exam.extension, isNull);
      expect(exam.toMap().containsKey('extension'), isFalse);
    });

    for (final Object? nonMap in <Object?>[42, 'texte', <int>[1, 2], null]) {
      test('un payload non-Map ($nonMap) ⇒ `null` (rien à préserver)', () {
        final exam = ZExam.fromMap(<String, dynamic>{
          'id': 'e1',
          'folder_id': 'f1',
          'title': 'T',
          'extension': nonMap,
        });
        expect(exam.extension, isNull);
      });
    }

    test('`formatVersion` est RAPPORTÉ, jamais interprété', () {
      final exam = ZExam.fromMap(_mapAvecExtension());
      expect(exam.extension!.formatVersion, 3);
    });

    test('égalité PROFONDE : une entité relue égale celle en mémoire', () {
      final a = ZExam.fromMap(_mapAvecExtension());
      final b = ZExam.fromMap(
        jsonDecode(jsonEncode(a.toMap())) as Map<String, dynamic>,
      );
      expect(a.extension, b.extension,
          reason: 'un payload imbriqué exige une égalité profonde');
    });

    test('AD-16 — ni `updated_at` ni `is_deleted` ne fuient', () {
      final exam = ZExam.fromMap(<String, dynamic>{
        ..._mapAvecExtension(),
        'updated_at': 12345,
        'is_deleted': true,
      });
      final Map<String, dynamic> out = exam.toMap();
      expect(out.containsKey('is_deleted'), isFalse);
      expect(exam.extra.containsKey('updated_at'), isFalse);
      expect(exam.extra.containsKey('is_deleted'), isFalse);
    });
  });
}

class _ExtensionTypee implements ZExtension {
  const _ExtensionTypee(this.version);

  final int version;

  @override
  int get formatVersion => version;

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'typee': true};
}
