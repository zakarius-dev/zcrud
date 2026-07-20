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
//   `tool/reserved_keys_gate` — décode une SONDE polluée pour CHAQUE entité **par
//   le REGISTRE** (`registry.decode` → `registry.encode`, la voie exacte de
//   `FirebaseZRepositoryImpl.fromRegistry`) et vérifie (a) `extra` propre,
//   (b) round-trip AD-4 non régressé, (c) pas de `is_deleted` réémis (aucune
//   exception), (d) pas d'`updated_at` réémis hors allowlist legacy, **(e) la clé
//   inconnue SURVIT au round-trip registre** (DW-ES14-1, soldée en ES-2.0 : le
//   registrar généré câble désormais la factory de DOMAINE `ZXxx.fromMap`).
//   (a)/(b)/(e) ne s'appliquent qu'aux entités `ZExtensible` — saut DÉCLARÉ
//   (`kNonExtensibleKinds`), jamais silencieux. ⚠️ Le harnais est dans
//   `melos.ignore` : `melos run test` ne
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
//   - **(g) CANAUX HORS-CODEGEN** (H1, code-review ES-2.1) — cf. plus bas.
//
// ## 🔴 (g) — CANAUX HORS-CODEGEN : la règle que H1 (ES-2.1) a rendue obligatoire
//
// Un **canal hors-codegen** est un champ d'entité que le générateur ne sait pas
// traiter (`ZFlashcard.source` : `ZFlashcardSource` polymorphe ;
// `ZDocumentReadingState.learning` : `Map<int,int>` — aucune branche `isDartCoreMap`
// dans `_classify`). Il est décodé/réémis **À LA MAIN**, et sa clé **doit** être
// **RÉSERVÉE** — sinon elle atterrit dans `extra`, est **réémise en double**, et
// l'`==` entre une instance mémoire et la même relue du store **casse**.
//
// **Le fait mesuré (ES-2.1)** : le harnais **TRANSPORTAIT** ces canaux dans ses
// sondes (`kProbeBodies`) sans **RIEN en OBSERVER**. Retirer `kLearningKey` de
// `_reservedKeys` laissait le **gate VERT** — seuls rougissaient des tests écrits
// **à la main, par canal, dans le package**. Le correctif H2 d'ES-2.0 (ajouter
// `source` à la sonde) était donc lui aussi **INERTE**. ⇒ **R1 violé** : rien
// n'obligeait le PROCHAIN canal (ES-2.2 `ZSmartNote.content`, ES-2.5…) à naître
// avec son observateur — seule la discipline du dev.
//
// **(g) rend le canal MACHINE-DÉTECTABLE, sans une ligne de code par entité** :
//   un champ d'instance d'une classe `@ZcrudModel` **`ZExtensible`** qui n'est
//   **NI** annoté `@ZcrudField`/`@ZcrudId`, **NI** l'un des deux slots AD-4
//   (`extra`, `extension`) **EST**, par construction, un canal hors-codegen.
//   Le gate exige alors, pour sa clé persistée (snake_case du nom de champ) :
//   - **(g1)** elle figure dans les **clés réservées** déclarées par la classe
//     (littéral de `Set` statique : chaînes + `const` top-level résolus) —
//     c'est l'invariant lui-même, désormais tenu par une machine ;
//   - **(g2)** elle figure dans `kProbeBodies[kind]` — **la sonde DOIT porter le
//     canal**, ce qui donne des **DENTS** à l'assertion comportementale **(f)**
//     du volet (A) (`extra ∩ corps-de-sonde == ∅`). Sans (g2), on désactiverait
//     (f) en vidant simplement la sonde.
//
// ⇒ (g1) attrape le canal **jamais réservé** (le bug), (g2) attrape le canal
//   **jamais sondé** (le faux vert), et (f) attrape la **régression** d'un canal
//   qui l'était. **La discipline du dev cesse d'être le garde-fou.**
//
// ⚠️ **Conséquence normative** : la clé persistée d'un canal hors-codegen est le
//   **snake_case de son nom de champ** (`learning` → `learning`, `source` →
//   `source`). C'est ce qui permet au gate de la dériver **par machine**. Une clé
//   divergente est **ROUGE** — et c'est voulu : un canal dont la clé n'est pas
//   dérivable est un canal que le gate ne peut pas garder.
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
// analyzer 12 : l'AST a été restructuré. `ClassDeclaration`/`EnumDeclaration`
// exposent désormais leur nom via `namePart.typeName` (le `namePart` porte aussi
// les type-params et l'éventuel constructeur primaire) au lieu d'un `name`
// direct. `ClassTypeAlias` et `MixinDeclaration` conservent `name`.
String? _declName(CompilationUnitMember d) {
  if (d is ClassDeclaration) return d.namePart.typeName.lexeme;
  if (d is ClassTypeAlias) return d.name.lexeme;
  if (d is EnumDeclaration) return d.namePart.typeName.lexeme;
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
    // `mixin M on ZExtensible` : toute classe qui mixe `M` EST `ZExtensible`.
    // Arête indispensable à la résolution TRANSITIVE (M4).
    for (final t in d.onClause?.superclassConstraints ?? const <NamedType>[]) {
      yield t.toSource();
    }
    for (final t in d.implementsClause?.interfaces ?? const <NamedType>[]) {
      yield t.toSource();
    }
  }
}

/// Nom simple d'un `NamedType` (générique et préfixe d'import ôtés :
/// `p.ZExtensible<T>` → `ZExtensible`).
String _simpleTypeName(String source) =>
    source.split('<').first.trim().split('.').last;

// ---------------------------------------------------------------------------
// M4 — index de types : `ZExtensible` TRANSITIF (code-review ES-2.0)
// ---------------------------------------------------------------------------

