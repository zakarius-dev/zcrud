// Gate ES-1.4 / M5 : **clés de sync RÉSERVÉES** (AD-19.1.c) — volets (A) ET (B).
//
// ## Pourquoi ce gate existe
//
// AD-19 : `updated_at` / `is_deleted` (`ZSyncMeta.reservedKeys`) appartiennent au
// **store**, jamais au domaine. Une entité ne les capture JAMAIS dans son `extra`
// (AD-4) et ne les réémet JAMAIS depuis son `toMap`/`toJson` (AD-16).
//
// En ES-1.3, `ZRepetitionInfo` et `ZStudySessionConfig` violaient cet invariant
// (2 findings **HIGH**) — **sous 1193 tests verts**. Les tests par entité ajoutés
// alors ne protègent QUE ces entités : ils ne disent rien des ~8 entités d'ES-2.
// Ce gate protège l'invariant **par machine**, pas par vigilance.
//
// ## ⚠️ POURQUOI CE GATE PARSE LE DART (AST) ET NE « GREPPE » PLUS (H1, ES-1.4)
//
// La v1 de ce gate reconnaissait les classes `ZExtensible` avec une **regex
// ligne-à-ligne** n'acceptant que `[abstract] class X … with … ZExtensible` sur
// **une seule ligne**. Trois formes **légales et banales** lui échappaient — dont
// l'**en-tête enroulée** que `dart format` **produit lui-même** dès que la
// déclaration dépasse 80 colonnes, et les **modificateurs Dart 3**
// (`final`/`base`/`sealed`/`interface class`), plus la forme `class X = Y with Z;`.
// Une entité d'ES-2 **écrite à la main** (comme `ZMindmap`/`ZMindmapNode`) dans
// l'une de ces formes traversait le contrôle de couverture **VERTE, sans jamais
// être sondée** : le filet censé attraper « une entité que personne ne sonde »
// était lui-même aveugle (cinquième faux vert de l'epic).
//
// Une regex « plus grosse » aurait reconduit la même fragilité (il resterait
// toujours une forme légale non prévue). Ce gate **PARSE** donc le Dart avec
// `package:analyzer` (AST syntaxique, sans résolution) :
//   - les classes sont reconnues par leurs `extendsClause`/`withClause`/
//     `implementsClause` — **indifférentes aux modificateurs, aux retours à la
//     ligne et aux commentaires**, donc à TOUTE forme de déclaration légale ;
//   - la présence de `ZSyncMeta.reservedKeys` est cherchée dans le **flux de
//     jetons** (les commentaires — `//` **ET** `/* */` — en sont absents par
//     construction : plus aucun « dépouillement » textuel à maintenir) ;
//   - le câblage du harnais est lu comme une **VALEUR** (éléments du littéral
//     `kRegistrars` / clés de `kProbeBodies` / arguments `className:` de
//     `kManualProbes`), plus comme une **mention textuelle** (M3) : un nom cité
//     dans un commentaire de bloc, dans une autre liste ou dans du code mort ne
//     compte PLUS comme « câblé ».
// Un fichier Dart **non parsable** est un **ÉCHEC** du gate (jamais un skip
// silencieux) : le gate refuse de scanner à l'aveugle.
//
// ## Deux volets — les DEUX requis (AD-19.1.c)
//
// **(A) COMPORTEMENTAL** (l'autorité) : `flutter test --tags reserved-keys` dans
//   `tool/reserved_keys_gate` — décode une SONDE polluée pour CHAQUE entité et
//   vérifie (a) `extra` propre, (b) round-trip AD-4 non régressé, (c) pas de
//   `is_deleted` réémis (aucune exception), (d) pas d'`updated_at` réémis hors
//   allowlist legacy. ⚠️ Le harnais est dans `melos.ignore` : `melos run test` ne
//   l'exécute PAS — d'où l'invocation EXPLICITE ici. `exit 79` (« aucun test
//   exécuté ») est traité comme **FATAL** : sans test, le gate n'a rien prouvé
//   (ce serait le faux vert total qu'il est censé prévenir).
//
// **(B) SYNTAXIQUE** (filet pédagogique) : tout fichier de `packages/*/lib` (hors
//   `*.g.dart`) déclarant une classe `ZExtensible` **ou** un membre `extra`
//   CONCRET (champ ou getter avec corps) DOIT contenir le jeton
//   `ZSyncMeta.reservedKeys`. Un `extra` **abstrait** (le contrat `ZExtensible`
//   du cœur lui-même : `Map<String, dynamic> get extra;`) n'est PAS concerné.
//
// **CONTRÔLE DE COUVERTURE (anti-faux-vert par omission, AD-19.1.c pt.1)** : le
//   gate dérive l'inventaire du DISQUE et le confronte au câblage du harnais.
//   - (1) `R_disk \ R_wired ≠ ∅` → ROUGE (registrar non câblé ⇒ entité non sondée) ;
//   - (2) `R_wired \ R_disk ≠ ∅` → ROUGE (câblage MORT) ;
//   - (3) `E_disk \ E_covered ≠ ∅` → ROUGE (classe `ZExtensible` ni enregistrée ni
//         sondée) — la règle que H1 rendait aveugle, désormais fondée sur l'AST ;
//   - (4) `K_disk \ K_wired ≠ ∅` (et l'inverse) → ROUGE (kind du disque sans corps
//         de sonde, ou corps orphelin). **C'est l'ancrage RUNTIME de (1)** : le
//         harnais verrouille à l'exécution `registry.kinds == kProbeBodies.keys`
//         **dans les deux sens** (test « chaque kind enregistré a un corps de
//         sonde »), donc `K_wired` reflète le registre RÉELLEMENT construit par
//         `kRegistrars` — et non ce que le gate aurait « cru lire ».
//
// ## Prérequis
//
// Le gate lit les `*.g.dart` (gitignorés, AD-3) : il **PRÉSUPPOSE le codegen**
// (`melos run generate`), comme `gate:codegen`. En CI il est exécuté par
// `melos run verify`, APRÈS l'étape de codegen.
//
// Usage : dart run scripts/ci/gate_reserved_keys.dart [--root <path>]
//   `--root` (convention maison) : racine alternative pour les fixtures de
//   `prove_gates.dart`. En mode fixture, le volet (A) est explicitement SKIPPÉ
//   (la fixture n'embarque pas le harnais) — le volet (B) et la couverture
//   restent exercés. En mode RÉEL (sans `--root`), l'absence du harnais est FATALE.
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Chemin (relatif à la racine) du harnais portant le volet (A).
const String _harnessPath = 'tool/reserved_keys_gate';

