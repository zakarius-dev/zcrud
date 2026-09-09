/// Format d'affichage partagé par les surfaces d'examen blanc.
///
/// Aucune valeur de règle ici — ni seuil, ni barème : le taux de réussite
/// exigé est une **donnée de l'application**, et ce paquet n'en écrit aucun,
/// pas même en repli.
library;

/// Durée en chiffres seuls (`mm:ss`, ou `h:mm:ss` au-delà de l'heure).
///
/// Aucun mot : la durée visible est lisible dans toutes les langues, et
/// l'annonce en toutes lettres reste au `Semantics` de l'appelant. Une durée
/// négative vaut zéro — jamais un affichage absurde.
String zWhiteExamDigits(Duration value) {
  final totalSeconds = value.inSeconds < 0 ? 0 : value.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds.remainder(Duration.secondsPerMinute);
  final body =
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return hours > 0 ? '$hours:$body' : body;
}
