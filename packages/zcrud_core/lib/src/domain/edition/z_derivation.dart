/// Dérivation **déclarative** d'un champ à partir d'autres champs (CR-IFFD-22).
///
/// origine: motif redécouvert à l'identique par chaque hôte — « choisir un
/// dossier force le titre », « choisir un client remplit son adresse ». La
/// capacité existait déjà (`fieldListenable(a).addListener(...) → setValue(b)`)
/// mais **impérativement**, recâblée par formulaire, avec deux pièges que
/// chacun réécrivait seul : la **sérialisation des résolutions asynchrones**
/// (deux sélections rapprochées se résolvant dans le désordre) et la politique
/// d'**écrasement d'une saisie manuelle**. Les deux appartiennent au socle.
///
/// **Pur-Dart** (couche `domain`, garde `domain_purity_test.dart`) : aucune
/// dépendance Flutter. Contrairement au reste de `ZFieldSpec`, [ZDerivation]
/// porte des **closures** fournies par l'hôte : elle n'est donc PAS émise par
/// le générateur (AD-3, `ConstantReader`) — c'est une **surcharge runtime**
/// posée par l'hôte via `spec.copyWith(derivedFrom: ...)` ou une spec écrite à
/// la main. Le schéma statique reste pur-données.
library;

import 'z_field_choice.dart';
import 'z_field_spec.dart';

/// Politique d'écrasement d'une dérivation — **OBLIGATOIRE à la déclaration**,
/// aucun défaut : le comportement legacy (écraser une saisie) et le
/// comportement prudent divergent trop pour qu'un défaut soit choisi par le
/// socle.
enum ZDerivationOverwrite {
  /// Écrit la valeur dérivée **inconditionnellement**, même si l'utilisateur a
  /// déjà saisi manuellement le champ cible. Parité du comportement legacy.
  always,

  /// N'écrit la valeur dérivée que si l'utilisateur **n'a jamais touché** le
  /// champ cible (`ZFormController.isTouched(target) == false`). Une saisie
  /// manuelle « gèle » définitivement la cible (jusqu'à
  /// `reset`/`reseed`/`markPristine`, qui re-vierge le suivi).
  ifPristine,
}

/// Bornes **dérivées** d'un champ (cible `bounds`).
///
/// Pur-données. [min]/[max] sont volontairement `Object?` : le canal existant
/// (`ZValidatorSpec.minKey`/`maxKey` inter-champs, et les bornes de date
/// `minDateKey`/`maxDateKey`) compare aussi bien des `num` que des `DateTime`
/// ou des `String` ISO-8601.
class ZFieldBounds {
  /// Construit un couple de bornes (l'une ou l'autre peut rester `null`).
  const ZFieldBounds({this.min, this.max});

  /// Borne minimale (`num`, `DateTime` ou `String` ISO-8601), ou `null`.
  final Object? min;

  /// Borne maximale (`num`, `DateTime` ou `String` ISO-8601), ou `null`.
  final Object? max;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZFieldBounds &&
          runtimeType == other.runtimeType &&
          min == other.min &&
          max == other.max;

  @override
  int get hashCode => Object.hash(runtimeType, min, max);

  @override
  String toString() => 'ZFieldBounds(min: $min, max: $max)';
}

/// Clés des **tranches compagnes** dans lesquelles le moteur de dérivation
/// publie les cibles qui ne sont pas la valeur du champ (`options`, `bounds`).
///
/// Ce ne sont PAS de nouveaux canaux : ce sont des tranches ordinaires du
/// `ZFormController`, déjà consommées par la présentation existante —
/// `ZSelectConfig.choicesFromKey` pour les options, `ZValidatorSpec.minKey`/
/// `maxKey` (et `ZDateConfig.minDateKey`/`maxDateKey`) pour les bornes. L'hôte
/// **branche** sa spec sur ces clés :
///
/// ```dart
/// ZFieldSpec(
///   name: 'ville',
///   type: EditionFieldType.select,
///   config: ZSelectConfig(choicesFromKey: ZDerivationChannels.optionsKey('ville')),
///   derivedFrom: ZDerivation(
///     sources: <String>['pays'],
///     overwrite: ZDerivationOverwrite.always,
///     options: (v) async => villesDe(v['pays']),
///   ),
/// )
/// ```
abstract final class ZDerivationChannels {
  /// Préfixe commun (choisi pour ne jamais entrer en collision avec une clé
  /// persistée snake_case — AD-3).
  static const String prefix = r'$zderived';

