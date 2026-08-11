/// État d'apprentissage par page d'un document.
///
/// ## Pourquoi cette classe est écrite à la main
///
/// Le générateur zcrud ne supporte aucun type `Map` en champ codegen : un
/// champ `qualityByPage: Map<int, int>` annoté `@ZcrudField` ferait échouer
/// le build. Cette classe est donc un value object pur : aucune annotation,
/// aucun fichier compagnon généré, aucune nature enregistrée, aucun
/// registrar.
///
/// Pur Dart — aucune dépendance Flutter/Firebase/Hive.
library;

import 'package:zcrud_core/domain.dart';

import 'z_doc_page_quality.dart';

/// Clé persistée de la map d'apprentissage (snake_case, imbriquée sous
/// `learning`).
const String kQualityByPageKey = 'quality_by_page';

/// Qualité d'apprentissage par page d'un document, colocalisée dans l'état
/// personnel [ZDocumentReadingState] (jamais dans le sous-arbre partageable
/// du document, invariant AD-9).
///
/// [qualityByPage] associe chaque page 1-based à sa qualité entière
/// ([ZDocPageQuality.value]). Une page absente compte comme « à revoir » :
/// le décompte de maîtrise part de zéro.
///
/// Persistance : `{"quality_by_page": {"1": 2, "3": 0}}` — clés = numéro de
/// page en `String` (seule forme valide en JSON/Firestore), valeurs = `int`.
class ZDocumentLearningInfo {
  /// Constructeur bas niveau (`const`).
  ///
  /// Ne filtre pas [qualityByPage] : un constructeur `const` ne le peut pas,
  /// et un `assert` serait un contresens ici — le décodage généré construit
  /// l'entité avec les valeurs brutes avant sanitisation, donc un `assert`
  /// ferait lever la désérialisation d'une donnée corrompue, en violation
  /// directe de l'invariant AD-10 (« un champ absent/corrompu ne fait
  /// jamais échouer le parent »).
  ///
  /// La garde de l'invariant « pages 1-based, valeurs entières » vit donc
  /// aux frontières réelles, et à toutes : [fromJson]/[fromJsonSafe]
  /// (désérialisation — la seule voie par laquelle une donnée corrompue
  /// peut entrer), [mark] et [copyWith] (mutation applicative). Voir
  /// `_guard`.
  ///
  /// Le slot stocké reste brut (le constructeur `const` ne peut rien
  /// filtrer, l'invariant AD-10 y interdit l'`assert`) ; c'est l'accesseur
  /// [qualityByPage] qui rend une vue non modifiable
  /// (`zUnmodifiableScalarMap`) — inconditionnellement, y compris quand ce
  /// constructeur `const` est invoqué non-`const` avec une référence
  /// mutable retenue.
  const ZDocumentLearningInfo({
    Map<int, int> qualityByPage = const <int, int>{},
    // ignore: prefer_initializing_formals
  }) : _qualityByPage = qualityByPage;

  /// État vide (aucune page évaluée) — défaut sûr de toute dégénérescence.
  static const ZDocumentLearningInfo empty = ZDocumentLearningInfo();

  /// Reconstruit défensivement depuis la map persistée — ne lève jamais
  /// (invariant AD-10).
  ///
  /// Chaque entrée est validée puis ignorée si invalide (jamais d'échec du
  /// parent) :
  /// - `quality_by_page` absente ou non-map ⇒ [empty] ;
  /// - clé non parsable en `int` (`"abc"`) ⇒ entrée ignorée ;
  /// - page `< 1` (`"0"`, `"-3"`) ⇒ entrée ignorée — l'indexation est
  ///   1-based (alignée sur les viewers PDF) ; une page `0`/négative est
  ///   une corruption, pas une donnée ;
  /// - valeur ni `num` ni `String` numérique (`"x"`, une map, `null`) ⇒
  ///   entrée ignorée.
  ///
  /// La coercion `String` est explicite : une qualité persistée en chaîne
  /// (coercion Firestore/Hive, ou repli depuis un schéma legacy porté par
  /// un import externe) est acceptée comme n'importe quel autre scalaire
  /// coercible ailleurs dans ce paquet — la rejeter aurait été une perte
  /// muette, silencieuse au moment précis où elle compterait le plus.
  factory ZDocumentLearningInfo.fromJson(Map<String, dynamic> json) {
    final raw = json[kQualityByPageKey];
    if (raw is! Map) return empty;
    final map = <int, int>{};
    for (final entry in raw.entries) {
      final page = int.tryParse('${entry.key}');
      // Pages 1-based : `0`, négatif ou non parsable ⇒ entrée rejetée.
      if (page == null || page < 1) continue;
      final value = _asQuality(entry.value);
      if (value == null) continue;
      map[page] = value;
    }
    // La map exposée est non modifiable (comme `extra` sur les entités
    // extensibles du paquet) — une mutation en place contournerait
    // l'invariant 1-based, changerait le `hashCode` (une somme) et
    // perdrait l'instance dans son propre `Set`.
    return map.isEmpty
        ? empty
        : ZDocumentLearningInfo(qualityByPage: _guard(map));
  }

