/// Port de **lecture audio** — abstraction pure, sans moteur ni plugin.
///
/// Le cœur ne sait pas jouer un son et ne cherche pas à l'apprendre : lire un
/// fichier audio demande un plugin natif, donc une chaîne de build que ce
/// paquet n'inflige à personne. Il déclare ici le **contrat** qu'un hôte (ou un
/// satellite) satisfait avec le moteur de son choix, et fournit un repli inerte
/// pour que le câblage reste possible quand aucun moteur n'est branché.
library;

import 'package:dartz/dartz.dart' show Unit, left;

import '../failures/z_failure.dart';

/// États de lecture observables d'un [ZAudioPlaybackPort].
///
/// Un implémenteur ne doit émettre que des transitions qu'il constate
/// réellement : l'état est une **observation**, pas une intention. Les valeurs
/// sont sérialisées en camelCase si elles doivent l'être.
enum ZAudioPlaybackState {
  /// Aucune source chargée, ou source relâchée.
  idle,

  /// Source acceptée, préparation en cours (téléchargement, décodage).
  loading,

  /// Lecture en cours.
  playing,

  /// Lecture suspendue, position conservée.
  paused,

  /// Lecture arrivée en fin de source.
  completed,

  /// Lecture interrompue par une erreur ; le détail voyage par le `Left` de
  /// l'opération fautive, pas par cet état.
  failed,
}

/// Provenance d'un média audio, indépendante de tout moteur.
///
/// Trois provenances couvrent les usages du socle : une **URL** distante, un
/// **asset** empaqueté dans l'application, un **fichier** du système. Le port
/// ne les interprète pas — il les transporte jusqu'à l'implémentation, qui sait
/// seule ce que son moteur attend.
enum ZAudioSourceKind {
  /// [ZAudioSource.location] est une URL absolue.
  url,

  /// [ZAudioSource.location] est une clé d'asset de l'application.
  asset,

  /// [ZAudioSource.location] est un chemin du système de fichiers.
  file,
}

/// Média audio à charger : une provenance et une localisation.
///
/// Type de valeur : deux sources de même [kind] et même [location] sont égales,
/// ce qui permet à une implémentation d'éviter un rechargement inutile.
class ZAudioSource {
  /// Construit une source explicite.
  const ZAudioSource({required this.kind, required this.location});

  /// Source distante, désignée par une URL absolue.
  const ZAudioSource.url(String url)
    : kind = ZAudioSourceKind.url,
      location = url;

  /// Source empaquetée dans l'application, désignée par sa clé d'asset.
  const ZAudioSource.asset(String assetKey)
    : kind = ZAudioSourceKind.asset,
      location = assetKey;

  /// Source du système de fichiers, désignée par son chemin.
  const ZAudioSource.file(String path)
    : kind = ZAudioSourceKind.file,
      location = path;

  /// Provenance du média.
  final ZAudioSourceKind kind;

  /// Localisation, interprétée selon [kind].
  final String location;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZAudioSource &&
          other.kind == kind &&
          other.location == location;

  @override
  int get hashCode => Object.hash(kind, location);

  @override
  String toString() => 'ZAudioSource(${kind.name}: $location)';
}

/// Contrat de lecture audio d'une source unique.
///
/// ## Contrat de résultat (AD-11)
///
/// Les **opérations** rendent `ZResult<Unit>` : jamais d'exception à travers la
/// frontière du port, y compris pour une source introuvable ou un moteur
/// absent. Les **flux** ([position], [state]) sont nus, conformément à la même
/// règle — un flux n'est jamais enveloppé dans un `Either`.
///
/// ## Ce qu'un implémenteur doit garantir
///
/// * **Une instance, une source** : [load] remplace la source courante ; la
///   position repart de zéro et [duration] est réévaluée.
/// * **Ordre libre, échec typé** : [play], [pause] et [seek] appelés avant tout
///   [load] réussi rendent un `Left`, jamais une exception ni un silence.
/// * **Flux à vie liée** : [position] et [state] se ferment à [dispose]. Un
///   abonné tardif ne doit pas rester suspendu indéfiniment.
/// * **Idempotence** : [pause] sur une lecture déjà suspendue et [dispose] déjà
///   appelé sont des succès, pas des erreurs.
/// * **Indisponibilité honnête** : [isAvailable] vaut `false` dès que le moteur
///   n'est pas exploitable sur la plateforme courante, et toutes les opérations
///   rendent alors un `Left` — jamais un succès silencieux sans son.
///
/// ## Ce qu'un appelant doit prévoir
///
/// Sonder [isAvailable] au **câblage** (pour ne pas proposer un geste
/// impossible), et traiter le `Left` au geste : les deux ne sont pas
/// redondants, une source peut échouer sur un moteur pourtant disponible.
abstract class ZAudioPlaybackPort {
  /// Constructeur `const` pour les implémentations sans état.
  const ZAudioPlaybackPort();

