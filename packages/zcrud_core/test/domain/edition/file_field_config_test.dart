// AC4 (E3-3c) — `FileFieldConfig` (const, ==/hashCode, défauts sûrs) +
// `ZFileSource` (camelCase).
import 'package:test/test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  test('ZFileSource : valeurs camelCase attendues', () {
    expect(
      ZFileSource.values.map((e) => e.name).toList(),
      <String>['scan', 'camera', 'gallery', 'filePicker'],
    );
  });

  test('FileFieldConfig est un ZFieldConfig const', () {
    const cfg = FileFieldConfig();
    expect(cfg, isA<ZFieldConfig>());
    // Défaut sûr : toutes les sources autorisées, aucune borne.
    expect(cfg.allowedSources, ZFileSource.values);
    expect(cfg.maxFiles, isNull);
    expect(cfg.maxSizeBytes, isNull);
    expect(cfg.acceptedExtensions, isEmpty);
  });

  test('== / hashCode : égalité de valeur (deep list)', () {
    const a = FileFieldConfig(
      acceptedExtensions: <String>['pdf'],
      maxFiles: 3,
      allowedSources: <ZFileSource>[ZFileSource.gallery, ZFileSource.camera],
    );
    const b = FileFieldConfig(
      acceptedExtensions: <String>['pdf'],
      maxFiles: 3,
      allowedSources: <ZFileSource>[ZFileSource.gallery, ZFileSource.camera],
    );
    const c = FileFieldConfig(
      acceptedExtensions: <String>['png'],
      maxFiles: 3,
    );
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a, isNot(c));
  });
}
