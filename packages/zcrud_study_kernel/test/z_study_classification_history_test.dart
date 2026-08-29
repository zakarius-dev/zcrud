// Garde de l'HISTORISATION des classifications.
//
// Le défaut qu'elle surveille : un socle qui traiterait « une valeur de
// vocabulaire par cible » comme un invariant. Une classe change de niveau
// d'une année sur l'autre ; un cours change de modalité d'un semestre au
// suivant. Si la deuxième affectation remplace la première, l'historique est
// perdu au moment même où il devient utile.
//
// Ici, deux classifications du MÊME vocabulaire sur la MÊME cible, séparées
// par la période ou par l'intervalle de validité, coexistent — et le noyau ne
// déclare aucun conflit.

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

const ZStudyRef _cible = ZStudyRef(type: kZStudyRefTypeGroup, id: 'g1');

void main() {
  group('Classification — deux valeurs coexistent', () {
    test('deux périodes, deux valeurs du même vocabulaire, deux entités', () {
      const a = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzNiveauScolaire',
        valueKey: 'zzValeurA',
        periodId: 'per2026',
      );
      const b = ZStudyClassification(
        id: 'c2',
        targetRef: _cible,
        vocabularyKey: 'zzNiveauScolaire',
        valueKey: 'zzValeurB',
        periodId: 'per2027',
      );

      // Rien ne les fusionne, rien ne les oppose : ce sont deux faits.
      expect(a, isNot(equals(b)));
      expect(a.targetRef.sameTarget(b.targetRef), isTrue);
      expect(a.vocabularyKey, equals(b.vocabularyKey));
      expect(a.valueKey, isNot(equals(b.valueKey)));

      // Et la sélection par période se fait sur la donnée, sans arbitrage du
      // noyau.
      final histoire = <ZStudyClassification>[a, b];
      final pour2027 = histoire
          .where((ZStudyClassification c) => c.periodId == 'per2027')
          .toList();
      expect(pour2027, hasLength(1));
      expect(pour2027.single.valueKey, equals('zzValeurB'));
    });

    test('deux intervalles de validité disjoints coexistent', () {
      final a = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzModalite',
        valueKey: 'zzValeurA',
        validFrom: DateTime.utc(2026),
        validTo: DateTime.utc(2027),
      );
      final b = ZStudyClassification(
        id: 'c2',
        targetRef: _cible,
        vocabularyKey: 'zzModalite',
        valueKey: 'zzValeurB',
        validFrom: DateTime.utc(2027),
      );

      expect(a.isActiveAt(DateTime.utc(2026, 6)), isTrue);
      expect(b.isActiveAt(DateTime.utc(2026, 6)), isFalse);
      // Borne haute EXCLUE : la bascule est nette, sans jour où les deux
      // valent.
      expect(a.isActiveAt(DateTime.utc(2027)), isFalse);
      expect(b.isActiveAt(DateTime.utc(2027)), isTrue);
    });

    test('une classification intemporelle vaut à tout instant', () {
      const c = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzVocab',
        valueKey: 'zzValeur',
      );
      expect(c.isActiveAt(DateTime.utc(1970)), isTrue);
      expect(c.isActiveAt(DateTime.utc(2200)), isTrue);
    });

    test('la période n\'entre pas dans le calcul de validité', () {
      // Une période est un identifiant, pas un intervalle : le noyau ne va
      // pas la chercher pour en déduire des bornes.
      const c = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzVocab',
        valueKey: 'zzValeur',
        periodId: 'per2026',
      );
      expect(c.isActiveAt(DateTime.utc(2100)), isTrue);
    });

    test('les deux classifications survivent au round-trip séparément', () {
      const a = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzVocab',
        valueKey: 'zzValeurA',
        periodId: 'p1',
      );
      const b = ZStudyClassification(
        id: 'c2',
        targetRef: _cible,
        vocabularyKey: 'zzVocab',
        valueKey: 'zzValeurB',
        periodId: 'p2',
      );
      final maps = <Map<String, dynamic>>[a.toMap(), b.toMap()];
      final relues = maps.map(ZStudyClassification.fromMap).toList();
      expect(relues, equals(<ZStudyClassification>[a, b]));
      expect(
        relues.map((ZStudyClassification c) => c.valueKey).toSet(),
        equals(<String>{'zzValeurA', 'zzValeurB'}),
      );
    });
  });

  group('Archiver ne cascade jamais', () {
    test('archiver un groupe ne touche ni ses classifications ni ses '
        'rattachements', () {
      const groupe = ZStudyGroup(id: 'g1', status: kZStudyStatusActive);
      final archive = groupe.copyWith(status: kZStudyStatusArchived);

      expect(archive.isArchived, isTrue);
      expect(groupe.isArchived, isFalse);
      // Le groupe ne porte AUCUNE liste de dépendants : il n'y a rien à
      // cascader, par construction.
      expect(
        <String>{for (final spec in $ZStudyGroupFieldSpecs) spec.name},
        isNot(contains('classifications')),
      );
      // Et la classification qui le vise ne change pas d'état.
      const c = ZStudyClassification(
        id: 'c1',
        targetRef: _cible,
        vocabularyKey: 'zzVocab',
        valueKey: 'zzValeur',
      );
      expect(c.isActiveAt(DateTime.utc(2026)), isTrue);
    });
  });
}