/// Index des hiérarchies déclarées dans `packages/*/lib` — **résout `ZExtensible`
/// TRANSITIVEMENT** (M4).
///
/// ## Le trou que ceci ferme
///
/// La v1 ne lisait que les super-types **directement cités** par une déclaration.
/// Une entité **écrite à la main** (donc hors `R_disk`) héritant `ZExtensible`
/// **indirectement** —
///
/// ```dart
/// abstract class ZBaseStudyEntity with ZExtensible { … }
/// class ZSmartNote extends ZBaseStudyEntity { … }   // ni `ZExtensible` cité,
///                                                   // ni `extra` déclaré ici
/// ```
///
/// — n'entrait **ni** dans `E_disk` (super-type direct = `ZBaseStudyEntity`,
/// `extra` hérité donc non « concret »), **ni** dans `R_disk` : elle **échappait
/// intégralement** au gate — ni sondée, ni signalée.
///
/// Le trou était **pré-existant**, mais ES-2.0 l'a rendu **porteur** : depuis
/// cette story, TOUT le filet DW-ES14-1 repose sur ce contrôle de couverture — et
/// ES-2 crée ~8 entités, plusieurs écrites à la main.
///
/// **Toujours zéro regex (R5)** : les arêtes viennent de l'AST
/// (`extends`/`with`/`implements`/`on`) ; seule la **résolution par nom** est
/// faite ici (le gate parse sans résolution sémantique, par conception : ni SDK
/// ni deps à charger).
class _TypeIndex {
  _TypeIndex(this._supersByName);

  /// `nom déclaré` → super-types cités (noms simples).
  final Map<String, Set<String>> _supersByName;

  final Map<String, bool> _memo = <String, bool>{};

  /// Construit l'index sur toutes les unités **sources** de `packages/*/lib`.
  factory _TypeIndex.build(Map<String, CompilationUnit> units) {
    final supers = <String, Set<String>>{};
    for (final unit in units.values) {
      for (final d in unit.declarations) {
        final name = _declName(d);
        if (name == null) continue;
        supers
            .putIfAbsent(name, () => <String>{})
            .addAll(_superTypeNames(d).map(_simpleTypeName));
      }
    }
    return _TypeIndex(supers);
  }

  /// `true` si [name] est `ZExtensible` — **directement ou transitivement**.
  /// Garde-fou de cycle (`_memo` posé à `false` avant la descente).
  bool isExtensibleName(String name) {
    if (name == 'ZExtensible') return true;
    final cached = _memo[name];
    if (cached != null) return cached;
    _memo[name] = false; // coupe les cycles (`class A extends B`, `B extends A`)
    final supers = _supersByName[name];
    final result = supers != null && supers.any(isExtensibleName);
    _memo[name] = result;
    return result;
  }

  /// `true` si la déclaration [d] est `ZExtensible` (super-type direct **ou**
  /// hérité par un super-type intermédiaire déclaré ailleurs dans `packages/*/lib`).
  bool isExtensibleDecl(CompilationUnitMember d) =>
      _superTypeNames(d).map(_simpleTypeName).any(isExtensibleName);
}

