import 'package:zcrud_core/zcrud_core.dart';

/// Implémentation de DÉMO du seam [ZFilePicker] injecté dans le [ZcrudScope]
/// racine (EX-1, AC4). Ne touche PAS au système de fichiers : renvoie un
/// [AppFile] FACTICE déterministe (`localPath` synthétique, état `pending`),
/// suffisant pour exercer les familles `file`/`image`/`document` du moteur
/// d'édition sans dépendance native (`image_picker`/`file_picker` → EX-2+/E7).
///
/// AD-1/AD-6 : l'impl concrète du picker vit dans l'APP (ou un binding), jamais
/// dans `zcrud_core` qui n'expose que l'interface.
class DemoFilePicker implements ZFilePicker {
  /// Construit un picker de démo `const`.
  const DemoFilePicker();

  @override
  Future<List<AppFile>> pick({
    required ZFileSource source,
    required FileFieldConfig config,
  }) async {
    final ext = config.acceptedExtensions.isNotEmpty
        ? config.acceptedExtensions.first
        : 'bin';
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return <AppFile>[
      AppFile(
        id: 'demo-$stamp',
        name: 'demo_${source.name}_$stamp.$ext',
        mimeType: config.acceptedMimeTypes.isNotEmpty
            ? config.acceptedMimeTypes.first
            : 'application/octet-stream',
        sizeBytes: 1024,
        localPath: '/demo/$stamp.$ext',
      ),
    ];
  }
}
