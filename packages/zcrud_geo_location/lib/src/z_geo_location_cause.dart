/// Causes d'échec **neutres** de la résolution « ma position ».
///
/// Le port `ZGeoLocationResolver` de `zcrud_geo` exprime l'échec par `null`
/// (contrat nominal, invariant AD-10 — jamais un throw). `null` seul ne
/// permet pas à l'hôte de distinguer « service désactivé » (mérite
/// généralement d'informer l'utilisateur) de « permission refusée » (peut
/// rester silencieux). Ce paquet expose donc la cause par un canal latéral
/// ([ZGeoLocationFailureListener]) — le message affiché à l'utilisateur reste
/// à la charge de l'hôte (libellé et l10n hors de ce satellite).
library;

/// Cause d'échec d'une résolution de position. Une cause est notifiée **au
/// plus une fois par appel** du resolver, toujours avant que le `Future`
/// complète `null`.
enum ZGeoLocationFailureCause {
  /// Le **service** de localisation de l'appareil est désactivé
  /// (`isLocationServiceEnabled == false`). Un hôte informe généralement
  /// l'utilisateur dans ce cas.
  serviceDisabled,

  /// Permission refusée : `denied` au contrôle puis encore `denied` après
  /// l'unique redemande (une seule `requestPermission`).
  permissionDenied,

  /// Permission refusée **définitivement** (`deniedForever`, au contrôle ou
  /// en réponse à la redemande). Redemander est inutile : seul un passage
  /// par les réglages système peut la rouvrir.
  permissionDeniedForever,

  /// Toute autre défaillance : exception du plugin, timeout de lecture
  /// (borné à 10 s), position hors-bornes/non finie.
  error,
}

/// Écouteur d'échec optionnel : reçoit la [ZGeoLocationFailureCause] quand le
/// resolver va rendre `null`. Jamais invoqué sur un succès. Un throw dans ce
/// callback est avalé (invariant AD-10 : aucune exception ne s'échappe du
/// resolver).
typedef ZGeoLocationFailureListener = void Function(
  ZGeoLocationFailureCause cause,
);