/// Fichier de câblage lu pour dériver `R_wired` / `K_wired`.
const String _registrarsFile = '$_harnessPath/lib/src/registrars.dart';

/// Fichier des sondes manuelles (entités `ZExtensible` hors registre).
const String _manualProbesFile = '$_harnessPath/lib/src/manual_probes.dart';

/// Allowlist du **volet (B) SEUL** : fichiers déclarant un membre `extra` concret
/// **sans** consommer `ZSyncMeta.reservedKeys`.
///
/// ⛔ **PORTÉE STRICTEMENT BORNÉE AU VOLET (B).** Elle ne dispense **JAMAIS** du
/// contrôle de couverture : une classe **`ZExtensible`** allowlistée ici resterait
/// **ROUGE** en règle (3) si elle n'était ni enregistrée ni sondée. On ne « passe
/// pas le gate » en s'ajoutant à cette liste.
///
/// Les 6 classes `ZExtensible` du repo dérivent toutes leurs clés réservées de la
/// définition machine unique (`ZSyncMeta.reservedKeys`) : **aucune** n'est ici.
///
/// - `packages/zcrud_core/lib/src/domain/edition/app_file.dart` (`AppFile`) —
///   **DÉCOUVERT par le passage à l'AST (ES-1.4/H1)** : l'ancienne regex du volet
///   (B) exigeait `final Map<String, dynamic> extra;` et ratait donc le type
///   **nullable** (`Map<String, dynamic>? extra;`). `AppFile` est un **value
///   object** (dartdoc : « ce n'est **PAS** un `ZEntity` »), **NON `ZExtensible`**,
///   embarqué comme sous-map d'un champ d'entité. Son `extra` n'est **pas un
///   fourre-tout** : `fromMap` ne lit QUE la clé imbriquée `map['extra']`
///   (`_asStringMap(map['extra'])`) et `toMap` ne réémet QUE `'extra'` — les clés
///   réservées, écrites par le store à la **racine** du document, ne peuvent
///   structurellement ni y entrer ni en sortir. Un `_reservedKeys` y serait un
///   garde sans objet (et un simple commentaire citant `ZSyncMeta.reservedKeys`
///   ne satisferait PLUS le contrôle, qui lit désormais les **jetons**).
const Set<String> kSyntacticAllowlist = <String>{
  'packages/zcrud_core/lib/src/domain/edition/app_file.dart',
};

