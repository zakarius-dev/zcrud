/// `ZPlaceSearchProvider` — **seam de recherche géographique injectable** (gap
/// B10, parité DODLP). Port **abstrait pur-Dart**, couche `domain`
/// (AD-1/AD-4/AD-14).
///
/// origine: DODLP offre une autocomplétion d'adresse (Google Places via un proxy,
/// clé **côté serveur**). zcrud ne peut pas embarquer cette dépendance (AD-12 :
/// ZÉRO clé/endpoint/réseau dans le package). Ce port définit **uniquement le
/// contrat** ; l'implémentation concrète (Google Places via proxy, OSM Nominatim,
/// mock de test…) vit **entièrement dans l'app hôte** et est **injectée par
/// closure** dans la factory du widget adresse (même patron que `catalog`/
/// `subdivisionCatalog`, AD-4).
///
/// **AUCUNE clé API, AUCUN endpoint/URL, AUCUNE dépendance réseau
/// (`http`/`google_maps_webservice`/`flutter_google_places`), AUCUN proxy** ne
/// vit ici. Le gate de secrets (`isolation_gates_test.dart`) reste vert.
///
/// Le fournisseur mappe **lui-même** le résultat géo en [ZPostalAddress] **neutre**
/// (incluant `formatted`) : aucun type tiers ne franchit cette frontière.
library;

import 'z_postal_address.dart';

/// Prédiction d'autocomplétion neutre (pur-Dart, `const`). Ne porte que
/// l'identifiant opaque du lieu et son libellé affichable — aucun type tiers.
class ZPlacePrediction {
  /// Construit une prédiction à partir de son [placeId] opaque et de sa
  /// [description] affichable.
  const ZPlacePrediction({required this.placeId, required this.description});

  /// Identifiant opaque du lieu (transmis tel quel à [ZPlaceSearchProvider.details]).
  final String placeId;

  /// Libellé affichable de la prédiction (montré à l'utilisateur).
  final String description;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZPlacePrediction &&
          other.placeId == placeId &&
          other.description == description;

  @override
  int get hashCode => Object.hash(placeId, description);

  @override
  String toString() =>
      'ZPlacePrediction(placeId: $placeId, description: $description)';
}

/// Contrat de recherche géographique injectable (AD-4). L'implémentation vit
/// **hors** de `zcrud_intl` (app hôte) ; aucune clé/endpoint/réseau ici (AD-12).
abstract class ZPlaceSearchProvider {
  /// Recherche des prédictions pour [query]. [countryIso] (alpha-2, optionnel)
  /// borne la recherche à un pays ; [sessionToken] regroupe les appels d'une même
  /// session de saisie (facturation/latence côté implémentation).
  Future<List<ZPlacePrediction>> search(
    String query, {
    String? countryIso,
    String? sessionToken,
  });

  /// Résout les détails d'un lieu par son [placeId] opaque et les mappe en
  /// [ZPostalAddress] **neutre** (incluant `formatted`). `null` si introuvable.
  /// [sessionToken] clôt la session de saisie côté implémentation.
  Future<ZPostalAddress?> details(
    String placeId, {
    String? sessionToken,
  });
}
