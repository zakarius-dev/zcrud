/// Causes d'échec **neutres** de la résolution « ma position » (G10, parité
/// legacy `gff:219-265`).
///
/// origine: le port `ZGeoLocationResolver` de `zcrud_geo` exprime l'échec par
/// `null` (contrat nominal, AD-10 — jamais un throw). `null` seul ne permet
/// pas à l'hôte de distinguer « service désactivé » (le legacy affiche un
/// SnackBar, `gff:224-229`) de « permission refusée » (le legacy se tait,
/// `gff:236-238`). Ce paquet expose donc la CAUSE par un canal latéral
/// ([ZGeoLocationFailureListener]) — le MESSAGE utilisateur reste à la charge
/// de l'hôte (libellé/l10n hors de ce satellite, FR-26).
library;

/// Cause d'échec d'une résolution de position. Une cause est notifiée **au
/// plus une fois par appel** du resolver, toujours AVANT que le `Future`
/// complète `null`.
enum ZGeoLocationFailureCause {
  /// Le **service** de localisation de l'appareil est désactivé (parité
  /// `gff:221`, `isLocationServiceEnabled == false`). Le legacy informe
  /// l'utilisateur dans ce cas — l'hôte devrait faire de même.
  serviceDisabled,

  /// Permission refusée : `denied` au contrôle PUIS encore `denied` après
  /// l'unique redemande (parité `gff:233-238` — une seule `requestPermission`).
  permissionDenied,

  /// Permission refusée **définitivement** (`deniedForever`, au contrôle ou en
  /// réponse à la redemande — parité `gff:240`). Redemander est inutile :
  /// seul un passage par les réglages système peut la rouvrir.
  permissionDeniedForever,

  /// Toute autre défaillance : exception du plugin, timeout de lecture
  /// (le legacy borne à 10 s), position hors-bornes/non finie. Parité
  /// `gff:262-264` (catch → debugPrint → abandon silencieux).
  error,
}

/// Écouteur d'échec optionnel : reçoit la [ZGeoLocationFailureCause] quand le
/// resolver va rendre `null`. Jamais invoqué sur un succès. Un throw DANS ce
/// callback est avalé (AD-10 : aucune exception ne s'échappe du resolver).
typedef ZGeoLocationFailureListener = void Function(
  ZGeoLocationFailureCause cause,
);
