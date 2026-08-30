/// Générateur `source_gen` du moteur codegen `zcrud` (invariant AD-3).
///
/// Lit STATIQUEMENT (`analyzer`/`ConstantReader`/`TypeChecker` — **jamais**
/// `reflectable`, **jamais** d'exécution d'annotation) les classes annotées
/// `@ZcrudModel` (+ champs `@ZcrudField`/`@ZcrudId`) et émet, dans le
/// `part '<file>.g.dart'` :
///   1. `_$XxxFromMap` — reconstruction **défensive** (invariant AD-10 :
///      champ absent → `defaultValue`/valeur sûre ; enum inconnu → repli,
///      jamais `byName` nu ; sous-objet corrompu → n'échoue jamais le
///      parent) ;
///   2. l'extension publique `XxxZcrud` — `toMap()` (snake_case, enum `.name`
///      camelCase, dates ISO-8601, récursion sous-objets) + `copyWith()` **à
///      sentinelle** (reset-`null` distinct de « non fourni ») ;
///   2 bis. le mixin `_$XxxZcrud` — **les mêmes** `toMap()`/`copyWith()`, mais
///      en membres d'INSTANCE, à appliquer (`class Xxx … with _$XxxZcrud`)
///      quand un membre d'extension ne suffit pas : une extension ne satisfait
///      jamais un membre abstrait hérité et reste invisible à un appel fait à
///      travers un type de base. Application facultative, corps identiques ;
///   3. `$XxxFieldSpecs` — `List<ZFieldSpec>` projeté 1:1 de `@ZcrudField`, avec
///      **inférence de type** si `@ZcrudField.type == null` ;
///   4. `registerXxx(ZcrudRegistry)` — câblage `kind → (fromMap, toMap,
///      fieldSpecs)`.
///
/// **Échec de build EXPLICITE** (`InvalidGenerationSourceError`, jamais un cast
/// `null` silencieux — invariant AD-3) : type de champ non (dé)sérialisable,
/// cible non classe, collision de clé persistée, valeur d'énumération
/// d'annotation non reconnue, `@ZcrudIgnore` combiné à `@ZcrudField`/`@ZcrudId`
/// sur le même champ, **champ non annoté dont le type n'est pas sérialisable**
/// (le seul silence qui coûterait des données), **enum redéclarant `name`
/// comme membre d'instance** (l'encodage `.name` émettrait le membre déclaré —
/// un libellé d'affichage — au lieu du nom technique attendu par le décodeur),
/// **`toMap()`/`copyWith()` hérité en membre d'INSTANCE sans application du
/// mixin `_$XxxZcrud`** (l'extension émise serait alors sémantiquement morte —
/// un membre d'extension ne surcharge jamais un membre d'instance hérité).
///
/// ## Ce que le `toMap()` émis met dans la map — et ce qu'il n'y met pas
///
/// **Champs.** Seuls les champs annotés `@ZcrudField`/`@ZcrudId` sont émis —
/// qu'ils soient déclarés sur la classe annotée ou **hérités** d'une
/// super-classe ou d'un mixin hors SDK. Les champs hérités viennent en tête, dans
/// l'ordre de linéarisation Dart (ancêtre le plus lointain d'abord) ; une
/// redéclaration plus proche masque celle de base. Un champ hérité annoté que le
/// constructeur non nommé n'expose pas (`super.<champ>`) est un échec de build.
/// Un champ non annoté **de type sérialisable** est ignoré en silence (contrat
/// assumé : c'est ainsi qu'un modèle garde des champs d'exécution hors
/// persistance). Un champ non annoté dont le type n'est **pas** sérialisable est
/// au contraire un **échec de build** : `@ZcrudIgnore` est la façon d'assumer
/// l'exclusion. Le contrôle couvre les champs déclarés dans la classe annotée
/// **et** les champs concrets hérités d'une super-classe ou d'un mixin hors SDK.
/// En sont exemptés — parce qu'un autre signal couvre déjà leur cas — les champs
/// **privés** (jamais persistables sous leur propre nom) et, sur une classe
/// `ZExtensible`, les slots du contrat AD-4 (`extension`, `extra`), déjà gardés
/// par le contrat de factory de domaine et le garde d'extensibilité émis.
///
/// **Clés de synchronisation.** `updated_at` et `is_deleted`
/// (`_kReservedSyncKeys`, miroir de `ZSyncMeta.reservedKeys`) appartiennent à la
/// couche de synchronisation, **hors-entité**. Un modèle qui en porte un miroir
/// nullable voit sa clé **omise quand la valeur est nulle**, et émise sinon.
/// L'asymétrie visible entre `created_at` (toujours émis, `null` compris) et
/// `updated_at` ne tient donc pas au type du champ mais au **statut de la clé** :
/// l'émettre à `null` inconditionnellement signalerait une collision avec la
/// couche de sync à chaque écriture de chaque entité concernée, sans qu'aucun de
/// ces cas ne porte de signal ; ne pas émettre la valeur **non nulle** casserait
/// la fidélité du round-trip `fromMap(toMap(x))`.
///
/// **Dates.** Toute date est émise en **`String` ISO-8601**, y compris sous
/// `@ZcrudField(persistAs: ZPersistAs.timestamp)`. Ce hint n'agit pas sur le
/// `toMap()` : il alimente la métadonnée neutre `$XxxTimestampFields`, que le
/// **repository** applique pour écrire le format natif du backend (le type natif
/// reste confiné à son adaptateur — invariant AD-5). Conséquence en migration
/// progressive : un moteur hérité qui appelle `toMap()` **directement**, sans
/// passer par le repository, écrit des `String` là où le parc attend le type
/// natif.
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

/// `TypeChecker` (non-`reflectable`, par nom de type) des annotations.
const _fieldChecker =
    TypeChecker.typeNamed(ZcrudField, inPackage: 'zcrud_annotations');
const _idChecker =
    TypeChecker.typeNamed(ZcrudId, inPackage: 'zcrud_annotations');
const _modelChecker =
    TypeChecker.typeNamed(ZcrudModel, inPackage: 'zcrud_annotations');
const _ignoreChecker =
    TypeChecker.typeNamed(ZcrudIgnore, inPackage: 'zcrud_annotations');

/// `TypeChecker` du mixin `ZExtensible` (AD-4).
///
/// `isAssignableFrom` résout la hiérarchie **TRANSITIVEMENT** (super-classe,
/// mixin d'un super-type, interface) : `class ZSmartNote extends ZBaseStudyEntity`
/// où la base porte `with ZExtensible` est bien reconnue (vérifié).
/// C'est ce qui distingue les classes qui ONT un slot `extra` — les seules pour
/// lesquelles le garde d'extensibilité a un sens.
const _extensibleChecker =
    TypeChecker.typeNamed(ZExtensible, inPackage: 'zcrud_core');

/// Clé de SONDE du garde runtime d'extensibilité (émis dans chaque `.g.dart`).
///
/// Volontairement improbable : elle n'est le nom persisté d'aucun champ de
/// schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`. Une
/// entité conforme à AD-4 la fait donc **atterrir dans `extra`**.
const _extraProbeKey = 'zz__zcrud_extra_probe__';

