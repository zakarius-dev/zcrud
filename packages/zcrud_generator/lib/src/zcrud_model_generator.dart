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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:zcrud_annotations/zcrud_annotations.dart';
import 'package:zcrud_core/domain.dart';

/// Sentinelle interne : marque « argument non fourni » dans `copyWith`.
const _undefinedRef = '_\$undefined';

/// `TypeChecker` (non-`reflectable`, par nom de type) des annotations E2-4.
const _fieldChecker =
    TypeChecker.typeNamed(ZcrudField, inPackage: 'zcrud_annotations');
const _idChecker =
    TypeChecker.typeNamed(ZcrudId, inPackage: 'zcrud_annotations');
const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');

/// `TypeChecker` du mixin `ZExtensible` (AD-4).
///
/// `isAssignableFrom` résout la hiérarchie **TRANSITIVEMENT** (super-classe,
/// mixin d'un super-type, interface) : `class ZSmartNote extends ZBaseStudyEntity`
/// où la base porte `with ZExtensible` est bien reconnue (prouvé par spike).
/// C'est ce qui distingue les classes qui ONT un slot `extra` — les seules pour
/// lesquelles le contrat DW-ES14-1 a un sens.
const _extensibleChecker =
    TypeChecker.typeNamed(ZExtensible, inPackage: 'zcrud_core');

/// Clé de SONDE du garde runtime DW-ES14-1 (émis dans chaque `.g.dart`).
///
/// Volontairement improbable : elle n'est le nom persisté d'aucun champ de
/// schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`. Une
/// entité conforme à AD-4 la fait donc **atterrir dans `extra`**.
const _extraProbeKey = 'zz__zcrud_extra_probe__';

/// **DW-ES14-2 (ES-3.0)** — présence des collaborateurs INJECTABLES qu'une entité
/// accepte, détectée sur l'AST de ses paramètres nommés. Pilote l'émission des
/// variantes `fromMapWithContext`/`toMapWithContext` du registrar.
class _ContextShape {
  const _ContextShape({
    required this.fromMapExtensionParser,
    required this.fromMapSourceRegistry,
    required this.toMapSourceRegistry,
  });

  /// `fromMap` accepte un `extensionParser` nommé (slot `extension` typé, AD-4).
  final bool fromMapExtensionParser;

  /// `fromMap` accepte un `sourceRegistry` nommé (provenance ouverte, AD-4 pt.3).
  final bool fromMapSourceRegistry;

  /// `toMap` accepte un `sourceRegistry` nommé (ré-encodage de provenance).
  final bool toMapSourceRegistry;

