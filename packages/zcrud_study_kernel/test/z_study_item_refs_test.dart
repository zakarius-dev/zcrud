/// Tests de CONTRAT des ports neutres `ZStudyDocumentRef` / `ZStudyNoteRef`
/// (option C — ports au kernel, aucune arête nouvelle ; AD-1/AD-4/AD-10/AD-17).
///
/// ## 🔴 Pourquoi ces tests ne se contentent PAS de « l'interface existe »
///
/// Une garde qui vérifie qu'une interface **existe** ne prouve rien : le simple
/// fait d'écrire `abstract interface class Foo {}` la rendrait verte. Ce qu'il
/// faut prouver d'un contrat, c'est qu'il **CONTRAINT** :
///
/// 1. un double **complet** compile et rend ce qu'il porte (§ « double de
///    test ») ;
/// 2. le port est **substituable** — une fonction générique qui ne connaît que
///    l'interface lit les valeurs de n'importe quel implémenteur, y compris un
///    implémenteur **externe au kernel** (c'est tout l'objet du port) ;
/// 3. un double **auquel il manque un membre NE COMPILE PAS** — c'est un rouge
///    de **COMPILATION**, légitime et attendu, prouvé par la campagne R3 (le
///    retrait d'un membre du port fait rougir un test de COMPORTEMENT, pas
///    seulement un test d'existence) ;
/// 4. les **absences décidées** sont gelées (`updatedAt`, `pageCount`,
///    `extension`, `excerpt`, `tagIds`) : un futur contributeur qui les
///    rajouterait ferait rougir la garde de sur-spécification, et devrait donc
///    **motiver** l'ajout par un usage réel — c'est la seule protection contre
///    la dérive « port → modèle dupliqué ».
/// 5. la **pureté** du port (zéro import) est vérifiée sur la SOURCE, en plus du
///    scan global de `z_kernel_purity_test.dart`.
@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Doubles de test — l'implémentation « côté satellite » que le kernel n'a pas.
// ─────────────────────────────────────────────────────────────────────────────

/// Double COMPLET de [ZStudyDocumentRef] : un porteur d'hôte qui projette son
/// propre modèle sur le port (patron `ZFlashcard implements ZSessionCandidate`).
class _FakeDocumentRef implements ZStudyDocumentRef {
  const _FakeDocumentRef({
    this.id,
    this.title = '',
    this.formatKey,
  });

  @override
  final String? id;

  @override
  final String title;

  @override
  final String? formatKey;
}

/// Double COMPLET de [ZStudyNoteRef].
class _FakeNoteRef implements ZStudyNoteRef {
  const _FakeNoteRef({this.id, this.title = ''});

  @override
  final String? id;

  @override
  final String title;
}

/// Porteur ADAPTATEUR : le cas où l'hôte n'implémente pas le port sur son
/// entité mais l'enveloppe. Prouve que le port se satisfait par **composition**
/// aussi bien que par héritage d'interface (AD-4 — aucune contrainte de
/// hiérarchie imposée au satellite).
class _AdapterDocumentRef implements ZStudyDocumentRef {
  const _AdapterDocumentRef(this._fileName, this._mime);

  final String _fileName;
  final String? _mime;

  @override
  String? get id => null;

  @override
  String get title => _fileName;

  @override
  String? get formatKey => _mime;
}

// ─────────────────────────────────────────────────────────────────────────────
// Consommateurs GÉNÉRIQUES — ils ne connaissent QUE le port. C'est ce que la
// future voie typée `.documents(…)`/`.notes(…)` fera, en substance.
// ─────────────────────────────────────────────────────────────────────────────

/// Reproduit littéralement la dérivation de clé de widget des voies typées
/// existantes (`'zDefaultDocumentCard-${doc.id ?? 'ephemeral-$index'}'`).
String _widgetKeyOf(ZStudyDocumentRef doc, int index) =>
    'zDefaultDocumentCard-${doc.id ?? 'ephemeral-$index'}';

