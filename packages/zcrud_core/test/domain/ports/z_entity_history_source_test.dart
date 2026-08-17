import 'package:test/test.dart';
import 'package:zcrud_core/domain.dart';

class _Item extends ZEntity {
  const _Item(this.id);
  @override
  final String? id;
}

class _Source extends ZEntityHistorySource<_Item> {
  @override
  Stream<List<ZHistoryEntry>> watchHistory(_Item entity) =>
      Stream<List<ZHistoryEntry>>.value(const <ZHistoryEntry>[]);
}

void main() {
  test(
    'le port expose un flux nu et l’entrée conserve action/libellé métier',
    () async {
      final entries = await _Source().watchHistory(const _Item('a')).first;
      expect(entries, isEmpty);
      const entry = ZHistoryEntry(
        action: ZCrudAction.update,
        operationLabel: 'Visa douanier',
      );
      expect(entry.action, ZCrudAction.update);
      expect(entry.operationLabel, 'Visa douanier');
    },
  );
}