  /// Coerce défensivement une valeur de qualité persistée — `null` si elle
  /// n'est pas interprétable (l'entrée est alors ignorée, jamais de
  /// `throw`).
  ///
  /// Accepte `num` et `String` numérique (`'2'`, `'2.0'`) — même tolérance
  /// que le décodage généré. Rejette tout le reste (`'x'`, une map, une
  /// liste, `null`, `bool`).
  static int? _asQuality(Object? raw) {
    if (raw is num) return raw.toInt();
    if (raw is String) return num.tryParse(raw)?.toInt();
    return null;
  }

  /// Rend une map de qualités non modifiable et filtrée sur l'invariant
  /// « pages 1-based ».
  ///
  /// La garde vit à toutes les frontières qui construisent une map :
  /// [fromJson], [mark] et [copyWith] — pas seulement à la désérialisation.
  /// Sans cela, une page `0` injectée après coup changerait le `hashCode`
  /// (une somme) et perdrait l'instance dans son propre `Set`, tout en
  /// produisant un round-trip cassé (persistée puis silencieusement
  /// rejetée à la relecture).
  static Map<int, int> _guard(Map<int, int> raw) =>
      // Vue non modifiable (idempotente ⇒ l'accesseur la rend telle
      // quelle, zéro-copie sur le chemin chaud fromJson/mark/copyWith).
      zUnmodifiableScalarMap(<int, int>{
        for (final e in raw.entries)
          if (e.key >= 1) e.key: e.value,
      });

  /// Décodage tolérant à tout d'une valeur brute de store (canal
  /// hors-codegen de [ZDocumentReadingState]).
  ///
  /// [raw] non-map (`42`, `"x"`, `null`, une liste) ⇒ [empty]. Une `Map` à
  /// clés non-`String` (store forgeant une map hétérogène) est coercée sans
  /// lever.
  static ZDocumentLearningInfo fromJsonSafe(Object? raw) {
    if (raw is Map<String, dynamic>) return ZDocumentLearningInfo.fromJson(raw);
    if (raw is Map) {
      try {
        return ZDocumentLearningInfo.fromJson(<String, dynamic>{
          for (final e in raw.entries) '${e.key}': e.value,
        });
      } catch (_) {
        return empty;
      }
    }
    return empty;
  }

  /// Qualité par page 1-based (page absente ⇒ [ZDocPageQuality.toReview]).
  ///
  /// Non modifiable inconditionnellement : l'accesseur rend une vue
  /// `unmodifiable` du slot brut — une mutation en place lève
  /// `UnsupportedError`, même sur une instance née du constructeur `const`
  /// invoqué non-`const`. Sans quoi elle changerait le [hashCode] (une
  /// somme) et perdrait l'instance dans son propre `Set`.
  Map<int, int> get qualityByPage => zUnmodifiableScalarMap(_qualityByPage);

  /// Slot brut tel que reçu par le constructeur — lu nulle part ailleurs
  /// que dans l'accesseur [qualityByPage] (le constructeur `const` ne peut
  /// pas le filtrer).
  final Map<int, int> _qualityByPage;