/// Membres de classe de [d] (vide pour un alias de classe).
// analyzer 12 : les membres passent par le `body` (`ClassBody`/`EnumBody`),
// qui n'existait pas auparavant — `d.members` a disparu des trois formes.
List<ClassMember> _membersOf(CompilationUnitMember d) {
  if (d is ClassDeclaration) return d.body.members;
  if (d is EnumDeclaration) return d.body.members;
  if (d is MixinDeclaration) return d.body.members;
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

/// Toutes les classes de [unit] portant un `extra` (`ZExtensible` **direct ou
/// TRANSITIF** via [index] — M4 — **ou** membre `extra` concret) — quelle que
/// soit la forme de la déclaration.
List<_EntityDecl> _entityDecls(
  CompilationUnit unit,
  String rel,
  _TypeIndex index,
) {
  final out = <_EntityDecl>[];
  for (final d in unit.declarations) {
    final name = _declName(d);
    if (name == null) continue;
    // `ZExtensible` lui-même (le mixin du cœur) est le CONTRAT, pas une entité :
    // son `extra` est abstrait, il n'a rien à sonder.
    if (name == 'ZExtensible') continue;
    final extensible = index.isExtensibleDecl(d);
    if (!extensible && !_declaresConcreteExtra(d)) continue;
    out.add(_EntityDecl(name: name, file: rel, isZExtensible: extensible));
  }
  return out;
}

// ---------------------------------------------------------------------------
// (g) — CANAUX HORS-CODEGEN (H1, code-review ES-2.1)
// ---------------------------------------------------------------------------

/// Clé persistée d'un champ Dart lowerCamelCase (`fieldRename: snake`, défaut du
/// générateur) : `qualityByPage` → `quality_by_page`, `learning` → `learning`.
String _snakeKey(String dartName) {
  final buffer = StringBuffer();
  for (var i = 0; i < dartName.length; i++) {
    final c = dartName[i];
    final upper = c.toUpperCase();
    final isUpper = c != c.toLowerCase() && c == upper;
    if (isUpper && i > 0) buffer.write('_');
    buffer.write(c.toLowerCase());
  }
  return buffer.toString();
}

/// `kind` déclaré par l'annotation `@ZcrudModel(kind: '…')` de [d], ou `null`.
String? _zcrudModelKind(CompilationUnitMember d) {
  if (d is! ClassDeclaration) return null;
  for (final a in d.metadata) {
    if (a.name.name != 'ZcrudModel') continue;
    final args = a.arguments;
    if (args == null) continue;
    final kind = _namedStringArg(args, 'kind');
    if (kind != null) return kind;
  }
  return null;
}

/// `const String kX = 'valeur';` top-level de [unit] : `nom → valeur`.
///
/// Permet de résoudre `kLearningKey` (déclaré une seule fois, consommé par
/// `fromMap` / `toMap` / `_reservedKeys` — le repo bannit les littéraux dupliqués).
Map<String, String> _topLevelConstStrings(CompilationUnit unit) {
  final out = <String, String>{};
  for (final d in unit.declarations) {
    if (d is! TopLevelVariableDeclaration) continue;
    for (final v in d.variables.variables) {
      final init = v.initializer;
      if (init is SimpleStringLiteral) out[v.name.lexeme] = init.value;
    }
  }
  return out;
}

/// Clés **littérales** des `Set` statiques déclarés par la classe [d] (typiquement
/// `_reservedKeys`).
///
/// Sont collectés : les chaînes littérales (`'extension'`, `'source'`) et les
/// identifiants résolus en `const String` top-level du même fichier
/// (`kLearningKey`). Sont **ignorés** (par construction, ce ne sont pas des
/// canaux) : les `for (final spec in $XxxFieldSpecs) spec.name` (schéma) et les
/// spreads (`...ZSyncMeta.reservedKeys`).
Set<String> _declaredReservedKeys(
  CompilationUnitMember d,
  Map<String, String> consts,
) {
  final out = <String>{};
  for (final m in _membersOf(d)) {
    if (m is! FieldDeclaration || !m.isStatic) continue;
    for (final v in m.fields.variables) {
      final init = v.initializer;
      if (init is! SetOrMapLiteral) continue;
      for (final e in init.elements) {
        if (e is SimpleStringLiteral) {
          out.add(e.value);
        } else if (e is SimpleIdentifier) {
          final resolved = consts[e.name];
          if (resolved != null) out.add(resolved);
        }
      }
    }
  }
  return out;
}

/// Un canal **hors-codegen** déclaré par une entité `@ZcrudModel` `ZExtensible`.
class _Channel {
  const _Channel({
    required this.className,
    required this.kind,
    required this.fieldName,
    required this.key,
    required this.file,
    required this.reserved,
  });

  final String className;
  final String kind;
  final String fieldName;

  /// Clé persistée dérivée (snake_case du nom de champ).
  final String key;
  final String file;

  /// `true` si [key] figure dans les clés réservées déclarées par la classe.
  final bool reserved;
}

/// Canaux hors-codegen déclarés par [unit] : champ d'instance d'une classe
/// `@ZcrudModel` **`ZExtensible`**, **non** annoté `@ZcrudField`/`@ZcrudId`, et
/// **différent** des deux slots AD-4 (`extra`, `extension`).
List<_Channel> _channelsOf(
  CompilationUnit unit,
  String rel,
  _TypeIndex index,
) {
  final consts = _topLevelConstStrings(unit);
  final out = <_Channel>[];
  for (final d in unit.declarations) {
    final kind = _zcrudModelKind(d);
    if (kind == null) continue;
    // Périmètre : les entités `ZExtensible` — ce sont EXACTEMENT celles qui ont
    // un `extra` où une clé oubliée peut atterrir (et que le volet (A) sonde).
    if (!index.isExtensibleDecl(d)) continue;
    final reserved = _declaredReservedKeys(d, consts);
    // Getters CONCRETS de la classe — sert à reconnaître le **champ de support**
    // d'un slot AD-4 exposé par accesseur (`final Map _extra;` +
    // `get extra => zNormalizeExtra(_extra, …)`, patron ES-2.2b).
    final concreteGetters = <String>{
      for (final m in _membersOf(d))
        if (m is MethodDeclaration &&
            m.isGetter &&
            m.body is! EmptyFunctionBody)
          m.name.lexeme,
    };
    for (final m in _membersOf(d)) {
      if (m is! FieldDeclaration || m.isStatic || m.abstractKeyword != null) {
        continue;
      }
      final annotated = m.metadata.any(
        (a) => a.name.name == 'ZcrudField' || a.name.name == 'ZcrudId',
      );
      if (annotated) continue;
      for (final v in m.fields.variables) {
        final name = v.name.lexeme;
        // Les DEUX slots AD-4 ont déjà leurs propres filets (assertions (a)/(b)/
        // (e), garde runtime `_$zRequireExtraPreserved`, verrou DW-ES14-2).
        if (name == 'extra' || name == 'extension') continue;
        // 🔴 CHAMP DE SUPPORT D'UN ACCESSEUR (`final X _y; ... get y => …`).
        //
        // ES-2.2b a introduit ce patron pour `extra` (`_extra` + `get extra`) ;
        // ES-3.0 (DW-ES24-1) le GÉNÉRALISE aux canaux hors-codegen exposés par un
        // accesseur **immuabilisant** (`_content` + `get content`, `_sectionOrders`
        // + `get sectionOrders`). La clé persistée d'un tel canal est celle de son
        // **ACCESSEUR PUBLIC** (`content`/`section_orders`), JAMAIS du slot brut
        // `_content`/`_section_orders` (qui n'est persisté sous aucun nom).
        final backedPublic =
            name.startsWith('_') && concreteGetters.contains(name.substring(1))
                ? name.substring(1)
                : null;
        // Les slots AD-4 adossés à leur accesseur (`_extra`/`_extension`) ne sont
        // PAS des canaux (g) — ils ont déjà leurs propres filets.
        if (backedPublic == 'extra' || backedPublic == 'extension') continue;
        // La clé du canal est dérivée de la surface PUBLIQUE (l'accesseur) quand
        // le champ est un slot de support ; sinon du champ lui-même. **Un champ
        // privé SANS accesseur concret reste un canal keyé sur `_x`** (il peut être
        // réémis à la main par `toMap()`) — portée minimale préservée.
        final channelName = backedPublic ?? name;
        final key = _snakeKey(channelName);
        out.add(
          _Channel(
            className: _declName(d)!,
            kind: kind,
            fieldName: name,
            key: key,
            file: rel,
            reserved: reserved.contains(key),
          ),
        );
      }
    }
  }
  return out;
}

/// Parse **une fois** toutes les unités SOURCES de `packages/*/lib` (hors
/// `*.g.dart`) : `rel → CompilationUnit`. Sert à la fois à construire l'index de
/// types (M4), au volet (B), à la règle (3) et à la règle (g).
Map<String, CompilationUnit> _parseSourceUnits(Directory root) {
  final units = <String, CompilationUnit>{};
  for (final lib in _packageLibs(root)) {
    for (final file in _dartFilesUnder(lib, generated: false)) {
      final rel = _rel(root, file);
      final unit = _parseOrFail(file, rel);
      if (unit != null) units[rel] = unit;
    }
  }
  return units;
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

void _checkSyntactic(Map<String, CompilationUnit> units, _TypeIndex index) {
  for (final entry in units.entries) {
    final rel = entry.key;
    if (kSyntacticAllowlist.contains(rel)) continue;
    if (_entityDecls(entry.value, rel, index).isEmpty) continue;

    if (!_usesReservedKeysToken(entry.value)) {
      _fail(
        'ajoutez `...ZSyncMeta.reservedKeys` à `_reservedKeys` (AD-19.1) — '
        'fichier: $rel',
      );
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

// ---------------------------------------------------------------------------
// 🔴 (j)/(k) — LES VOIES D'ÉCRITURE DE `extra` (remédiation ES-2.2b)
// ---------------------------------------------------------------------------
//
// ## (j) — LE HARNAIS NE CHOISIT PLUS LA VOIE
//
// Le harnais câblait **UNE** voie d'écriture par entité (`kExtraWriters`) — et
// **il choisissait laquelle** : systématiquement `copyWith`, **celle qui filtre
// déjà**. **MESURÉ (code-review ES-2.2b)** : l'entité que (i.1) encodait avait donc
// un `extra` **DÉJÀ PROPRE** ⇒ retirer la garde de sortie de `toMap()` laissait le
// gate **VERT sur 8 entités sur 9** (HIGH-1), et la voie **CONSTRUCTEUR** —
// publique, polluante — n'était sondée **nulle part** : 6 entités sur 9 portaient
// `updated_at`/`is_deleted` dans leur `extra` **EN MÉMOIRE** (HIGH-2).
//
// ⇒ Les voies sont désormais **DÉRIVÉES DU DISQUE** (AST), pas déclarées par le
//   harnais : pour toute classe `ZExtensible`, **tout constructeur public** et
//   **toute méthode publique** portant un paramètre nommé `extra` **EST** une voie
//   d'écriture publique, et **DOIT** être câblée. Dans les **deux sens** :
//     - voie sur disque, non câblée   ⇒ ROUGE (la garde ne serait pas exercée) ;
//     - voie câblée, absente du disque ⇒ ROUGE (câblage MORT).
//
// ## (k) — UN WRITER TRANSMET `extra` **VERBATIM**
//
// Un writer qui **sanitise lui-même** avant d'appeler la voie publique (« menteur
// POLI ») rend (i.1) **trivialement verte** : elle n'exerce plus AUCUNE garde de
// l'entité — et le TÉMOIN D'ÉCRITURE ne le voit pas (il n'observe qu'une clé NON
// réservée). C'est le finding **MAJEUR-2**, et c'est la forme que `kExtraWriters`
// avait **DÉJÀ** en production. La règle exige donc que le paramètre `extra` du
// writer apparaisse **EXACTEMENT UNE FOIS** dans son corps, **comme argument nommé
// `extra:`** d'une invocation. Toute autre forme (boucle, condition, appel de
// méthode dessus) est **ROUGE**.

/// Nom du paramètre `extra` d'un writer et occurrences de son identifiant.
class _ParamUses extends RecursiveAstVisitor<void> {
  _ParamUses(this.name);

  final String name;
  final List<SimpleIdentifier> uses = <SimpleIdentifier>[];

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.name == name) uses.add(node);
    super.visitSimpleIdentifier(node);
  }
}

/// Corps + paramètres d'un writer, qu'il soit un **tear-off** de fonction
/// top-level (`write: _ctorSmartNote`) ou une **closure** inline.
({FormalParameterList? params, FunctionBody? body})? _writerFn(
  CompilationUnit unit,
  Expression writeArg,
) {
  if (writeArg is FunctionExpression) {
    return (params: writeArg.parameters, body: writeArg.body);
  }
  if (writeArg is SimpleIdentifier) {
    for (final d in unit.declarations) {
      if (d is FunctionDeclaration && d.name.lexeme == writeArg.name) {
        return (
          params: d.functionExpression.parameters,
          body: d.functionExpression.body,
        );
      }
    }
  }
  return null;
}

/// **(k)** — le writer transmet-il `extra` **VERBATIM** ?
void _checkWriterVerbatim(
  CompilationUnit unit,
  String file,
  String label,
  Expression writeArg,
) {
  final fn = _writerFn(unit, writeArg);
  if (fn == null || fn.params == null) {
    _fail(
      '(k) writer ILLISIBLE pour `$label` ($file) : `write:` doit être un tear-off '
      'de fonction top-level du MÊME fichier, ou une closure littérale. Le gate '
      'refuse de valider un writer qu\'il ne peut pas LIRE (il pourrait sanitiser '
      'lui-même — finding MAJEUR-2).',
    );
    return;
  }
  final params = fn.params!.parameters;
  if (params.length != 2) {
    _fail(
      '(k) writer `$label` ($file) : signature inattendue (2 paramètres attendus : '
      'l\'entité, puis `extra`).',
    );
    return;
  }
  final extraParam = params[1].name?.lexeme;
  if (extraParam == null) {
    _fail('(k) writer `$label` ($file) : paramètre `extra` sans nom.');
    return;
  }
  final visitor = _ParamUses(extraParam);
  fn.body!.accept(visitor);
  final uses = visitor.uses;
  final ok = uses.length == 1 &&
      uses.single.parent is NamedExpression &&
      (uses.single.parent! as NamedExpression).name.label.name == 'extra';
  if (!ok) {
    _fail(
      '(k) WRITER MENTEUR (ou suspect) — `$label` ($file) : le paramètre '
      '`$extraParam` doit être transmis **VERBATIM** à la voie publique de '
      'l\'entité, c.-à-d. apparaître EXACTEMENT UNE FOIS, comme argument nommé '
      '`extra:` (${uses.length} occurrence(s) trouvée(s)).\n'
      '\n'
      'POURQUOI : un writer qui DÉPOUILLE `extra` lui-même avant d\'appeler '
      '`copyWith`/le constructeur rend les assertions (i.1a)/(i.1b)/(i.1c) '
      'TRIVIALEMENT VERTES — elles n\'exercent plus AUCUNE garde de l\'entité. Le '
      'TÉMOIN D\'ÉCRITURE ne l\'attrape PAS (il n\'observe qu\'une clé NON '
      'réservée) : c\'est le finding MAJEUR-2 de la code-review ES-2.2b, et c\'est '
      'la forme que `kExtraWriters` avait DÉJÀ en production.\n'
      '\n'
      'GESTE : `write: (e, x) => (e as ZXxx).copyWith(extra: x)` — RIEN d\'autre '
      'sur `x`.',
    );
  }
}

/// Voies déclarées dans une liste littérale de `ZExtraWriter(...)` — **et** (k)
/// vérifiée sur chacun.
Set<String> _voiesOf(
  CompilationUnit unit,
  String file,
  String owner,
  Expression? list,
) {
  final voies = <String>{};
  if (list is! ListLiteral) {
    _fail(
      '(j) `$owner` ($file) : la liste de `ZExtraWriter` n\'est pas un littéral de '
      'liste — le gate ne peut plus dériver les voies câblées (il ne devinera '
      'pas : c\'est ROUGE).',
    );
    return voies;
  }
  for (final e in list.elements) {
    final args = _argsOf(e);
    if (args == null) continue;
    final voie = _namedStringArg(args, 'voie');
    if (voie == null) {
      _fail(
        '(j) `$owner` ($file) : un `ZExtraWriter` sans `voie:` LITTÉRALE — le nom '
        'de la voie est LU PAR LE GATE (ne jamais l\'interpoler).',
      );
      continue;
    }
    voies.add(voie);
    for (final a in args.arguments) {
      if (a is NamedExpression && a.name.label.name == 'write') {
        _checkWriterVerbatim(unit, file, '$owner#$voie', a.expression);
      }
    }
  }
  return voies;
}

/// Câblage RÉEL du harnais, lu comme une **valeur** (jamais comme une mention).
class _Wiring {
  _Wiring({
    required this.registrars,
    required this.probeKinds,
    required this.probeBodyKeys,
    required this.manualClasses,
    required this.voiesByKind,
    required this.voiesByClass,
    required this.hasWriterTable,
  });

  /// `kind → voies câblées` (clés de `kExtraWriters`, valeurs `voie:`). Règle (j).
  final Map<String, Set<String>> voiesByKind;

  /// `className → voies câblées` (sondes manuelles, champ `writes:`). Règle (j).
  final Map<String, Set<String>> voiesByClass;

  /// La table `kExtraWriters` a-t-elle été trouvée ? (les fixtures de
  /// `prove_gates` n'embarquent pas le harnais : (j)/(k) y sont SKIPPÉES —
  /// skip **DÉCLARÉ**, cf. `--root`.)
  final bool hasWriterTable;

  /// Éléments du littéral `kRegistrars` (`R_wired`).
  final Set<String> registrars;

  /// Clés du littéral `kProbeBodies` (`K_wired`) — verrouillées à l'exécution
  /// sur `registry.kinds` par le harnais (dans les DEUX sens).
  final Set<String> probeKinds;

  /// `kind → clés du CORPS de sonde` — consommé par la règle **(g2)** : un canal
  /// hors-codegen déclaré doit être **porté par la sonde**, sinon l'assertion
  /// comportementale (f) du volet (A) serait désactivable en vidant la sonde.
  final Map<String, Set<String>> probeBodyKeys;

  /// `className:` des éléments de `kManualProbes`.
  final Set<String> manualClasses;
}

_Wiring _readWiring(Directory root, {required bool fixtureMode}) {
  final registrars = <String>{};
  final probeKinds = <String>{};
  final probeBodyKeys = <String, Set<String>>{};
  final manualClasses = <String>{};
  final voiesByKind = <String, Set<String>>{};
  final voiesByClass = <String, Set<String>>{};
  var hasWriterTable = false;

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
            if (k is! SimpleStringLiteral) continue;
            probeKinds.add(k.value);
            // Clés du CORPS de sonde (règle (g2)) — lues comme une VALEUR.
            final body = e.value;
            final keys = <String>{};
            if (body is SetOrMapLiteral) {
              for (final b in body.elements) {
                if (b is MapLiteralEntry) {
                  final bk = b.key;
                  if (bk is SimpleStringLiteral) keys.add(bk.value);
                }
              }
            }
            probeBodyKeys[k.value] = keys;
          }
        }
      } else {
        _fail(
          '`kProbeBodies` introuvable ou n\'est plus un littéral de map dans '
          '$_registrarsFile — le gate ne peut plus dériver les kinds sondés.',
        );
      }

      // 🔴 (j)/(k) — LES VOIES D'ÉCRITURE (`kExtraWriters` : kind → [voies]).
      final writersInit = _topLevelInitializer(unit, 'kExtraWriters');
      if (writersInit is SetOrMapLiteral) {
        hasWriterTable = true;
        for (final e in writersInit.elements) {
          if (e is! MapLiteralEntry) continue;
          final k = e.key;
          if (k is! SimpleStringLiteral) continue;
          voiesByKind[k.value] =
              _voiesOf(unit, _registrarsFile, k.value, e.value);
        }
      } else if (!fixtureMode) {
        _fail(
          '`kExtraWriters` introuvable ou n\'est plus un littéral de map dans '
          '$_registrarsFile — le gate ne peut plus dériver les VOIES d\'écriture '
          'câblées (règle (j)). Sans elle, le harnais pourrait de nouveau ne '
          'sonder QUE la voie la plus sûre (finding HIGH-1, ES-2.2b).',
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
          if (name == null) continue;
          manualClasses.add(name);
          // (j)/(k) — les voies de la sonde manuelle (champ `writes:`).
          //
          // ⚠️ SKIP DÉCLARÉ en mode fixture (`--root`) : les fixtures de
          // `prove_gates` n'embarquent qu'un SQUELETTE de harnais (elles prouvent
          // les règles (1)/(2)/(3)/(4)/(g)/(h), pas (j)/(k)). En mode RÉEL, une
          // sonde manuelle SANS `writes:` est **ROUGE** (voie non sondée).
          if (fixtureMode) continue;
          Expression? writes;
          for (final a in args.arguments) {
            if (a is NamedExpression && a.name.label.name == 'writes') {
              writes = a.expression;
            }
          }
          voiesByClass[name] =
              _voiesOf(unit, _manualProbesFile, name, writes);
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
    probeBodyKeys: probeBodyKeys,
    manualClasses: manualClasses,
    voiesByKind: voiesByKind,
    voiesByClass: voiesByClass,
    hasWriterTable: hasWriterTable,
  );
}

/// **(j)** — voies d'écriture publiques de `extra` **DÉRIVÉES DU DISQUE** pour la
/// déclaration [d] : tout **constructeur public** et toute **méthode publique**
/// portant un paramètre nommé `extra`.
///
/// Le constructeur **par défaut** (sans nom) est la voie `'ctor'` ; un
/// constructeur nommé est `'ctor:<nom>'` ; une méthode est son propre nom
/// (`'copyWith'`).
Set<String> _voiesOnDisk(CompilationUnitMember d) {
  final voies = <String>{};
  for (final m in _membersOf(d)) {
    if (m is ConstructorDeclaration) {
      final name = m.name?.lexeme;
      if (name != null && name.startsWith('_')) continue; // ctor privé
      if (!_hasExtraParam(m.parameters)) continue;
      voies.add(name == null ? 'ctor' : 'ctor:$name');
    } else if (m is MethodDeclaration) {
      if (m.isStatic || m.isGetter || m.isSetter) continue;
      final name = m.name.lexeme;
      if (name.startsWith('_')) continue; // méthode privée
      final params = m.parameters;
      if (params == null || !_hasExtraParam(params)) continue;
      voies.add(name);
    }
  }
  return voies;
}

/// La liste de paramètres porte-t-elle un paramètre **nommé `extra`** ?
bool _hasExtraParam(FormalParameterList params) =>
    params.parameters.any((p) => p.name?.lexeme == 'extra');

// ---------------------------------------------------------------------------
// (h) — POLITIQUE `hide` DES EXTENSIONS GÉNÉRÉES (M2 généralisé, ES-2.1)
// ---------------------------------------------------------------------------
//
// ## La règle, et pourquoi elle n'était tenue par AUCUNE machine
//
// Le `copyWith` **GÉNÉRÉ** (extension `XxxZcrud`) ne connaît QUE les champs
// `@ZcrudField` : il **IGNORE** `extra`, `extension` et les canaux hors-codegen
// (`source`, `learning`) et les **remet à leurs DÉFAUTS** ⇒ **perte silencieuse**.
// Les entités le neutralisent par un `copyWith` d'**INSTANCE**… mais cela ne
// masque que l'appel **IMPLICITE**. L'appel **EXPLICITE d'extension** reste ouvert
// **dès que le barrel exporte l'extension** :
//
// ```dart
// import 'package:zcrud_flashcard/zcrud_flashcard.dart';
// ZFlashcardZcrud(card).copyWith(question: 'x')  // ⇒ extra, extension ET source
//                                                //   REMIS AUX DÉFAUTS. DÉTRUITS.
// ```
//
// D'où la politique `hide` du repo (précédents : `ZStudyFolderZcrud`,
// `ZRepetitionInfoZcrud`, `ZStudySessionConfigZcrud`). **Mais AUCUN gate ne la
// tenait** — elle vivait en **commentaire de barrel**. Résultat, mesuré :
// **`ZFlashcardZcrud` était EXPORTÉE** — l'entité PHARE, `ZExtensible`, porteuse
// du canal `source` — **sous 1000+ tests verts**. C'est la MÊME faute que H1 :
// **une règle sans sa machine**.
//
// **(h)** : toute entité `@ZcrudModel` **`ZExtensible`** exportée par un point
// d'entrée public de son package (`packages/<pkg>/lib/*.dart`) doit y voir son
// extension générée `XxxZcrud` **`hide`** (ou non listée dans un `show`).

/// (h) — aucun point d'entrée public n'expose l'extension générée d'une entité
/// `ZExtensible` (son `copyWith` généré détruirait `extra`/`extension`/canaux).
void _checkGeneratedExtensionsHidden(
  Map<String, CompilationUnit> units,
  _TypeIndex index,
) {
  // Entités `@ZcrudModel` + `ZExtensible` : `nom → fichier source`.
  final entities = <String, String>{};
  for (final entry in units.entries) {
    for (final d in entry.value.declarations) {
      if (_zcrudModelKind(d) == null) continue;
      if (!index.isExtensibleDecl(d)) continue;
      entities[_declName(d)!] = entry.key;
    }
  }

  for (final entry in units.entries) {
    final rel = entry.key;
    final parts = rel.split('/');
    // Point d'entrée PUBLIC = `packages/<pkg>/lib/<file>.dart` (profondeur 1 —
    // ce qu'un consommateur peut importer ; `lib/src/**` ne l'est pas).
    if (parts.length != 4) continue;
    final pkgLib = parts.sublist(0, 3).join('/');

    for (final dir in entry.value.directives) {
      if (dir is! ExportDirective) continue;
      final uri = dir.uri.stringValue;
      // Les ré-exports `package:` visent un AUTRE package : c'est SON barrel qui
      // porte la responsabilité (et il est vérifié de son côté).
      if (uri == null || uri.startsWith('package:') || uri.startsWith('dart:')) {
        continue;
      }
      final target = '$pkgLib/$uri';

      for (final ent in entities.entries) {
        if (ent.value != target) continue;
        final extName = '${ent.key}Zcrud';

        final hidden = dir.combinators
            .whereType<HideCombinator>()
            .expand((c) => c.hiddenNames)
            .any((n) => n.name == extName);
        final shows = dir.combinators.whereType<ShowCombinator>().toList();
        final shownNames =
            shows.expand((c) => c.shownNames).map((n) => n.name).toSet();
        // Exposée si : aucun `show` et pas de `hide` ; ou un `show` qui la liste.
        final exposed =
            shows.isEmpty ? !hidden : shownNames.contains(extName);
        if (!exposed) continue;

        _fail(
          '(h) EXTENSION GÉNÉRÉE EXPORTÉE : `$extName` est exposée par le point '
          'd\'entrée public `$rel` (`export \'$uri\';` sans `hide`), alors que '
          '`${ent.key}` est `ZExtensible`.\n'
          'Son `copyWith` GÉNÉRÉ ne connaît QUE les champs `@ZcrudField` : il '
          'IGNORE `extra`, `extension` et les canaux hors-codegen, et les REMET '
          'AUX DÉFAUTS. Le `copyWith` d\'INSTANCE ne masque que l\'appel '
          'IMPLICITE — l\'appel EXPLICITE d\'extension reste ouvert depuis l\'API '
          'PUBLIQUE :\n'
          '    $extName(e).copyWith(...)   ⇒ extra / extension / canaux DÉTRUITS\n'
          'GESTE : `export \'$uri\' hide $extName;` (précédents : '
          '`ZStudyFolderZcrud`, `ZRepetitionInfoZcrud`). Si la surface publique a '
          'besoin de `toMap()`, la PROMOUVOIR en méthode d\'instance (patron '
          '`ZDocumentViewerPrefs.toMap`).',
        );
      }
    }
  }
}

void _checkCoverage(
  Directory root,
  Map<String, CompilationUnit> units,
  _TypeIndex index, {
  required bool fixtureMode,
}) {
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
        '(`kProbeBodies`) — **2 lignes**, c\'est tout (depuis ES-2.0/DW-ES14-1, '
        '`registry.decode` décode par la factory de DOMAINE : aucun décodeur '
        'manuel n\'est plus à câbler).',
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
  //     ⚠️ H1 (ES-1.4) : détection par AST ⇒ TOUTE forme de déclaration légale
  //     est couverte (une ligne, en-tête ENROULÉE par `dart format`,
  //     `final class`, `base`/`sealed`/`interface class`,
  //     `class X = Y with ZExtensible;`).
  //     ⚠️ M4 (ES-2.0) : détection TRANSITIVE ⇒ une entité écrite à la main qui
  //     hérite `ZExtensible` par un super-type INTERMÉDIAIRE
  //     (`class ZSmartNote extends ZBaseStudyEntity`) ne passe plus au travers.
  //     Périmètre = les classes `ZExtensible` : ce sont EXACTEMENT celles dont le
  //     volet (A) sait sonder l'`extra` (assertions (a)/(b)/(e) conditionnées à
  //     `entity is ZExtensible`). L'allowlist du volet (B) ne les exempte PAS.
  for (final entry in units.entries) {
    for (final decl in _entityDecls(entry.value, entry.key, index)) {
      if (!decl.isZExtensible) continue;
      final covered = wiring.registrars.contains('register${decl.name}') ||
          wiring.manualClasses.contains(decl.name);
      if (covered) continue;
      _fail(
        '`${decl.name}` est `ZExtensible` (slot `extra`, AD-4 — directement ou '
        'PAR HÉRITAGE) mais n\'est ni enregistrée (`register${decl.name}` absent '
        'de $_registrarsFile) ni sondée ($_manualProbesFile) — fichier: '
        '${decl.file}. Le volet (A) ne la couvrirait pas (faux vert par '
        'omission).',
      );
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

  // ─────────────────────────────────────────────────────────────────────────
  // 🔴 (j) — VOIES D'ÉCRITURE : DÉRIVÉES DU DISQUE, JAMAIS CHOISIES PAR LE
  //          HARNAIS (remédiation HIGH-1/HIGH-2, code-review ES-2.2b).
  // ─────────────────────────────────────────────────────────────────────────
  var voieCount = 0;
  if (!fixtureMode && wiring.hasWriterTable) {
    for (final entry in units.entries) {
      for (final d in entry.value.declarations) {
        final name = _declName(d);
        if (name == null || name == 'ZExtensible') continue;
        if (!index.isExtensibleDecl(d)) continue;

        final onDisk = _voiesOnDisk(d);
        final kind = _zcrudModelKind(d);
        // Une entité `ZExtensible` est couverte SOIT par un kind du registre,
        // SOIT par une sonde manuelle (règle (3) le garantit déjà).
        final wired = kind != null
            ? wiring.voiesByKind[kind]
            : wiring.voiesByClass[name];
        if (wired == null) continue; // règle (3) a déjà rougi.
        voieCount += onDisk.length;

        for (final voie in onDisk.difference(wired)) {
          _fail(
            '(j) VOIE D\'ÉCRITURE NON SONDÉE : `$name.$voie` (${entry.key}) prend '
            'un paramètre `extra` — c\'est une **voie d\'écriture PUBLIQUE** du '
            'slot AD-4 — mais elle n\'est PAS câblée dans le harnais '
            '(`kExtraWriters[\'${kind ?? name}\']` / `ZManualProbe.writes`).\n'
            '\n'
            'POURQUOI C\'EST ROUGE : les assertions (i.1a)/(i.1b)/(i.1c) '
            'n\'exercent QUE les voies câblées. Tant que le harnais ne sondait que '
            '`copyWith` (la voie qui FILTRE déjà), l\'entité encodée avait un '
            '`extra` DÉJÀ PROPRE ⇒ la garde de sortie n\'était exigée par AUCUNE '
            'machine (8 entités sur 9 — MESURÉ), et la voie CONSTRUCTEUR '
            '(polluante) portait `updated_at`/`is_deleted` EN MÉMOIRE sur 6 '
            'entités sur 9. C\'est le finding HIGH-1/HIGH-2 de la code-review '
            'ES-2.2b : **le harnais choisissait la voie**.\n'
            '\n'
            'GESTE : ajouter `ZExtraWriter(voie: \'$voie\', write: …, '
            'eagerlyNormalized: …)` à la liste du kind (le writer doit passer '
            '`extra` VERBATIM — règle (k)).',
          );
        }
        for (final voie in wired.difference(onDisk)) {
          _fail(
            '(j) VOIE MORTE dans le harnais : `${kind ?? name}` câble la voie '
            '`$voie`, mais `$name` (${entry.key}) n\'expose AUCUN constructeur ni '
            'méthode publique de ce nom prenant un paramètre `extra` — retirez '
            'l\'entrée (sinon la table se fossilise et prétend couvrir une voie '
            'qui n\'existe plus).',
          );
        }
      }
    }
  }

  // (g) — CANAUX HORS-CODEGEN (H1, code-review ES-2.1).
  //
  // Un champ d'instance d'une entité `@ZcrudModel` `ZExtensible` qui n'est NI
  // `@ZcrudField`/`@ZcrudId`, NI l'un des deux slots AD-4 (`extra`/`extension`)
  // EST un canal hors-codegen : le générateur ne le connaît pas, l'entité le
  // décode/réémet À LA MAIN. Deux obligations, toutes deux tenues ICI par une
  // machine — plus par la discipline du dev (R1).
  var channelCount = 0;
  for (final entry in units.entries) {
    for (final ch in _channelsOf(entry.value, entry.key, index)) {
      channelCount++;

      // (g1) — le canal DOIT être une clé RÉSERVÉE de l'entité.
      if (!ch.reserved) {
        _fail(
          '(g1) CANAL HORS-CODEGEN NON RÉSERVÉ : `${ch.className}.${ch.fieldName}` '
          '(${ch.file}) n\'est ni `@ZcrudField`/`@ZcrudId`, ni `extra`/`extension` '
          '— c\'est donc un canal décodé/réémis À LA MAIN (patron '
          '`ZFlashcard.source` / `ZDocumentReadingState.learning`). Sa clé '
          'persistée `${ch.key}` DOIT figurer dans les clés RÉSERVÉES de la classe '
          '(`_reservedKeys`), sinon elle atterrit dans `extra` (AD-4 : `extra` = '
          'clés INCONNUES du domaine), est RÉÉMISE EN DOUBLE par `toMap()`, et '
          'l\'`==` entre une instance mémoire et la même relue du store CASSE.\n'
          'GESTE : ajouter `${ch.key}` (ou la constante qui la porte) à '
          '`${ch.className}._reservedKeys`.\n'
          '⚠️ Si la clé persistée de ce champ n\'est PAS le snake_case de son nom, '
          'le gate ne peut pas la dériver : c\'est un canal INGARDABLE — renommez '
          'le champ ou la clé.',
        );
      }

      // (g2) — le canal DOIT être PORTÉ PAR LA SONDE (sans quoi (f) est inerte).
      final body = wiring.probeBodyKeys[ch.kind];
      if (body == null) {
        _fail(
          '(g2) le kind `${ch.kind}` (`${ch.className}`, ${ch.file}) porte un canal '
          'hors-codegen `${ch.key}` mais n\'a AUCUN corps de sonde dans '
          '`kProbeBodies` ($_registrarsFile).',
        );
      } else if (!body.contains(ch.key)) {
        _fail(
          '(g2) CANAL DÉCLARÉ, JAMAIS SONDÉ : `${ch.className}.${ch.fieldName}` '
          '(${ch.file}) est un canal hors-codegen de clé `${ch.key}`, mais '
          '`kProbeBodies[\'${ch.kind}\']` NE LA PORTE PAS ($_registrarsFile).\n'
          'Conséquence : le canal serait « préservé » PAR PROSE — l\'assertion '
          'comportementale (f) du volet (A) (`extra ∩ corps-de-sonde == ∅`) ne '
          'l\'observerait JAMAIS, et le retirer de `_reservedKeys` laisserait le '
          'gate VERT. C\'est EXACTEMENT le finding H1 d\'ES-2.1 (et H2 d\'ES-2.0 '
          'sur `source`) : la sonde TRANSPORTAIT le canal sans que rien ne '
          'l\'OBSERVE.\n'
          'GESTE : ajouter une valeur NON VIDE sous la clé `${ch.key}` au corps de '
          'sonde du kind `${ch.kind}`.',
        );
      }
    }
  }

  stdout.writeln(
    '[gate:reserved-keys] couverture : ${rDisk.length} registrar(s) sur disque '
    '(${kDisk.length} kind(s)), ${wiring.registrars.length} câblé(s) '
    '(${wiring.probeKinds.length} sonde(s)), '
    '${wiring.manualClasses.length} sonde(s) manuelle(s), '
    '$channelCount canal/canaux hors-codegen (règle (g)), '
    '$voieCount voie(s) d\'écriture de `extra` sondée(s) (règles (j)/(k)).',
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
      '(AD-19.1), ou DÉTRUIT une clé métier inconnue (AD-4). Voir les assertions '
      'ci-dessus — (a) `extra` pollué, (b) round-trip AD-4 régressé au décodage, '
      '(c) `is_deleted` réémis, (d) `updated_at` réémis hors allowlist, '
      '(e) clé inconnue PERDUE au round-trip `registry.decode → encode` '
      '(DW-ES14-1 : le registrar généré doit câbler `fromMap: ZXxx.fromMap`, la '
      'factory de DOMAINE — jamais `_\$ZXxxFromMap`).',
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

  // Un SEUL parcours des sources : l'index de types (M4 — `ZExtensible`
  // transitif) est dérivé du même AST que les deux contrôles qui le consomment.
  final units = _parseSourceUnits(root);
  final index = _TypeIndex.build(units);

  _checkSyntactic(units, index);
  _checkGeneratedExtensionsHidden(units, index);
  _checkCoverage(root, units, index, fixtureMode: fixtureMode);

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