/// Présence des collaborateurs INJECTABLES qu'une entité
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

  /// Cœur d'émission, **indépendant de [BuildStep]** (testable directement,
  /// sans pipeline `build_runner`).
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

    final rename = _renameOf(
      annotation.read('fieldRename'),
      element,
      // Lecture de SECOURS, évaluée seulement si la constante est illisible :
      // le texte réellement écrit sur l'annotation. Coût AST nul sur le chemin
      // nominal.
      writtenArgument: () => _writtenRenameArgumentOf(element),
    );
    final kind = annotation.read('kind').isNull
        ? className
        : annotation.read('kind').stringValue;

    // Un membre d'EXTENSION ne surcharge jamais un membre d'INSTANCE hérité :
    // si la hiérarchie en déclare un, l'extension émise serait sémantiquement
    // MORTE. Contrôlé AVANT toute émission.
    _rejectDeadExtensionMembers(element, className);

    final fields = _collectFields(element, rename);

    // (AD-4) : le registrar DOIT décoder par la factory de DOMAINE.
    // Contrat vérifié PAR MACHINE, jamais présumé.
    final isExtensible = _requireDomainFromMap(element, className);

    // Forme des collaborateurs INJECTABLES que la factory de
    // domaine accepte (`extensionParser`/`sourceRegistry`). Le registrar thread le
    // ZDecodeContext dans CES paramètres — plus jamais un tear-off nu qui les
    // laisse `null`. Détecté sur l'AST des paramètres (jamais de regex).
    final ctxShape = _contextShapeOf(element);

    final buffer = StringBuffer()
      ..writeln(_emitFromMap(className, fields))
      ..writeln()
      ..writeln(_emitExtension(className, fields))
      ..writeln()
      ..writeln(_emitInstanceMixin(className, fields))
      ..writeln()
      ..writeln(_emitFieldSpecs(className, fields))
      ..writeln()
      ..writeln(_emitPersistedKeys(className, fields))
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
  // Contrat — factory de DOMAINE `Xxx.fromMap` obligatoire.
  // --------------------------------------------------------------------------

  /// Exige que la classe annotée déclare un décodeur de **domaine**
  /// `Xxx.fromMap(Map<String, dynamic> map)` — factory **ou méthode statique**
  /// — que [_emitRegister] câble sur le registre (`fromMap: Xxx.fromMap`).
  /// Retourne `true` si la classe est **`ZExtensible`** (transitivement).
  ///
  /// ## Pourquoi un ÉCHEC DE BUILD, jamais un repli
  ///
  /// Le repli « naturel » serait `_$XxxFromMap` — la factory du **codegen**, qui
  /// ne connaît QUE les champs `@ZcrudField` et ne peuple donc **NI `extra`, NI
  /// `extension`, NI `source`** (canaux **hors-codegen**, câblés à la main par la
  /// factory de domaine). Sur la voie registre (`registry.decode`,
  /// `FirebaseZRepositoryImpl.fromRegistry`), toute clé métier inconnue du
  /// schéma serait alors **détruite** à chaque cycle lecture → écriture
  /// (`toMap()` ne réémet que ce que `fromMap` a peuplé) — violation d'**AD-4**,
  /// irréversible.
  ///
  /// ## Un contrat de SIGNATURE seul ne prouve RIEN
  ///
  /// Valider **l'EXISTENCE** d'une signature ne garantit jamais le **POUVOIR**
  /// de préserver `extra` — un message d'erreur qui se contenterait de
  /// **prescrire la forme suivante** serait trompeur :
  ///
  /// ```dart
  /// factory Xxx.fromMap(Map<String, dynamic> map) => _$XxxFromMap(map); // ⛔
  /// ```
  ///
  /// Sur une classe `ZExtensible`, **ce geste détruit `extra`** tout en
  /// satisfaisant un contrat de simple présence : build VERT, perte de données
  /// silencieuse. D'où trois protections complémentaires, toutes **par
  /// machine** :
  ///
  /// 1. le message d'erreur **prescrit la forme QUI MARCHE** (celle de
  ///    `ZFlashcard`/`ZStudyFolder` : `extra: _extraFrom(map)` sur les clés non
  ///    réservées) ;
  /// 2. **BUILD ROUGE** si une classe `ZExtensible` délègue **NUEMENT** à
  ///    `_$XxxFromMap` — détecté sur l'**AST du corps** du décodeur
  ///    (`package:analyzer`, jamais de regex) ;
  /// 3. **GARDE RUNTIME** émis dans le registrar de toute classe `ZExtensible`
  ///    ([_emitRegister]) : il **OBSERVE** le pouvoir (décode une sonde, exige la
  ///    clé inconnue dans `extra`) au lieu de juger une forme. C'est le seul
  ///    filet qui suive les packages **PUBLIÉS** chez un consommateur externe,
  ///    lequel n'a **pas** le harnais `reserved_keys_gate` interne au dépôt. Il
  ///    attrape **toute** factory impotente, y compris celles que (2) ne peut
  ///    pas voir (corps ré-écrit à la main sans `extra:`).
  bool _requireDomainFromMap(ClassElement element, String className) {
    final extensible = _extensibleChecker.isAssignableFrom(element);

    // Un `fromMap` STATIQUE est un tear-off parfaitement valide
    // (`Xxx.fromMap` s'assigne au registre exactement comme une factory) : il est
    // ACCEPTÉ. Se limiter à `element.constructors` affirmerait à tort
    // « ne déclare AUCUNE factory fromMap » pour un mainteneur qui en a bien une
    // sous forme de méthode statique.
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

  /// Forme des collaborateurs INJECTABLES de l'entité.
  ///
  /// Inspecte l'AST des paramètres NOMMÉS (jamais de regex) de la factory de
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

  /// Le **geste correctif**, écrit dans la forme QUI MARCHE.
  ///
  /// Une classe **`ZExtensible`** ne peut PAS se contenter de déléguer à
  /// `_$XxxFromMap` : la prescription est donc **différente** selon le cas.
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
  /// les **TYPES** (`TypeSystem`), jamais sur une chaîne d'affichage.
  ///
  /// Comparer `type.getDisplayString() == 'Map<String, dynamic>'` **REJETTERAIT**
  /// (échec de build) des décodeurs légaux et **assignables** —
  /// `Map<String, Object?>` (mutuellement sous-type en Dart), un typedef alias
  /// (`typedef JsonMap = Map<String, dynamic>` → `getDisplayString()` rend
  /// `JsonMap`), une forme préfixée par un import. Le critère RÉEL est
  /// l'assignabilité d'un `Map<String, dynamic>` au paramètre — c'est exactement
  /// ce que le tear-off exige (vérifié : les 3 formes passent).
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

  /// Sur une classe `ZExtensible`, une **DÉLÉGATION NUE** à
  /// `_$XxxFromMap` est un **ÉCHEC DE BUILD** : le codegen ignore `extra`, donc
  /// ce geste le détruirait silencieusement s'il était toléré.
  ///
  /// Lecture du **corps** par l'AST (`ParsedLibraryResult.getFragmentDeclaration`)
  /// — **jamais de regex sur du Dart**.
  ///
  /// **Ce contrôle est un filet de FORME** : il attrape le geste précis d'une
  /// délégation nue, pas toute factory impotente (un corps ré-écrit à la
  /// main qui « oublie » `extra:` lui échappe). Le filet de **POUVOIR** — celui
  /// qui observe vraiment — est le garde runtime émis par [_emitRegister]. Si
  /// l'AST est indisponible (session absente), on ne **dégrade pas en silence** :
  /// le garde runtime reste émis inconditionnellement et couvre ce cas.
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
  // Contrat — l'extension émise doit être ATTEIGNABLE.
  // --------------------------------------------------------------------------

  /// Membres que le générateur émet **à la fois** dans l'extension publique
  /// `XxxZcrud` et dans le mixin d'instance `_$XxxZcrud`.
  static const List<String> _kInstanceEmittedMembers = <String>[
    'toMap',
    'copyWith',
  ];

  /// Refuse une extension générée **sémantiquement morte**.
  ///
  /// Un membre d'**extension** n'est ni virtuel ni héritable : il ne surcharge
  /// **jamais** un membre d'instance homonyme hérité d'une super-classe, d'un
  /// mixin ou d'une interface. Si la hiérarchie de la classe annotée déclare
  /// déjà `toMap()` (ou `copyWith()`) comme membre d'instance — abstrait ou
  /// concret — et que la classe **n'applique pas** le mixin `_$XxxZcrud`, le
  /// `toMap()` émis dans l'extension n'est **jamais appelé** : c'est
  /// l'implémentation héritée qui répond, y compris sur `model.toMap()` écrit
  /// depuis la classe elle-même.
  ///
  /// Aucun signal existant ne couvre ce cas : le `.g.dart` compile, `analyze`
  /// est vert, l'objet en mémoire est correct — et les champs propres du modèle
  /// ne sont **jamais écrits** au document persisté. D'où un **échec de build**.
  ///
  /// **Trois cas hors périmètre**, et pourquoi :
  ///
  ///   - la classe annotée **applique** le mixin `_$XxxZcrud` : elle porte alors
  ///     des membres d'instance réels, qui surchargent l'héritage. C'est le
  ///     remède ;
  ///   - la classe annotée **déclare elle-même** le membre : le choix est écrit
  ///     dans sa propre source, sous l'œil de son auteur — l'extension est
  ///     inerte, mais délibérément ;
  ///   - le membre hérité vient d'une **extension** : une extension ne se
  ///     transmet pas par héritage et ne masque rien. Seuls les membres portés
  ///     par les `InterfaceElement` des super-types sont examinés, ce qui exclut
  ///     structurellement ce cas.
  void _rejectDeadExtensionMembers(ClassElement element, String className) {
    if (_appliesGeneratedMixin(element, className)) return;
    for (final memberName in _kInstanceEmittedMembers) {
      final declaredLocally =
          element.methods.any((m) => !m.isStatic && m.name == memberName);
      if (declaredLocally) continue;
      final inherited = _inheritedInstanceMember(element, memberName);
      if (inherited == null) continue;
      throw InvalidGenerationSourceError(
        '$className hérite un `$memberName()` déclaré comme MEMBRE D\'INSTANCE '
        'par ${inherited.owner} (${inherited.where}), et n\'applique PAS le '
        'mixin `_\$${className}Zcrud`.\n'
        'Un membre d\'EXTENSION ne surcharge JAMAIS un membre d\'instance '
        'hérité : le `$memberName()` émis dans l\'extension `${className}Zcrud` '
        'ne serait jamais appelé — c\'est l\'implémentation héritée qui '
        'répondrait, y compris depuis $className. L\'extension serait '
        'SYNTAXIQUEMENT PRÉSENTE et SÉMANTIQUEMENT MORTE : build vert, '
        '`analyze` vert, objet en mémoire correct, et les champs propres de '
        '$className JAMAIS ÉCRITS au document persisté.\n'
        'GESTE : appliquer le mixin d\'instance émis —\n'
        '    class $className extends … with _\$${className}Zcrud { … }\n'
        'Il porte les MÊMES corps que l\'extension (même map, à l\'octet), mais '
        'en membres d\'instance : ils surchargent l\'héritage et répondent en '
        'appel polymorphe.\n'
        'ALTERNATIVE ASSUMÉE : déclarer `$memberName()` à la main sur '
        '$className — le codegen cesse alors de l\'écrire, et la composition '
        'avec la base est à votre charge.',
        element: element,
      );
    }
  }

  /// `true` si la classe annotée applique le mixin généré `_$XxxZcrud`.
  ///
  /// Deux lectures, dans cet ordre : les super-types **résolus**
  /// (`element.mixins`), puis — parce que le mixin vit dans le `part` généré et
  /// n'est donc pas résolvable au **premier** build — la clause `with` de l'AST.
  /// Sans la seconde, tout premier build d'un modèle conforme échouerait.
  bool _appliesGeneratedMixin(ClassElement element, String className) {
    final expected = '_\$${className}Zcrud';
    for (final applied in element.mixins) {
      if (applied.element.name == expected) return true;
    }
    final node = _classAstOf(element);
    final withClause = node?.withClause;
    if (withClause == null) return false;
    // Comparaison sur `toSource()` : le nom du type d'un `with` non résolu
    // reste lisible sur l'AST, là où l'élément est absent.
    return withClause.mixinTypes.any((t) => t.toSource().trim() == expected);
  }

  /// Déclaration AST de la classe annotée, ou `null` si la session d'analyse
  /// n'est pas atteignable.
  ClassDeclaration? _classAstOf(ClassElement element) {
    final session = element.session;
    if (session == null) return null;
    final parsed = session.getParsedLibraryByElement(element.library);
    if (parsed is! ParsedLibraryResult) return null;
    final node = parsed.getFragmentDeclaration(element.firstFragment)?.node;
    return node is ClassDeclaration ? node : null;
  }

  /// Source EXACTE de l'argument `fieldRename:` tel qu'il est **écrit** sur
  /// `@ZcrudModel`, ou `null` si l'annotation ne le mentionne pas — ou si l'AST
  /// n'est pas atteignable.
  ///
  /// Sert uniquement de lecture de secours quand la constante de l'annotation
  /// est illisible : le texte écrit reste disponible là où la valeur résolue ne
  /// l'est plus. Rien n'est deviné — l'appelant n'accepte que la forme
  /// littérale `ZFieldRename.<valeur>`.
  String? _writtenRenameArgumentOf(Element element) {
    if (element is! ClassElement) return null;
    final node = _classAstOf(element);
    if (node == null) return null;
    for (final annotation in node.metadata) {
      // Le nom peut être préfixé par un import (`z.ZcrudModel`) : on compare le
      // dernier segment, jamais le nom nu.
      if (annotation.name.name.split('.').last != 'ZcrudModel') continue;
      for (final argument
          in annotation.arguments?.arguments ?? const <Expression>[]) {
        if (argument is! NamedExpression) continue;
        if (argument.name.label.name != 'fieldRename') continue;
        return argument.expression.toSource();
      }
    }
    return null;
  }

  /// Le membre d'instance nommé [memberName] déclaré par un super-type hors SDK
  /// de [element] (super-classe à quelque niveau, mixin ou interface), ou `null`.
  ///
  /// Le mixin généré `_$XxxZcrud` est exclu : c'est le remède, jamais le défaut.
  ({String owner, String where})? _inheritedInstanceMember(
    ClassElement element,
    String memberName,
  ) {
    final generated = '_\$${element.name}Zcrud';
    for (final supertype in element.allSupertypes) {
      final owner = supertype.element;
      if (owner.library.uri.isScheme('dart')) continue;
      if (owner.name == generated) continue;
      for (final method in owner.methods) {
        if (method.isStatic || method.name != memberName) continue;
        return (
          owner: owner.name ?? '<anonyme>',
          where: _declarationSite(method),
        );
      }
    }
    return null;
  }

  /// `uri:ligne` de la déclaration de [member] — de quoi ouvrir le fichier
  /// fautif depuis le message d'erreur, sans le chercher. Repli sur l'URI seule
  /// si la position n'est pas atteignable (déclaration sans nom d'origine).
  String _declarationSite(ExecutableElement member) {
    final fragment = member.firstFragment;
    final unit = fragment.libraryFragment;
    final uri = unit.source.uri.toString();
    final offset = fragment.nameOffset;
    if (offset == null) return uri;
    return '$uri:${unit.lineInfo.getLocation(offset).lineNumber}';
  }

  // --------------------------------------------------------------------------
  // Collecte des champs (statique).
  // --------------------------------------------------------------------------

  List<_Field> _collectFields(ClassElement element, ZFieldRename rename) {
    final fields = <_Field>[];
    final seenKeys = <String>{};
    final silentlyLost = <FieldElement>[];
    final maskedEnums = <(FieldElement, EnumElement)>[];
    // (AD-4) Une classe `ZExtensible` porte par CONTRAT les slots hors-codegen
    // `extension`/`extra` : ils sont exemptés du contrôle de perte silencieuse
    // (cf. [_isSilentlyLost]).
    final extensible = _extensibleChecker.isAssignableFrom(element);
    // Champs annotés HÉRITÉS d'abord (ordre de linéarisation Dart : ancêtre le
    // plus lointain → classe annotée), champs locaux ensuite. Un champ hérité
    // n'est collecté que si le constructeur non nommé de la classe l'accepte —
    // sans quoi le code émis ne compilerait pas ([_requireInheritedInConstructor]).
    final inherited = _inheritedAnnotatedFields(element);
    if (inherited.isNotEmpty) _requireInheritedInConstructor(element, inherited);
    for (final field in <FieldElement>[...inherited, ...element.fields]) {
      // analyzer 12 : `Element.isSynthetic` a été retiré de l'API publique. Le
      // remplaçant sémantique sur `PropertyInducingElement` est
      // `isOriginDeclaration` (le champ vient d'une `FieldDeclaration` /
      // `EnumConstantDeclaration` explicite) ; sa négation couvre exactement
      // l'ancien « synthétique » (propriété induite par un getter/setter), et
      // reste conservatrice face à d'éventuelles futures origines.
      if (field.isStatic || !field.isOriginDeclaration) continue;
      final fieldAnno = _fieldChecker.firstAnnotationOf(field);
      final isId = _idChecker.hasAnnotationOf(field);
      _rejectContradictoryIgnore(field, serialized: fieldAnno != null || isId);
      if (fieldAnno == null && !isId) {
        if (_isSilentlyLost(field, extensible: extensible)) {
          silentlyLost.add(field);
        }
        continue;
      }

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

      final resolved = _resolveField(field, dartName, key, reader, isId);
      if (resolved.category == _Cat.enumType ||
          resolved.category == _Cat.listEnum) {
        final masked = _maskedNameEnum(field.type);
        if (masked != null) maskedEnums.add((field, masked));
      }
      fields.add(resolved);
    }
    if (maskedEnums.isNotEmpty) {
      _rejectMaskedEnumName(element, maskedEnums);
    }
    _collectInheritedSilentlyLost(element, extensible, silentlyLost);
    if (silentlyLost.isNotEmpty) {
      _rejectSilentlyLostFields(element, silentlyLost);
    }
    return fields;
  }

  /// Champs concrets **hérités** portant `@ZcrudField`/`@ZcrudId`, dans l'ordre
  /// de **linéarisation Dart** (ancêtre le plus lointain → mixins → classe
  /// annotée) — donc STABLE d'un build à l'autre.
  ///
  /// ## Ce que ça change pour l'appelant
  ///
  /// Un champ déclaré et annoté dans une classe de base entre désormais dans
  /// `toMap()`, dans le décodeur émis et dans `$XxxFieldSpecs` de la
  /// sous-classe, **avant** les champs déclarés localement. Sans cette collecte,
  /// il en était absent alors que son annotation demandait explicitement sa
  /// persistance : le build restait vert et la donnée disparaissait du document
  /// à la première écriture, sans aucun signal.
  ///
  /// **Masquage** : si un **champ** du même nom Dart est redéclaré plus près de
  /// la classe annotée (localement ou dans une base intermédiaire), c'est cette
  /// déclaration-là qui fait foi ; la plus lointaine est ignorée, jamais
  /// collectée deux fois. Deux champs de noms Dart différents résolvant vers la
  /// **même clé persistée** restent une collision — échec de build inchangé.
  ///
  /// Un **accesseur** (`DateTime get createdAt => …`) qui rétrécit un champ
  /// hérité ne masque **pas** : il n'apporte aucun stockage, et la spec du champ
  /// hérité reste collectée. Le `toMap()` émis lit `this.<champ>`, donc
  /// l'accesseur — le rétrécissement est honoré sans perdre la persistance. Si
  /// le constructeur non nommé n'expose pas le champ ainsi conservé, l'échec de
  /// build de [_requireInheritedInConstructor] le nomme.
  ///
  /// Les interfaces (`implements`) ne sont pas parcourues : elles n'apportent
  /// aucun stockage concret. Les bases du SDK non plus. Un champ hérité
  /// `abstract`, `static` ou synthétique (induit par un accesseur) est exclu :
  /// il n'a pas de stockage propre à persister.
  List<FieldElement> _inheritedAnnotatedFields(ClassElement element) {
    final bases = <InterfaceElement>[];
    final visited = <InterfaceElement>{};
    void walk(InterfaceElement e) {
      final superElement = e.supertype?.element;
      if (superElement != null) {
        walk(superElement);
        if (visited.add(superElement)) bases.add(superElement);
      }
      for (final mixin in e.mixins) {
        if (visited.add(mixin.element)) bases.add(mixin.element);
      }
    }

    walk(element);
    if (bases.isEmpty) return const <FieldElement>[];

    bool eligible(FieldElement field) =>
        !field.isStatic &&
        !field.isAbstract &&
        field.isOriginDeclaration &&
        (_fieldChecker.hasAnnotationOf(field) ||
            _idChecker.hasAnnotationOf(field));

    // Résolution du MASQUAGE : la déclaration la plus PROCHE de la classe
    // annotée gagne. `bases` est ordonné du plus lointain au plus proche, on le
    // parcourt donc à l'envers pour élire un vainqueur par nom.
    final winners = <String, FieldElement>{};
    // Seule une VRAIE redéclaration de champ masque. Un champ synthétique —
    // induit par un accesseur (`DateTime get createdAt => …`) — n'apporte aucun
    // stockage : le traiter comme un masquage ferait DISPARAÎTRE la spec du
    // champ hérité, en silence, alors que l'accesseur ne fait que rétrécir sa
    // lecture. `toMap()` lit `this.<champ>` : c'est l'accesseur qui répond,
    // exactement comme voulu.
    final masked = <String>{
      for (final f in element.fields)
        if (f.name != null && f.isOriginDeclaration) f.name!,
    };
    for (final base in bases.reversed) {
      if (base.library.uri.isScheme('dart')) continue;
      for (final field in base.fields) {
        final name = field.name;
        if (name == null || masked.contains(name)) continue;
        if (winners.containsKey(name)) continue;
        // Une redéclaration NON annotée plus proche masque aussi : elle vaut
        // renoncement explicite à la persistance de ce nom.
        if (!field.isStatic && field.isOriginDeclaration && !field.isAbstract) {
          winners[name] = field;
        }
      }
    }

    // Émission dans l'ordre de linéarisation (ancêtre le plus lointain d'abord).
    final ordered = <FieldElement>[];
    for (final base in bases) {
      if (base.library.uri.isScheme('dart')) continue;
      for (final field in base.fields) {
        final name = field.name;
        if (name == null) continue;
        if (!identical(winners[name], field)) continue;
        if (eligible(field)) ordered.add(field);
      }
    }
    return ordered;
  }

  /// Exige que le constructeur NON NOMMÉ de la classe annotée accepte chaque
  /// champ hérité collecté comme paramètre nommé (typiquement `super.xxx`).
  ///
  /// Le décodeur et le `copyWith` émis appellent `Xxx(champ: …)` : un champ
  /// hérité que le constructeur n'expose pas rendrait le `.g.dart` non
  /// compilable. Échec de build EXPLICITE et actionnable plutôt qu'une erreur
  /// d'analyse sur du code généré (invariant AD-3).
  ///
  /// Le contrôle ne porte que sur les champs **hérités** : un champ déclaré
  /// localement est sous l'œil direct de l'auteur de la classe, et le soumettre
  /// au même contrôle changerait le verdict de build de modèles existants.
  void _requireInheritedInConstructor(
    ClassElement element,
    List<FieldElement> inherited,
  ) {
    ConstructorElement? unnamed;
    for (final ctor in element.constructors) {
      final name = ctor.name;
      if (name == null || name.isEmpty || name == 'new') {
        unnamed = ctor;
        break;
      }
    }
    // Aucun constructeur non nommé : le code émis serait déjà invalide pour les
    // champs LOCAUX — ce contrôle-ci n'a rien à ajouter.
    if (unnamed == null) return;
    final accepted = <String>{
      for (final p in unnamed.formalParameters)
        if (p.isNamed && p.name != null) p.name!,
    };
    final missing = inherited
        .where((f) => f.name != null && !accepted.contains(f.name))
        .toList();
    if (missing.isEmpty) return;
    final inventory = missing
        .map((f) => '  - ${f.name} : ${f.type.getDisplayString()} '
            '(déclaré sur ${f.enclosingElement.name})')
        .join('\n');
    final plural = missing.length > 1;
    throw InvalidGenerationSourceError(
      '${missing.length} champ${plural ? 's' : ''} HÉRITÉ${plural ? 'S' : ''} '
      'annoté${plural ? 's' : ''} que le constructeur non nommé de '
      '${element.name} n\'accepte pas :\n$inventory\n'
      'Le décodeur et le `copyWith` émis appellent `${element.name}(champ: …)` : '
      'sans paramètre nommé correspondant, le `.g.dart` ne compilerait pas.\n'
      'DEUX REMÈDES, par champ :\n'
      '  1. exposer le champ dans le constructeur — `${element.name}({'
      'super.${missing.first.name}, …})` — c\'est le geste attendu ;\n'
      '  2. retirer l\'annotation de sérialisation sur la déclaration de base '
      'si ce champ ne doit pas être persisté par le codegen.',
      element: element,
    );
  }

  /// L'`EnumElement` du champ si son enum (élément de `List<T>` compris)
  /// REDÉCLARE `name` comme membre d'instance — champ ou getter, local ou
  /// hérité d'un mixin — masquant l'extension SDK `EnumName.name` ; `null`
  /// sinon.
  ///
  /// Détection STATIQUE : sur un enum standard, `name` n'est PAS un membre
  /// d'interface (c'est l'extension `EnumName` de `dart:core`, non masquable
  /// derrière la borne générique `Enum` du décodeur émis). La présence d'un
  /// champ d'instance `name` sur l'enum — déclaré (`final String name`) ou
  /// induit par un getter explicite (`String get name`) — signe donc
  /// exactement le masquage. Les mixins appliqués sont parcourus : un enum ne
  /// pouvant pas hériter d'implémentation autrement, ils couvrent toute
  /// implémentation non locale.
  EnumElement? _maskedNameEnum(DartType type) {
    var t = type;
    if (t.isDartCoreList && t is InterfaceType && t.typeArguments.isNotEmpty) {
      t = t.typeArguments.first;
    }
    final el = t.element;
    if (el is! EnumElement) return null;
    bool declaresInstanceName(InterfaceElement host) =>
        host.fields.any((f) => !f.isStatic && f.name == 'name');
    if (declaresInstanceName(el)) return el;
    for (final mixin in el.mixins) {
      if (declaresInstanceName(mixin.element)) return el;
    }
    return null;
  }

  /// Refuse le build sur les champs enum dont le type **redéclare `name`**.
  ///
  /// L'encodage émis passe par `.name` : sur un tel enum, l'appel résout sur le
  /// membre déclaré (typiquement un libellé d'affichage) et la valeur écrite
  /// diverge du nom technique. Le décodeur émis, lui, compare au nom technique
  /// via l'extension SDK (borne générique `Enum`, non masquable) : toute valeur
  /// écrite sous masquage serait définitivement illisible au décodage — sans
  /// aucun signal, ni au build, ni à l'exécution. Échec de build explicite
  /// (invariant AD-3), tous les champs fautifs du modèle nommés en une passe.
  Never _rejectMaskedEnumName(
    ClassElement element,
    List<(FieldElement, EnumElement)> masked,
  ) {
    final inventory = masked
        .map((m) => '  - ${m.$1.name} : ${m.$2.name}')
        .join('\n');
    final plural = masked.length > 1;
    throw InvalidGenerationSourceError(
      '${masked.length} champ${plural ? 's' : ''} enum sur ${element.name} '
      'dont le type REDÉCLARE `name` comme membre d\'instance :\n$inventory\n'
      'L\'encodage émis passe par `.name` : sur '
      '${plural ? 'ces enums' : 'cet enum'}, le membre déclaré (libellé '
      'd\'affichage ?) MASQUE l\'extension SDK `EnumName.name` — la valeur '
      'écrite divergerait du nom technique, et le décodeur émis (qui compare '
      'au nom technique, non masquable) ne la relirait JAMAIS.\n'
      'DEUX REMÈDES, par champ :\n'
      '  1. renommer le membre de l\'enum (ex. `label`) — `.name` redevient '
      'le nom technique ;\n'
      '  2. annoter le champ `@ZcrudIgnore()` et persister la valeur par un '
      'canal manuel (`fromMap`/`toMap` de domaine).',
      element: masked.length == 1 ? masked.first.$1 : element,
    );
  }

  /// `@ZcrudIgnore` combiné à `@ZcrudField` **ou** `@ZcrudId` sur le même champ
  /// est une contradiction : une déclaration exclut le champ de la persistance,
  /// l'autre l'y inscrit. La résoudre en silence — quel que soit le sens retenu —
  /// écrirait ou n'écrirait pas une donnée à l'insu de l'auteur : **échec de
  /// build explicite** (AD-3), au même titre que la collision de clé persistée.
  void _rejectContradictoryIgnore(
    FieldElement field, {
    required bool serialized,
  }) {
    if (!serialized || !_ignoreChecker.hasAnnotationOf(field)) return;
    throw InvalidGenerationSourceError(
      'Le champ ${field.name} porte `@ZcrudIgnore` ET une annotation de '
      'sérialisation (`@ZcrudField` ou `@ZcrudId`). Ces déclarations se '
      'CONTREDISENT : l\'une exclut le champ de la persistance, l\'autre l\'y '
      'inscrit. Aucune résolution silencieuse n\'est appliquée — retirer l\'une '
      'des deux annotations selon l\'intention réelle.',
      element: field,
    );
  }

  /// `true` si [field] — non annoté — serait **perdu en silence** : son type
  /// n'est pas sérialisable et rien ne déclare l'exclusion.
  ///
  /// ## Exemptions — les cas où un autre signal existe déjà
  ///
  /// - **Champ privé** (`_xxx`) : jamais persistable sous son propre nom par une
  ///   sérialisation manuelle ; c'est par construction un détail de stockage
  ///   (backing d'un accesseur), le signaler serait du bruit.
  /// - **Slots AD-4 d'une classe `ZExtensible`** ([extensible] vrai) :
  ///   `extension` et `extra` sont des canaux hors-codegen **par contrat**
  ///   d'architecture, déjà gardés par le contrat de factory de domaine
  ///   ([_requireDomainFromMap]) et le garde exécutoire émis dans le registrar.
  ///
  /// Le jugement de sérialisabilité n'est **pas** réimplémenté ici : il délègue à
  /// [_classify], seule autorité du générateur sur la question. Un type que
  /// [_classify] accepte ne peut donc jamais faire échouer ce contrôle, et
  /// réciproquement — les deux verdicts ne peuvent pas diverger.
  ///
  /// Sous résolution dégradée, ce contrôle échoue **fermé** : une annotation
  /// `@ZcrudIgnore` non résolue n'exempte plus, un type non résolu fait lever
  /// [_classify] — dans les deux cas le build **rougit**, il ne se tait pas.
  bool _isSilentlyLost(FieldElement field, {required bool extensible}) {
    final name = field.name;
    if (name == null || name.startsWith('_')) return false;
    if (extensible && (name == 'extension' || name == 'extra')) return false;
    if (_ignoreChecker.hasAnnotationOf(field)) return false;
    try {
      _classify(field, field.type);
      return false; // Type sérialisable : omission assumée, contrat inchangé.
    } on InvalidGenerationSourceError {
      return true;
    }
  }

  /// Applique le contrôle de perte silencieuse aux champs concrets **hérités**
  /// (chaîne des super-classes et mixins appliqués, hors SDK).
  ///
  /// Un champ hérité **annoté** est collecté et émis
  /// ([_inheritedAnnotatedFields]) ; un champ hérité **non annoté** de type non
  /// sérialisable serait perdu exactement comme un champ local — la garde le
  /// couvre donc avec les mêmes exemptions ([_isSilentlyLost]). Les interfaces
  /// (`implements`) ne sont pas
  /// parcourues : elles n'apportent aucun stockage concret. Un champ masqué par
  /// une déclaration locale du même nom n'est pas re-signalé.
  void _collectInheritedSilentlyLost(
    ClassElement element,
    bool extensible,
    List<FieldElement> lost,
  ) {
    final seen = <String>{
      for (final f in element.fields)
        if (f.name != null) f.name!,
    };
    final bases = <InterfaceElement>[];
    InterfaceElement? cursor = element;
    while (cursor != null) {
      for (final mixin in cursor.mixins) {
        bases.add(mixin.element);
      }
      final superElement = cursor.supertype?.element;
      if (superElement != null) bases.add(superElement);
      cursor = superElement;
    }
    for (final base in bases) {
      if (base.library.uri.isScheme('dart')) continue;
      for (final field in base.fields) {
        final name = field.name;
        if (name == null || seen.contains(name)) continue;
        if (field.isStatic || field.isAbstract || !field.isOriginDeclaration) {
          continue;
        }
        seen.add(name);
        if (_fieldChecker.hasAnnotationOf(field) ||
            _idChecker.hasAnnotationOf(field)) {
          continue;
        }
        if (_isSilentlyLost(field, extensible: extensible)) lost.add(field);
      }
    }
  }

  /// Refuse le build sur les champs d'instance **non annotés** dont le type n'est
  /// pas sérialisable — la seule forme d'omission qui perde des données sans
  /// qu'aucun signal ne la désigne.
  ///
  /// ## Pourquoi ce refus, et pourquoi seulement là
  ///
  /// Seuls les champs annotés `@ZcrudField`/`@ZcrudId` sont sérialisés : c'est le
  /// contrat, et des modèles s'appuient dessus pour garder des champs d'exécution
  /// hors persistance. Un champ non annoté **de type sérialisable** reste donc
  /// ignoré en silence, sans changement. Les champs **exemptés** (privés, slots
  /// AD-4 d'une classe `ZExtensible` — cf. [_isSilentlyLost]) n'atteignent
  /// jamais ce message : ce qui y arrive disparaîtrait réellement **sans aucun
  /// signal**, par construction.
  ///
  /// Un champ non annoté dont le type n'est **pas** sérialisable est un cas tout
  /// autre : le type désigne un sous-objet métier (un modèle voisin, une valeur
  /// structurée), qu'une sérialisation écrite à la main émettait presque toujours.
  /// Remplacer cette sérialisation par le code émis effacerait le champ du
  /// document à la première écriture, sans erreur de build ni d'analyse — la
  /// classe d'échec qu'un générateur doit refuser (invariant AD-3 : échec de
  /// build explicite, jamais de dégradation muette).
  ///
  /// Tous les champs fautifs d'un même modèle sont signalés **en un seul
  /// message** : un modèle qui en porte plusieurs se corrige en une passe, pas en
  /// autant de builds rouges successifs.
  Never _rejectSilentlyLostFields(
    ClassElement element,
    List<FieldElement> lost,
  ) {
    final inventory = lost
        .map((f) => '  - ${f.name} : ${f.type.getDisplayString()}')
        .join('\n');
    final plural = lost.length > 1;
    throw InvalidGenerationSourceError(
      '${lost.length} champ${plural ? 's' : ''} NON ANNOTÉ${plural ? 'S' : ''} '
      'de type non sérialisable sur ${element.name} :\n$inventory\n'
      'Le générateur ne sérialise que les champs annotés, et ${plural ? 'ces '
          'types ne sont' : 'ce type n\'est'} ni scalaire supporté, ni enum, ni '
      'classe @ZcrudModel. Laissé${plural ? 's' : ''} tel${plural ? 's' : ''} '
      'quel${plural ? 's' : ''}, ${plural ? 'ces champs seraient absents' : 'ce '
          'champ serait absent'} de `toMap()` comme du décodeur — '
      '${plural ? 'leurs valeurs disparaîtraient' : 'sa valeur disparaîtrait'} '
      'du document persisté à la première écriture, sans aucun signal.\n'
      'TROIS REMÈDES, par champ :\n'
      '  1. donner au champ un type sérialisable (scalaire supporté, enum, '
      '`List<T>` ou `Map<K, V>` de ceux-ci) et l\'annoter `@ZcrudField()` ;\n'
      '  2. si le sous-objet doit être persisté : annoter son TYPE avec '
      '`@ZcrudModel` ET annoter le champ `@ZcrudField()` — les DEUX gestes sont '
      'nécessaires, annoter le type seul laisse le champ hors du code émis. '
      'Impossible pour un type du SDK (`Set`, fonction… — une `Map<K, V>` est '
      'en revanche supportée telle quelle) : seuls les remèdes 1 et 3 '
      's\'appliquent alors ;\n'
      '  3. annoter le champ `@ZcrudIgnore()` s\'il est hors persistance. '
      'ATTENTION : `@ZcrudIgnore` signifie « cette donnée N\'EST PAS écrite par '
      'le codegen ». Si elle doit vivre dans le document, c\'est à l\'auteur de '
      'l\'écrire par un canal manuel (`fromMap`/`toMap` de domaine, slot '
      '`extra`) — sinon elle est abandonnée, cette fois explicitement.',
      element: lost.length == 1 ? lost.first : element,
    );
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

    final (category, elementTypeName, inferred, mapCodecs, elementCodec) =
        _classify(field, type);

    // Type de champ : explicite (@ZcrudField.type) sinon inféré.
    final explicitType = reader != null && !reader.read('type').isNull
        ? _emitConst(reader.read('type'))
        : null;
    final resolvedType = explicitType ?? 'EditionFieldType.$inferred';

    final annoMultiple =
        reader != null && reader.read('multiple').boolValue;

    // Lecture STATIQUE de `persistAs` — jamais d'exécution/`reflectable`.
    // Le nom de la constante passe par `_enumConstantName` (lecture unique du
    // dépôt, insensible aux alias `const` et aux préfixes d'import).
    // Absent/`iso8601` ⇒ `false` (aucun champ collecté dans
    // `$XxxTimestampFields`).
    final persistAsTimestamp = reader != null &&
        _enumConstantName(reader.read('persistAs')) == 'timestamp';

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
      mapCodecs: mapCodecs,
      elementCodec: elementCodec,
    );
  }

  /// Classe un champ en catégorie de (dé)sérialisation + son `EditionFieldType`
  /// inféré. Type non supporté → **échec explicite** (AD-3).
  (
    _Cat category,
    String? elementTypeName,
    String inferred,
    _MapCodecs? mapCodecs,
    _Codec? elementCodec,
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
      final (elemCat, _, elemInferred, _, _) = _classify(field, arg);
      if (elemCat == _Cat.mapType) {
        // `List<Map<K, V>?>` reste REFUSÉE : le décodage d'une liste filtre ses
        // éléments illisibles par `whereType`, geste qui effacerait aussi les
        // `null` DÉCLARÉS. Le contrat « la liste survit amputée » ne saurait
        // plus distinguer un trou voulu d'un élément corrompu — le générateur
        // refuse plutôt que de rendre une liste dont la longueur ment.
        if (arg.nullabilitySuffix == NullabilitySuffix.question) {
          // `getDisplayString()` rend ici le `?` final (la branche n'est
          // atteinte QUE sous suffixe `question`) : on le retire pour montrer le
          // remède, plutôt que d'appeler la surcharge dépréciée.
          final display = arg.getDisplayString();
          throw InvalidGenerationSourceError(
            'Élément de liste `Map` NULLABLE non supporté sur ${field.name} '
            '("${type.getDisplayString()}"). Le décodage défensif filtre les '
            'éléments illisibles : un `null` déclaré serait effacé avec eux, et '
            'la liste rendue aurait une longueur différente de celle écrite. '
            'Remède : déclarer l\'élément NON nullable '
            '(`List<${display.substring(0, display.length - 1)}>`).',
            element: field,
          );
        }
        return (
          _Cat.listMap,
          arg.getDisplayString(),
          elemInferred,
          null,
          // Profondeur 1 : la liste occupe déjà les noms de profondeur 0
          // (`e$`), la map imbriquée prend `e$1`/`k$1`/`v$1`.
          _nestedMapCodec(field, arg as InterfaceType, 1),
        );
      }
      final _Cat listCat = switch (elemCat) {
        _Cat.enumType => _Cat.listEnum,
        _Cat.subModel => _Cat.listModel,
        _ => _Cat.listScalar,
      };
      return (listCat, _typeName(arg), elemInferred, null, null);
    }
    // Dictionnaires homogènes : Map<K, V>.
    if (type.isDartCoreMap && type is InterfaceType) {
      return (
        _Cat.mapType,
        null,
        'dynamicItem',
        _mapCodecsOf(field, type, 0),
        null,
      );
    }
    if (type.isDartCoreString) {
      return (_Cat.stringType, null, 'text', null, null);
    }
    if (type.isDartCoreInt) return (_Cat.intType, null, 'integer', null, null);
    if (type.isDartCoreDouble) {
      return (_Cat.doubleType, null, 'float', null, null);
    }
    if (type.isDartCoreNum) return (_Cat.numType, null, 'number', null, null);
    if (type.isDartCoreBool) {
      return (_Cat.boolType, null, 'boolean', null, null);
    }

    final el = type.element;
    if (el is EnumElement) {
      return (_Cat.enumType, _typeName(type), 'select', null, null);
    }
    if (_typeName(type) == 'DateTime') {
      return (_Cat.dateTimeType, null, 'dateTime', null, null);
    }
    // Plage de dates `ZDateRange` : (dé)sérialisation DÉFENSIVE via le
    // helper `_$asDateRange` (bâti sur `ZDateRange.fromJsonSafe` → jamais de
    // throw) ; `toMap` via `.toJson()`. Patron strict de la branche `DateTime`.
    if (_typeName(type) == 'ZDateRange') {
      return (_Cat.dateRangeType, null, 'dateRange', null, null);
    }
    if (el != null && _modelChecker.hasAnnotationOf(el)) {
      return (_Cat.subModel, _typeName(type), 'subItems', null, null);
    }

    throw InvalidGenerationSourceError(
      'Type de champ non (dé)sérialisable "${type.getDisplayString()}" sur '
      '${field.name} : ni scalaire supporté, ni enum, ni `Map`, ni @ZcrudModel '
      'annoté. Annoter le type cible avec @ZcrudModel, ou en changer.',
      element: field,
    );
  }

  // --------------------------------------------------------------------------
  // Map<K, V> — codecs de clé et de valeur.
  // --------------------------------------------------------------------------

  /// Codecs de clé et de valeur d'un champ `Map<K, V>`.
  ///
  /// **Clé** : `String` ou enum (encodée par `.name`, camelCase — même
  /// convention que tout enum persisté). Une clé d'un autre type est un échec de
  /// build : la map persistée doit rester à clés `String`.
  ///
  /// **Valeur** : `dynamic`/`Object?` (recopiée telle quelle), scalaire supporté,
  /// `DateTime`, `ZDateRange`, enum, sous-modèle `@ZcrudModel`, `List<T>` de
  /// ceux-ci, ou une `Map<K2, V2>` IMBRIQUÉE obéissant aux mêmes règles (à
  /// profondeur libre). Une valeur nullable est admise et son `null` est
  /// PRÉSERVÉ.
  ///
  /// Le décodage émis est **défensif** (invariant AD-10) : une entrée dont la clé
  /// ou la valeur est illisible est ignorée, et le reste de la map survit — le
  /// parent ne lève jamais. Une map imbriquée applique la même règle à son
  /// propre niveau : une entrée interne illisible n'emporte ni la map interne,
  /// ni l'entrée externe, ni le parent.
  ///
  /// [depth] est la profondeur d'imbrication de CETTE map ; elle ne sert qu'à
  /// nommer les variables liées du code émis ([_boundName]), de sorte qu'une map
  /// imbriquée ne masque pas les liaisons de la map qui la porte.
  _MapCodecs _mapCodecsOf(FieldElement field, InterfaceType type, int depth) {
    final args = type.typeArguments;
    if (args.length != 2) {
      throw InvalidGenerationSourceError(
        'Map sans arguments de type non supportée sur ${field.name}.',
        element: field,
      );
    }
    return _MapCodecs(
      key: _mapKeyCodec(field, args[0]),
      value: _mapValueCodec(field, args[1], depth),
    );
  }

  /// Nom d'une variable liée du code émis, qualifié par [depth].
  ///
  /// La profondeur 0 rend le nom HISTORIQUE (`e$`, `k$`, `v$`) : le texte émis
  /// pour toutes les formes déjà supportées avant l'ouverture de l'imbrication
  /// reste identique à l'octet. Seuls les niveaux imbriqués — inatteignables
  /// auparavant — prennent un suffixe (`e$1`, `k$2`…).
  static String _boundName(String base, int depth) =>
      depth == 0 ? '$base\$' : '$base\$$depth';

  /// Codec d'une `Map<K, V>` **imbriquée** — valeur d'une autre map, ou élément
  /// d'une `List`.
  ///
  /// Rend le même triplet condition/décodage/encodage que la branche
  /// `_Cat.mapType` d'un champ de premier niveau : `# is Map` en garde, une
  /// compréhension de map qui saute les entrées illisibles en décodage, et
  /// `.map((k, v) => MapEntry(…))` en encodage. La map persistée reste à clés
  /// `String` à tous les niveaux.
  _Codec _nestedMapCodec(FieldElement field, InterfaceType type, int depth) {
    final c = _mapCodecsOf(field, type, depth);
    final e = _boundName('e', depth);
    final k = _boundName('k', depth);
    final v = _boundName('v', depth);
    final conds = <String>[
      if (c.key.cond != null) c.key.condOf('$e.key'),
      if (c.value.cond != null) c.value.condOf('$e.value'),
    ];
    final guard = conds.isEmpty ? '' : 'if (${conds.join(' && ')}) ';
    return _Codec(
      typeStr: type.getDisplayString(),
      cond: '# is Map',
      decode: '<${c.key.typeStr}, ${c.value.typeStr}>{'
          'for (final $e in (# as Map).entries) '
          '$guard${c.key.decodeOf('$e.key')}: '
          '${c.value.decodeOf('$e.value')},'
          '}',
      encode: '#.map(($k, $v) => MapEntry(${c.key.encodeOf(k)}, '
          '${c.value.encodeOf(v)}))',
    );
  }

  _Codec _mapKeyCodec(FieldElement field, DartType key) {
    if (key.isDartCoreString) {
      return const _Codec(
        typeStr: 'String',
        cond: '# is String',
        decode: '# as String',
        encode: '#',
      );
    }
    final el = key.element;
    if (el is EnumElement && key.nullabilitySuffix != NullabilitySuffix.question) {
      final name = _typeName(key);
      return _Codec(
        typeStr: '$name',
        cond: '_\$enumFromName($name.values, #) != null',
        decode: '_\$enumFromName($name.values, #)!',
        encode: '#.name',
      );
    }
    throw InvalidGenerationSourceError(
      'Clé de Map non supportée "${key.getDisplayString()}" sur ${field.name} : '
      'la map persistée doit avoir des clés `String`. Seuls `String` et un enum '
      'NON nullable (encodé par `.name`) conviennent.',
      element: field,
    );
  }

  _Codec _mapValueCodec(FieldElement field, DartType value, int depth) {
    final nullable = value.nullabilitySuffix == NullabilitySuffix.question;
    final display = value.getDisplayString();
    // `dynamic` / `Object?` : recopie intégrale, aucune condition — c'est la
    // forme la plus répandue (`Map<String, dynamic>`) et la seule qui préserve
    // une structure imbriquée arbitraire.
    if (value is DynamicType || (value.isDartCoreObject && nullable)) {
      return _Codec(typeStr: display, cond: null, decode: '#', encode: '#');
    }
    final inner = _mapValueCodecNonNull(field, value, depth);
    if (!nullable) return inner;
    return _Codec(
      typeStr: display,
      cond: '(# == null || ${inner.cond ?? 'true'})',
      decode: '# == null ? null : ${inner.decode}',
      // Un encodage IDENTITÉ reste identité sous nullabilité : émettre
      // `v == null ? null : v` serait du bruit dans le `.g.dart`.
      encode: inner.encode == '#' ? '#' : '# == null ? null : ${inner.encode}',
    );
  }

  _Codec _mapValueCodecNonNull(FieldElement field, DartType value, int depth) {
    final display = value.getDisplayString();
    if (value.isDartCoreString) {
      return _Codec(
        typeStr: display,
        cond: '# is String',
        decode: '# as String',
        encode: '#',
      );
    }
    if (value.isDartCoreBool) {
      return _Codec(
        typeStr: display,
        cond: '# is bool',
        decode: '# as bool',
        encode: '#',
      );
    }
    if (value.isDartCoreInt) return _helperCodec(display, '_\$asInt');
    if (value.isDartCoreDouble) return _helperCodec(display, '_\$asDouble');
    if (value.isDartCoreNum) return _helperCodec(display, '_\$asNum');
    if (_typeName(value) == 'DateTime') {
      return _helperCodec(display, '_\$asDateTime', encode: '#.toIso8601String()');
    }
    if (_typeName(value) == 'ZDateRange') {
      return _helperCodec(display, '_\$asDateRange', encode: '#.toJson()');
    }
    final el = value.element;
    if (el is EnumElement) {
      final name = _typeName(value);
      return _Codec(
        typeStr: display,
        cond: '_\$enumFromName($name.values, #) != null',
        decode: '_\$enumFromName($name.values, #)!',
        encode: '#.name',
      );
    }
    if (el != null && _modelChecker.hasAnnotationOf(el)) {
      final name = _typeName(value);
      return _Codec(
        typeStr: display,
        cond: '_\$decodeModel(#, $name.fromMap) != null',
        decode: '_\$decodeModel(#, $name.fromMap)!',
        encode: '#.toMap()',
      );
    }
    if (value.isDartCoreList && value is InterfaceType) {
      final arg = value.typeArguments.isEmpty ? null : value.typeArguments.first;
      if (arg != null && arg.nullabilitySuffix != NullabilitySuffix.question) {
        // L'élément est décodé un cran plus PROFOND : s'il est lui-même une map
        // (`Map<String, List<Map<…>>>`), ses liaisons ne doivent pas masquer
        // celles de la liste ni celles de la map qui la porte.
        final elem = _mapValueCodecNonNull(field, arg, depth + 1);
        final elemType = arg.getDisplayString();
        final e = _boundName('e', depth);
        // Élément illisible → `null`, filtré par `whereType` : la liste survit
        // amputée, jamais la map ni le parent (AD-10).
        final decodeElem = elem.cond == null
            ? elem.decodeOf(e)
            : '${elem.condOf(e)} ? ${elem.decodeOf(e)} : null';
        return _Codec(
          typeStr: display,
          cond: '# is List',
          decode: '(# as List).map(($e) => $decodeElem)'
              '.whereType<$elemType>().toList()',
          encode: '#.map(($e) => ${elem.encodeOf(e)}).toList()',
        );
      }
    }
    // `Map<K2, V2>` IMBRIQUÉE : mêmes règles de clé et de valeur, appliquées un
    // cran plus profond. Sans cette branche, la seule façon de persister une
    // structure à deux niveaux était de déclarer la valeur `dynamic`, ce qui
    // rendait le type de la map interne au consommateur — et lui laissait
    // l'entière charge du décodage défensif.
    if (value.isDartCoreMap && value is InterfaceType) {
      return _nestedMapCodec(field, value, depth + 1);
    }
    throw InvalidGenerationSourceError(
      'Valeur de Map non (dé)sérialisable "$display" sur ${field.name} : ni '
      '`dynamic`, ni scalaire supporté, ni `DateTime`, ni enum, ni @ZcrudModel '
      'annoté, ni `List` ou `Map` de ceux-ci. Remède le plus simple : déclarer '
      'la valeur `dynamic` (`Map<String, dynamic>`), qui recopie la structure '
      'telle quelle.',
      element: field,
    );
  }

  /// Codec bâti sur un helper émis rendant `T?` (`_$asInt`, `_$asDateTime`…).
  _Codec _helperCodec(String typeStr, String helper, {String encode = '#'}) =>
      _Codec(
        typeStr: typeStr,
        cond: '$helper(#) != null',
        decode: '$helper(#)!',
        encode: encode,
      );

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
      case _Cat.listMap:
        final c = f.elementCodec!;
        final t = f.elementTypeName;
        // Élément non-map → `null`, filtré par `whereType` ; entrée illisible
        // À L'INTÉRIEUR d'un élément → sautée par la compréhension. Les deux
        // niveaux sont défensifs (AD-10), et aucun ne remonte au parent.
        return '$m is List ? ($m as List)'
            '.map((e\$) => ${c.condOf('e\$')} ? ${c.decodeOf('e\$')} : null)'
            '.whereType<$t>().toList() : $def';
      case _Cat.mapType:
        final c = f.mapCodecs!;
        // Entrée dont la clé OU la valeur est illisible : ignorée (AD-10). Le
        // reste de la map survit, le parent ne lève jamais.
        final conds = <String>[
          if (c.key.cond != null) c.key.condOf('e\$.key'),
          if (c.value.cond != null) c.value.condOf('e\$.value'),
        ];
        final guard = conds.isEmpty ? '' : 'if (${conds.join(' && ')}) ';
        return '$m is Map ? <${c.key.typeStr}, ${c.value.typeStr}>{'
            'for (final e\$ in ($m as Map).entries) '
            '$guard${c.key.decodeOf('e\$.key')}: '
            '${c.value.decodeOf('e\$.value')},'
            '} : $def';
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
      case _Cat.listMap:
        return 'const <${f.elementTypeName}>[]';
      case _Cat.mapType:
        final c = f.mapCodecs!;
        return 'const <${c.key.typeStr}, ${c.value.typeStr}>{}';
    }
  }

  // --------------------------------------------------------------------------
  // Émission — extension publique : toMap + copyWith sentinelle.
  // --------------------------------------------------------------------------

  /// Corps PARTAGÉ des deux émissions de `toMap()`/`copyWith()` — l'extension
  /// [_emitExtension] et le mixin [_emitInstanceMixin].
  ///
  /// Le texte est produit **une seule fois** : appliquer le mixin ne peut donc
  /// pas changer d'un octet la map produite par l'extension. C'est la propriété
  /// que la garde d'identité de sérialisation vérifie.
  String _emitSerializationMembers(String className, List<_Field> fields) {
    // Un miroir de clé RÉSERVÉE de sync (`updated_at`,
    // `is_deleted` — possédées par la couche de sync) n'est émis que
    // s'il porte RÉELLEMENT une valeur.
    //
    // L'émettre INCONDITIONNELLEMENT, `null` compris, déclencherait
    // l'avertissement de collision de zcrud à CHAQUE écriture, sur 100 % des
    // entités concernées — zcrud avertissant contre lui-même, sans qu'aucun de
    // ces cas ne porte de signal. Omettre le `null` supprime exactement ce
    // bruit-là et **conserve** l'avertissement quand il est légitime : une
    // valeur métier réelle qui SERA écrasée par la méta hors-entité.
    //
    // On n'omet PAS la clé non-nulle : le round-trip `fromMap(toMap(x))` doit
    // rester fidèle pour un miroir renseigné.
    final toMapEntries = fields
        .map((f) => _kReservedSyncKeys.contains(f.key) && f.nullable
            ? "      if (this.${f.dartName} != null) '${f.key}': "
                "${_toMapExpr(f)},"
            : "      '${f.key}': ${_toMapExpr(f)},")
        .join('\n');

    final copyParams = fields
        .map((f) => '    Object? ${f.dartName} = $_undefinedRef,')
        .join('\n');
    final copyArgs = fields
        .map((f) => '      ${f.dartName}: identical(${f.dartName}, '
            '$_undefinedRef) ? this.${f.dartName} : ${f.dartName} as '
            '${f.typeStr},')
        .join('\n');

    return '  /// Sérialise vers la map persistée (snake_case, enum camelCase, '
        'ISO-8601).\n'
        '  Map<String, dynamic> toMap() => <String, dynamic>{\n'
        '$toMapEntries\n'
        '      };\n\n'
        '  /// Copie avec sentinelle : un argument omis préserve la valeur, '
        '`null` explicite la remet à `null`.\n'
        '  $className copyWith({\n$copyParams\n  }) =>\n'
        '      $className(\n$copyArgs\n      );';
  }

  String _emitExtension(String className, List<_Field> fields) =>
      'extension ${className}Zcrud on $className {\n'
      '${_emitSerializationMembers(className, fields)}\n'
      '}';

  /// Émet le mixin `_\$XxxZcrud` — les MÊMES `toMap()`/`copyWith()`, mais en
  /// **membres d'instance**.
  ///
  /// ## Pourquoi il existe en plus de l'extension
  ///
  /// Un membre d'**extension** n'est ni virtuel ni héritable : il ne satisfait
  /// **jamais** un membre abstrait déclaré par une super-classe, et il est
  /// invisible à tout appel fait à travers un type de base (`(model as
  /// Base).toMap()`). Une hiérarchie dont la racine déclare `toMap()` /
  /// `copyWith()` abstraits ne peut donc PAS adopter le codegen par la seule
  /// extension. Le mixin, lui, apporte des membres d'instance réels : il
  /// implémente le membre abstrait hérité et répond en appel polymorphe.
  ///
  /// ## Comment on l'applique
  ///
  /// ```dart
  /// class Facture extends DynamicModel with _$FactureZcrud { … }
  /// ```
  ///
  /// L'application est **facultative** : sans elle, rien ne change, l'extension
  /// reste la voie d'appel. Avec elle, le membre d'instance masque le membre
  /// d'extension homonyme — les deux corps étant émis depuis la même source de
  /// texte ([_emitSerializationMembers]), la map produite est identique.
  ///
  /// Le mixin déclare un **getter abstrait par champ persisté** : la classe les
  /// satisfait avec ses propres champs, qu'ils soient déclarés localement ou
  /// hérités. Il ne déclare **aucun champ d'instance**, ce qui laisse intacts
  /// les constructeurs `const` du modèle. Contrepartie à connaître : un champ
  /// déclaré dans la classe qui applique le mixin devient un `@override` du
  /// getter abstrait — le lint `annotate_overrides` le réclame.
  String _emitInstanceMixin(String className, List<_Field> fields) {
    final getters = fields
        .map((f) => '  ${f.typeStr} get ${f.dartName};')
        .join('\n');
    return '/// `toMap()`/`copyWith()` de `$className` en MEMBRES D\'INSTANCE.\n'
        '///\n'
        '/// À appliquer (`class $className … with _\$${className}Zcrud`) quand '
        'un membre\n'
        '/// d\'extension ne suffit pas : un membre d\'extension ne satisfait '
        'jamais un\n'
        '/// membre abstrait hérité et reste invisible à un appel fait à '
        'travers un type\n'
        '/// de base. Corps identiques à ceux de l\'extension '
        '`${className}Zcrud` : la map\n'
        '/// produite ne change pas. Les champs déclarés par la classe '
        'deviennent alors\n'
        '/// des `@override` des getters ci-dessous.\n'
        'mixin _\$${className}Zcrud {\n'
        '$getters\n\n'
        '${_emitSerializationMembers(className, fields)}\n'
        '}';
  }

  /// Clés possédées par la couche de synchronisation (`ZSyncMeta`) —
  /// jamais réémises par le corps métier. Miroir littéral de
  /// `ZSyncMeta.reservedKeys` : le générateur ne peut pas importer `zcrud_core`
  /// (il tournerait alors sur sa propre dépendance), d'où la duplication —
  /// gardée par un test qui compare les deux ensembles.
  static const Set<String> _kReservedSyncKeys = <String>{
    'updated_at',
    'is_deleted',
  };

  /// Expression d'encodage d'un champ dans le `toMap()` émis.
  ///
  /// L'encodage enum passe par `.name` (nom technique, camelCase) : un enum
  /// qui redéclarerait `name` comme membre d'instance changerait la valeur
  /// émise — ce cas est **refusé au build** en amont ([_rejectMaskedEnumName]),
  /// l'expression émise ici ne peut donc résoudre que sur `EnumName.name`.
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
      case _Cat.listMap:
        // Chaque élément réencodé par son codec de map : clés `String` à tous
        // les niveaux, quelle que soit la clé Dart.
        final c = f.elementCodec!;
        return '$v$q.map((e\$) => ${c.encodeOf('e\$')}).toList()';
      case _Cat.mapType:
        final c = f.mapCodecs!;
        // Clé toujours réencodée en `String` (enum → `.name`) : la map persistée
        // reste à clés `String`, quelle que soit la clé Dart.
        return '$v$q.map((k\$, v\$) => MapEntry(${c.key.encodeOf('k\$')}, '
            '${c.value.encodeOf('v\$')}))';
    }
  }

  // --------------------------------------------------------------------------
  // Émission — ZFieldSpec[] (projection 1:1 + inférence).
  // --------------------------------------------------------------------------

  /// Émet `$XxxPersistedKeys` — l'ensemble EXACT des clés que `toMap()` peut
  /// produire, **champs nuls compris**.
  ///
  /// ## À quoi ça sert
  ///
  /// Un hôte qui mappe son modèle vers une entité `Z` doit couvrir 100 % des
  /// champs persistés, sous peine d'en détruire silencieusement. Tenir cet
  /// inventaire **à la main** dans chaque descripteur laisserait un
  /// champ neuf ajouté par un tag futur **invisible** jusqu'à ce qu'une
  /// donnée disparaisse. Généré, il permet une garde d'exhaustivité **automatique**.
  ///
  /// **« peut produire », pas « produit toujours »** : une clé réservée-miroir
  /// n'est émise que si elle porte une valeur, et un champ nul
  /// n'apparaît pas dans une map donnée. L'ensemble est donc le **surensemble**
  /// stable — c'est exactement ce qu'une garde d'exhaustivité doit comparer.
  String _emitPersistedKeys(String className, List<_Field> fields) {
    final entries = fields.map((f) => "  '${f.key}',").join('\n');
    return "/// Clés que `$className.toMap()` PEUT produire — "
        'surensemble\n'
        '/// stable, champs nuls compris. Source unique pour une garde '
        "d'exhaustivité\n"
        '/// côté hôte : un champ ajouté par un tag futur apparaît ici sans '
        'action.\n'
        'const Set<String> \$${className}PersistedKeys = <String>{\n'
        '$entries\n'
        '};';
  }

  String _emitFieldSpecs(String className, List<_Field> fields) {
    final specs = fields.map(_emitSpec).join('\n');
    return '/// Schéma déclaratif projeté depuis @ZcrudField.\n'
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
      // `showIfNull` a pour défaut `false` (côté annotation ET
      // `ZFieldSpec`). On n'émet donc que la valeur NON-défaut (`true`) — sinon le
      // flip du défaut serait silencieusement écrasé. `@ZcrudField()` (défaut
      // false) ⇒ aucune émission ⇒ `ZFieldSpec` prend son défaut `false`.
      // Opt-in `@ZcrudField(showIfNull: true)` ⇒ `showIfNull: true` émis.
      if (r.read('showIfNull').boolValue) parts.add('showIfNull: true');
      // Ornements déclaratifs (const AST re-émis 1:1) + hint/helper.
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
    // `fromMap: $className.fromMap` — le décodeur de **DOMAINE** :
    // lui seul peuple les canaux HORS-codegen (`extra` AD-4, `source`), là où
    // `_$${className}FromMap` (codegen) les IGNORE — ce qui détruirait toute clé
    // métier inconnue sur la voie `registry.decode`. Existence + compatibilité de
    // signature sont VÉRIFIÉES (`_requireDomainFromMap`) : jamais de repli.
    // Le tear-off reste assignable à `T Function(Map<String, dynamic>)` même si le
    // décodeur déclare des paramètres OPTIONNELS supplémentaires (sous-typage Dart).
    final doc = '/// Enregistre `$className` (kind "$kind") sur [registry] : '
        '(dé)sérialisation + schéma.\n';

    // Variantes CONSCIENTES DU CONTEXTE. Le tear-off nu
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

    // GARDE EXÉCUTOIRE, émis pour toute classe `ZExtensible`.
    //
    // Le contrat de BUILD ne vérifie qu'une SIGNATURE (et refuse la délégation
    // nue) : il ne peut pas prouver qu'une factory ré-écrite à la main peuple
    // vraiment `extra`. Ce garde, lui, l'OBSERVE — il décode une sonde portant
    // une clé inconnue et exige qu'elle atterrisse dans `extra`. Il vit dans le
    // `.g.dart`, donc il SUIT LES PACKAGES PUBLIÉS : un consommateur externe
    // n'a pas `tool/reserved_keys_gate`, mais il a CE garde.
    //
    // Volontairement PAS sous `assert` : un `assert` s'évapore en release —
    // ce serait une dégradation silencieuse. Le coût est un
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
  // Émission — artefact NEUTRE des clés persistées en Timestamp.
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
      // Lecture unique du dépôt ([_enumConstantName]) : le dernier segment de
      // l'accesseur QUALIFIÉ que `revive()` rend pour toute constante d'enum —
      // y compris derrière un alias `const` ou un préfixe d'import (mesuré).
      final valueName = _enumConstantName(r);
      if (valueName == null) {
        // Jamais observé sur une source valide (l'accesseur d'une constante
        // d'enum n'est jamais vide) : refus explicite plutôt qu'une émission
        // corrompue si une résolution dégradée y menait.
        throw InvalidGenerationSourceError(
          'Constante d\'enum `${el.name}` illisible dans une annotation : '
          'accesseur vide. Passer une constante d\'enum écrite littéralement '
          '(`${el.name}.valeur`).',
        );
      }
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

/// Nom de la **constante d'enum** portée par [r], ou `null` si [r] n'est pas une
/// valeur d'enum (ou si l'accesseur est vide — jamais observé sur une source
/// valide, cf. le refus explicite dans [ZcrudModelGenerator._emitConst]).
///
/// Source unique de lecture des enums d'annotation du générateur
/// (`fieldRename`, `persistAs`, tout enum re-émis dans un `ZFieldSpec`). Toute
/// autre façon de lire un enum d'annotation est fragile :
///
/// - comparer `revive().accessor` à un nom nu ne réussit jamais : pour une
///   constante d'enum, l'accesseur est **toujours qualifié** (`Type.constante`) —
///   `reviveInstance` résout l'`InterfaceElement` de l'enum avant toute variable
///   porteuse, y compris derrière un alias `const` ou un préfixe d'import.
///   C'était le bug d'origine de `fieldRename` (comparaison à `'none'`,
///   retombée muette sur `snake`) ;
/// - `objectValue.variable?.name` rend le nom de la **variable** qui porte la
///   valeur, pas celui de la constante : sur `const alias = ZFieldRename.kebab;`
///   puis `@ZcrudModel(fieldRename: alias)`, il rend `alias`. Mesuré.
///
/// La lecture retenue est le **dernier segment de l'accesseur qualifié**.
/// Mesuré exhaustivement sur la suite du paquet (quatre stratégies de
/// `fieldRename`, `persistAs`, chacun écrit littéralement **et** derrière un
/// alias `const`) : l'accesseur couvre tous les cas. Une projection redondante
/// par l'index du modèle d'élément a été retirée — aucun test ne pouvait la
/// distinguer de cette lecture-ci.
String? _enumConstantName(ConstantReader r) {
  if (r.isNull) return null;
  if (r.objectValue.type?.element is! EnumElement) return null;
  final accessor = r.revive().accessor;
  return accessor.isEmpty ? null : accessor.split('.').last;
}

/// Forme LITTÉRALE seule acceptée en lecture de secours : `ZFieldRename.valeur`,
/// éventuellement préfixée par un import (`z.ZFieldRename.valeur`).
///
/// Le nom de l'énumération est exigé : sans lui, `x.kebab` d'une TOUTE AUTRE
/// énumération passerait pour un renommage.
final RegExp _literalRenamePattern =
    RegExp(r'^(?:[A-Za-z_$][\w$]*\.)?ZFieldRename\.([A-Za-z_$][\w$]*)$');

/// Stratégie de renommage déclarée par `@ZcrudModel.fieldRename`.
///
/// Une constante inconnue est un **échec de build explicite**, jamais un repli
/// muet sur `snake` : un repli renommerait toutes les clés persistées d'un modèle
/// à l'insu de son auteur, rendant illisibles les documents déjà écrits.
ZFieldRename _renameOf(
  ConstantReader r,
  Element element, {
  required String? Function() writtenArgument,
}) {
  if (r.isNull) {
    // La constante est illisible : la résolution de l'annotation a échoué.
    // Ultime recours AVANT de refuser — ce que l'auteur a littéralement ÉCRIT,
    // lu sur l'AST, qui survit à l'échec de résolution. Ce n'est pas un repli :
    // aucune valeur n'est supposée, seule la forme littérale
    // `ZFieldRename.<valeur>` (préfixe d'import toléré) est acceptée. Un alias
    // `const`, une expression calculée ou un argument absent ne donnent RIEN à
    // lire, et le build échoue — un repli muet reproduirait exactement la
    // corruption de clés que ce point d'échec existe pour interdire.
    final written = writtenArgument();
    if (written != null) {
      final literal = _literalRenamePattern.firstMatch(written.trim());
      if (literal != null) {
        for (final value in ZFieldRename.values) {
          if (value.name == literal.group(1)) return value;
        }
      }
    }
    throw InvalidGenerationSourceError(
      'Lecture de `@ZcrudModel.fieldRename` impossible : la résolution de '
      'l\'annotation a échoué (constante nulle). Aucun repli n\'est appliqué — '
      'il renommerait les clés persistées à l\'insu de l\'auteur.'
      '${written == null ? ' Aucun argument `fieldRename:` n\'est écrit sur '
          'l\'annotation.' : ' Argument écrit : `$written`.'}'
      '\nÀ vérifier, dans la bibliothèque qui porte le modèle :'
      '\n  1. `ZFieldRename` doit y être IMPORTÉ — '
      '`package:zcrud_annotations/zcrud_annotations.dart` le ré-exporte ; '
      'un identifiant non résolu devient une constante nulle, pas une erreur '
      'de compilation visible du générateur ;'
      '\n  2. écrire la valeur LITTÉRALEMENT (`fieldRename: '
      'ZFieldRename.${ZFieldRename.values.first.name}`), jamais via un alias '
      '`const` ni une expression calculée ;'
      '\n  3. `zcrud_annotations` et `zcrud_core` doivent provenir de la MÊME '
      'version : deux copies distinctes rendent l\'énumération non résoluble '
      'depuis l\'annotation.',
      element: element,
    );
  }
  final name = _enumConstantName(r);
  for (final value in ZFieldRename.values) {
    if (value.name == name) return value;
  }
  throw InvalidGenerationSourceError(
    'Valeur de `@ZcrudModel.fieldRename` non reconnue : "$name". Attendu l\'une '
    'de ${ZFieldRename.values.map((v) => v.name).join(', ')}. Aucun repli n\'est '
    'appliqué : il renommerait toutes les clés persistées du modèle, rendant '
    'illisibles les documents déjà écrits.',
    element: element,
  );
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
/// `byName` nu), date ISO tolérante ; sentinelle `copyWith` ; **garde
/// exécutoire d'extensibilité**.
const _sharedHelpers = '''
/// Sentinelle « argument non fourni » du `copyWith` généré (reset-null).
const Object? _\$undefined = _ZUndefined();

/// Clé de SONDE de la garde d'extensibilité : n'est le nom persisté d'AUCUN
/// champ de schéma, ni une clé réservée (`ZSyncMeta`), ni `source`/`extension`.
const String _\$zExtraProbeKey = '$_extraProbeKey';

/// **GARDE EXÉCUTOIRE d'extensibilité** (invariant AD-4) — émise dans le `register…`
/// de toute classe `ZExtensible`.
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
///     préservé au décodage n'est **jamais réémis**. Attention : le `toMap()` **généré**
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

/// Décode défensivement une plage `ZDateRange` (AD-10) : délègue à
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
  listModel,

  /// `List<Map<K, V>>` — liste dont l'élément est un dictionnaire homogène. Son
  /// codec d'élément vit dans `_Field.elementCodec` (les catégories `list*`
  /// ci-dessus se décrivent, elles, par le seul `elementTypeName`).
  listMap,
  mapType;

  /// `true` pour une collection ORDONNÉE de valeurs homogènes — ce que
  /// `ZFieldSpec.multiple` décrit. Une `Map` en est exclue : elle est un
  /// dictionnaire, pas une multi-valeur d'un même champ, et la marquer
  /// `multiple` ferait rendre une saisie de liste par le moteur d'édition.
  bool get isCollection =>
      this == _Cat.listScalar ||
      this == _Cat.listEnum ||
      this == _Cat.listModel ||
      this == _Cat.listMap;
}

/// Codec d'un fragment de valeur — un `#` marque l'expression source.
class _Codec {
  const _Codec({
    required this.typeStr,
    required this.cond,
    required this.decode,
    required this.encode,
  });

  /// Type Dart rendu par [decode] (tel qu'écrit dans le littéral émis).
  final String typeStr;

  /// Condition de décodabilité, ou `null` si la valeur est toujours décodable.
  final String? cond;

  final String decode;
  final String encode;

  String condOf(String expr) => cond!.replaceAll('#', expr);
  String decodeOf(String expr) => decode.replaceAll('#', expr);
  String encodeOf(String expr) => encode.replaceAll('#', expr);
}

/// Codecs de clé et de valeur d'un champ `Map<K, V>`.
class _MapCodecs {
  const _MapCodecs({required this.key, required this.value});

  final _Codec key;
  final _Codec value;
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
    this.mapCodecs,
    this.elementCodec,
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

  /// Le champ doit être persisté en `Timestamp` natif côté Firestore
  /// (clé collectée dans `$XxxTimestampFields`). Défaut `false` (ISO-8601).
  final bool persistAsTimestamp;

  /// Codecs de clé/valeur — non nul si et seulement si [category] vaut
  /// `_Cat.mapType`.
  final _MapCodecs? mapCodecs;

  /// Codec de l'ÉLÉMENT — non nul si et seulement si [category] vaut
  /// `_Cat.listMap`. [elementTypeName] porte alors le type de l'élément écrit
  /// en toutes lettres (`Map<String, int>`), pas un simple nom de classe.
  final _Codec? elementCodec;
}