/// Reproduit `_zDeriveReorderIds` : identité de réordonnancement DÉRIVÉE des
/// modèles, `null` si un `id` est nul/vide ou dupliqué (capacité RETIRÉE).
List<String>? _reorderIds(List<ZStudyDocumentRef> docs) {
  final ids = <String>[];
  for (final doc in docs) {
    final id = doc.id;
    if (id == null || id.isEmpty) return null;
    if (ids.contains(id)) return null;
    ids.add(id);
  }
  return ids;
}

/// Projection du port vers les primitives de `ZDefaultDocumentCard`.
({String title, String? formatKey}) _cardInputs(ZStudyDocumentRef doc) =>
    (title: doc.title, formatKey: doc.formatKey);

/// Racine du package, quel que soit le CWD (patron `z_kernel_purity_test`).
Directory _kernelLibDir() {
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    final nested = Directory('${dir.path}/packages/zcrud_study_kernel/lib');
    if (nested.existsSync()) return nested;
    final direct = Directory('${dir.path}/lib');
    if (direct.existsSync() &&
        File('${dir.path}/lib/zcrud_study_kernel.dart').existsSync()) {
      return direct;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) break;
    dir = parent;
  }
  fail('lib/ de zcrud_study_kernel introuvable depuis ${Directory.current.path}');
}

String _sourceOf(String relative) {
  final file = File('${_kernelLibDir().path}/$relative');
  if (!file.existsSync()) fail('source introuvable : ${file.path}');
  return file.readAsStringSync();
}

/// Code seul (lignes de commentaire `//`/`///` retirées) — la dartdoc DOIT
/// pouvoir NOMMER les membres écartés pour motiver leur absence sans faire
/// rougir la garde de sur-spécification.
String _codeOnly(String source) => source
    .split('\n')
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