  /// Tranche portant la `List<ZFieldChoice>` dérivée du champ [field].
  static String optionsKey(String field) => '$prefix.options.$field';

  /// Tranche portant la borne **minimale** dérivée du champ [field].
  static String minKey(String field) => '$prefix.min.$field';

  /// Tranche portant la borne **maximale** dérivée du champ [field].
  static String maxKey(String field) => '$prefix.max.$field';

  /// `true` si [name] est une tranche compagne possédée par le moteur (jamais
  /// une saisie utilisateur, jamais soumise).
  static bool isDerivedChannel(String name) => name.startsWith('$prefix.');
}

/// Fonction de dérivation **asynchrone** : reçoit le snapshot `nom → valeur`
/// des [ZDerivation.sources] et renvoie la cible. Toujours `Future` : c'est le
/// cas dangereux (résolutions dans le désordre) que le socle doit sérialiser ;
/// les cibles purement synchrones (`visible`/`bounds`) ont leur propre type.
typedef ZDerivationValueFn = Future<Object?> Function(
  Map<String, Object?> sources,
);

/// Fonction de dérivation des **options** d'un `select`/`radio`/`checkbox`.
typedef ZDerivationOptionsFn = Future<List<ZFieldChoice>> Function(
  Map<String, Object?> sources,
);

/// Prédicat de **visibilité** dérivée — SYNCHRONE (il alimente le canal
/// structurel `visibleFields`, recalculé en un temps).
typedef ZDerivationVisibleFn = bool Function(Map<String, Object?> sources);

/// Fonction de **bornes** dérivées — SYNCHRONE (même raison).
typedef ZDerivationBoundsFn = ZFieldBounds? Function(
  Map<String, Object?> sources,
);

/// Déclaration « ce champ **dérive** de ces champs-là » (CR-IFFD-22).
///
/// **Quatre cibles séparées et optionnelles** — surtout pas un callback
/// fourre-tout : chacune a son canal de sortie propre et sa robustesse propre.
///
/// | Cible | Écrit dans | Consommé par |
/// |---|---|---|
/// | [value] | la tranche du champ cible | tout widget de champ (`value-in-slice`) |
/// | [options] | `ZDerivationChannels.optionsKey(cible)` | `ZSelectConfig.choicesFromKey` |
/// | [visible] | `controller.visibleFields` (via `DynamicEdition`) | le build structurel |
/// | [bounds] | `ZDerivationChannels.min/maxKey(cible)` | `ZValidatorSpec.minKey/maxKey` |
///
/// **[overwrite] ne gouverne que [value]** : c'est la SEULE cible qui entre en
/// concurrence avec une saisie utilisateur. [options]/[visible]/[bounds]
/// écrivent des canaux **possédés par le moteur**, que l'utilisateur n'écrit
/// jamais — il n'y a rien à y écraser. Le paramètre reste **requis** pour que
/// la politique appliquée à [value] soit toujours lisible dans la spec.
///
/// **Frontière avec `ZFieldSpec.condition` (`ZCondition`)** : `ZCondition` est
/// la visibilité **déclarative pur-données** (`const`, émise par le générateur,
/// sérialisable, sources `state`/`persisted`/`context`) — elle reste la voie
/// par défaut. [visible] est l'**échappatoire impérative** pour ce que
/// `ZCondition` ne sait pas exprimer (calcul arbitraire sur plusieurs sources).
/// Elles ne se remplacent pas : elles se **composent en ET** — un champ est
/// visible ssi sa `condition` passe ET sa dérivation [visible] renvoie `true`.
/// Un champ sans [visible] n'est jamais masqué par le moteur.
class ZDerivation {
  /// Déclare une dérivation. [sources] liste les champs observés ; [overwrite]
  /// est **requis** (aucun défaut) ; les quatre cibles sont optionnelles.
  const ZDerivation({
    required this.sources,
    required this.overwrite,
    this.value,
    this.options,
    this.visible,
    this.bounds,
  });

