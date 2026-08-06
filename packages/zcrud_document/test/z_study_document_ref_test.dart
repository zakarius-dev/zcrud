/// `ZStudyDocument implements ZStudyDocumentRef` — le port neutre du kernel,
/// **satisfait sans arête nouvelle et sans toucher à la sérialisation**.
///
/// ## Ce que ce fichier garde, et pourquoi il est SÉPARÉ
///
/// `z_study_document_test.dart` garde l'**entité persistée** (round-trip,
/// invariants de valeur, `extra`/`extension`). Ce fichier-ci garde le **contrat
/// de PORT** — une propriété d'une autre nature : « la même donnée est
/// **adressable** sous le nom que le socle emploie, et l'ajout de cette adresse
/// n'a **rien** changé au reste ».
///
/// Les deux moitiés sont indissociables : une garde qui vérifierait seulement
/// `doc is ZStudyDocumentRef` serait satisfaite d'un `implements` qui aurait,
/// au passage, ajouté un champ au schéma persisté — c'est-à-dire de la seule
/// chose que ce lot ne devait PAS faire.
library;

import 'package:test/test.dart';
import 'package:zcrud_document/zcrud_document.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

void main() {
  group('le port est SATISFAIT — et par la VRAIE donnée', () {
    test('🔴 `ZStudyDocument` EST un `ZStudyDocumentRef`', () {
      const d = ZStudyDocument();
      expect(d, isA<ZStudyDocumentRef>());

      // 🔒 Contre-preuve de non-vacuité : la variable est RÉELLEMENT utilisable
      // au type du port (un `isA` seul passerait sur un `dynamic`).
      const ZStudyDocumentRef ref = ZStudyDocument(
        id: 'd1',
        fileName: 'cours.pdf',
      );
      expect(ref.id, 'd1');
      expect(ref.title, 'cours.pdf');
      expect(ref.formatKey, 'pdf');
    });

    test('🔴 `title` est la VRAIE donnée, pas une constante — il SUIT `fileName`',
        () {
      // Anti-vacuité : deux valeurs. Un `String get title => "document"` serait
      // vert sur une seule.
      expect(const ZStudyDocument(fileName: 'a.pdf').title, 'a.pdf');
      expect(const ZStudyDocument(fileName: 'b.md').title, 'b.md');
      // Défaut de `fileName` ⇒ `''`, JAMAIS `null` (le port l'exige non
      // nullable) et JAMAIS un repli en dur (« Sans titre » serait un libellé
      // français dans un DOMAINE — FR-26, et le port le dit : le repli visible
      // est l'affaire de l'hôte).
      expect(const ZStudyDocument().title, '');
    });

    test('🔴 `formatKey` SUIT `fileName` (il n\'est pas figé)', () {
      expect(const ZStudyDocument(fileName: 'a.pdf').formatKey, 'pdf');
      expect(const ZStudyDocument(fileName: 'a.epub').formatKey, 'epub');
      expect(const ZStudyDocument(fileName: 'a').formatKey, isNull);
    });
  });

  group('`deriveFormatKey` — la table EXACTE, chaque ligne ACTIONNÉE', () {
    // 🔴 Une seule entrée `'x.pdf' → 'pdf'` serait verte pour une dizaine
    // d'implémentations différentes (dont plusieurs FAUSSES sur les cas réels).
    // La table est donc énumérée, et chaque ligne porte le défaut qu'elle
    // exclut.
    const cases = <({String input, String? expected, String why})>[
      (input: 'cours.pdf', expected: 'pdf', why: 'cas nominal'),
      (
        input: 'cours.PDF',
        expected: 'pdf',
        why: '🔴 sans `toLowerCase`, la clé ne rencontrerait AUCUN candidat de '
            'la normalisation aval (qui, elle, travaille en minuscules) : '
            'glyphe et couleur de format retomberaient sur le repli.',
      ),
      (
        input: '  cours.pdf  ',
        expected: 'pdf',
        why: '🔴 sans `trim`, le suffixe serait « pdf   » (espaces) — une clé '
            'qui ne matche rien.',
      ),
      (
        input: 'archive.tar.gz',
        expected: 'gz',
        why: '🔴 un `indexOf(".")` (PREMIER point) rendrait « tar.gz ».',
      ),
      (
        input: 'notes/2026.v2/README',
        expected: null,
        why: '🔴 sans découpe du CHEMIN, le dernier point est dans un segment '
            'de dossier ⇒ la clé serait « v2/readme » : une clé FAUSSE, pas '
            'une clé absente.',
      ),
      (
        input: r'C:\docs\2026.v2\README',
        expected: null,
        why: 'même piège, séparateur Windows.',
      ),
      (
        input: 'notes/cours.pdf',
        expected: 'pdf',
        why: '🔒 contre-preuve : la découpe de chemin ne DÉTRUIT pas un '
            'suffixe légitime.',
      ),
      (
        input: '.gitignore',
        expected: null,
        why: '🔴 le point EN TÊTE nomme un fichier caché — `lastIndexOf(".") '
            '>= 0` rendrait « gitignore » comme s\'il s\'agissait d\'un format.',
      ),
      (
        input: 'README',
        expected: null,
        why: 'aucun point.',
      ),
      (
        input: 'cours.',
        expected: null,
        why: '🔴 suffixe VIDE — sans la garde `dot == length - 1`, la clé '
            'serait la chaîne vide, qui n\'est pas « absente » pour un '
            'appelant qui teste `!= null`.',
      ),
      (
        input: 'Dr. Smith notes',
        expected: null,
        why: '🔴 un suffixe contenant une ESPACE n\'en est pas un : la clé '
            'serait « smith notes ».',
      ),
      (
        input: '',
        expected: null,
        why: 'rien à dériver.',
      ),
      (
        input: '   ',
        expected: null,
        why: 'blanc pur ⇒ rien à dériver (AD-10 : jamais de throw).',
      ),
    ];

    for (final c in cases) {
      test('« ${c.input} » ⇒ ${c.expected ?? 'null'}', () {
        expect(
          ZStudyDocument.deriveFormatKey(c.input),
          c.expected,
          reason: c.why,
        );
        // 🔒 Le getter du port et la fonction nommée sont la MÊME règle — deux
        // implémentations jumelles finiraient par diverger (leçon
        // `sanitizePageCount`, H2/ES-2.1).
        expect(
          ZStudyDocument(fileName: c.input).formatKey,
          c.expected,
          reason: 'le getter `formatKey` DIVERGE de `deriveFormatKey` : ${c.why}',
        );
      });
    }

    test('AD-10 — aucune entrée ne fait lever, même pathologique', () {
      for (final input in const <String>[
        '.',
        '..',
        '...',
        '/',
        r'\',
        '/.',
        './',
        'a/.b',
        '\u0000.pdf',
        'é.PDF',
      ]) {
        expect(
          () => ZStudyDocument.deriveFormatKey(input),
          returnsNormally,
          reason: '🔴 « $input » fait lever — AD-10 l\'interdit.',
        );
      }
      // Quelques valeurs, pour que le test ne soit pas qu'un « ça ne lève pas ».
      expect(ZStudyDocument.deriveFormatKey('.'), isNull);
      expect(ZStudyDocument.deriveFormatKey('a/.b'), isNull);
      expect(ZStudyDocument.deriveFormatKey('é.PDF'), 'pdf');
    });

    test(
      '🔒 la sortie est un POINT FIXE de la normalisation aval (minuscules, '
      'sans point de tête)',
      () {
        // La normalisation de consommation (`zDocumentFormatKeyCandidates`,
        // `zcrud_study`) minuscule et retire un point de tête. Notre clé
        // traverse donc cette étape SANS CHANGER — ce qui est la condition pour
        // que produire ici et résoudre là-bas ne soit PAS une duplication.
        for (final n in const <String>['cours.PDF', 'A.TaR.Gz', 'x.PnG']) {
          final key = ZStudyDocument.deriveFormatKey(n)!;
          expect(key, key.toLowerCase());
          expect(key.startsWith('.'), isFalse);
          expect(key.trim(), key);
        }
      },
    );
  });

  group('🔴 STRICTEMENT ADDITIF — la sérialisation est INTACTE', () {
    // 🔴 C'est la moitié qui compte. Un `implements` satisfait par des CHAMPS
    // (au lieu de getters dérivés) toucherait `toMap`/`fromMap` et la
    // rétro-compatibilité de sérialisation (gate `verify:serialization`).

    test('🔴 `title`/`format_key` n\'entrent PAS dans la map persistée', () {
      const d = ZStudyDocument(id: 'd1', fileName: 'cours.pdf');
      final map = d.toMap();

      for (final k in const <String>[
        'title',
        'format_key',
        'formatKey',
        'format',
      ]) {
        expect(
          map.containsKey(k),
          isFalse,
          reason: '🔴 « $k » est entré dans la map persistée : le port a été '
              'satisfait par un CHAMP au lieu d\'un getter dérivé ⇒ la '
              'rétro-compat de sérialisation est rompue.',
        );
      }
      // 🔒 Contre-preuve : la map n'est pas vide (sinon le test ci-dessus
      // serait vert par cécité).
      expect(map.keys, contains('file_name'));
    });

    test('🔴 le SCHÉMA généré ne connaît ni `title` ni `formatKey`', () {
      final names = $ZStudyDocumentFieldSpecs.map((s) => s.name).toSet();
      expect(names, contains('file_name'));
      expect(names, isNot(contains('title')));
      expect(names, isNot(contains('format_key')));
      expect(names, isNot(contains('formatKey')));
    });

    test('🔴 `title`/`formatKey` n\'entrent PAS dans `==`/`hashCode`', () {
      // Deux documents de MÊME `fileName` : identiques. Le port n'ajoute aucune
      // dimension d'identité.
      const a = ZStudyDocument(id: 'd', fileName: 'x.pdf');
      const b = ZStudyDocument(id: 'd', fileName: 'x.pdf');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('🔴 round-trip INCHANGÉ : ce qui sort rentre, à l\'identique', () {
      final d = ZStudyDocument(
        id: 'd1',
        folderId: 'f1',
        fileName: 'cours.pdf',
        status: ZDocumentStatus.ready,
        storagePath: 'gs://x/y',
        pageCount: 12,
        sizeBytes: 4096,
        createdAt: DateTime.utc(2026, 8, 5),
        extra: const <String, dynamic>{'iffd_type': 'lecture'},
      );
      final relu = ZStudyDocument.fromMap(d.toMap());
      expect(relu, equals(d));
      // Et le port reste satisfait APRÈS un aller-retour store.
      expect(relu.title, 'cours.pdf');
      expect(relu.formatKey, 'pdf');
    });

    test('🔴 `title`/`formatKey` ne s\'aliassent PAS sur le slot AD-4 '
        '`extension` (le piège de nommage)', () {
      // `ZStudyDocument.extension` vaut `ZExtension?` — un `String? get
      // extension` sur le port aurait fait de ce `implements` une erreur de
      // COMPILATION. On prouve ici que les deux membres coexistent, distincts.
      const d = ZStudyDocument(fileName: 'cours.pdf');
      expect(d.extension, isNull);
      expect(d.formatKey, 'pdf');
      expect(d.extension, isNot(same(d.formatKey)));
    });
  });
}
