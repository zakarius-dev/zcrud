// Chaînage parent de `ZWidgetRegistry` (CR DODLP 2026-08-13) : le lookup
// remonte au parent, un ajout ULTÉRIEUR au parent est visible de l'enfant
// (chaîne vivante, pas une copie figée), l'enfant OMBRE le parent, `kinds`
// expose l'union dédupliquée, la collision LOCALE throw toujours.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

Widget _marker(String tag) => Text(tag, textDirection: TextDirection.ltr);

ZFieldWidgetBuilder _builder(String tag) => (context, ctx) => _marker(tag);

void main() {
  test('le lookup MANQUANT remonte au parent (try + strict + isRegistered)',
      () {
    final parent = ZWidgetRegistry()..register('markdown', _builder('p:md'));
    final child = ZWidgetRegistry(parent: parent);

    expect(child.isRegistered('markdown'), isTrue);
    expect(child.tryBuilderFor('markdown'), isNotNull);
    expect(child.builderFor('markdown'), same(parent.builderFor('markdown')));
    // Absent PARTOUT : le strict throw, le défensif rend null.
    expect(child.tryBuilderFor('geo'), isNull);
    expect(() => child.builderFor('geo'),
        throwsA(isA<ZUnregisteredTypeError>()));
  });

  test('un ajout ULTÉRIEUR au parent est visible de l\'enfant (chaîne '
      'vivante — l\'avantage souligné par la CR)', () {
    final parent = ZWidgetRegistry();
    final child = ZWidgetRegistry(parent: parent)
      ..register('widget', _builder('c:w'));

    expect(child.tryBuilderFor('markdown'), isNull,
        reason: 'rien encore chez le parent');
    parent.register('markdown', _builder('p:md'));
    expect(child.tryBuilderFor('markdown'), isNotNull,
        reason: 'l\'ajout postérieur du parent traverse la chaîne');
  });

  test('OMBRAGE : le kind local de l\'enfant gagne sur celui du parent, '
      'sans throw de collision', () {
    final parent = ZWidgetRegistry()..register('widget', _builder('p:w'));
    final child = ZWidgetRegistry(parent: parent);
    // Enregistrer un kind déjà servi par le parent est PERMIS (ombrage).
    expect(() => child.register('widget', _builder('c:w')), returnsNormally);
    expect(child.builderFor('widget'), isNot(same(parent.builderFor('widget'))));
    // Le parent n'est pas affecté.
    expect(parent.builderFor('widget'), isNotNull);
  });

  test('`kinds` expose l\'UNION dédupliquée (kind ombré compté une fois)', () {
    final grandParent = ZWidgetRegistry()..register('geo', _builder('g:geo'));
    final parent = ZWidgetRegistry(parent: grandParent)
      ..register('markdown', _builder('p:md'));
    final child = ZWidgetRegistry(parent: parent)
      ..register('widget', _builder('c:w'))
      ..register('markdown', _builder('c:md'));

    expect(child.kinds.toSet(), <String>{'widget', 'markdown', 'geo'});
    expect(child.kinds.where((k) => k == 'markdown').length, 1,
        reason: 'kind ombré dédupliqué');
    // Et c'est bien le builder ENFANT que le lookup rend pour le kind ombré.
    expect(child.builderFor('markdown'),
        isNot(same(parent.builderFor('markdown'))));
  });

  test('la collision LOCALE throw toujours (jamais de last-wins silencieux)',
      () {
    final child = ZWidgetRegistry(parent: ZWidgetRegistry())
      ..register('widget', _builder('c:w'));
    expect(() => child.register('widget', _builder('c:w2')),
        throwsA(isA<ZDuplicateRegistrationError>()));
  });

  test('sans parent : comportement racine strictement inchangé', () {
    final registry = ZWidgetRegistry()..register('widget', _builder('w'));
    expect(registry.parent, isNull);
    expect(registry.tryBuilderFor('widget'), isNotNull);
    expect(registry.tryBuilderFor('markdown'), isNull);
    expect(registry.kinds.toList(), <String>['widget']);
  });
}