void main() {
  group('ZStudyDocumentRef — le port CONTRAINT et se LIT', () {
    test('un double complet porte ses valeurs à travers le type du port', () {
      const ZStudyDocumentRef doc = _FakeDocumentRef(
        id: 'doc-1',
        title: 'Cours de douane.pdf',
        formatKey: 'application/pdf',
      );
      expect(doc.id, 'doc-1');
      expect(doc.title, 'Cours de douane.pdf');
      expect(doc.formatKey, 'application/pdf');
    });

    test('éphémère : id null ⇒ clé de widget de repli indexée (patron voie typée)',
        () {
      const ZStudyDocumentRef materialise = _FakeDocumentRef(id: 'd7', title: 'a');
      const ZStudyDocumentRef ephemere = _FakeDocumentRef(title: 'b');
      expect(_widgetKeyOf(materialise, 3), 'zDefaultDocumentCard-d7');
      expect(_widgetKeyOf(ephemere, 3), 'zDefaultDocumentCard-ephemeral-3');
    });

    test('identité de réordonnancement DÉRIVÉE du port (id nul/vide/dupliqué ⇒ null)',
        () {
      expect(
        _reorderIds(const <ZStudyDocumentRef>[
          _FakeDocumentRef(id: 'a', title: 'A'),
          _FakeDocumentRef(id: 'b', title: 'B'),
        ]),
        <String>['a', 'b'],
      );
      expect(
        _reorderIds(const <ZStudyDocumentRef>[
          _FakeDocumentRef(id: 'a', title: 'A'),
          _FakeDocumentRef(title: 'B'),
        ]),
        isNull,
        reason: 'un id nul retire la capacité de réordonnancement (AD-10, '
            'jamais un throw)',
      );
      expect(
        _reorderIds(const <ZStudyDocumentRef>[
          _FakeDocumentRef(id: 'a', title: 'A'),
          _FakeDocumentRef(id: '', title: 'B'),
        ]),
        isNull,
      );
      expect(
        _reorderIds(const <ZStudyDocumentRef>[
          _FakeDocumentRef(id: 'a', title: 'A'),
          _FakeDocumentRef(id: 'a', title: 'B'),
        ]),
        isNull,
      );
    });

    test('substituabilité : un ADAPTATEUR (composition) satisfait le port', () {
      const ZStudyDocumentRef doc =
          _AdapterDocumentRef('rapport.docx', 'image/png');
      final inputs = _cardInputs(doc);
      expect(inputs.title, 'rapport.docx');
      expect(inputs.formatKey, 'image/png');
      expect(doc.id, isNull);
    });

    test('formatKey est OPAQUE : extension, MIME ou convention d\'hôte, sans enum',
        () {
      for (final key in <String?>[
        'pdf',
        '.PDF',
        'application/pdf',
        'image/png',
        'iffd:polycopie',
        '',
        null,
      ]) {
        final ZStudyDocumentRef doc = _FakeDocumentRef(title: 't', formatKey: key);
        expect(
          doc.formatKey,
          key,
          reason: 'le port TRANSPORTE la clé telle quelle — il ne classifie pas '
              '(AD-4 : jamais un enum fermé pour un type extensible)',
        );
      }
    });

    test('AD-10 : aucun accès ne lève, même sur un porteur tout-nul', () {
      const ZStudyDocumentRef doc = _FakeDocumentRef();
      expect(() => doc.id, returnsNormally);
      expect(() => doc.title, returnsNormally);
      expect(() => doc.formatKey, returnsNormally);
      expect(doc.title, '');
    });
  });

  group('ZStudyNoteRef — le port CONTRAINT et se LIT', () {
    test('un double complet porte ses valeurs à travers le type du port', () {
      const ZStudyNoteRef note = _FakeNoteRef(id: 'n-1', title: 'Valeur en douane');
      expect(note.id, 'n-1');
      expect(note.title, 'Valeur en douane');
    });

    test('éphémère : id null ⇒ isEphemeral logique côté consommateur', () {
      const ZStudyNoteRef note = _FakeNoteRef(title: 'brouillon');
      expect(note.id, isNull);
      expect(note.title, 'brouillon');
    });

    test('substituabilité : une liste de ports se projette en titres de cartes',
        () {
      const notes = <ZStudyNoteRef>[
        _FakeNoteRef(id: 'a', title: 'Alpha'),
        _FakeNoteRef(id: 'b', title: 'Beta'),
      ];
      expect(
        notes.map((n) => n.title).toList(),
        <String>['Alpha', 'Beta'],
      );
    });

    test('AD-10 : aucun accès ne lève, même sur un porteur tout-nul', () {
      const ZStudyNoteRef note = _FakeNoteRef();
      expect(() => note.id, returnsNormally);
      expect(() => note.title, returnsNormally);
      expect(note.title, '');
    });
  });

  group('Anti-SUR-SPÉCIFICATION — les absences sont DÉCIDÉES et GELÉES', () {
    // 🔴 C'est la garde qui protège le port du glissement « port → modèle
    // dupliqué ». Chaque nom listé ici a été écarté pour une raison écrite dans
    // la dartdoc du port ; le rajouter DOIT être un acte conscient, motivé par
    // un usage réel d'une carte du socle.
    const documentInterdits = <String, String>{
      'updatedAt': 'aucune carte ne consomme un DateTime (subtitle déjà '
          'localisé) ET ZStudyDocument n\'a PAS d\'updatedAt (AD-19/D2 : clé '
          'LWW hors-entité, ZSyncMeta)',
      'pageCount': 'ZDefaultDocumentCard n\'a AUCUN créneau de nombre de pages '
          '— un port se dimensionne sur ce qui est CONSOMMÉ',
      'extension': 'le nom est PRIS : ZStudyDocument.extension vaut ZExtension? '
          '(slot AD-4) — un String? get extension casserait le `implements`',
      'sizeBytes': 'aucune carte ne le consomme (méta-info ⇒ subtitle d\'hôte)',
      'storagePath': 'aucune carte ne le consomme (et ce serait une fuite de '
          'la couche data dans un port de présentation)',
      'folderId': 'le rattachement est déjà porté par ZSessionCandidate pour la '
          'sélection ; aucune carte de document ne le consomme',
      'status': 'aucune carte ne le consomme, et ce serait un enum FERMÉ (AD-4)',
      'createdAt': 'aucune carte ne consomme un DateTime',
      'formatLabel': 'libellé VISIBLE et LOCALISÉ ⇒ injecté par l\'hôte '
          '(FR-26) — jamais porté par un modèle neutre',
    };
    const noteInterdits = <String, String>{
      'updatedAt': 'ZSmartNote n\'en a PAS (AD-19/D2) et la carte prend un '
          'subtitle déjà localisé',
      'excerpt': 'OPTION dont la source est un texte brut d\'hôte ; ZSmartNote '
          'ne porte que du Delta (List<Map<String, dynamic>> content) ⇒ rappel '
          'excerptOf de la voie typée (précédent dateLabelOf)',
      'plainTextPreview': 'idem excerpt — n\'existe NULLE PART dans le dépôt '
          'hors l\'exemple de dartdoc de ZDefaultNoteCard',
      'tagIds': 'ZDefaultNoteCard.tags reçoit des balises DÉJÀ RÉSOLUES via le '
          'rappel tagsOf (patron .flashcards)',
      'content': 'le socle ne parse AUCUN rich-text',
      'createdAt': 'aucune carte ne consomme un DateTime',
      'folderId': 'aucune carte de note ne le consomme',
      'subFolderId': 'aucune carte de note ne le consomme',
    };

    test('ZStudyDocumentRef n\'expose QUE {id, title, formatKey}', () {
      final code = _codeOnly(_sourceOf('src/domain/z_study_document_ref.dart'));
      for (final entry in documentInterdits.entries) {
        expect(
          code.contains('get ${entry.key}'),
          isFalse,
          reason: 'SUR-SPÉCIFICATION : `${entry.key}` a été ajouté au port '
              'ZStudyDocumentRef. Motif de son exclusion : ${entry.value}. '
              'Si un usage RÉEL d\'une carte du socle le justifie désormais, '
              'documente-le et retire l\'entrée de cette garde — mais ne '
              'l\'ajoute jamais « au cas où ».',
        );
      }
      for (final attendu in <String>['get id', 'get title', 'get formatKey']) {
        expect(code.contains(attendu), isTrue,
            reason: 'membre attendu manquant : $attendu');
      }
    });

    test('ZStudyNoteRef n\'expose QUE {id, title}', () {
      final code = _codeOnly(_sourceOf('src/domain/z_study_note_ref.dart'));
      for (final entry in noteInterdits.entries) {
        expect(
          code.contains('get ${entry.key}'),
          isFalse,
          reason: 'SUR-SPÉCIFICATION : `${entry.key}` a été ajouté au port '
              'ZStudyNoteRef. Motif de son exclusion : ${entry.value}.',
        );
      }
      for (final attendu in <String>['get id', 'get title']) {
        expect(code.contains(attendu), isTrue,
            reason: 'membre attendu manquant : $attendu');
      }
    });
  });

  group('Pureté — les ports sont PUR-DART, zéro import', () {
    // Redondant avec `z_kernel_purity_test.dart` (qui interdit Flutter partout
    // dans lib/) mais STRICTEMENT plus fort ici : un port neutre ne doit
    // importer RIEN DU TOUT — pas même `zcrud_core`. Sinon l'acyclicité tient
    // encore, mais la neutralité du contrat, non (le satellite se retrouverait
    // à devoir dépendre de ce que le port a tiré).
    for (final relative in <String>[
      'src/domain/z_study_document_ref.dart',
      'src/domain/z_study_note_ref.dart',
    ]) {
      test('$relative ne contient AUCUNE directive import/part', () {
        final code = _codeOnly(_sourceOf(relative));
        expect(code.contains('import '), isFalse,
            reason: '$relative doit rester sans dépendance (port neutre)');
        expect(code.contains('part '), isFalse,
            reason: '$relative ne doit porter aucun codegen');
        expect(code.contains('@ZcrudModel'), isFalse,
            reason: 'un port n\'est PAS une entité persistée (aucun codegen, '
                'aucun ZTypeRegistry — YAGNI, précédent ZDailyStudyTask)');
      });
    }

    test('les ports sont bien réexportés par le barrel public', () {
      final barrel = _sourceOf('zcrud_study_kernel.dart');
      expect(barrel.contains("export 'src/domain/z_study_document_ref.dart';"),
          isTrue);
      expect(
          barrel.contains("export 'src/domain/z_study_note_ref.dart';"), isTrue);
    });
  });
}
