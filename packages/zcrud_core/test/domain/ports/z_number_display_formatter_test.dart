// CR-IFFD-94 — règle de repli du port `ZNumberDisplayFormatter`
// (`zNumberDisplayTextOf`, source unique — pur-Dart).
//
// Le repli est la CHAÎNE BRUTE dans TOUS les chemins dégradés : port absent,
// valeur non numérique, port rendant `null`/vide, port qui lève. Le formatage
// n'est visible que pour l'hôte qui injecte (AD-10, FR-26 : aucun format par
// défaut inventé par le socle).
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';

class _Guillemets extends ZNumberDisplayFormatter {
  const _Guillemets();
  @override
  String? format(num value, {String? localeTag}) => '«$value»';
}

class _Nul extends ZNumberDisplayFormatter {
  const _Nul();
  @override
  String? format(num value, {String? localeTag}) => null;
}

class _Vide extends ZNumberDisplayFormatter {
  const _Vide();
  @override
  String? format(num value, {String? localeTag}) => '';
}

class _Leve extends ZNumberDisplayFormatter {
  const _Leve();
  @override
  String? format(num value, {String? localeTag}) =>
      throw StateError('impl hôte fautive');
}

class _Locale extends ZNumberDisplayFormatter {
  const _Locale();
  @override
  String? format(num value, {String? localeTag}) => '$localeTag:$value';
}

void main() {
  test('🔴 sans port, la chaîne brute est rendue (hôte passif immobile)', () {
    expect(zNumberDisplayTextOf(null, 12.0), '12.0');
    expect(zNumberDisplayTextOf(null, 'libre'), 'libre');
    expect(zNumberDisplayTextOf(null, null), 'null');
  });

  test('🔴 avec port, le nombre est projeté — y compris un num porté en '
      'chaîne', () {
    expect(zNumberDisplayTextOf(const _Guillemets(), 12.0), '«12.0»');
    expect(zNumberDisplayTextOf(const _Guillemets(), '12.5'), '«12.5»');
  });

  test('🔴 chemins dégradés ⇒ chaîne brute, jamais une exception', () {
    expect(zNumberDisplayTextOf(const _Guillemets(), 'libre'), 'libre');
    expect(zNumberDisplayTextOf(const _Nul(), 3), '3');
    expect(zNumberDisplayTextOf(const _Vide(), 3), '3');
    expect(zNumberDisplayTextOf(const _Leve(), 3), '3');
  });

  test('la locale ambiante est transmise au port', () {
    expect(
      zNumberDisplayTextOf(const _Locale(), 2, localeTag: 'fr-FR'),
      'fr-FR:2',
    );
  });
}