  /// `true` si un moteur exploitable est branché sur la plateforme courante.
  ///
  /// Se lit au câblage. Une valeur `false` n'est pas une erreur : c'est une
  /// capacité absente, que l'appelant traduit en geste non proposé.
  bool get isAvailable;

  /// Durée totale de la source courante, ou `null` tant qu'elle est inconnue
  /// (aucune source, préparation en cours, flux de durée indéterminée).
  Duration? get duration;

  /// Position de lecture, émise au rythme choisi par l'implémentation.
  ///
  /// Flux nu (AD-11), fermé à [dispose]. Aucune émission n'est garantie : une
  /// source jamais chargée, ou un moteur absent, produit un flux vide.
  Stream<Duration> get position;

  /// États de lecture successifs.
  ///
  /// Flux nu (AD-11), fermé à [dispose]. L'implémentation n'émet que les
  /// transitions qu'elle constate.
  Stream<ZAudioPlaybackState> get state;

  /// Charge [source] et remplace la source courante.
  ///
  /// Succès signifie « source acceptée et préparée », pas « lecture démarrée » :
  /// [play] reste nécessaire.
  Future<ZResult<Unit>> load(ZAudioSource source);

  /// Démarre ou reprend la lecture de la source courante.
  Future<ZResult<Unit>> play();

  /// Suspend la lecture en conservant la position.
  Future<ZResult<Unit>> pause();

  /// Déplace la tête de lecture à [position].
  ///
  /// Une position hors bornes est **bornée** par l'implémentation, jamais
  /// rejetée : le geste a un sens même approximatif.
  Future<ZResult<Unit>> seek(Duration position);

  /// Relâche le moteur et ferme [position] et [state].
  ///
  /// Idempotent. Après [dispose], toute opération rend un `Left`.
  Future<void> dispose();
}

/// Repli **inerte** : aucun moteur, aucun son, aucune émission.
///
/// C'est le défaut zéro-dépendance du socle. Il rend le câblage possible sans
/// plugin : un assemblage peut demander un [ZAudioPlaybackPort] sans forcer
/// chaque hôte à en fournir un, et sans jamais faire croire qu'un son est joué.
///
/// [isAvailable] vaut `false`, [duration] vaut `null`, [position] et [state]
/// sont des flux **déjà clos** (ils se terminent sans aucune émission), et
/// chaque opération rend un `Left(ZUnsupportedOperationFailure)` nommant le
/// membre appelé — un appelant peut donc distinguer « capacité absente » d'une
/// panne réelle.
class ZInertAudioPlaybackPort extends ZAudioPlaybackPort {
  /// Construit le repli inerte. `const` : il n'a aucun état.
  const ZInertAudioPlaybackPort();

  @override
  bool get isAvailable => false;

  @override
  Duration? get duration => null;

  @override
  Stream<Duration> get position => const Stream<Duration>.empty();

  @override
  Stream<ZAudioPlaybackState> get state =>
      const Stream<ZAudioPlaybackState>.empty();

  @override
  Future<ZResult<Unit>> load(ZAudioSource source) async => _absent('load');

  @override
  Future<ZResult<Unit>> play() async => _absent('play');

  @override
  Future<ZResult<Unit>> pause() async => _absent('pause');

  @override
  Future<ZResult<Unit>> seek(Duration position) async => _absent('seek');

  @override
  Future<void> dispose() async {}

  // Un seul message, un `operation` distinct par membre : c'est `operation` qui
  // porte le diagnostic exploitable, pas le parsing du message.
  ZResult<Unit> _absent(String operation) => left<ZFailure, Unit>(
    ZUnsupportedOperationFailure(
      'Aucun moteur audio branché : ZInertAudioPlaybackPort ne lit rien.',
      operation: operation,
    ),
  );
}
