/// Natures d'annotation additives (`underline`/`strikethrough`/`squiggly`) —
/// côté DOMAINE : chaque nature neuve se sérialise et se relit, une nature
/// INCONNUE retombe sur le repli sans lever (AD-10), et une donnée qui
/// n'emploie que les natures antérieures se relit à l'identique (inertie).
///
/// Les assertions portent sur la VALEUR relue et sur la map PRODUITE — pas
/// sur la cardinalité de l'enum, qui ne prouverait rien du décodage.
library;

import 'package:test/test.dart';
import 'package:zcrud_document/zcrud_document.dart';

void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // 1 — Chaque nature se sérialise et se RELIT (round-trip par valeur).
  // ═══════════════════════════════════════════════════════════════════════
  group('round-trip — chaque nature traverse toMap/fromMap', () {
    for (final kind in ZDocumentAnnotationKind.values) {
      test('`${kind.name}` survit au round-trip', () {
        final a = ZDocumentAnnotation(id: 'a1', docId: 'd1', kind: kind);
        final map = a.toMap();
        // Le nom d'enum camelCase est la forme persistée (AD-3).
        expect(map['kind'], kind.name);
        expect(ZDocumentAnnotation.fromMap(map).kind, kind);
      });
    }

    test('les trois natures neuves persistent des noms DISTINCTS et attendus',
        () {
      String persisted(ZDocumentAnnotationKind k) =>
          ZDocumentAnnotation(kind: k).toMap()['kind'] as String;
      expect(persisted(ZDocumentAnnotationKind.underline), 'underline');
      expect(persisted(ZDocumentAnnotationKind.strikethrough), 'strikethrough');
      expect(persisted(ZDocumentAnnotationKind.squiggly), 'squiggly');
      // Contrat de nommage avec l'hôte : ces trois noms sont exactement ceux
      // que la visionneuse écrit déjà. Une divergence casserait la relecture
      // des annotations déjà persistées.
      expect(
        ZDocumentAnnotationKind.values.map((k) => k.name).toSet(),
        <String>{
          'highlight',
          'stickyNote',
          'underline',
          'strikethrough',
          'squiggly',
        },
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 2 — Une nature INCONNUE retombe sur le repli, SANS LEVER (AD-10).
  // ═══════════════════════════════════════════════════════════════════════
  group('repli défensif — nature inconnue, jamais de throw (AD-10)', () {
    const cas = <String, Object?>{
      'nature d\'une version FUTURE': 'freeform',
      'casse divergente': 'UNDERLINE',
      'nom snake_case': 'strike_through',
      'chaîne vide': '',
      'null explicite': null,
      'non-String (int)': 7,
      'non-String (map)': <String, dynamic>{'k': 'underline'},
      'non-String (liste)': <String>['squiggly'],
    };
    cas.forEach((libelle, valeur) {
      test('$libelle ⇒ highlight, sans lever', () {
        late ZDocumentAnnotation a;
        expect(
          () => a = ZDocumentAnnotation.fromMap(<String, dynamic>{
            'id': 'x',
            'kind': valeur,
          }),
          returnsNormally,
        );
        expect(a.kind, ZDocumentAnnotationKind.highlight,
            reason: 'le repli est la PREMIÈRE constante déclarée : ajouter '
                'une nature en fin de liste ne doit pas le déplacer.');
      });
    });

    test('`kind` absent de la map ⇒ highlight', () {
      final a = ZDocumentAnnotation.fromMap(const <String, dynamic>{'id': 'x'});
      expect(a.kind, ZDocumentAnnotationKind.highlight);
    });

    test('une nature inconnue NE FUIT PAS dans extra (elle est consommée)',
        () {
      final a = ZDocumentAnnotation.fromMap(const <String, dynamic>{
        'id': 'x',
        'kind': 'freeform',
      });
      expect(a.extra.containsKey('kind'), isFalse);
      // Et la relecture est stable : re-sérialiser produit le repli, pas la
      // valeur inconnue.
      expect(a.toMap()['kind'], 'highlight');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // 3 — INERTIE : une donnée n'employant que les natures antérieures est
  //     relue et re-sérialisée EXACTEMENT comme avant l'ajout.
  // ═══════════════════════════════════════════════════════════════════════
  group('inertie — les natures antérieures sont intactes', () {
    test('une map écrite par une version antérieure se relit à l\'identique',
        () {
      // Map telle qu'une version ne connaissant que highlight/stickyNote
      // l'aurait écrite (surensemble de clés figé par le générateur).
      const legacy = <String, dynamic>{
        'id': 'ann-1',
        'doc_id': 'doc-9',
        'page': 3,
        'kind': 'stickyNote',
        'color_key': 'amber',
        'bounds': <String, dynamic>{
          'left': 0.1,
          'top': 0.2,
          'right': 0.4,
          'bottom': 0.5,
        },
        'rects': null,
        'text': 'passage',
        'created_at': null,
      };
      final a = ZDocumentAnnotation.fromMap(legacy);
      expect(a.kind, ZDocumentAnnotationKind.stickyNote);
      expect(a.toMap()['kind'], 'stickyNote');
      // Le round-trip complet est stable clé par clé.
      expect(a.toMap(), ZDocumentAnnotation.fromMap(a.toMap()).toMap());
    });

    test('le défaut du constructeur reste highlight', () {
      expect(const ZDocumentAnnotation().kind,
          ZDocumentAnnotationKind.highlight);
      expect(ZDocumentAnnotationKind.values.first,
          ZDocumentAnnotationKind.highlight);
      // La note ancrée reste en DEUXIÈME position : les deux natures
      // antérieures gardent leur rang, l'ajout est strictement en queue.
      expect(ZDocumentAnnotationKind.values[1],
          ZDocumentAnnotationKind.stickyNote);
    });
  });
}