int _failures = 0;

void _fail(String message) {
  _failures++;
  stderr.writeln('[gate:reserved-keys] ÉCHEC : $message');
}

// ---------------------------------------------------------------------------
// Socle AST — plus AUCUN scan ligne-à-ligne (H1/M3)
// ---------------------------------------------------------------------------

/// Parse [file] en AST **syntaxique** (aucune résolution : ni SDK, ni deps).
///
/// Un fichier non parsable est un **ÉCHEC** (jamais un skip) : un gate qui
/// n'arrive pas à lire un fichier ne peut rien affirmer à son sujet.
CompilationUnit? _parseOrFail(File file, String rel) {
  try {
    return parseString(content: file.readAsStringSync()).unit;
  } on ArgumentError catch (e) {
    final msg = e.toString().split('\n').take(3).join(' ');
    _fail(
      'fichier Dart NON PARSABLE ($rel) — le gate refuse de scanner à '
      'l\'aveugle (une classe `ZExtensible` pourrait s\'y cacher) : $msg',
    );
    return null;
  }
}

/// `true` si le flux de JETONS de [unit] contient `ZSyncMeta.reservedKeys`.
///
/// Le flux de jetons **exclut les commentaires par construction** (ligne ET
/// bloc) : une mention en dartdoc ou en `/* … */` ne satisfait PAS ce contrôle,
/// sans aucun « dépouillement » textuel à maintenir.
bool _usesReservedKeysToken(CompilationUnit unit) {
  Token? t = unit.beginToken;
  while (t != null && !t.isEof) {
    if (t.lexeme == 'ZSyncMeta' &&
        t.next?.lexeme == '.' &&
        t.next?.next?.lexeme == 'reservedKeys') {
      return true;
    }
    t = t.next;
  }
  return false;
}

/// Nom déclaré d'un membre de compilation (classe / alias / enum / mixin).
String? _declName(CompilationUnitMember d) {
  if (d is ClassDeclaration) return d.name.lexeme;
  if (d is ClassTypeAlias) return d.name.lexeme;
  if (d is EnumDeclaration) return d.name.lexeme;
  if (d is MixinDeclaration) return d.name.lexeme;
  return null;
}

/// Tous les super-types cités par [d] (`extends` / `with` / `implements`).
///
/// **Indifférent aux modificateurs Dart 3** (`abstract`/`base`/`final`/`sealed`/
/// `interface`/`mixin class`), aux **retours à la ligne** et aux commentaires :
/// c'est de la STRUCTURE, pas du texte.
Iterable<String> _superTypeNames(CompilationUnitMember d) sync* {
  if (d is ClassDeclaration) {
    final ext = d.extendsClause;
    if (ext != null) yield ext.superclass.toSource();
    for (final t in d.withClause?.mixinTypes ?? const <NamedType>[]) {
      yield t.toSource();
    }
    for (final t in d.implementsClause?.interfaces ?? const <NamedType>[]) {
      yield t.toSource();
    }
  } else if (d is ClassTypeAlias) {
    // Forme `class X = Base with ZExtensible;` (alias de classe — LÉGALE).
    yield d.superclass.toSource();
    for (final t in d.withClause.mixinTypes) {
      yield t.toSource();
    }
    for (final t in d.implementsClause?.interfaces ?? const <NamedType>[]) {
      yield t.toSource();
    }
  } else if (d is EnumDeclaration) {
    for (final t in d.withClause?.mixinTypes ?? const <NamedType>[]) {
      yield t.toSource();
    }
    for (final t in d.implementsClause?.interfaces ?? const <NamedType>[]) {
      yield t.toSource();
    }
  } else if (d is MixinDeclaration) {
    for (final t in d.implementsClause?.interfaces ?? const <NamedType>[]) {
      yield t.toSource();
    }
  }
}

/// `true` si [source] (source d'un `NamedType`) désigne `ZExtensible`
/// (générique et/ou préfixe d'import compris : `p.ZExtensible<T>`).
bool _isZExtensibleType(String source) {
  final base = source.split('<').first.trim();
  return base.split('.').last == 'ZExtensible';
}