  /// `true` si la factory de domaine consomme AU MOINS un collaborateur injectable.
  bool get fromMapAny => fromMapExtensionParser || fromMapSourceRegistry;
}

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

    // DW-ES14-1 (AD-4) : le registrar DOIT décoder par la factory de DOMAINE.
    // Contrat vérifié PAR MACHINE, jamais présumé (R1/R6).
    final isExtensible = _requireDomainFromMap(element, className);

    // DW-ES14-2 (ES-3.0) : forme des collaborateurs INJECTABLES que la factory de
    // domaine accepte (`extensionParser`/`sourceRegistry`). Le registrar thread le
    // ZDecodeContext dans CES paramètres — plus jamais un tear-off nu qui les
    // laisse `null`. Détecté sur l'AST des paramètres (jamais de regex — R5).
    final ctxShape = _contextShapeOf(element);

    final buffer = StringBuffer()
      ..writeln(_emitFromMap(className, fields))
      ..writeln()
      ..writeln(_emitExtension(className, fields))
      ..writeln()
      ..writeln(_emitFieldSpecs(className, fields))
      ..writeln()
      ..writeln(_emitRegister(className, kind,
          extensible: isExtensible, ctx: ctxShape))
      ..writeln()
      ..writeln(_emitTimestampFields(className, fields));

    // Deux fragments : les helpers PARTAGÉS (dédupliqués par source_gen quand
    // plusieurs modèles vivent dans la même bibliothèque) + le code du modèle.
    return <String>[_sharedHelpers, buffer.toString().trim()];
  }

  // --------------------------------------------------------------------------
  // Contrat DW-ES14-1 — factory de DOMAINE `Xxx.fromMap` obligatoire.
  // --------------------------------------------------------------------------

  /// Exige que la classe annotée déclare un décodeur de **domaine**
  /// `Xxx.fromMap(Map<String, dynamic> map)` — factory **ou méthode statique**
  /// (M2) — que [_emitRegister] câble sur le registre (`fromMap: Xxx.fromMap`).
  /// Retourne `true` si la classe est **`ZExtensible`** (transitivement).
  ///
  /// ## Pourquoi un ÉCHEC DE BUILD, jamais un repli (R6, DW-ES14-1)
  ///
  /// Le repli « naturel » serait `_$XxxFromMap` — la factory du **codegen**, qui
  /// ne connaît QUE les champs `@ZcrudField` et ne peuple donc **NI `extra`, NI
  /// `extension`, NI `source`** (canaux **hors-codegen**, câblés à la main par la
  /// factory de domaine). C'est **exactement** le défaut DW-ES14-1 : sur la voie
  /// registre (`registry.decode`, `FirebaseZRepositoryImpl.fromRegistry`), toute
  /// clé métier inconnue du schéma était **détruite** à chaque cycle
  /// lecture → écriture (`toMap()` ne réémet que ce que `fromMap` a peuplé) —
  /// violation d'**AD-4**, irréversible.
  ///
  /// ## ⚠️ H1 (code-review ES-2.0) — un contrat de SIGNATURE ne prouve RIEN
  ///
  /// La v1 de ce contrat validait **l'EXISTENCE** d'une signature, jamais le
  /// **POUVOIR** de préserver `extra`… et son message d'erreur **prescrivait
  /// littéralement la forme impotente** :
  ///
  /// ```dart
  /// factory Xxx.fromMap(Map<String, dynamic> map) => _$XxxFromMap(map); // ⛔
  /// ```
  ///
  /// Sur une classe `ZExtensible`, **ce geste EST DW-ES14-1** : contrat
  /// satisfait, build VERT, `extra` DÉTRUIT. *Le gate qui interdit la dette
  /// enseignait la dette.* Trois corrections, toutes **par machine** :
  ///
  /// 1. le message **prescrit la forme QUI MARCHE** (celle de `ZFlashcard`/
  ///    `ZStudyFolder` : `extra: _extraFrom(map)` sur les clés non réservées) ;
  /// 2. **BUILD ROUGE** si une classe `ZExtensible` délègue **NUEMENT** à
  ///    `_$XxxFromMap` — détecté sur l'**AST du corps** du décodeur
  ///    (`package:analyzer`, jamais de regex — R5) ;
  /// 3. **GARDE RUNTIME** émis dans le registrar de toute classe `ZExtensible`
  ///    ([_emitRegister]) : il **OBSERVE** le pouvoir (décode une sonde, exige la
  ///    clé inconnue dans `extra`) au lieu de juger une forme. C'est le seul
  ///    filet qui suive les packages **PUBLIÉS** chez un consommateur externe,
  ///    lequel n'a **pas** le harnais `reserved_keys_gate` — trou hors-repo
  ///    identifié par H1. Il attrape **toute** factory impotente, y compris
  ///    celles que (2) ne peut pas voir (corps ré-écrit à la main sans `extra:`).
  bool _requireDomainFromMap(ClassElement element, String className) {
    final extensible = _extensibleChecker.isAssignableFrom(element);

    // M2 — un `fromMap` STATIQUE est un tear-off parfaitement valide
    // (`Xxx.fromMap` s'assigne au registre exactement comme une factory) : il est
    // ACCEPTÉ. La v1 ne regardait que `element.constructors` et affirmait
    // « ne déclare AUCUNE factory fromMap » — message FAUX pour le mainteneur qui
    // en avait bien une sous les yeux.
    final ExecutableElement? decoder = element.constructors
            .where((c) => c.name == 'fromMap')
            .cast<ExecutableElement?>()
            .firstOrNull ??
        element.methods
            .where((m) => m.isStatic && m.name == 'fromMap')
            .cast<ExecutableElement?>()
            .firstOrNull;

    if (decoder == null) {
      throw InvalidGenerationSourceError(
        '$className est annotée @ZcrudModel mais ne déclare AUCUN décodeur de '
        'domaine `fromMap` (ni factory, ni méthode statique) — DW-ES14-1 / AD-4. '
        'Sans lui, le registrar généré décoderait par `_\$${className}FromMap` — '
        'la factory du CODEGEN, qui ignore les canaux HORS-codegen (`extra`, '
        '`extension`, `source`) et DÉTRUIT donc les clés métier inconnues à '
        'chaque cycle lecture→écriture via `registry.decode`.\n'
        '${_prescription(className, extensible: extensible)}',
        element: element,
      );
    }

    _requireCompatibleSignature(decoder, className);
    if (extensible) _rejectNakedCodegenDelegation(decoder, className);
    return extensible;
  }

  /// **DW-ES14-2 (ES-3.0)** — forme des collaborateurs INJECTABLES de l'entité.
  ///
  /// Inspecte l'AST des paramètres NOMMÉS (jamais de regex — R5) de la factory de
  /// domaine `fromMap` (`extensionParser`/`sourceRegistry`) et de l'`operator`
  /// d'instance `toMap` (`sourceRegistry`). Ces paramètres sont **optionnels** —
  /// un tear-off nu les laisse `null`, ce qui DÉTRUIT le slot `extension` typé et
  /// COURT-CIRCUITE le `ZSourceRegistry` de l'app sur la voie registre
  /// (`registry.decode`). Le registrar émis les **thread** depuis le
  /// `ZDecodeContext` injecté (AD-4, compose avec `ZTypeRegistry`/`ZSourceRegistry`).
  _ContextShape _contextShapeOf(ClassElement element) {
    final decoder = element.constructors
            .where((c) => c.name == 'fromMap')
            .cast<ExecutableElement?>()
            .firstOrNull ??
        element.methods
            .where((m) => m.isStatic && m.name == 'fromMap')
            .cast<ExecutableElement?>()
            .firstOrNull;
    final toMap = element.methods
        .where((m) => !m.isStatic && m.name == 'toMap')
        .cast<ExecutableElement?>()
        .firstOrNull;
    bool hasNamed(ExecutableElement? e, String name) =>
        e != null &&
        e.formalParameters.any((p) => p.isNamed && p.name == name);
    return _ContextShape(
      fromMapExtensionParser: hasNamed(decoder, 'extensionParser'),
      fromMapSourceRegistry: hasNamed(decoder, 'sourceRegistry'),
      toMapSourceRegistry: hasNamed(toMap, 'sourceRegistry'),
    );
  }

  /// Le **geste correctif**, écrit dans la forme QUI MARCHE (H1 pt. 1).
  ///
  /// Une classe **`ZExtensible`** ne peut PAS se contenter de déléguer à
  /// `_$XxxFromMap` : la prescription est donc **différente** selon le cas — et
  /// c'est précisément ce que la v1 confondait.
  String _prescription(String className, {required bool extensible}) {
    if (!extensible) {
      return 'GESTE : $className n\'est pas `ZExtensible` (aucun slot `extra`) — '
          'une délégation nue suffit :\n'
          '    factory $className.fromMap(Map<String, dynamic> map) => '
          '_\$${className}FromMap(map);\n'
          '(des paramètres OPTIONNELS supplémentaires sont autorisés ; une '
          'méthode `static` convient aussi.)';
    }
    return 'GESTE : $className est `ZExtensible` — sa factory DOIT peupler le '
        'slot `extra` (AD-4), sinon `registry.decode` détruit les clés métier '
        'inconnues. Patron RÉEL du repo (`ZFlashcard`, `ZStudyFolder`…) :\n'
        '    factory $className.fromMap(Map<String, dynamic> map) {\n'
        '      final base = _\$${className}FromMap(map);   // champs du schéma\n'
        '      return $className(\n'
        '        /* …champs recopiés depuis `base`… */\n'
        '        extra: _extraFrom(map),                  // ✅ clés HORS-schéma\n'
        '      );\n'
        '    }\n'
        '    static final Set<String> _reservedKeys = <String>{\n'
        '      for (final spec in \$${className}FieldSpecs) spec.name,\n'
        '      ...ZSyncMeta.reservedKeys,                  // AD-19.1\n'
        '    };\n'
        '    static Map<String, dynamic> _extraFrom(Map<String, dynamic> map) =>\n'
        '        Map<String, dynamic>.unmodifiable(<String, dynamic>{\n'
        '          for (final e in map.entries)\n'
        '            if (!_reservedKeys.contains(e.key)) e.key: e.value,\n'
        '        });\n'
        '⛔ NE PAS écrire `=> _\$${className}FromMap(map);` nu : le build le '
        'REFUSE (il détruirait `extra`), et le registrar généré porte en plus un '
        'GARDE RUNTIME qui l\'observe.';
  }

  /// Signature compatible avec `T Function(Map<String, dynamic>)` — vérifiée sur
  /// les **TYPES** (`TypeSystem`), jamais sur une chaîne d'affichage (M1).
  ///
  /// La v1 comparait `type.getDisplayString() == 'Map<String, dynamic>'` : elle
  /// **REJETAIT** (échec de build) des décodeurs légaux et **assignables** —
  /// `Map<String, Object?>` (mutuellement sous-type en Dart), un typedef alias
  /// (`typedef JsonMap = Map<String, dynamic>` → `getDisplayString()` rend
  /// `JsonMap`), une forme préfixée par un import. Le critère RÉEL est
  /// l'assignabilité d'un `Map<String, dynamic>` au paramètre — c'est exactement
  /// ce que le tear-off exige. (Prouvé par spike : les 3 formes passent.)
  void _requireCompatibleSignature(ExecutableElement decoder, String className) {
    final params = decoder.formalParameters;
    final positionalRequired =
        params.where((p) => p.isPositional && p.isRequired).toList();
    final surplusRequired =
        params.where((p) => p.isRequired && !p.isPositional).toList();

    final typeSystem = decoder.library.typeSystem;
    final typeProvider = decoder.library.typeProvider;
    final mapStringDynamic = typeProvider.mapType(
      typeProvider.stringType,
      typeProvider.dynamicType,
    );

    final signatureOk = positionalRequired.length == 1 &&
        surplusRequired.isEmpty &&
        typeSystem.isAssignableTo(
          mapStringDynamic,
          positionalRequired.first.type,
        );

    if (signatureOk) return;
    throw InvalidGenerationSourceError(
      'Le décodeur `$className.fromMap` a une signature INCOMPATIBLE avec le '
      'registre (DW-ES14-1 / AD-4). Attendu : exactement UN paramètre '
      'positionnel requis auquel un `Map<String, dynamic>` soit ASSIGNABLE '
      '(`Map<String, dynamic>`, `Map<String, Object?>`, un typedef alias… tous '
      'conviennent), tous les autres paramètres étant OPTIONNELS (nommés ou '
      'positionnels). Trouvé : '
      '(${params.map((p) => '${p.type.getDisplayString()} ${p.name}'
          '${p.isRequired ? '' : '?'}').join(', ')}). '
      'Aucun repli sur `_\$${className}FromMap` n\'est possible : il '
      'détruirait `extra`/`extension`/`source` sur la voie `registry.decode`.',
      element: decoder,
    );
  }

  /// **H1 pt. 2** — sur une classe `ZExtensible`, une **DÉLÉGATION NUE** à
  /// `_$XxxFromMap` est un **ÉCHEC DE BUILD** : c'est *littéralement* DW-ES14-1
  /// (le codegen ignore `extra`), et c'était le geste que l'ancien message
  /// d'erreur **dictait**.
  ///
  /// Lecture du **corps** par l'AST (`ParsedLibraryResult.getFragmentDeclaration`)
  /// — **jamais de regex sur du Dart** (R5).
  ///
  /// ⚠️ **Ce contrôle est un filet de FORME** : il attrape le geste exact que le
  /// message prescrivait, pas toute factory impotente (un corps ré-écrit à la
  /// main qui « oublie » `extra:` lui échappe). Le filet de **POUVOIR** — celui
  /// qui observe vraiment — est le garde runtime émis par [_emitRegister]. Si
  /// l'AST est indisponible (session absente), on ne **dégrade pas en silence**
  /// (R6) : le garde runtime reste émis inconditionnellement et couvre ce cas.
  void _rejectNakedCodegenDelegation(
    ExecutableElement decoder,
    String className,
  ) {
    final body = _bodyAstOf(decoder);
    if (body == null) return; // Pouvoir toujours gardé au runtime (cf. dartdoc).
    if (!_isNakedCodegenDelegation(body, className)) return;

    throw InvalidGenerationSourceError(
      '`$className.fromMap` DÉLÈGUE NUEMENT à `_\$${className}FromMap` alors que '
      '$className est `ZExtensible` (slot `extra`, AD-4) — c\'est EXACTEMENT '
      'DW-ES14-1 : `_\$${className}FromMap` ne connaît QUE les champs '
      '`@ZcrudField` et laisse `extra` VIDE. Le build serait vert et '
      '`registry.decode` DÉTRUIRAIT toute clé métier inconnue du schéma, à '
      'chaque cycle lecture→écriture — irréversible.\n'
      '${_prescription(className, extensible: true)}',
      element: decoder,
    );
  }

  /// Corps AST du décodeur [decoder] (factory ou méthode statique), ou `null` si
  /// l'AST n'est pas atteignable depuis la session d'analyse.
  FunctionBody? _bodyAstOf(ExecutableElement decoder) {
    final session = decoder.session;
    if (session == null) return null;
    final parsed = session.getParsedLibraryByElement(decoder.library);
    if (parsed is! ParsedLibraryResult) return null;
    final node = parsed.getFragmentDeclaration(decoder.firstFragment)?.node;
    if (node is ConstructorDeclaration) return node.body;
    if (node is MethodDeclaration) return node.body;
    return null;
  }

  /// `true` si [body] se réduit à `_$XxxFromMap(map)` — forme `=> …` **ou** bloc
  /// à `return` unique. Rien d'autre n'est jugé : ce contrôle ne prétend pas
  /// décider si un corps quelconque peuple `extra` (c'est le rôle du garde
  /// runtime), seulement refuser le geste précis que l'ancien message dictait.
  bool _isNakedCodegenDelegation(FunctionBody body, String className) {
    Expression? expr;
    if (body is ExpressionFunctionBody) {
      expr = body.expression;
    } else if (body is BlockFunctionBody) {
      final statements = body.block.statements;
      if (statements.length != 1) return false;
      final only = statements.first;
      if (only is ReturnStatement) expr = only.expression;
    }
    if (expr is! MethodInvocation) return false;
    if (expr.target != null) return false;
    return expr.methodName.name == '_\$${className}FromMap';
  }

  // --------------------------------------------------------------------------
  // Collecte des champs (statique).
  // --------------------------------------------------------------------------

  List<_Field> _collectFields(ClassElement element, ZFieldRename rename) {
    final fields = <_Field>[];
    final seenKeys = <String>{};
    for (final field in element.fields) {
      // analyzer 12 : `Element.isSynthetic` a été retiré de l'API publique. Le
      // remplaçant sémantique sur `PropertyInducingElement` est
      // `isOriginDeclaration` (le champ vient d'une `FieldDeclaration` /
      // `EnumConstantDeclaration` explicite) ; sa négation couvre exactement
      // l'ancien « synthétique » (propriété induite par un getter/setter), et
      // reste conservatrice face à d'éventuelles futures origines.
      if (field.isStatic || !field.isOriginDeclaration) continue;
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

    // Hint B14 : lecture STATIQUE de `persistAs` (revive accessor == 'timestamp')
    // — jamais d'exécution/`reflectable`. Absent/`iso8601` ⇒ `false` (aucun champ
    // collecté dans `$XxxTimestampFields`).
    final persistAsTimestamp = reader != null &&
        !reader.read('persistAs').isNull &&
        reader.read('persistAs').revive().accessor.split('.').last ==
            'timestamp';

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
      persistAsTimestamp: persistAsTimestamp,
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
    // Plage de dates `ZDateRange` (AD-47) : (dé)sérialisation DÉFENSIVE via le
    // helper `_$asDateRange` (bâti sur `ZDateRange.fromJsonSafe` → jamais de
    // throw) ; `toMap` via `.toJson()`. Patron strict de la branche `DateTime`.
    if (_typeName(type) == 'ZDateRange') {
      return (_Cat.dateRangeType, null, 'dateRange');
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
      case _Cat.dateRangeType:
        return orDef('_\$asDateRange($m)');
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
      case _Cat.dateRangeType:
        // Repli sûr d'un champ `ZDateRange` NON nullable (invariant `end >= start`
        // respecté : plage dégénérée epoch→epoch). En pratique un champ dateRange
        // est presque toujours nullable ⇒ repli `null` (branche au-dessus).
        return 'ZDateRange(start: DateTime.fromMillisecondsSinceEpoch(0), '
            'end: DateTime.fromMillisecondsSinceEpoch(0))';
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
      case _Cat.dateRangeType:
        return '$v$q.toJson()';
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
      // DP-13 : `showIfNull` a pour défaut `false` (côté annotation ET
      // `ZFieldSpec`). On n'émet donc que la valeur NON-défaut (`true`) — sinon le
      // flip du défaut serait silencieusement écrasé. `@ZcrudField()` (défaut
      // false) ⇒ aucune émission ⇒ `ZFieldSpec` prend son défaut `false` (parité
      // DODLP). Opt-in `@ZcrudField(showIfNull: true)` ⇒ `showIfNull: true` émis.
      if (r.read('showIfNull').boolValue) parts.add('showIfNull: true');
      // DP-12 : ornements déclaratifs (const AST re-émis 1:1) + hint/helper.
      if (!r.read('leading').isNull) {
        parts.add('leading: ${_emitConst(r.read('leading'))}');
      }
      if (!r.read('prefix').isNull) {
        parts.add('prefix: ${_emitConst(r.read('prefix'))}');
      }
      if (!r.read('suffix').isNull) {
        parts.add('suffix: ${_emitConst(r.read('suffix'))}');
      }
      if (!r.read('hintText').isNull) {
        parts.add('hintText: ${_emitConst(r.read('hintText'))}');
      }
      if (!r.read('helperText').isNull) {
        parts.add('helperText: ${_emitConst(r.read('helperText'))}');
      }
    }
    if (f.multiple) parts.add('multiple: true');
    if (f.isId) parts.add('isId: true');
    return '  ZFieldSpec(${parts.join(', ')}),';
  }

  // --------------------------------------------------------------------------
  // Émission — register(ZcrudRegistry).
  // --------------------------------------------------------------------------

  String _emitRegister(
    String className,
    String kind, {
    required bool extensible,
    required _ContextShape ctx,
  }) {
    // ⚠️ `fromMap: $className.fromMap` — le décodeur de **DOMAINE** (DW-ES14-1) :
    // lui seul peuple les canaux HORS-codegen (`extra` AD-4, `source`), là où
    // `_$${className}FromMap` (codegen) les IGNORE — ce qui détruisait toute clé
    // métier inconnue sur la voie `registry.decode`. Existence + compatibilité de
    // signature sont VÉRIFIÉES (`_requireDomainFromMap`) : jamais de repli.
    // Le tear-off reste assignable à `T Function(Map<String, dynamic>)` même si le
    // décodeur déclare des paramètres OPTIONNELS supplémentaires (sous-typage Dart).
    final doc = '/// Enregistre `$className` (kind "$kind") sur [registry] : '
        '(dé)sérialisation + schéma.\n';

    // 🔴 DW-ES14-2 (ES-3.0) — variantes CONSCIENTES DU CONTEXTE. Le tear-off nu
    // `$className.fromMap` laisse `extensionParser`/`sourceRegistry` à `null` ⇒
    // slot `extension` NON typé + `ZSourceRegistry` court-circuité sur la voie
    // registre (la SEULE qu'un store emprunte). On thread donc le ZDecodeContext.
    String contextArgs(String pad) {
      final args = <String>[];
      if (ctx.fromMapAny) {
        final params = <String>[];
        if (ctx.fromMapSourceRegistry) {
          params.add('$pad      sourceRegistry: context?.sourceRegistry,');
        }
        if (ctx.fromMapExtensionParser) {
          params.add('$pad      extensionParser: context?.extensionParser == null'
              '\n$pad          ? null'
              "\n$pad          : (json) => context!.extensionParser!('$kind', json),");
        }
        args.add('$pad  fromMapWithContext: (map, context) => '
            '$className.fromMap(\n'
            '$pad      map,\n'
            '${params.join('\n')}\n'
            '$pad  ),');
      }
      if (ctx.toMapSourceRegistry) {
        args.add('$pad  toMapWithContext: (value, context) =>\n'
            '$pad      value.toMap(sourceRegistry: context?.sourceRegistry),');
      }
      return args.isEmpty ? '' : '\n${args.join('\n')}';
    }

    /// Arguments de `registry.register<T>(…)`, indentés de [pad] espaces.
    String registerArgs(String pad) => "$pad  '$kind',\n"
        '$pad  fromMap: $className.fromMap,\n'
        '$pad  toMap: (value) => value.toMap(),\n'
        '$pad  fieldSpecs: \$${className}FieldSpecs,${contextArgs(pad)}\n'
        '$pad';

    if (!extensible) {
      // Aucun slot `extra` : rien à préserver, aucun garde à poser.
      return '${doc}void register$className(ZcrudRegistry registry) =>\n'
          '    registry.register<$className>(\n'
          '${registerArgs('    ')});';
    }

    // 🔴 H1 — GARDE EXÉCUTOIRE DW-ES14-1, émis pour toute classe `ZExtensible`.
    //
    // Le contrat de BUILD ne vérifie qu'une SIGNATURE (et refuse la délégation
    // nue) : il ne peut pas prouver qu'une factory ré-écrite à la main peuple
    // vraiment `extra`. Ce garde, lui, l'OBSERVE — il décode une sonde portant
    // une clé inconnue et exige qu'elle atterrisse dans `extra`. Il vit dans le
    // `.g.dart`, donc il SUIT LES PACKAGES PUBLIÉS : un consommateur externe
    // (DODLP, lex_douane) n'a pas `tool/reserved_keys_gate`, mais il a CE garde.
    //
    // ⚠️ Volontairement PAS sous `assert` : un `assert` s'évapore en release —
    // ce serait la dégradation silencieuse que R6 interdit. Le coût est un
    // décodage de sonde par kind, UNE FOIS, à l'enregistrement.
    return '${doc}void register$className(ZcrudRegistry registry) {\n'
        '  // DW-ES14-1 (AD-4) : POUVOIR observé, pas seulement signature vérifiée.\n'
        '  _\$zRequireExtraPreserved<$className>(\n'
        "    '$className',\n"
        '    $className.fromMap,\n'
        '    (value) => value.toMap(),\n'
        '    (value) => value.extra,\n'
        '  );\n'
        '  registry.register<$className>(\n'
        '${registerArgs('  ')});\n'
        '}';
  }

  // --------------------------------------------------------------------------
  // Émission — artefact NEUTRE des clés persistées en Timestamp (gap B14).
  // --------------------------------------------------------------------------

  /// Émet `const Set<String> $XxxTimestampFields = <String>{ 'key', ... };`
  /// listant les **clés persistées** (mêmes `f.key` que `toMap`/`_emitSpec`) des
  /// champs `@ZcrudField(persistAs: ZPersistAs.timestamp)`.
  ///
  /// **Métadonnée neutre pur-Dart (AD-5)** : littéraux `String` uniquement —
  /// aucun type `zcrud_core` ni `cloud_firestore`. `zcrud_firestore` la consomme
  /// via un `Set<String>` nu (le hint ne transite PAS par `ZFieldSpec`/registre
  /// pour éviter de toucher `zcrud_core`). Aucun champ hinté ⇒ `const <String>{}`.
  String _emitTimestampFields(String className, List<_Field> fields) {
    final keys = fields
        .where((f) => f.persistAsTimestamp)
        .map((f) => "'${f.key}'")
        .toList();
    final body = keys.isEmpty ? '<String>{}' : '<String>{\n  ${keys.join(',\n  ')},\n}';
    return '/// Clés persistées à encoder en `Timestamp` Firestore natif '
        '(gap B14, AD-5).\n'
        '///\n'
        '/// Métadonnée NEUTRE (littéraux `String`) : à passer au param '
        '`timestampFields`\n'
        '/// de `FirebaseZRepositoryImpl` — `Timestamp` reste confiné à '
        '`zcrud_firestore`.\n'
        'const Set<String> \$${className}TimestampFields = $body;';
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
/// `byName` nu), date ISO tolérante ; sentinelle `copyWith` ; **garde exécutoire
/// DW-ES14-1** (H1).
const _sharedHelpers = '''
/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _\$undefined = _ZUndefined();

/// Clé de SONDE du garde DW-ES14-1 : n'est le nom persisté d'AUCUN champ de
/// schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`.
const String _\$zExtraProbeKey = '$_extraProbeKey';

/// 🔴 **GARDE EXÉCUTOIRE DW-ES14-1 / AD-4** — émis dans le `register…` de toute
/// classe `ZExtensible` (H1, code-review ES-2.0).
///
/// ## Ce qu'il fait, et pourquoi il existe
///
/// Il **OBSERVE le POUVOIR** du couple (`fromMap`, `toMap`) au lieu de faire
/// confiance à sa forme : il décode une sonde portant une clé **inconnue du
/// schéma**, puis la ré-encode, et exige que la clé **survive au round-trip
/// COMPLET** — exactement le cycle lecture → écriture d'un store câblé sur
/// `registry.decode`/`registry.encode` (`FirebaseZRepositoryImpl.fromRegistry`).
///
/// Les **DEUX** jambes sont vérifiées, parce que la destruction peut venir de
/// l'une **ou** de l'autre :
///   - **(entrée)** `fromMap` amnésique — délègue à `_\$XxxFromMap` (la factory
///     du CODEGEN, qui ne connaît QUE les champs `@ZcrudField`) ou « oublie »
///     `extra:` en recopiant les champs ⇒ `extra` reste VIDE ;
///   - **(sortie)** `toMap` amnésique — n'étale pas `...extra` ⇒ ce qui avait été
///     préservé au décodage n'est **jamais réémis**. ⚠️ Le `toMap()` **généré**
///     (extension `XxxZcrud`) n'étale PAS `extra` : une entité `ZExtensible` qui
///     ne définit pas son propre `toMap()` d'instance tombe dans ce cas.
///
/// Le contrat de **BUILD** vérifie une signature et refuse la délégation nue ; il
/// ne peut pas prouver qu'un corps ré-écrit à la main préserve `extra`. **Ce
/// garde-ci le prouve**, à l'enregistrement, une fois par kind. C'est le seul
/// filet qui suive les packages **PUBLIÉS** : un consommateur externe a le
/// générateur, mais **pas** le harnais `tool/reserved_keys_gate`.
///
/// ## Pourquoi il n'est PAS sous `assert`
///
/// Un `assert` s'évapore en release : le filet disparaîtrait précisément là où la
/// perte de données est définitive. Aucune dégradation silencieuse (R6).
void _\$zRequireExtraPreserved<T>(
  String className,
  T Function(Map<String, dynamic> map) fromMap,
  Map<String, dynamic> Function(T value) toMap,
  Map<String, dynamic> Function(T value) extraOf,
) {
  final T decoded;
  try {
    decoded = fromMap(<String, dynamic>{_\$zExtraProbeKey: true});
  } catch (error) {
    throw StateError(
      'zcrud/DW-ES14-1 : `\$className.fromMap` a LEVÉ sur une map de sonde. '
      'Le décodage doit être DÉFENSIF (AD-10) : un champ absent ou corrompu ne '
      'fait JAMAIS échouer le parent. Erreur : \$error',
    );
  }

  // Jambe (entrée) — `fromMap` peuple-t-il `extra` ?
  if (extraOf(decoded)[_\$zExtraProbeKey] != true) {
    throw StateError(
      'zcrud/DW-ES14-1 (AD-4) : `\$className` est `ZExtensible`, mais son '
      'décodeur de domaine `\$className.fromMap` NE PEUPLE PAS `extra` — la clé '
      'hors-schéma de la sonde a été DÉTRUITE au DÉCODAGE.\\n'
      'Conséquence si ce registrar était utilisé (registry.decode / '
      'FirebaseZRepositoryImpl.fromRegistry) : TOUTE clé métier inconnue du '
      'schéma serait effacée à chaque cycle lecture -> écriture. IRRÉVERSIBLE.\\n'
      'CAUSE la plus fréquente : `factory \$className.fromMap(map) => '
      '_\\\$\${className}FromMap(map);` — la factory du CODEGEN ne connaît que les '
      'champs @ZcrudField.\\n'
      'GESTE : recopier les champs depuis `_\\\$\${className}FromMap(map)` PUIS '
      'passer `extra: _extraFrom(map)` (clés non réservées de la map). Patron de '
      'référence : `ZFlashcard.fromMap` / `ZStudyFolder.fromMap`.',
    );
  }

  // Jambe (sortie) — `toMap` réémet-il `extra` ?
  final Map<String, dynamic> encoded;
  try {
    encoded = toMap(decoded);
  } catch (error) {
    throw StateError(
      'zcrud/DW-ES14-1 : `\$className.toMap()` a LEVÉ sur une entité décodée '
      'depuis une map de sonde. Erreur : \$error',
    );
  }
  if (encoded[_\$zExtraProbeKey] != true) {
    throw StateError(
      'zcrud/DW-ES14-1 (AD-4) : `\$className.fromMap` préserve bien `extra`, '
      'mais `\$className.toMap()` NE LE RÉÉMET PAS — la clé hors-schéma est '
      'DÉTRUITE à l\\'ENCODAGE. Le round-trip d\\'un store est donc amnésique '
      'malgré un décodage correct.\\n'
      'CAUSE la plus fréquente : l\\'entité s\\'appuie sur le `toMap()` GÉNÉRÉ '
      '(extension `\${className}Zcrud`), qui n\\'émet QUE les champs @ZcrudField '
      'et n\\'étale PAS `extra`.\\n'
      'GESTE : déclarer un `toMap()` d\\'INSTANCE qui étale l\\'échappatoire — '
      '`Map<String, dynamic> toMap() => {...extra, ...\${className}Zcrud(this).toMap()};` '
      '(patron `ZFlashcard.toMap` / `ZStudyFolder.toMap`).',
    );
  }
}

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

/// Décode défensivement une plage `ZDateRange` (AD-10/AD-47) : délègue à
/// `ZDateRange.fromJsonSafe` — `null` sur TOUTE anomalie (non-map, clé absente,
/// valeur non-`String`, date non-ISO, `start > end`), jamais de throw. Le parent
/// survit toujours (champ corrompu → `null`).
ZDateRange? _\$asDateRange(Object? v) => ZDateRange.fromJsonSafe(v);

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
  dateRangeType,
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
    required this.persistAsTimestamp,
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

  /// Hint B14 : le champ doit être persisté en `Timestamp` natif côté Firestore
  /// (clé collectée dans `$XxxTimestampFields`). Défaut `false` (ISO-8601).
  final bool persistAsTimestamp;
}
