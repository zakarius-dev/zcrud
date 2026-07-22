/// Traduction **pure** des identifiants de format natifs en `ZDropKind`, et
/// construction des `ZDroppedItem` neutres.
///
/// Ce fichier ne contient AUCUNE dépendance à `super_drag_and_drop` /
/// `super_clipboard` ni au moteur Flutter : c'est délibéré. Les règles
/// structurantes du contrat de `ZDropRegionRenderer` (filtrage par `accepts`,
/// robustesse AD-10, paresse de `readBytes`) vivent ici précisément pour être
/// **exécutables sous `flutter test` sans engine natif**. Le fichier
/// `presentation/z_native_drop_region_renderer.dart` ne fait que brancher le
/// paquet tiers sur ces règles.
library;

import 'dart:typed_data';

import 'package:zcrud_core/zcrud_core.dart';

import 'z_drop_read_failure.dart';

/// Source de données **neutre** d'un élément déposé.
///
/// C'est la couture (« seam ») qui confine le paquet tiers : l'adaptateur
/// `super_drag_and_drop` implémente cette interface dans la couche
/// présentation, et [zBuildDroppedItems] ne connaît qu'elle. Aucun type tiers
/// n'apparaît donc dans les règles métier — condition 2 d'AD-57 — et un double
/// de test suffit à prouver ces règles.
abstract class ZDropItemSource {
  /// Constructeur `const` pour permettre des sources immuables.
  const ZDropItemSource();

  /// Identifiants de format annoncés par la plateforme (UTI macOS/iOS, type
  /// MIME Linux/Android/web, nom de format Windows). Peut être vide.
  ///
  /// Peut lever : [zBuildDroppedItems] traite l'échec comme « aucun format »
  /// (AD-10).
  List<String> get platformFormats;

  /// Nom de fichier suggéré, `null` si la source n'en propose pas.
  ///
  /// Peut lever ou rendre une future en erreur : traité comme `null` (AD-10).
  Future<String?> readSuggestedName();

  /// Contenu textuel (texte brut ou adresse), `null` si indisponible.
  ///
  /// Peut lever ou rendre une future en erreur : traité comme `null` (AD-10).
  Future<String?> readText();

  /// Lecture du contenu binaire. **N'est jamais appelée** par
  /// [zBuildDroppedItems] — seulement câblée dans `ZDroppedItem.readBytes`.
  Future<Uint8List> readBytes();
}

/// Ordre de préférence quand plusieurs natures sont plausibles pour un même
/// élément.
///
/// [ZDropKind.file] passe **avant** [ZDropKind.image] : un `.png` glissé depuis
/// l'explorateur annonce à la fois « poignée de fichier » et « image PNG », et
/// un hôte qui accepte `{file}` doit le recevoir. À l'inverse une image collée
/// depuis un navigateur n'annonce QUE l'image : elle reste [ZDropKind.image].
/// [ZDropKind.unknown] ferme la marche — il n'est retenu que si l'hôte l'a
/// explicitement demandé.
const List<ZDropKind> kZDropKindPriority = <ZDropKind>[
  ZDropKind.file,
  ZDropKind.image,
  ZDropKind.uri,
  ZDropKind.text,
  ZDropKind.unknown,
];

// --- Tables de correspondance -------------------------------------------

/// Identifiants Windows internes de `super_clipboard` (`NativeShell_CF_<n>`),
/// en MINUSCULES : toute la comparaison se fait sur l'identifiant normalisé,
/// les plateformes n'ayant pas de casse garantie.
const String _cfUnicodeText = 'nativeshell_cf_13';
const String _cfHdrop = 'nativeshell_cf_15';
const String _cfTiff = 'nativeshell_cf_6';

const Set<String> _imageUtis = <String>{
  'public.png',
  'public.jpeg',
  'public.tiff',
  'public.heic',
  'public.heif',
  'public.svg-image',
  'com.compuserve.gif',
  'com.microsoft.bmp',
  'com.microsoft.ico',
  'org.webmproject.webp',
};