/// Membres de classe de [d] (vide pour un alias de classe).
List<ClassMember> _membersOf(CompilationUnitMember d) {
  if (d is ClassDeclaration) return d.members;
  if (d is EnumDeclaration) return d.members;
  if (d is MixinDeclaration) return d.members;
  return const <ClassMember>[];
}

/// `true` si [d] déclare un membre `extra` **CONCRET** (champ d'instance, ou
/// getter avec corps).
///
/// Un `extra` **abstrait** (`Map<String, dynamic> get extra;`) est le **contrat**
/// (`mixin ZExtensible` du cœur), pas un stockage : il n'est pas concerné par
/// AD-19.1 — sans quoi le gate rougirait sur sa propre définition.
bool _declaresConcreteExtra(CompilationUnitMember d) {
  for (final m in _membersOf(d)) {
    if (m is FieldDeclaration) {
      if (m.isStatic || m.abstractKeyword != null) continue;
      for (final v in m.fields.variables) {
        if (v.name.lexeme == 'extra') return true;
      }
    } else if (m is MethodDeclaration) {
      // Getter `extra` AVEC corps (`=> _extra;` ou `{ … }`) — la forme qui
      // échappait au volet (B) de la v1 (H1, pt. 2).
      if (m.isGetter &&
          m.name.lexeme == 'extra' &&
          m.body is! EmptyFunctionBody) {
        return true;
      }
    }
  }
  return false;
}

/// Une classe du disque portant le slot `extra` (AD-4).
class _EntityDecl {
  const _EntityDecl({
    required this.name,
    required this.file,
    required this.isZExtensible,
  });

  final String name;
  final String file;

  /// `true` si la classe mixe/implémente/étend `ZExtensible` (par l'AST).
  final bool isZExtensible;
}

/// Toutes les classes de [unit] portant un `extra` (mixin `ZExtensible` **ou**
/// membre `extra` concret) — **quelle que soit la forme de la déclaration**.
List<_EntityDecl> _entityDecls(CompilationUnit unit, String rel) {
  final out = <_EntityDecl>[];
  for (final d in unit.declarations) {
    final name = _declName(d);
    if (name == null) continue;
    final extensible = _superTypeNames(d).any(_isZExtensibleType);
    if (!extensible && !_declaresConcreteExtra(d)) continue;
    out.add(_EntityDecl(name: name, file: rel, isZExtensible: extensible));
  }
  return out;
}

// ---------------------------------------------------------------------------
// Parcours du disque
// ---------------------------------------------------------------------------

List<File> _dartFilesUnder(Directory dir, {required bool generated}) {
  if (!dir.existsSync()) return <File>[];
  final out = dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) {
        final p = f.path.replaceAll(r'\', '/');
        if (!p.endsWith('.dart')) return false;
        final isG = p.endsWith('.g.dart') || p.endsWith('.freezed.dart');
        return generated ? isG : !isG;
      })
      .toList();
  out.sort((File a, File b) => a.path.compareTo(b.path));
  return out;
}

/// Répertoires `packages/<pkg>/lib` sous [root].
List<Directory> _packageLibs(Directory root) {
  final pkgs = Directory('${root.path}/packages');
  if (!pkgs.existsSync()) return <Directory>[];
  final out = pkgs
      .listSync()
      .whereType<Directory>()
      .map((Directory d) => Directory('${d.path}/lib'))
      .where((Directory d) => d.existsSync())
      .toList();
  out.sort((Directory a, Directory b) => a.path.compareTo(b.path));
  return out;
}