  /// Champs **sources** observés (abonnement CIBLÉ à leur tranche — SM-1).
  final List<String> sources;

  /// Politique d'écrasement de [value] — **requise**, aucun défaut.
  final ZDerivationOverwrite overwrite;

  /// Dérive la **valeur** du champ cible (asynchrone, sérialisée par jeton).
  final ZDerivationValueFn? value;

  /// Dérive les **options** du champ cible (asynchrone, sérialisée par jeton).
  final ZDerivationOptionsFn? options;

  /// Dérive la **visibilité** du champ cible (synchrone ; composée en ET avec
  /// `ZFieldSpec.condition`).
  final ZDerivationVisibleFn? visible;

  /// Dérive les **bornes** du champ cible (synchrone).
  final ZDerivationBoundsFn? bounds;

  /// `true` si au moins une cible est déclarée (une dérivation sans cible est
  /// inerte — défensif, jamais une erreur).
  bool get hasTarget =>
      value != null || options != null || visible != null || bounds != null;
}

/// Détecte les **cycles** du graphe de dérivation de [fields] (CR-IFFD-22,
/// décision 3).
///
/// Retourne la liste des cycles trouvés, chacun sous forme de chemin NOMMÉ et
/// **normalisé** (rotation commençant par le plus petit nom, arête de retour
/// incluse) : `['a', 'b', 'a']` pour `a → b → a`.
///
/// **Pur et sans effet de bord** — même idiome que
/// `ZSyncMeta.collidingReservedKeys` (CR-IFFD-14) : un hôte peut l'appeler
/// **avant** d'attacher son formulaire, y compris en release. Un cycle reste
/// **exprimable** : le moteur ne lève pas, il le signale (debug) et coupe la
/// propagation à l'exécution (garde de réentrance).
List<List<String>> zDerivationCycles(List<ZFieldSpec> fields) {
  final edges = <String, List<String>>{};
  for (final f in fields) {
    final d = f.derivedFrom;
    if (d == null || !d.hasTarget) continue;
    // Arête source → cible : un changement de `source` propage vers `f.name`.
    for (final s in d.sources) {
      (edges[s] ??= <String>[]).add(f.name);
    }
  }
  final cycles = <String, List<String>>{};
  final state = <String, int>{}; // 0/absent = blanc, 1 = gris, 2 = noir.
  final stack = <String>[];

  void visit(String node) {
    state[node] = 1;
    stack.add(node);
    for (final next in edges[node] ?? const <String>[]) {
      final st = state[next] ?? 0;
      if (st == 1) {
        final from = stack.indexOf(next);
        final path = <String>[...stack.sublist(from), next];
        final key = _normalizeCycle(path).join('→');
        cycles[key] = _normalizeCycle(path);
      } else if (st == 0) {
        visit(next);
      }
    }
    stack.removeLast();
    state[node] = 2;
  }

  for (final node in edges.keys.toList(growable: false)) {
    if ((state[node] ?? 0) == 0) visit(node);
  }
  return cycles.values.toList(growable: false);
}

/// Normalise un cycle `[a, b, a]` par rotation sur son plus petit nom, pour que
/// deux découvertes du même cycle produisent le MÊME chemin (dédoublonnage).
List<String> _normalizeCycle(List<String> path) {
  final ring = path.sublist(0, path.length - 1);
  var pivot = 0;
  for (var i = 1; i < ring.length; i++) {
    if (ring[i].compareTo(ring[pivot]) < 0) pivot = i;
  }
  final rotated = <String>[
    for (var i = 0; i < ring.length; i++) ring[(pivot + i) % ring.length],
  ];
  return <String>[...rotated, rotated.first];
}