const Set<String> _imageWindowsFormats = <String>{
  'png',
  'jfif',
  'gif',
  _cfTiff,
};

const Set<String> _plainTextIds = <String>{
  'text/plain',
  'public.utf8-plain-text',
  'public.plain-text',
  _cfUnicodeText,
};

const Set<String> _htmlIds = <String>{
  'text/html',
  'public.html',
  'html format',
};

const Set<String> _uriIds = <String>{
  'public.url',
  'public.url-name',
};

/// Reverse-DNS plausible : `com.adobe.pdf`, `org.7-zip.7-zip-archive`…
final RegExp _utiPattern = RegExp(r'^[a-z0-9][a-z0-9+_-]*(\.[a-z0-9+_-]+)+$');

/// Type MIME plausible : `application/pdf`, `video/mp4`…
final RegExp _mimePattern = RegExp(r'^[a-z0-9][a-z0-9.+_-]*/[a-z0-9][a-z0-9.+_-]*$');

/// Natures plausibles pour UN identifiant de format natif.
Set<ZDropKind> _kindsForFormat(String raw) {
  final String id = raw.trim();
  if (id.isEmpty) return const <ZDropKind>{};
  final String lower = id.toLowerCase();

  // 1. Images — les plus spécifiques d'abord.
  if (lower.startsWith('image/')) return const <ZDropKind>{ZDropKind.image};
  if (_imageUtis.contains(lower)) return const <ZDropKind>{ZDropKind.image};
  if (_imageWindowsFormats.contains(lower)) {
    return const <ZDropKind>{ZDropKind.image};
  }

  // 2. Poignées de fichier explicites.
  if (lower == 'public.file-url' || lower == _cfHdrop) {
    return const <ZDropKind>{ZDropKind.file};
  }

  // 3. `text/uri-list` est AMBIGU sur Linux/Android/web : c'est le format de
  //    repli à la fois de `fileUri` et de `uri`. On ne tranche pas ici — les
  //    deux natures sont candidates et c'est `accepts` qui décide (voir
  //    [zSelectDropKind]). Trancher arbitrairement ferait rater soit les
  //    fichiers glissés depuis un explorateur, soit les liens glissés depuis
  //    un navigateur.
  if (lower == 'text/uri-list') {
    return const <ZDropKind>{ZDropKind.file, ZDropKind.uri};
  }

  // 4. Adresses.
  if (_uriIds.contains(lower)) return const <ZDropKind>{ZDropKind.uri};
  if (lower.startsWith('uniformresourcelocator')) {
    return const <ZDropKind>{ZDropKind.uri};
  }

  // 5. Texte (HTML compris : c'est du texte enrichi, pas un fichier).
  if (_plainTextIds.contains(lower) || _htmlIds.contains(lower)) {
    return const <ZDropKind>{ZDropKind.text};
  }

  // 6. Tout autre type MIME ou UTI de contenu désigne un fichier.
  if (_mimePattern.hasMatch(lower) || _utiPattern.hasMatch(lower)) {
    return const <ZDropKind>{ZDropKind.file};
  }

  return const <ZDropKind>{ZDropKind.unknown};
}

/// Natures plausibles pour un élément, d'après TOUS ses formats natifs.
///
/// Rend toujours un ensemble non vide : à défaut de reconnaissance, exactement
/// `{ZDropKind.unknown}` (AD-10 — jamais un rejet silencieux, jamais un throw).
/// [ZDropKind.unknown] est écarté dès qu'au moins une nature reconnue existe.
Set<ZDropKind> zCandidateDropKinds(Iterable<String> platformFormats) {
  final Set<ZDropKind> out = <ZDropKind>{};
  for (final String f in platformFormats) {
    out.addAll(_kindsForFormat(f));
  }
  if (out.length > 1) out.remove(ZDropKind.unknown);
  if (out.isEmpty) return const <ZDropKind>{ZDropKind.unknown};
  return out;
}

