/// Générateur `source_gen` du moteur codegen `zcrud` (E2-5, AD-3).
///
/// Lit STATIQUEMENT (`analyzer`/`ConstantReader`/`TypeChecker` — **jamais**
/// `reflectable`, **jamais** d'exécution d'annotation) les classes annotées
/// `@ZcrudModel` (+ champs `@ZcrudField`/`@ZcrudId`, E2-4) et émet, dans le
/// `part '<file>.g.dart'` :
///   1. `_$XxxFromMap` — reconstruction **défensive** (AD-10 : champ absent →
///      `defaultValue`/valeur sûre ; enum inconnu → repli, jamais `byName` nu ;
///      sous-objet corrompu → n'échoue jamais le parent) ;
///   2. l'extension publique `XxxZcrud` — `toMap()` (snake_case, enum `.name`
///      camelCase, dates ISO-8601, récursion sous-objets) + `copyWith()` **à
///      sentinelle** (reset-`null` distinct de « non fourni ») ;
///   3. `$XxxFieldSpecs` — `List<ZFieldSpec>` projeté 1:1 de `@ZcrudField`, avec
///      **inférence de type** si `@ZcrudField.type == null` ;
///   4. `registerXxx(ZcrudRegistry)` — câblage `kind → (fromMap, toMap,
///      fieldSpecs)`.
///
/// **Échec de build EXPLICITE** (`InvalidGenerationSourceError`, jamais un cast
/// `null` silencieux — AD-3) : type de champ non (dé)sérialisable, cible non
/// classe, collision de clé persistée.
library;

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/edition.dart';

/// Sentinelle interne : marque « argument non fourni » dans `copyWith`.
const _undefinedRef = '_\$undefined';

/// `TypeChecker` (non-`reflectable`, par nom de type) des annotations E2-4.
const _fieldChecker =
    TypeChecker.typeNamed(ZcrudField, inPackage: 'zcrud_annotations');
const _idChecker =
    TypeChecker.typeNamed(ZcrudId, inPackage: 'zcrud_annotations');
const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

/// Générateur du modèle `@ZcrudModel` (émission `part`).
class ZcrudModelGenerator extends GeneratorForAnnotation<ZcrudModel> {
  /// Construit le générateur (`const`, sans état).
  const ZcrudModelGenerator();

  @override
  TypeChecker get typeChecker => _modelChecker;