String _rel(Directory root, File f) => f.path
    .replaceAll(r'\', '/')
    .replaceFirst('${root.path.replaceAll(r'\', '/')}/', '');

// ---------------------------------------------------------------------------
// Volet (B) — syntaxique (filet pédagogique), fondé sur l'AST
// ---------------------------------------------------------------------------

void _checkSyntactic(Directory root) {
  for (final lib in _packageLibs(root)) {
    for (final file in _dartFilesUnder(lib, generated: false)) {
      final rel = _rel(root, file);
      if (kSyntacticAllowlist.contains(rel)) continue;

      final unit = _parseOrFail(file, rel);
      if (unit == null) continue;
      if (_entityDecls(unit, rel).isEmpty) continue;

      if (!_usesReservedKeysToken(unit)) {
        _fail(
          'ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1) — '
          'fichier: $rel',
        );
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Contrôle de couverture — anti-faux-vert par omission (AD-19.1.c pt.1)
// ---------------------------------------------------------------------------

/// Trouve l'initialiseur de la variable top-level [name] dans [unit].
Expression? _topLevelInitializer(CompilationUnit unit, String name) {
  for (final d in unit.declarations) {
    if (d is! TopLevelVariableDeclaration) continue;
    for (final v in d.variables.variables) {
      if (v.name.lexeme == name) return v.initializer;
    }
  }
  return null;
}

/// Extrait le `kind` (`registry.register<X>('kind', …)`) d'un corps de registrar.
class _KindFinder extends RecursiveAstVisitor<void> {
  String? kind;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (kind == null && node.methodName.name == 'register') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty && args.first is SimpleStringLiteral) {
        kind = (args.first as SimpleStringLiteral).value;
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// `ArgumentList` d'un élément de liste, qu'il soit `Foo(...)` (parsé en
/// `MethodInvocation` faute de résolution) ou `const Foo(...)`
/// (`InstanceCreationExpression`).
ArgumentList? _argsOf(CollectionElement e) {
  if (e is MethodInvocation) return e.argumentList;
  if (e is InstanceCreationExpression) return e.argumentList;
  return null;
}

/// Valeur littérale d'un argument nommé [name].
String? _namedStringArg(ArgumentList args, String name) {
  for (final a in args.arguments) {
    if (a is NamedExpression && a.name.label.name == name) {
      final v = a.expression;
      if (v is SimpleStringLiteral) return v.value;
    }
  }
  return null;
}

/// Câblage RÉEL du harnais, lu comme une **valeur** (jamais comme une mention).
class _Wiring {
  _Wiring({
    required this.registrars,
    required this.probeKinds,
    required this.manualClasses,
  });

  /// Éléments du littéral `kRegistrars` (`R_wired`).
  final Set<String> registrars;

  /// Clés du littéral `kProbeBodies` (`K_wired`) — verrouillées à l'exécution
  /// sur `registry.kinds` par le harnais (dans les DEUX sens).
  final Set<String> probeKinds;

  /// `className:` des éléments de `kManualProbes`.
  final Set<String> manualClasses;
}

_Wiring _readWiring(Directory root, {required bool fixtureMode}) {
  final registrars = <String>{};
  final probeKinds = <String>{};
  final manualClasses = <String>{};

  final regFile = File('${root.path}/$_registrarsFile');
  if (regFile.existsSync()) {
    final unit = _parseOrFail(regFile, _registrarsFile);
    if (unit != null) {
      // R_wired = ÉLÉMENTS du littéral `kRegistrars` (M3 : appartenance RÉELLE,
      // pas mention textuelle — un nom cité dans un commentaire de bloc, dans
      // `const _obsoletes = [...]` ou dans du code mort ne compte PAS).
      final regInit = _topLevelInitializer(unit, 'kRegistrars');
      if (regInit is ListLiteral) {
        for (final e in regInit.elements) {
          if (e is SimpleIdentifier) registrars.add(e.name);
        }
      } else {
        _fail(
          '`kRegistrars` introuvable ou n\'est plus un littéral de liste dans '
          '$_registrarsFile — le gate ne peut plus dériver le câblage RÉEL '
          '(il ne devinera pas : c\'est ROUGE).',
        );
      }

      // K_wired = CLÉS du littéral `kProbeBodies`. Ancrage RUNTIME de R_wired :
      // le harnais verrouille `registry.kinds == kProbeBodies.keys` dans les
      // deux sens ⇒ ces clés sont les kinds RÉELLEMENT enregistrés.
      final probeInit = _topLevelInitializer(unit, 'kProbeBodies');
      if (probeInit is SetOrMapLiteral) {
        for (final e in probeInit.elements) {
          if (e is MapLiteralEntry) {
            final k = e.key;
            if (k is SimpleStringLiteral) probeKinds.add(k.value);
          }
        }
      } else {
        _fail(
          '`kProbeBodies` introuvable ou n\'est plus un littéral de map dans '
          '$_registrarsFile — le gate ne peut plus dériver les kinds sondés.',
        );
      }
    }
  } else if (!fixtureMode) {
    _fail(
      'câblage introuvable : $_registrarsFile — le harnais du volet (A) est '
      'ABSENT, le gate ne prouverait RIEN.',
    );
  }

  final probesFile = File('${root.path}/$_manualProbesFile');
  if (probesFile.existsSync()) {
    final unit = _parseOrFail(probesFile, _manualProbesFile);
    if (unit != null) {
      final init = _topLevelInitializer(unit, 'kManualProbes');
      if (init is ListLiteral) {
        for (final e in init.elements) {
          final args = _argsOf(e);
          if (args == null) continue;
          final name = _namedStringArg(args, 'className');
          if (name != null) manualClasses.add(name);
        }
      } else {
        _fail(
          '`kManualProbes` introuvable ou n\'est plus un littéral de liste dans '
          '$_manualProbesFile — les sondes manuelles ne sont plus dérivables.',
        );
      }
    }
  }

  return _Wiring(
    registrars: registrars,
    probeKinds: probeKinds,
    manualClasses: manualClasses,
  );
}

void _checkCoverage(Directory root, {required bool fixtureMode}) {
  // ---- R_disk / K_disk : registrars GÉNÉRÉS présents sur DISQUE -------------
  // (les fixtures du générateur vivent sous `test/`, hors `packages/*/lib` :
  // déjà exclues par la restriction du parcours.)
  final rDisk = <String, String>{}; // registrar -> fichier
  final kDisk = <String, String>{}; // kind      -> registrar
  for (final lib in _packageLibs(root)) {
    for (final file in _dartFilesUnder(lib, generated: true)) {
      final rel = _rel(root, file);
      final unit = _parseOrFail(file, rel);
      if (unit == null) continue;
      for (final d in unit.declarations) {
        if (d is! FunctionDeclaration) continue;
        final name = d.name.lexeme;
        if (!name.startsWith('registerZ')) continue;
        rDisk[name] = rel;
        final finder = _KindFinder();
        d.functionExpression.body.accept(finder);
        final kind = finder.kind;
        if (kind == null) {
          _fail(
            '`$name` ($rel) : `kind` illisible (aucun `registry.register(\'…\')` '
            'trouvé) — le gate ne peut pas confronter ce registrar au harnais.',
          );
        } else {
          kDisk[kind] = name;
        }
      }
    }
  }

  final wiring = _readWiring(root, fixtureMode: fixtureMode);

  // (1) Registrar sur disque, NON câblé → faux vert par omission.
  for (final entry in rDisk.entries) {
    if (!wiring.registrars.contains(entry.key)) {
      _fail(
        '`${entry.key}` existe (${entry.value}) mais n\'est pas câblé dans '
        '$_registrarsFile — le gate serait un FAUX VERT PAR OMISSION '
        '(AD-19.1.c pt.1). Ajoutez-le à `kRegistrars`, avec son corps de sonde '
        '(`kProbeBodies`) et son décodeur de domaine (`kDomainDecoders`).',
      );
    }
  }

  // (2) Câblage MORT (registrar câblé, disparu du disque).
  for (final wired in wiring.registrars) {
    if (!rDisk.containsKey(wired)) {
      _fail(
        '`$wired` est câblé dans $_registrarsFile mais n\'existe plus sur '
        'disque — câblage MORT, à retirer (anti-pourrissement).',
      );
    }
  }

  // (3) Classe `ZExtensible` ni enregistrée, ni sondée manuellement.
  //     ⚠️ H1 : détection par AST ⇒ TOUTE forme de déclaration légale est
  //     couverte (une ligne, en-tête ENROULÉE par `dart format`, `final class`,
  //     `base`/`sealed`/`interface class`, `class X = Y with ZExtensible;`).
  //     Périmètre = les classes `ZExtensible` : ce sont EXACTEMENT celles dont le
  //     volet (A) sait sonder l'`extra` (assertions (a)/(b) conditionnées à
  //     `entity is ZExtensible`). L'allowlist du volet (B) ne les exempte PAS.
  for (final lib in _packageLibs(root)) {
    for (final file in _dartFilesUnder(lib, generated: false)) {
      final rel = _rel(root, file);
      final unit = _parseOrFail(file, rel);
      if (unit == null) continue;
      for (final decl in _entityDecls(unit, rel)) {
        if (!decl.isZExtensible) continue;
        final covered = wiring.registrars.contains('register${decl.name}') ||
            wiring.manualClasses.contains(decl.name);
        if (covered) continue;
        _fail(
          '`${decl.name}` est `ZExtensible` (slot `extra`, AD-4) mais n\'est ni '
          'enregistrée (`register${decl.name}` absent de $_registrarsFile) ni '
          'sondée ($_manualProbesFile) — fichier: $rel. Le volet (A) ne la '
          'couvrirait pas (faux vert par omission).',
        );
      }
    }
  }

  // (4) Kinds : disque ↔ corps de sonde (ancrage RUNTIME du câblage, M3).
  for (final entry in kDisk.entries) {
    if (!wiring.probeKinds.contains(entry.key)) {
      _fail(
        'le kind `${entry.key}` (enregistré par `${entry.value}`) n\'a AUCUN '
        'corps de sonde dans `kProbeBodies` ($_registrarsFile) — sonde muette '
        '= faux vert. Ajoutez son corps métier minimal valide.',
      );
    }
  }
  for (final kind in wiring.probeKinds) {
    if (!kDisk.containsKey(kind) && !fixtureMode) {
      _fail(
        'corps de sonde ORPHELIN : le kind `$kind` de `kProbeBodies` n\'est '
        'enregistré par AUCUN registrar sur disque — nettoyer $_registrarsFile.',
      );
    }
  }

  stdout.writeln(
    '[gate:reserved-keys] couverture : ${rDisk.length} registrar(s) sur disque '
    '(${kDisk.length} kind(s)), ${wiring.registrars.length} câblé(s) '
    '(${wiring.probeKinds.length} sonde(s)), '
    '${wiring.manualClasses.length} sonde(s) manuelle(s).',
  );
}

// ---------------------------------------------------------------------------
// Volet (A) — comportemental (autorité)
// ---------------------------------------------------------------------------

void _runBehavioural(Directory root) {
  final harness = Directory('${root.path}/$_harnessPath');
  if (!harness.existsSync()) {
    _fail(
      'harnais introuvable ($_harnessPath) — le volet (A) COMPORTEMENTAL ne '
      'peut pas s\'exécuter : le gate serait un faux vert total.',
    );
    return;
  }

  stdout.writeln(
    '[gate:reserved-keys] volet (A) — flutter test --tags reserved-keys '
    '($_harnessPath)…',
  );
  final r = Process.runSync(
    'flutter',
    <String>['test', '--tags', 'reserved-keys'],
    workingDirectory: harness.path,
  );
  stdout.write(r.stdout);
  stderr.write(r.stderr);

  // ⚠️ PIÈGE CAPITAL : le harnais est dans `melos.ignore` ⇒ `melos run test` ne
  // le lance PAS. Si aucun test taggé n'est exécuté (exit 79), le volet (A) n'a
  // RIEN prouvé — c'est FATAL (contrairement à `verify:serialization`, où le
  // corpus est encore dû à ES-3.5).
  if (r.exitCode == 79) {
    _fail(
      'AUCUN test taggé `reserved-keys` exécuté dans $_harnessPath (exit 79). '
      'Le volet (A) n\'a rien prouvé — faux vert total. Vérifiez '
      '`@Tags([\'reserved-keys\'])` et `dart_test.yaml`.',
    );
    return;
  }
  if (r.exitCode != 0) {
    _fail(
      'volet (A) ROUGE : une entité capture/réémet des clés de sync réservées '
      '(AD-19.1). Voir les assertions ci-dessus — (a) `extra` pollué, '
      '(b) round-trip AD-4 régressé, (c) `is_deleted` réémis, '
      '(d) `updated_at` réémis hors allowlist.',
    );
  }
}

void main(List<String> args) {
  var rootArg = '.';
  var fixtureMode = false;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--root' && i + 1 < args.length) {
      rootArg = args[i + 1];
      fixtureMode = true;
    }
  }
  final root = Directory(rootArg);
  if (!root.existsSync()) {
    stderr.writeln('[gate:reserved-keys] ÉCHEC : racine introuvable ($rootArg)');
    exit(2);
  }

  _checkSyntactic(root);
  _checkCoverage(root, fixtureMode: fixtureMode);

  if (fixtureMode) {
    stdout.writeln(
      '[gate:reserved-keys] volet (A) SKIPPÉ — mode fixture (--root $rootArg) : '
      'la fixture n\'embarque pas le harnais. Volets (B) + couverture exercés.',
    );
  } else {
    _runBehavioural(root);
  }

  if (_failures > 0) {
    stderr.writeln('');
    stderr.writeln('[gate:reserved-keys] $_failures violation(s) — AD-19.1.');
    exit(1);
  }
  stdout.writeln(
    '[gate:reserved-keys] OK — clés de sync réservées : volet (A) + volet (B) + '
    'couverture (AD-19.1.c).',
  );
}
