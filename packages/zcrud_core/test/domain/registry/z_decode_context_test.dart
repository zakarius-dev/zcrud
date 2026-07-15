// Seam d'injection DW-ES14-2 (ES-3.0) — pouvoir DISCRIMINANT au niveau CŒUR.
//
// Prouve, sans dépendre d'aucun satellite (CORE OUT=0), que :
//  - AC1 : un `ZcrudRegistry()` SANS contexte se comporte EXACTEMENT comme avant
//    (le codec conscient du contexte décode avec `context == null`) ;
//  - AC3 (analogue) : un `ZcrudRegistry(decodeContext:)` câblant un résolveur
//    d'extension fait revenir le slot TYPÉ — retirer le threading le fait
//    RETOMBER opaque (pouvoir discriminant) ;
//  - AC4 (analogue) : le `sourceRegistry` du contexte est HONORÉ ;
//  - AC5 : `decode` ne throw JAMAIS, même sur un parser qui lève.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/domain.dart';

/// Extension TYPÉE de fixture (analogue de `ZNoteAudio`, mais LOCALE au cœur).
class _TypedExt implements ZExtension {
  const _TypedExt(this.value);
  final String value;
  @override
  int get formatVersion => 1;
  @override
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'format_version': 1, 'value': value};
}

/// Extension OPAQUE de survie (analogue de `ZOpaqueNoteExtension`).
class _OpaqueExt implements ZExtension {
  const _OpaqueExt(this.payload);
  final Map<String, dynamic> payload;
  @override
  int get formatVersion => 0;
  @override
  Map<String, dynamic> toJson() => payload;
}

/// Entité de fixture `ZExtensible` dont la factory accepte un `extensionParser`
/// ET un `sourceRegistry` INJECTABLES (patron `ZFlashcard`/`ZSmartNote`).
class _Probe with ZExtensible {
  const _Probe(
      {this.extension,
      this.sourcePayload,
      Map<String, dynamic> extra = const <String, dynamic>{}})
      // ignore: prefer_initializing_formals
      : _extra = extra;

  factory _Probe.fromMap(
    Map<String, dynamic> map, {
    ZExtension? Function(Map<String, dynamic>)? extensionParser,
    ZSourceRegistry? sourceRegistry,
  }) {
    final rawExt = map['extension'];
    ZExtension? ext;
    if (rawExt is Map<String, dynamic>) {
      final typed = extensionParser == null
          ? null
          : ZExtension.guard<ZExtension?>(() => extensionParser(rawExt));
      ext = typed ?? _OpaqueExt(rawExt); // survie verbatim, jamais détruit
    }
    Map<String, dynamic>? src;
    final rawSrc = map['source'];
    if (rawSrc is Map<String, dynamic>) {
      final codec = sourceRegistry?.tryCodecFor('${rawSrc['kind']}');
      src = codec != null
          ? codec.fromJson(rawSrc) as Map<String, dynamic>
          : rawSrc;
    }
    return _Probe(extension: ext, sourcePayload: src);
  }

  @override
  final ZExtension? extension;
  final Map<String, dynamic>? sourcePayload;
  final Map<String, dynamic> _extra;
  @override
  Map<String, dynamic> get extra => _extra;

  Map<String, dynamic> toMap() => <String, dynamic>{
        if (extension != null) 'extension': extension!.toJson(),
        if (sourcePayload != null) 'source': sourcePayload,
      };
}

ZExtension? _resolve(String kind, Map<String, dynamic> json) =>
    kind == 'probe' ? _TypedExt('${json['value']}') : null;

void _register(ZcrudRegistry r, {bool thread = true}) {
  r.register<_Probe>(
    'probe',
    fromMap: _Probe.fromMap,
    toMap: (v) => v.toMap(),
    // R3 : `thread=false` NEUTRALISE l'injection du contexte (le codec retombe
    // sur le tear-off nu) — le test discriminant DOIT alors rougir.
    fromMapWithContext: thread
        ? (map, context) => _Probe.fromMap(
              map,
              extensionParser: context?.extensionParser == null
                  ? null
                  : (json) => context!.extensionParser!('probe', json),
              sourceRegistry: context?.sourceRegistry,
            )
        : null,
  );
}

