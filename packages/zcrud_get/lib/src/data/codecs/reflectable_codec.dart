/// Adaptateur d'un modèle `reflectable` **DODLP** vers le `ZcrudRegistry`
/// (FR-11) — **SEULE exception `reflectable` autorisée par AD-3**.
///
/// origine: canonique §21/§7 — « DODLP repose sur reflectable/GetX ; zcrud NE
/// DOIT ni imposer reflectable, ni forcer lex à l'adopter ». Ce fichier est le
/// **chemin EXACT allowlisté** par `scripts/ci/gate_reflectable.dart`
/// (`zcrud_get/lib/src/data/codecs/reflectable_codec.dart`) : c'est l'UNIQUE
/// endroit du dépôt qui peut `import 'package:reflectable/reflectable.dart'`.
/// `reflectable` est ajouté aux `dependencies` de **`zcrud_get` uniquement** —
/// jamais au cœur (AD-3), et n'est pas un `zcrud_*` (AD-1 : cœur OUT=0 inchangé).
///
/// **Réflexion INJECTÉE (seam AD-6)** : la capacité d'introspection est un port
/// fin [ZReflectionCapability], PAS un `Get.find` en dur ni un reflector figé.
/// La logique d'adaptation ([ReflectableCodec]) est donc **testable sans**
/// exécuter `initializeReflectable()` — on injecte un double en test. Le
/// câblage sur le VRAI reflector DODLP + `initializeReflectable()` + init
/// Firebase est **déféré à E7-2** (app DODLP, hors `packages/`), ce qui évite
/// tout `*.reflectable.dart` généré sous `packages/` (qui serait scanné et
/// rejeté par le gate).
library;

import 'package:reflectable/reflectable.dart';
import 'package:zcrud_core/zcrud_core.dart';

/// Port fin de **capacité de réflexion** d'un modèle [T] (seam AD-6).
///
/// Abstrait l'introspection reflectable d'un modèle DODLP : en production,
/// implémenté par [ReflectableMirrorCapability] par-dessus un [Reflectable]
/// reflector (branché en E7-2) ; en test, par un simple double (aucune
/// dépendance reflectable requise côté test → gate VERT, cf. AC6).
abstract class ZReflectionCapability<T extends Object> {
  /// Discriminant persistant du modèle réfléchi.
  String get kind;

  /// Sérialise [value] en map via l'introspection du modèle.
  Map<String, dynamic> toMap(T value);

  /// Reconstruit une instance [T] (non-null) depuis sa [map].
  T fromMap(Map<String, dynamic> map);
}

/// Adapte un modèle `reflectable` [T] au `ZcrudRegistry` en s'appuyant sur une
/// [ZReflectionCapability] **injectée** (seam AD-6). C'est un [ZModelAdapter] :
/// `registerInto(registry)` (hérité) rend le modèle décodable/encodable via
/// `registry.decode/encode(kind, …)`, et [fromMapSafe] (hérité) fournit le mode
/// défensif AD-10 — sans que le cœur ne connaisse `reflectable`.
class ReflectableCodec<T extends Object> extends ZModelAdapter<T> {
  /// Construit l'adaptateur autour de la capacité réflexive injectée, plus les
  /// [fieldSpecs] éventuels (FOURNIS, pas inférés — FR-11). Formelle
  /// initialisante privée : l'argument externe reste nommé `capability`.
  ReflectableCodec({
    required this._capability,
    this.fieldSpecs = const <ZFieldSpec>[],
  });

  final ZReflectionCapability<T> _capability;

  @override
  final List<ZFieldSpec> fieldSpecs;

  @override
  String get kind => _capability.kind;

  @override
  T fromMap(Map<String, dynamic> map) => _capability.fromMap(map);

  @override
  Map<String, dynamic> toMap(T value) => _capability.toMap(value);
}

/// Capacité de réflexion **réelle** au-dessus d'un [Reflectable] reflector
/// (branchée en **E7-2** sur le reflector DODLP + `initializeReflectable()`).
///
/// Référence les types `reflectable` ([Reflectable]/[InstanceMirror]) pour la
/// sérialisation par introspection (`invokeGetter` sur [fieldNames]). **NON
/// exercée par les tests E2-6** (qui injectent un double) : l'exercer exigerait
/// un `*.reflectable.dart` généré sous `packages/`, que le gate rejetterait.
/// La reconstruction ([fromMap]) délègue à la factory du modèle ([construct]) —
/// patron DODLP usuel (factory `.fromMap`) ; E7-2 finalise le câblage.
class ReflectableMirrorCapability<T extends Object>
    implements ZReflectionCapability<T> {
  /// Construit la capacité à partir du [reflector] DODLP, du [kind], de la liste
  /// des [fieldNames] à réfléchir et de la factory de reconstruction [construct].
  ReflectableMirrorCapability({
    required this._reflector,
    required this.kind,
    required this._fieldNames,
    required this._construct,
  });

  final Reflectable _reflector;
  final List<String> _fieldNames;
  final T Function(Map<String, dynamic> map) _construct;

  @override
  final String kind;

  @override
  Map<String, dynamic> toMap(T value) {
    final InstanceMirror mirror = _reflector.reflect(value);
    return <String, dynamic>{
      for (final field in _fieldNames) field: mirror.invokeGetter(field),
    };
  }

  @override
  T fromMap(Map<String, dynamic> map) => _construct(map);
}