  @override
  Iterable<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) =>
      generateForModel(element, annotation);

  /// Cœur d'émission, **indépendant de [BuildStep]** (testable directement, sans
  /// pipeline `build_runner` — cf. `build_failure_test.dart`, AC9).
  Iterable<String> generateForModel(Element element, ConstantReader annotation) {
    if (element is! ClassElement) {
      throw InvalidGenerationSourceError(
        '@ZcrudModel ne peut annoter qu\'une CLASSE (trouvé : '
        '${element.runtimeType}).',
        element: element,
      );
    }
    final className = element.name;
    if (className == null || className.isEmpty) {
      throw InvalidGenerationSourceError(
        '@ZcrudModel exige une classe nommée.',
        element: element,
      );
    }

    final rename = _renameOf(annotation.read('fieldRename'));
    final kind = annotation.read('kind').isNull
        ? className
        : annotation.read('kind').stringValue;

    final fields = _collectFields(element, rename);

    final buffer = StringBuffer()
      ..writeln(_emitFromMap(className, fields))
      ..writeln()
      ..writeln(_emitExtension(className, fields))
      ..writeln()
      ..writeln(_emitFieldSpecs(className, fields))
      ..writeln()
      ..writeln(_emitRegister(className, kind, fields));

    // Deux fragments : les helpers PARTAGÉS (dédupliqués par source_gen quand
    // plusieurs modèles vivent dans la même bibliothèque) + le code du modèle.
    return <String>[_sharedHelpers, buffer.toString().trim()];
  }

  // --------------------------------------------------------------------------
  // Collecte des champs (statique).
  // --------------------------------------------------------------------------

  List<_Field> _collectFields(ClassElement element, ZFieldRename rename) {
    final fields = <_Field>[];
    final seenKeys = <String>{};
    for (final field in element.fields) {
      if (field.isStatic || field.isSynthetic) continue;
      final fieldAnno = _fieldChecker.firstAnnotationOf(field);
      final isId = _idChecker.hasAnnotationOf(field);
      if (fieldAnno == null && !isId) continue;

      final reader = fieldAnno == null ? null : ConstantReader(fieldAnno);
      final dartName = field.name;
      if (dartName == null) continue;

      final explicitName = reader != null && !reader.read('name').isNull
          ? reader.read('name').stringValue
          : null;
      final key = explicitName ?? _rename(dartName, rename);
      if (!seenKeys.add(key)) {
        throw InvalidGenerationSourceError(
          'Collision de clé persistée "$key" sur ${element.name}.$dartName '
          '(désambiguïser via @ZcrudField(name:)).',
          element: field,
        );
      }

      fields.add(_resolveField(field, dartName, key, reader, isId));
    }
    return fields;
  }

  _Field _resolveField(
    FieldElement field,
    String dartName,
    String key,
    ConstantReader? reader,
    bool isId,
  ) {
    final type = field.type;
    final nullable = type.nullabilitySuffix == NullabilitySuffix.question;
    final typeStr = type.getDisplayString();

    final (category, elementTypeName, inferred) = _classify(field, type);

    // Type de champ : explicite (@ZcrudField.type) sinon inféré.
    final explicitType = reader != null && !reader.read('type').isNull
        ? _emitConst(reader.read('type'))
        : null;
    final resolvedType = explicitType ?? 'EditionFieldType.$inferred';

    final annoMultiple =
        reader != null && reader.read('multiple').boolValue;

    return _Field(
      dartName: dartName,
      key: key,
      typeStr: typeStr,
      nullable: nullable,
      category: category,
      elementTypeName: elementTypeName,
      reader: reader,
      isId: isId,
      fieldType: resolvedType,
      multiple: annoMultiple || category.isCollection,
    );
  }

  /// Classe un champ en catégorie de (dé)sérialisation + son `EditionFieldType`
  /// inféré. Type non supporté → **échec explicite** (AD-3, AC9).
  (
    _Cat category,
    String? elementTypeName,
    String inferred,
  ) _classify(FieldElement field, DartType type) {
    // Collections homogènes : List<T>.
    if (type.isDartCoreList && type is InterfaceType) {
      final arg = type.typeArguments.isEmpty
          ? null
          : type.typeArguments.first;
      if (arg == null) {
        throw InvalidGenerationSourceError(
          'List sans argument de type non supportée sur ${field.name}.',
          element: field,
        );
      }
      final (elemCat, _, elemInferred) = _classify(field, arg);
      final _Cat listCat = switch (elemCat) {
        _Cat.enumType => _Cat.listEnum,
        _Cat.subModel => _Cat.listModel,
        _ => _Cat.listScalar,
      };
      return (listCat, _typeName(arg), elemInferred);
    }
    if (type.isDartCoreString) return (_Cat.stringType, null, 'text');
    if (type.isDartCoreInt) return (_Cat.intType, null, 'integer');
    if (type.isDartCoreDouble) return (_Cat.doubleType, null, 'float');
    if (type.isDartCoreNum) return (_Cat.numType, null, 'number');
    if (type.isDartCoreBool) return (_Cat.boolType, null, 'boolean');

    final el = type.element;
    if (el is EnumElement) return (_Cat.enumType, _typeName(type), 'select');
    if (_typeName(type) == 'DateTime') {
      return (_Cat.dateTimeType, null, 'dateTime');
    }
    if (el != null && _modelChecker.hasAnnotationOf(el)) {
      return (_Cat.subModel, _typeName(type), 'subItems');
    }

    throw InvalidGenerationSourceError(
      'Type de champ non (dé)sérialisable "${type.getDisplayString()}" sur '
      '${field.name} : ni scalaire supporté, ni enum, ni @ZcrudModel annoté. '
      'Annoter le type cible avec @ZcrudModel, ou en changer.',
      element: field,
    );
  }

  // --------------------------------------------------------------------------
  // Émission — fromMap défensif (AD-10).
  // --------------------------------------------------------------------------

  String _emitFromMap(String className, List<_Field> fields) {
    final args = fields
        .map((f) => '  ${f.dartName}: ${_fromMapExpr(f)},')
        .join('\n');
    return '$className _\$${className}FromMap(Map<String, dynamic> map) =>\n'
        '    $className(\n$args\n    );';
  }

  String _fromMapExpr(_Field f) {
    final m = "map['${f.key}']";
    final def = _fallback(f);
    // Les helpers renvoient déjà `T?` : inutile (et lint `dead_null_aware`) de
    // rajouter `?? null` quand le repli EST `null` (champ nullable).
    String orDef(String expr) => def == 'null' ? expr : '$expr ?? $def';
    switch (f.category) {
      case _Cat.stringType:
        return '$m is String ? $m as String : $def';
      case _Cat.intType:
        return orDef('_\$asInt($m)');
      case _Cat.doubleType:
        return orDef('_\$asDouble($m)');
      case _Cat.numType:
        return orDef('_\$asNum($m)');
      case _Cat.boolType:
        return '$m is bool ? $m as bool : $def';
      case _Cat.dateTimeType:
        return orDef('_\$asDateTime($m)');
      case _Cat.enumType:
        return orDef('_\$enumFromName(${f.elementTypeName}.values, $m)');
      case _Cat.subModel:
        final t = f.elementTypeName;
        // Décodage DÉFENSIF (AD-10) : clés non-`String` / non-map / `fromMap`
        // qui throw retombent sur le repli — le parent survit toujours.
        return orDef('_\$decodeModel($m, $t.fromMap)');
      case _Cat.listScalar:
        final t = f.elementTypeName;
        return '$m is List ? ($m as List).whereType<$t>().toList() : $def';
      case _Cat.listEnum:
        final t = f.elementTypeName;
        return '$m is List ? ($m as List)'
            '.map((e) => _\$enumFromName($t.values, e))'
            '.whereType<$t>().toList() : $def';
      case _Cat.listModel:
        final t = f.elementTypeName;
        // Chaque élément décodé DÉFENSIVEMENT (AD-10) ; élément corrompu
        // (non-map, clés non-`String`, throw) → `null`, filtré via `whereType`.
        return '$m is List ? ($m as List)'
            '.map((e) => _\$decodeModel(e, $t.fromMap))'
            '.whereType<$t>().toList() : $def';
    }
  }

  /// Valeur de repli **sûre** (AD-10 : jamais de throw de parsing).
  String _fallback(_Field f) {
    final r = f.reader;
    if (r != null && !r.read('defaultValue').isNull) {
      return _emitConst(r.read('defaultValue'));
    }
    if (f.nullable) return 'null';
    switch (f.category) {
      case _Cat.stringType:
        return "''";
      case _Cat.intType:
      case _Cat.numType:
        return '0';
      case _Cat.doubleType:
        return '0.0';
      case _Cat.boolType:
        return 'false';
      case _Cat.dateTimeType:
        return 'DateTime.fromMillisecondsSinceEpoch(0)';
      case _Cat.enumType:
        return '${f.elementTypeName}.values.first';
      case _Cat.subModel:
        return '${f.elementTypeName}.fromMap(const <String, dynamic>{})';
      case _Cat.listScalar:
      case _Cat.listEnum:
        return 'const <${f.elementTypeName}>[]';
      case _Cat.listModel:
        return 'const <${f.elementTypeName}>[]';
    }
  }

  // --------------------------------------------------------------------------
  // Émission — extension publique : toMap + copyWith sentinelle.
  // --------------------------------------------------------------------------

  String _emitExtension(String className, List<_Field> fields) {
    final toMapEntries = fields
        .map((f) => "      '${f.key}': ${_toMapExpr(f)},")
        .join('\n');

    final copyParams = fields
        .map((f) => '    Object? ${f.dartName} = $_undefinedRef,')
        .join('\n');
    final copyArgs = fields
        .map((f) => '      ${f.dartName}: identical(${f.dartName}, '
            '$_undefinedRef) ? this.${f.dartName} : ${f.dartName} as '
            '${f.typeStr},')
        .join('\n');

    return 'extension ${className}Zcrud on $className {\n'
        '  /// Sérialise vers la map persistée (snake_case, enum camelCase, '
        'ISO-8601).\n'
        '  Map<String, dynamic> toMap() => <String, dynamic>{\n'
        '$toMapEntries\n'
        '      };\n\n'
        '  /// Copie avec sentinelle : un argument omis préserve la valeur, '
        '`null` explicite la remet à `null`.\n'
        '  $className copyWith({\n$copyParams\n  }) =>\n'
        '      $className(\n$copyArgs\n      );\n'
        '}';
  }

  String _toMapExpr(_Field f) {
    final v = 'this.${f.dartName}';
    final q = f.nullable ? '?' : '';
    switch (f.category) {
      case _Cat.stringType:
      case _Cat.intType:
      case _Cat.doubleType:
      case _Cat.numType:
      case _Cat.boolType:
      case _Cat.listScalar:
        return v;
      case _Cat.dateTimeType:
        return '$v$q.toIso8601String()';
      case _Cat.enumType:
        return '$v$q.name';
      case _Cat.subModel:
        return '$v$q.toMap()';
      case _Cat.listEnum:
        return '$v$q.map((e) => e.name).toList()';
      case _Cat.listModel:
        return '$v$q.map((e) => e.toMap()).toList()';
    }
  }

  // --------------------------------------------------------------------------
  // Émission — ZFieldSpec[] (projection 1:1 + inférence).
  // --------------------------------------------------------------------------

  String _emitFieldSpecs(String className, List<_Field> fields) {
    final specs = fields.map(_emitSpec).join('\n');
    return '/// Schéma déclaratif projeté depuis @ZcrudField (E2-5).\n'
        'const List<ZFieldSpec> \$${className}FieldSpecs = <ZFieldSpec>[\n'
        '$specs\n];';
  }

  String _emitSpec(_Field f) {
    final parts = <String>["name: '${f.key}'", 'type: ${f.fieldType}'];
    final r = f.reader;
    if (r != null) {
      if (!r.read('label').isNull) {
        parts.add('label: ${_emitConst(r.read('label'))}');
      }
      if (!r.read('validators').isNull) {
        parts.add('validators: ${_emitConst(r.read('validators'))}');
      }
      if (!r.read('config').isNull) {
        parts.add('config: ${_emitConst(r.read('config'))}');
      }
      if (!r.read('choices').isNull) {
        parts.add('choices: ${_emitConst(r.read('choices'))}');
      }
      if (!r.read('condition').isNull) {
        parts.add('condition: ${_emitConst(r.read('condition'))}');
      }
      if (!r.read('defaultValue').isNull) {
        parts.add('defaultValue: ${_emitConst(r.read('defaultValue'))}');
      }
      if (r.read('searchable').boolValue) parts.add('searchable: true');
      if (r.read('readOnly').boolValue) parts.add('readOnly: true');
      if (!r.read('showIfNull').boolValue) parts.add('showIfNull: false');
    }
    if (f.multiple) parts.add('multiple: true');
    if (f.isId) parts.add('isId: true');
    return '  ZFieldSpec(${parts.join(', ')}),';
  }

  // --------------------------------------------------------------------------
  // Émission — register(ZcrudRegistry).
  // --------------------------------------------------------------------------

  String _emitRegister(String className, String kind, List<_Field> fields) {
    return '/// Enregistre `$className` (kind "$kind") sur [registry] : '
        '(dé)sérialisation + schéma.\n'
        'void register$className(ZcrudRegistry registry) =>\n'
        '    registry.register<$className>(\n'
        "      '$kind',\n"
        '      fromMap: _\$${className}FromMap,\n'
        '      toMap: (value) => value.toMap(),\n'
        '      fieldSpecs: \$${className}FieldSpecs,\n'
        '    );';
  }

  // --------------------------------------------------------------------------
  // Reconstruction de littéraux `const` depuis les annotations (ConstantReader).
  // --------------------------------------------------------------------------

  String _emitConst(ConstantReader r) {
    if (r.isNull) return 'null';
    if (r.isBool) return r.boolValue.toString();
    if (r.isInt) return r.intValue.toString();
    if (r.isDouble) return r.doubleValue.toString();
    if (r.isString) return _quote(r.stringValue);
    if (r.isList) {
      return '[${r.listValue.map((e) => _emitConst(ConstantReader(e))).join(', ')}]';
    }
    final DartObject? obj = r.isLiteral ? null : r.objectValue;
    final el = obj?.type?.element;
    if (el is EnumElement) {
      // `revive().accessor` peut être `Enum.value` OU `value` selon le cas :
      // on ne garde que le dernier segment et on préfixe par le type.
      final valueName = r.revive().accessor.split('.').last;
      return '${el.name}.$valueName';
    }
    // Objet à constructeur `const`.
    final rev = r.revive();
    final typeName = el?.name ?? rev.source.fragment;
    final ctor = rev.accessor.isEmpty ? '' : '.${rev.accessor}';
    final pos = rev.positionalArguments
        .map((a) => _emitConst(ConstantReader(a)));
    final named = rev.namedArguments.entries
        .map((e) => '${e.key}: ${_emitConst(ConstantReader(e.value))}');
    final args = <String>[...pos, ...named].join(', ');
    return '$typeName$ctor($args)';
  }
}