  /// Nombre de pages maîtrisées (qualité `>= mastered`).
  int get masteredCount => qualityByPage.values
      .where((v) => v >= ZDocPageQuality.mastered.value)
      .length;

  /// Qualité de la page [page] (1-based) — [ZDocPageQuality.toReview] si
  /// absente ou corrompue (décodage défensif de la valeur, voir
  /// `ZDocPageQuality.fromJson`).
  ZDocPageQuality qualityOf(int page) =>
      ZDocPageQuality.fromJson(qualityByPage[page]);

  /// `true` si la page [page] (1-based) est maîtrisée.
  bool isMastered(int page) => qualityOf(page).isMastered;

  /// Copie où la page [page] (1-based) prend la qualité [quality].
  ///
  /// Garde d'invariant : une page `< 1` est hors du domaine de définition ⇒
  /// l'appel est un no-op (retourne `this`), jamais un `throw` (cette API
  /// est appelée depuis un viewer, à partir d'indices de page : la faire
  /// crasher l'écran de lecture serait pire que d'ignorer une page
  /// impossible). Symétrique du rejet opéré par [fromJson].
  ZDocumentLearningInfo mark(int page, ZDocPageQuality quality) {
    if (page < 1) return this;
    final next = Map<int, int>.from(qualityByPage);
    next[page] = quality.value;
    // La map rendue est non modifiable (elle ne l'était pas — une mutation
    // en place après coup contournerait l'invariant 1-based, changerait le
    // `hashCode` et perdrait l'instance dans son propre `Set`).
    return ZDocumentLearningInfo(qualityByPage: _guard(next));
  }

  /// Bascule idempotente d'une page entre « maîtrisée » et « à revoir ».
  ZDocumentLearningInfo toggle(int page) => mark(
        page,
        isMastered(page) ? ZDocPageQuality.toReview : ZDocPageQuality.mastered,
      );

  /// Copie gardée : la map fournie est filtrée (pages `< 1` rejetées) et
  /// rendue non modifiable.
  ///
  /// Un invariant de valeur a deux frontières — la désérialisation
  /// ([fromJson]) et la mutation applicative ([mark], `copyWith`). Ne
  /// fermer que la première laisse la garde rouvrable :
  /// `i.copyWith(qualityByPage: {0: 2})` persisterait une page `0` que la
  /// relecture rejette silencieusement ⇒ round-trip non idempotent.
  ZDocumentLearningInfo copyWith({Map<int, int>? qualityByPage}) =>
      ZDocumentLearningInfo(
        qualityByPage: _guard(qualityByPage ?? this.qualityByPage),
      );

  /// Sérialise vers la map persistée : clés de page en `String`, valeurs
  /// `int`.
  ///
  /// Round-trip stable : `fromJson(toJson(i)) == i` (les entrées invalides
  /// ne peuvent pas exister dans une instance issue de [fromJson]).
  Map<String, dynamic> toJson() => <String, dynamic>{
        kQualityByPageKey: <String, dynamic>{
          for (final entry in qualityByPage.entries)
            entry.key.toString(): entry.value,
        },
      };

  /// Égalité ordre-indépendante.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ZDocumentLearningInfo) return false;
    if (other.qualityByPage.length != qualityByPage.length) return false;
    for (final entry in qualityByPage.entries) {
      if (other.qualityByPage[entry.key] != entry.value) return false;
    }
    return true;
  }

  /// Hash commutatif (somme), donc indépendant de l'ordre d'itération de la
  /// map — en cohérence avec [operator ==], lui aussi ordre-indépendant.
  ///
  /// Ne pas « corriger » en `Object.hashAll` : deux instances égales
  /// construites dans des ordres d'insertion différents (JSON relu vs
  /// suite de [mark]) produiraient des hash différents — le contrat
  /// `==`/`hashCode` serait rompu (elles se perdraient dans un `Set`/
  /// `Map`). La somme est le choix correct ici, pas une négligence.
  @override
  int get hashCode {
    var acc = 0;
    for (final entry in qualityByPage.entries) {
      acc = acc + Object.hash(entry.key, entry.value);
    }
    return acc;
  }

  @override
  String toString() => 'ZDocumentLearningInfo(qualityByPage: $qualityByPage)';
}
