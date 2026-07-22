// CR-IFFD-18 — l'absence doit survivre sur le chemin ENTITÉ, pas seulement au
// codec de migration.
//
// CR-IFFD-12 avait livré `preserveAbsenceUnder` sur `ZStudyLegacyCodec`, et le
// handoff v0.4.6 avait recommandé aux hôtes de retirer leurs contournements
// app-side. C'était FAUX : les hôtes qui consomment les entités directement ne
// construisent aucun codec — leur chemin est
// `entité hôte → constructeur → toMap() → store`, et il ne traverse jamais
// `toCanonical`. Le retrait aurait détruit de la donnée, silencieusement.
//
// Ces gardes s'exercent sur le chemin RÉEL de ces hôtes : une entité canonique,
// son `toMap()`, son `fromMap()`. Pas sur le codec.
import 'package:test/test.dart';
// Surface PUR-DART du coeur : le barrel complet tirerait Flutter, et ce test
// tourne sous `dart test`.
import 'package:zcrud_core/domain.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  group('CR-IFFD-18 — chemin ENTITÉ (aucun codec construit)', () {
    test('🔴 l\'absence survit à toMap/fromMap', () {
      // Le modèle de l'hôte : deux champs nullables, l'un renseigné, l'autre non.
      // Passés par une fonction pour que l'analyseur ne replie pas la
      // nullabilité — c'est justement elle que ce test simule.
      final String? sourceFileName = _hostField(null);
      final String? sourceFolderId = _hostField('f1');

      final doc = ZStudyDocument(
        fileName: sourceFileName ?? '',
        folderId: sourceFolderId ?? '',
        extra: zMarkAbsent(const <String, dynamic>{}, zNullFieldsOf(
          <String, Object?>{
            'file_name': sourceFileName,
            'folder_id': sourceFolderId,
          },
        )),
      );

      final back = ZStudyDocument.fromMap(doc.toMap());

      expect(zIsAbsent(back.extra, 'file_name'), isTrue);
      expect(zIsAbsent(back.extra, 'folder_id'), isFalse);
      // Et la restitution rend la distinction au modèle de l'hôte :
      expect(zRestoreAbsentString(back.extra, 'file_name', back.fileName), isNull);
      expect(zRestoreAbsentString(back.extra, 'folder_id', back.folderId), 'f1');
    });

    test('🔴 la PERTE que le retrait aurait produite', () {
      // Contre-preuve : la même entité SANS marqueur — exactement ce que le §4
      // du handoff v0.4.6 recommandait. `null` et `''` redeviennent
      // indiscernables, sans exception ni recensement rouge.
      final sansMarqueur = ZStudyDocument(fileName: '', folderId: '');
      final back = ZStudyDocument.fromMap(sansMarqueur.toMap());
      expect(
        zRestoreAbsentString(back.extra, 'file_name', back.fileName),
        '',
        reason: 'sans marqueur, l\'absence est PERDUE — et silencieusement',
      );
    });

    test('un champ RENSEIGNÉ depuis l\'emporte sur un marqueur périmé', () {
      // Restitution conservatrice : sinon relire écraserait par `null` une
      // donnée que l'utilisateur a saisie après coup.
      final doc = ZStudyDocument(
        fileName: 'saisi-depuis.pdf',
        extra: zMarkAbsent(const <String, dynamic>{}, <String>{'file_name'}),
      );
      final back = ZStudyDocument.fromMap(doc.toMap());
      expect(
        zRestoreAbsentString(back.extra, 'file_name', back.fileName),
        'saisi-depuis.pdf',
      );
    });

    test('un document SAIN ne porte aucun marqueur (empreinte nulle)', () {
      final doc = ZStudyDocument(
        fileName: 'a.pdf',
        folderId: 'f',
        extra: zMarkAbsent(const <String, dynamic>{}, zNullFieldsOf(
          <String, Object?>{'file_name': 'a.pdf', 'folder_id': 'f'},
        )),
      );
      expect(doc.extra.containsKey(kZAbsentFieldsKey), isFalse);
    });
  });

  group('CR-IFFD-18 — invariants du marqueur', () {
    test('🔴 CUMULATIF : un second marquage n\'efface pas le premier', () {
      // Même leçon que CR-IFFD-7 : au second passage le champ vaut `''` et non
      // plus `null` ; un recalcul seul effacerait l'absence.
      var extra = zMarkAbsent(const <String, dynamic>{}, <String>{'file_name'});
      extra = zMarkAbsent(extra, <String>{'storage_path'});
      expect(zAbsentFields(extra), <String>{'file_name', 'storage_path'});
    });

    test('la clé est la MÊME que celle du codec (les deux chemins s\'accordent)',
        () {
      // Un document migré par le codec puis relu par le chemin entité doit voir
      // le même marqueur. Deux conventions qui s'ignorent seraient pires que
      // pas de convention du tout.
      expect(kZAbsentFieldsKey, '_legacy_absent_fields');
    });

    test('AD-10 — un marqueur CORROMPU ne fait jamais lever', () {
      for (final corrupt in <Object?>[
        'pas une liste',
        42,
        <Object?>[null, 7, '', <String>['imbriqué']],
      ]) {
        final extra = <String, dynamic>{kZAbsentFieldsKey: corrupt};
        expect(zAbsentFields(extra), isEmpty);
        expect(zIsAbsent(extra, 'file_name'), isFalse);
        expect(zRestoreAbsentString(extra, 'file_name', ''), '');
      }
    });

    test('les entrées valides survivent à côté des corrompues', () {
      final extra = <String, dynamic>{
        kZAbsentFieldsKey: <Object?>['file_name', null, 42, 'folder_id'],
      };
      expect(zAbsentFields(extra), <String>{'file_name', 'folder_id'});
    });

    test('sortie DÉTERMINISTE : les champs sont triés', () {
      final extra = zMarkAbsent(
        const <String, dynamic>{},
        <String>{'storage_path', 'file_name', 'folder_id'},
      );
      expect(
        extra[kZAbsentFieldsKey],
        <String>['file_name', 'folder_id', 'storage_path'],
      );
    });
  });
}

/// Rend la valeur telle quelle, en type NULLABLE opaque à l'analyse statique :
/// une constante `null` littérale ferait replier les `??` en code mort, et le
/// test ne simulerait plus rien.
String? _hostField(String? value) => value;