/// Nom simple d'un type (sans nullabilité ni arguments génériques).
String? _typeName(DartType type) => type.element?.name;

String _quote(String s) {
  final escaped = s
      .replaceAll('\\', '\\\\')
      .replaceAll("'", "\\'")
      .replaceAll('\n', '\\n')
      .replaceAll(r'$', '\\\$');
  return "'$escaped'";
}

ZFieldRename _renameOf(ConstantReader r) {
  if (r.isNull) return ZFieldRename.snake;
  return switch (r.revive().accessor) {
    'none' => ZFieldRename.none,
    'kebab' => ZFieldRename.kebab,
    'pascal' => ZFieldRename.pascal,
    _ => ZFieldRename.snake,
  };
}

String _rename(String dartName, ZFieldRename rename) {
  switch (rename) {
    case ZFieldRename.none:
      return dartName;
    case ZFieldRename.snake:
      return _toSnake(dartName);
    case ZFieldRename.kebab:
      return _toSnake(dartName).replaceAll('_', '-');
    case ZFieldRename.pascal:
      return dartName.isEmpty
          ? dartName
          : dartName[0].toUpperCase() + dartName.substring(1);
  }
}

String _toSnake(String s) {
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (c.toUpperCase() == c && c.toLowerCase() != c) {
      if (i > 0) b.write('_');
      b.write(c.toLowerCase());
    } else {
      b.write(c);
    }
  }
  return b.toString();
}