/// Retient la nature la plus prioritaire **présente dans [accepts]**.
///
/// Rend `null` quand aucune nature candidate n'est acceptée : l'élément est
/// alors **ignoré**, jamais une erreur (contrat 2 du port).
ZDropKind? zSelectDropKind(Set<ZDropKind> candidates, Set<ZDropKind> accepts) {
  for (final ZDropKind kind in kZDropKindPriority) {
    if (candidates.contains(kind) && accepts.contains(kind)) return kind;
  }
  return null;
}

/// Premier identifiant de format ressemblant à un type MIME, `null` sinon.
///
/// Les UTI Apple et les noms de format Windows ne sont PAS des types MIME et ne
/// sont donc jamais remontés dans `ZDroppedItem.mimeType` : mieux vaut `null`
/// qu'un `public.png` que l'hôte prendrait pour un MIME.
String? zMimeTypeForFormats(Iterable<String> platformFormats) {
  for (final String f in platformFormats) {
    final String lower = f.trim().toLowerCase();
    if (_mimePattern.hasMatch(lower)) return lower;
  }
  return null;
}

/// Construit les éléments déposés **neutres** à partir de [sources].
///
/// Tient les quatre points du contrat de `ZDropRegionRenderer` :
/// - **(2)** un élément dont aucune nature candidate n'est dans [accepts] est
///   ignoré — il n'apparaît pas dans le résultat ;
/// - **(3) AD-10** — aucune exception ne s'échappe : un format illisible, un
///   nom ou un texte dont la lecture échoue dégradent le champ concerné en
///   `null`, l'élément reste remonté (au pire en [ZDropKind.unknown]) ;
/// - **(4)** `ZDroppedItem.readBytes` n'est que **câblé** : [ZDropItemSource]
///   `.readBytes` n'est appelée nulle part ici. Aucun octet n'est matérialisé
///   au moment du dépôt.
Future<List<ZDroppedItem>> zBuildDroppedItems(
  List<ZDropItemSource> sources,
  Set<ZDropKind> accepts,
) async {
  final List<ZDroppedItem> out = <ZDroppedItem>[];
  for (final ZDropItemSource source in sources) {
    // AD-10 — même l'accès aux formats est gardé : un adaptateur de plateforme
    // peut lever ici (session déjà libérée).
    List<String> formats;
    try {
      formats = source.platformFormats;
    } catch (_) {
      formats = const <String>[];
    }

    final ZDropKind? kind = zSelectDropKind(
      zCandidateDropKinds(formats),
      accepts,
    );
    if (kind == null) continue;

    final String? name = await _guard(source.readSuggestedName);
    final String? text = (kind == ZDropKind.text || kind == ZDropKind.uri)
        ? await _guard(source.readText)
        : null;

    out.add(
      ZDroppedItem(
        kind: kind,
        name: name,
        mimeType: zMimeTypeForFormats(formats),
        text: text,
        // PARESSE (contrat 4) : on transmet une fermeture. `source.readBytes`
        // n'est invoquée que si — et quand — l'hôte le décide.
        readBytes: () => _readBytesGuarded(source),
      ),
    );
  }
  return out;
}

/// Exécute [op] en absorbant toute défaillance (AD-10).
Future<String?> _guard(Future<String?> Function() op) async {
  try {
    return await op();
  } catch (_) {
    return null;
  }
}

/// Normalise toute défaillance de lecture en [ZDropReadFailure].
///
/// L'échec reste porté par la future — il ne remonte donc jamais dans le
/// traitement du dépôt, seulement à l'hôte qui a demandé les octets.
Future<Uint8List> _readBytesGuarded(ZDropItemSource source) async {
  try {
    return await source.readBytes();
  } on ZDropReadFailure {
    rethrow;
  } catch (error) {
    throw ZDropReadFailure('$error');
  }
}
