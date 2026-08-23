// Deux canaux DÉCLARÉS sur `ZChatToolEntry` : la clé d'icône opaque et les
// libellés d'items d'un catalogue / d'un choix — rétrocompatibles avec la
// convention de repli `stateLabels[itemKey]`.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';

void main() {
  group('TOOLS-ITEMS — iconKey et itemLabels, canaux explicites', () {
    final ZChatToolEntry entry = ZChatToolEntry(
      key: 'corpus',
      state: ZChatCatalogState(
        itemKeys: <String>['code', 'tarif'],
        selectedKeys: <String>['code'],
      ),
      iconKey: 'icon.corpus',
      stateLabels: <String, String>{
        kZChatToolTokenAll: 'Tous',
        'tarif': 'Tarif (repli)',
      },
      itemLabels: <String, String>{'code': 'Code des douanes'},
    );

    test('iconKey est transporté, jamais interprété', () {
      expect(entry.iconKey, 'icon.corpus');
      expect(entry.withState(entry.state.cleared).iconKey, 'icon.corpus');
      expect(ZChatToolEntry(key: 'k', state: const ZChatToggleState()).iconKey,
          isNull);
    });

    test('describeItem lit itemLabels, puis retombe sur stateLabels', () {
      expect(entry.describeItem('code'), 'Code des douanes');
      expect(entry.describeItem('tarif'), 'Tarif (repli)',
          reason: 'la convention de repli reste honorée');
      expect(entry.describeItem('inconnu'), isNull,
          reason: 'le socle ne nomme jamais à la place de l\'hôte');
      // describeState reste le canal des ÉTATS, inchangé.
      expect(entry.describeState(), isNull);
      expect(entry.cleared().describeState(), 'Tous');
    });

    test('aller-retour JSON : icon_key et item_labels, omis si vides', () {
      final Map<String, dynamic> json = entry.toJson();
      expect(json['icon_key'], 'icon.corpus');
      expect(json['item_labels'], <String, String>{'code': 'Code des douanes'});
      final ZChatToolEntry back = ZChatToolEntry.fromJson(json)!;
      expect(back.iconKey, 'icon.corpus');
      expect(back.itemLabels, entry.itemLabels);
      expect(back.describeItem('code'), 'Code des douanes');
      final Map<String, dynamic> bare =
          ZChatToolEntry(key: 'k', state: const ZChatToggleState()).toJson();
      expect(bare.containsKey('icon_key'), isFalse);
      expect(bare.containsKey('item_labels'), isFalse);
      // Défensif : une valeur non texte est écartée, jamais une exception.
      final ZChatToolEntry corrupt = ZChatToolEntry.fromJson(<String, dynamic>{
        'key': 'k',
        'state': <String, dynamic>{'kind': 'toggle', 'value': true},
        'icon_key': 12,
        'item_labels': <String, dynamic>{'a': 1, 'b': 'B'},
      })!;
      expect(corrupt.iconKey, isNull);
      expect(corrupt.itemLabels, <String, String>{'b': 'B'});
    });
  });
}