/// Helpers **partagés** émis une fois par bibliothèque (dédupliqués par
/// source_gen). Parsing tolérant (AD-10) : `int|String`, enum par nom (jamais
/// `byName` nu), date ISO tolérante ; sentinelle `copyWith`.
const _sharedHelpers = '''
/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _\$undefined = _ZUndefined();

class _ZUndefined {
  const _ZUndefined();
}

int? _\$asInt(Object? v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  if (v is num) return v.toInt();
  return null;
}

double? _\$asDouble(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

num? _\$asNum(Object? v) {
  if (v is num) return v;
  if (v is String) return num.tryParse(v);
  return null;
}

DateTime? _\$asDateTime(Object? v) {
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

T? _\$enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final value in values) {
    if (value.name == name) return value;
  }
  return null;
}

/// Coerce défensive vers `Map<String, dynamic>` (AD-10) : `null` si [v] n'est
/// pas une Map ; sinon convertit toute clé en `String` (`Map<dynamic, dynamic>`
/// forgée / Hive) SANS jamais throw — un sous-objet à clés non-`String` ne casse
/// donc JAMAIS le parent (repli `null`).
Map<String, dynamic>? _\$asStringMap(Object? v) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) {
    try {
      return <String, dynamic>{
        for (final e in v.entries) '\${e.key}': e.value,
      };
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Décode défensivement un sous-modèle (AD-10) : coerce [v] en
/// `Map<String, dynamic>` puis délègue à [fromMap]. Toute anomalie (non-map,
/// clés non-`String`, `fromMap` qui throw) retombe sur `null` — le parent
/// survit toujours (sous-objet = `null`, filtrable en liste via `whereType`).
T? _\$decodeModel<T>(Object? v, T Function(Map<String, dynamic>) fromMap) {
  final m = _\$asStringMap(v);
  if (m == null) return null;
  try {
    return fromMap(m);
  } catch (_) {
    return null;
  }
}''';

/// Catégorie de (dé)sérialisation d'un champ.
enum _Cat {
  stringType,
  intType,
  doubleType,
  numType,
  boolType,
  dateTimeType,
  enumType,
  subModel,
  listScalar,
  listEnum,
  listModel;

  bool get isCollection =>
      this == _Cat.listScalar || this == _Cat.listEnum || this == _Cat.listModel;
}

/// Champ résolu (statique) à émettre.
class _Field {
  _Field({
    required this.dartName,
    required this.key,
    required this.typeStr,
    required this.nullable,
    required this.category,
    required this.elementTypeName,
    required this.reader,
    required this.isId,
    required this.fieldType,
    required this.multiple,
  });

  final String dartName;
  final String key;
  final String typeStr;
  final bool nullable;
  final _Cat category;
  final String? elementTypeName;
  final ConstantReader? reader;
  final bool isId;
  final String fieldType;
  final bool multiple;
}
