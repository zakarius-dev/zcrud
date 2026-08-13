// Garde des CHAMPS « CHEMIN » câblés dans l'écran : un `ZFieldSpec` à nom
// POINTÉ lit une valeur IMBRIQUÉE du modèle à l'ouverture du formulaire
// (`zFlattenPaths` à la frontière) et la soumission REGROUPE les clés pointées
// avant `decode` (`zRegroupPaths`) — round-trip complet sur l'entité, les
// champs imbriqués NON édités préservés. Contre-témoin : sans nom pointé, le
// chemin est strictement inchangé (gardes de z_crud_screen_minimal_test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_screen/zcrud_screen.dart';

import 'support/fixtures.dart';

/// Entité à SOUS-OBJET : le modèle est imbriqué, l'édition est plate.
class Setting extends ZEntity {
  const Setting({this.id, required this.label, this.chefId = '', this.zone = ''});

  @override
  final String? id;
  final String label;

  /// Champs du sous-objet persisté sous `vido` (imbriqué).
  final String chefId;
  final String zone;
}

/// Specs à noms POINTÉS : deux champs plats adressant le sous-objet `vido`.
const List<ZFieldSpec> settingSpecs = <ZFieldSpec>[
  ZFieldSpec(name: 'id', type: EditionFieldType.text, isId: true),
  ZFieldSpec(name: 'label', type: EditionFieldType.text, searchable: true),
  ZFieldSpec(name: 'vido.chefId', type: EditionFieldType.text),
  ZFieldSpec(name: 'vido.zone', type: EditionFieldType.text),
];

ZcrudRegistry buildSettingRegistry() {
  final registry = ZcrudRegistry();
  registry.register<Setting>(
    'setting',
    fromMap: (map) {
      final vido = map['vido'];
      final sub = vido is Map ? vido : const <String, Object?>{};
      return Setting(
        id: map['id'] as String?,
        label: (map['label'] as String?) ?? '',
        chefId: (sub['chefId'] as String?) ?? '',
        zone: (sub['zone'] as String?) ?? '',
      );
    },
    toMap: (setting) => <String, dynamic>{
      'id': setting.id,
      'label': setting.label,
      'vido': <String, dynamic>{
        'chefId': setting.chefId,
        'zone': setting.zone,
      },
    },
    fieldSpecs: settingSpecs,
  );
  return registry;
}

void main() {
  testWidgets(
      'champ pointé : la valeur IMBRIQUÉE est lue à l\'ouverture et REGROUPÉE '
      'à la sauvegarde (round-trip entité)', (tester) async {
    const initial = Setting(id: 's1', label: 'Poste', chefId: 'p42', zone: 'Nord');
    final saved = <Setting>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Setting>(
        title: 'Settings',
        source: ZCrudSource<Setting>.items(
          const <Setting>[initial],
          onSave: (s) async => saved.add(s),
        ),
        registry: buildSettingRegistry(),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    // Ouverture : la tranche `vido.chefId` porte la valeur IMBRIQUÉE (le
    // formulaire ne verrait qu'un champ vide sans l'aplatissement).
    final chefField = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.widgetWithText(TextField, 'p42'),
    );
    expect(chefField, findsOneWidget);

    // Édition du seul champ pointé `vido.chefId`.
    await tester.enterText(chefField, 'p77');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    // Soumission : les clés pointées sont REGROUPÉES avant `decode` — le
    // sous-objet est reconstruit, l'identité et les champs non édités
    // (imbriqués compris) sont préservés.
    expect(saved, hasLength(1));
    expect(saved.single.id, 's1');
    expect(saved.single.label, 'Poste');
    expect(saved.single.chefId, 'p77');
    expect(saved.single.zone, 'Nord');
  });

  testWidgets('création avec specs pointées : le sous-objet est reconstruit',
      (tester) async {
    final saved = <Setting>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Setting>(
        title: 'Settings',
        source: ZCrudSource<Setting>.items(
          const <Setting>[],
          onSave: (s) async => saved.add(s),
        ),
        registry: buildSettingRegistry(),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('zCrudCreate')));
    await tester.pumpAndSettle();

    final fieldsInForm = find.descendant(
      of: find.byType(DynamicEdition),
      matching: find.byType(TextField),
    );
    // label, vido.chefId, vido.zone (isId exclu).
    await tester.enterText(fieldsInForm.at(0), 'Nouveau');
    await tester.enterText(fieldsInForm.at(1), 'p01');
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();

    expect(saved, hasLength(1));
    expect(saved.single.label, 'Nouveau');
    expect(saved.single.chefId, 'p01');
    expect(saved.single.id, isNull);
  });

  testWidgets(
      'dupliquer avec specs pointées : copie sans identité, sous-objet repris',
      (tester) async {
    const initial = Setting(id: 's1', label: 'Poste', chefId: 'p42', zone: 'Nord');
    final saved = <Setting>[];
    await pumpScreen(
      tester,
      ZCrudScreen<Setting>(
        title: 'Settings',
        source: ZCrudSource<Setting>.items(
          const <Setting>[initial],
          onSave: (s) async => saved.add(s),
        ),
        registry: buildSettingRegistry(),
      ),
    );
    await tester.tap(find.byIcon(Icons.copy_outlined).first);
    await tester.pumpAndSettle();
    // La copie porte les valeurs imbriquées, aplaties dans le formulaire.
    expect(
      find.descendant(
        of: find.byType(DynamicEdition),
        matching: find.widgetWithText(TextField, 'p42'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('zCrudFormSave')));
    await tester.pumpAndSettle();
    expect(saved, hasLength(1));
    expect(saved.single.id, isNull); // copie SANS identité
    expect(saved.single.chefId, 'p42');
    expect(saved.single.zone, 'Nord');
  });
}