void main() {
  const payload = <String, dynamic>{'format_version': 1, 'value': 'hi'};

  test('AC1 — SANS contexte : decode identique a la voie historique (opaque)',
      () {
    final r = ZcrudRegistry(); // aucun contexte
    _register(r);
    final e = r.decode('probe', <String, dynamic>{'extension': payload}) as _Probe;
    // Aucun résolveur ⇒ opaque, JAMAIS typé (comportement d'avant ES-3.0).
    expect(e.extension, isA<_OpaqueExt>());
    expect(e.extension, isNot(isA<_TypedExt>()));
    // Ré-encodage verbatim (données préservées).
    expect(r.encode('probe', e)['extension'], equals(payload));
  });

  test('AC3 — AVEC contexte : le slot revient TYPE (pouvoir discriminant)', () {
    final r = ZcrudRegistry(
      decodeContext: const ZDecodeContext(extensionParser: _resolve),
    );
    _register(r);
    final e = r.decode('probe', <String, dynamic>{'extension': payload}) as _Probe;
    expect(e.extension, isA<_TypedExt>());
    expect((e.extension! as _TypedExt).value, 'hi');
  });

  test('R3 — retirer le threading fait RETOMBER opaque (rouge provoque)', () {
    final r = ZcrudRegistry(
      decodeContext: const ZDecodeContext(extensionParser: _resolve),
    );
    _register(r, thread: false); // injection NEUTRALISEE
    final e = r.decode('probe', <String, dynamic>{'extension': payload}) as _Probe;
    // Le contexte est câblé mais le codec ne le thread PAS ⇒ opaque.
    expect(e.extension, isA<_OpaqueExt>());
    expect(e.extension, isNot(isA<_TypedExt>()));
  });

  test('AC4 — le sourceRegistry du contexte est HONORE sur la voie registre', () {
    final sourceReg = ZSourceRegistry()
      ..register('art',
          fromJson: (j) => <String, dynamic>{'kind': 'art', 'norm': j['raw']},
          toJson: (v) => <String, dynamic>{'kind': 'art', 'raw': (v as Map)['norm']});
    final r = ZcrudRegistry(decodeContext: ZDecodeContext(sourceRegistry: sourceReg));
    _register(r);
    final e = r.decode('probe', <String, dynamic>{
      'source': <String, dynamic>{'kind': 'art', 'raw': 'brut'},
    }) as _Probe;
    // Le codec de l'app A ETE applique (payload normalise), pas le brut.
    expect(e.sourcePayload, equals(<String, dynamic>{'kind': 'art', 'norm': 'brut'}));

    // Temoin SANS contexte : payload brut (codec ignore).
    final r2 = ZcrudRegistry();
    _register(r2);
    final e2 = r2.decode('probe', <String, dynamic>{
      'source': <String, dynamic>{'kind': 'art', 'raw': 'brut'},
    }) as _Probe;
    expect(e2.sourcePayload, equals(<String, dynamic>{'kind': 'art', 'raw': 'brut'}));
  });

  test('AC5 — decode ne throw JAMAIS, meme si le parser leve', () {
    final r = ZcrudRegistry(
      decodeContext: ZDecodeContext(
        extensionParser: (kind, json) => throw StateError('boom'),
      ),
    );
    _register(r);
    late _Probe e;
    expect(
      () => e = r.decode('probe', <String, dynamic>{'extension': payload}) as _Probe,
      returnsNormally,
    );
    // L'exception du parser est absorbee (ZExtension.guard) ⇒ survie opaque.
    expect(e.extension, isA<_OpaqueExt>());
    expect(r.decode('probe', const <String, dynamic>{}), isA<_Probe>());
  });
}
