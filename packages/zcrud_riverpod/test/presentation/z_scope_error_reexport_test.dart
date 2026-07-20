// CR-4 (session lex_douane, 2026-07-20) — le barrel du binding doit ré-exporter
// `ZScopeError`, le type que ses PROPRES seams lèvent.
//
// Discriminant : ce fichier n'importe QUE `package:zcrud_riverpod/zcrud_riverpod.dart`
// — jamais `zcrud_core`. Retirer le `export … show ZScopeError` du barrel rend
// `ZScopeError` non résolu ⇒ le test NE COMPILE PLUS (rouge au chargement). C'est
// exactement la situation que subissait l'app hôte avant le correctif : devoir
// importer `zcrud_core` uniquement pour attraper l'erreur de son binding.
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Riverpod 3 : `ProviderException` (l'enveloppe des exceptions de provider) n'est
// PAS exporté par l'entrypoint principal — il vit dans `misc.dart`. Piège récurrent
// pour l'app hôte : cf. la note CR-4 de `docs/private-git-consumption.md`.
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart' show ZEntity;
import 'package:zcrud_riverpod/zcrud_riverpod.dart';

/// Entité de test minimale (identité opaque, AD-4).
class _Probe extends ZEntity {
  const _Probe();
  @override
  String? get id => 'probe';
}

void main() {
  test(
      'CR-4 — le barrel ré-exporte ZScopeError : un hôte attrape l\'erreur de seam '
      'SANS importer zcrud_core', () {
    // `ZScopeError` est nommé ici via le SEUL import du binding : si le ré-export
    // disparaît, cette ligne ne compile pas.
    expect(ZScopeError, isNotNull);

    final seam = zStudyRepositoryProvider<_Probe>();
    final container = ProviderContainer();
    addTearDown(container.dispose);

    // Riverpod 3 encapsule l'exception du provider ; on déballe pour asserter le
    // type RÉELLEMENT levé, pas seulement l'enveloppe.
    Object? inner;
    try {
      container.read(seam);
    } on ProviderException catch (e) {
      inner = e.exception;
    }

    expect(
      inner,
      isA<ZScopeError>(),
      reason: 'le seam non surchargé doit lever un ZScopeError, nommable depuis '
          'le seul barrel du binding (CR-4)',
    );
  });
}
