// CR-LEX-28 — aucun inventaire de persistance n'était généré : la garde
// d'exhaustivité côté `Z` devait être tenue À LA MAIN dans chaque descripteur
// d'hôte, et un champ nullable ajouté par un tag futur restait INVISIBLE
// jusqu'à ce qu'une donnée disparaisse (cf. CR-LEX-34).
import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('🔴 CR-LEX-28 — l inventaire de persistance est généré', () {
    test('il n\'est pas vide et porte les clés du schéma', () {
      expect($ZStudyFolderPersistedKeys, isNotEmpty);
      expect($ZStudyFolderPersistedKeys, contains('id'));
      expect($ZStudyFolderPersistedKeys, contains('title'));
    });

    test('🔴 il déclare une clé qu\'une map donnée peut NE PAS porter', () {
      // C'est tout l'intérêt : l'inventaire annonce ce qui EXISTE au schéma,
      // pas ce qu'un exemplaire particulier a renseigné. Un hôte sait donc
      // qu'un champ est à mapper AVANT d'avoir sous la main une donnée qui le
      // renseigne — sinon le champ reste invisible jusqu'à la première perte.
      const dossier = ZStudyFolder(id: 'f1', title: 'T');
      final Map<String, dynamic> map = dossier.toMap();
      // `updated_at` est un miroir réservé : omis quand il est nul (CR-LEX-31).
      expect(map.containsKey('updated_at'), isFalse,
          reason: 'omis sur cet exemplaire, car nul');
      expect($ZStudyFolderPersistedKeys, contains('updated_at'),
          reason: 'mais l\'inventaire le déclare quand même — c\'est le point');
    });

    test('un champ nul ORDINAIRE est bien déclaré ET émis (à null)', () {
      const dossier = ZStudyFolder(id: 'f1', title: 'T');
      expect(dossier.toMap()['archived_at'], isNull);
      expect($ZStudyFolderPersistedKeys, contains('archived_at'));
    });

    test('🔴 c\'est un SURENSEMBLE de toute map réellement produite', () {
      // L'invariant qu'une garde d'exhaustivité doit pouvoir comparer :
      // aucune clé émise ne doit échapper à l'inventaire.
      final List<ZStudyFolder> corpus = <ZStudyFolder>[
        const ZStudyFolder(id: 'f1', title: 'Minimal'),
        ZStudyFolder(
          id: 'f2',
          title: 'Complet',
          parentId: 'p',
          ownerId: 'o',
          archivedAt: DateTime.utc(2026),
          createdAt: DateTime.utc(2025),
          isPublic: true,
        ),
      ];
      for (final f in corpus) {
        final Set<String> emises = f.toMap().keys.toSet();
        expect(emises.difference($ZStudyFolderPersistedKeys), isEmpty,
            reason: 'une clé émise hors inventaire rendrait la garde d\'hôte '
                'aveugle — c\'est exactement le défaut de CR-LEX-28');
      }
    });

    test('contrôle POSITIF : la comparaison sait détecter un écart', () {
      // Sans lui, un inventaire vide rendrait le test précédent vert à tort.
      const inventaireFaux = <String>{'id'};
      const dossier = ZStudyFolder(id: 'f1', title: 'T');
      expect(dossier.toMap().keys.toSet().difference(inventaireFaux), isNotEmpty,
          reason: 'la détection d\'écart doit fonctionner');
    });

    test('AD-19 — aucune clé de sync réservée dans l\'inventaire métier', () {
      // `updated_at` reste dans le schéma (miroir déprécié), mais `is_deleted`
      // n'appartient jamais au corps métier.
      expect($ZStudyFolderPersistedKeys, isNot(contains('is_deleted')));
    });
  });
}
