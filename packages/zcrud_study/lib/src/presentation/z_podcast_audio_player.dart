/// `ZPodcastAudioPlayer` — mini-lecteur de l'audio **déjà produit** d'un
/// podcast d'étude.
///
/// Ce widget **lit** un média ; il ne le **produit** jamais. Aucune synthèse,
/// aucun appel de génération : le podcast porte déjà sa référence de résultat
/// (`ZStudyPodcast.resultRef`), et le moteur de lecture est apporté par l'hôte
/// sous la forme d'un [ZAudioPlaybackPort]. Le paquet ne tire donc aucun
/// plugin natif.
///
/// ## Contrat de montage
///
/// Le lecteur n'a de sens que si **trois** conditions sont réunies : un port
/// est fourni, ce port se déclare disponible ([ZAudioPlaybackPort.isAvailable]),
/// et le podcast porte réellement une source ([sourceOf]). [canPlay] pose ces
/// trois conditions en une question, et c'est la forme que les assemblages du
/// paquet appliquent : sans port, leur arbre est **strictement celui d'avant**
/// — le lecteur est un ajout opt-in, jamais une modification du chemin par
/// défaut.
///
/// ## Provenance de la source — règle explicite et totale
///
/// `resultRef` est une référence **opaque** : ni le kernel ni ce paquet ne la
/// valident. [sourceOf] applique une règle unique, déterministe et documentée :
/// un `resultRef` dont l'URI porte le schéma `http` ou `https` est une
/// [ZAudioSource.url] ; toute autre valeur non vide est un chemin
/// ([ZAudioSource.file]) ; une valeur vide n'est pas une source (`null`).
/// Aucun cas ne lève.
///
/// ## Propriété du port
///
/// Le port **appartient à l'appelant**. Ce widget ne l'ouvre pas et ne le ferme
/// pas : il ne rappelle **jamais** [ZAudioPlaybackPort.dispose]. Ce qui est
/// libéré au démontage, ce sont les **abonnements** de ce widget aux flux du
/// port, et rien d'autre.
///
/// ## Chargement
///
/// [ZAudioPlaybackPort.load] est appelé **une fois** au montage — jamais depuis
/// `build` — puis à nouveau seulement si la source ou le port change
/// d'identité. Un `Left` au chargement n'est pas une exception : il bascule
/// l'affichage sur l'état d'échec (invariant AD-10).
///
/// ## Rebuild granulaire (AD-2)
///
/// Un événement de position ne reconstruit que l'horodatage et le curseur : le
/// bouton de lecture, le reste du lecteur et l'arbre autour du lecteur sont
/// hors du `builder` concerné.
///
/// ## Libellés
///
/// Tous les libellés sont **injectés** et nullables (invariant FR-26) : le
/// socle ne traduit rien. Un libellé absent ⇒ l'annonce correspondante est
/// absente, jamais un texte en dur. L'état d'échec reste visible sans aucun
/// libellé (glyphe au rôle `error`).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        ZAudioPlaybackPort,
        ZAudioPlaybackState,
        ZAudioSource,
        ZFailure,
        ZResult,
        Unit;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart' show ZStudyPodcast;

/// Séparateur entre position et durée de l'horodatage (`00:12 / 03:40`).
///
/// Ponctuation, pas un libellé : il ne se traduit pas.
const String kZPodcastAudioTimeSeparator = ' / ';

/// Formate une durée en `mm:ss` (ou `h:mm:ss` au-delà de l'heure).
///
/// Total : une durée négative est ramenée à zéro plutôt que rendue avec un
/// signe (invariant AD-10).
String zFormatPodcastAudioTime(Duration value) {
  final Duration d = value.isNegative ? Duration.zero : value;
  final String two = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final String seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (d.inHours > 0) return '${d.inHours}:$two:$seconds';
  return '$two:$seconds';
}

/// Mini-lecteur audio d'un podcast, branché sur un [ZAudioPlaybackPort].
///
/// Rend une ligne de contrôles : bascule lecture/pause, horodatage
/// `position / durée`, curseur de déplacement. En échec, il rend un indicateur
/// unique et aucun contrôle actionnable.
class ZPodcastAudioPlayer extends StatefulWidget {
  /// Construit le lecteur pour [source], piloté par [port].
  ///
  /// L'appelant reste propriétaire de [port] : il n'est jamais disposé ici.
  const ZPodcastAudioPlayer({
    required this.source,
    required this.port,
    this.playLabel,
    this.pauseLabel,
    this.loadingLabel,
    this.failedLabel,
    this.elapsedLabel,
    this.seekLabel,
    super.key,
  });

  /// Média à lire, déjà résolu (voir [sourceOf]).
  final ZAudioSource source;

  /// Moteur de lecture apporté par l'hôte. Propriété de l'appelant.
  final ZAudioPlaybackPort port;

  /// Annonce du bouton en position « lecture ». `null` ⇒ annonce absente.
  final String? playLabel;

  /// Annonce du bouton en position « pause ». `null` ⇒ annonce absente.
  final String? pauseLabel;

  /// Annonce du bouton pendant la préparation. `null` ⇒ annonce absente.
  final String? loadingLabel;

  /// Message d'échec de lecture. `null` ⇒ l'échec reste **visible** (glyphe au
  /// rôle `error`), sans texte.
  final String? failedLabel;

  /// Annonce de l'horodatage. `null` ⇒ annonce absente.
  final String? elapsedLabel;

  /// Annonce du curseur de déplacement. `null` ⇒ annonce absente.
  final String? seekLabel;

  /// Source de lecture d'un [ZStudyPodcast], ou `null` s'il n'en porte aucune.
  ///
  /// Règle unique et totale : `resultRef` vide ⇒ `null` ; schéma `http`/`https`
  /// ⇒ [ZAudioSource.url] ; sinon [ZAudioSource.file]. Un `resultRef`
  /// syntaxiquement illisible n'est pas une erreur : il est traité en chemin.
  static ZAudioSource? sourceOf(ZStudyPodcast podcast) {
    final String ref = podcast.resultRef;
    if (ref.isEmpty) return null;
    final Uri? uri = Uri.tryParse(ref);
    final String scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') return ZAudioSource.url(ref);
    return ZAudioSource.file(ref);
  }

  /// `true` si [port] permet réellement de proposer un lecteur pour [podcast].
  ///
  /// Les trois conditions du contrat de montage, en une seule question.
  static bool canPlay(ZStudyPodcast podcast, ZAudioPlaybackPort? port) =>
      port != null && port.isAvailable && sourceOf(podcast) != null;

  /// Clé du bouton lecture/pause (testabilité).
  static const ValueKey<String> toggleKey =
      ValueKey<String>('zPodcastAudioPlayer_toggle');

  /// Clé de l'indicateur d'échec (testabilité).
  static const ValueKey<String> failureKey =
      ValueKey<String>('zPodcastAudioPlayer_failure');

  /// Clé de l'horodatage (testabilité).
  static const ValueKey<String> stampKey =
      ValueKey<String>('zPodcastAudioPlayer_stamp');

  /// Clé du curseur de déplacement (testabilité).
  static const ValueKey<String> sliderKey =
      ValueKey<String>('zPodcastAudioPlayer_slider');

  @override
  State<ZPodcastAudioPlayer> createState() => _ZPodcastAudioPlayerState();
}

class _ZPodcastAudioPlayerState extends State<ZPodcastAudioPlayer> {
  /// Tranche « état de lecture » — seule source de rebuild des contrôles.
  final ValueNotifier<ZAudioPlaybackState> _state =
      ValueNotifier<ZAudioPlaybackState>(ZAudioPlaybackState.loading);

  /// Tranche « position » — isolée pour que son flux ne reconstruise que
  /// l'horodatage et le curseur (AD-2).
  final ValueNotifier<Duration> _position =
      ValueNotifier<Duration>(Duration.zero);

  StreamSubscription<ZAudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(ZPodcastAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Un simple rebuild ne recharge RIEN : seul un changement réel de média ou
    // de moteur justifie un nouveau `load`.
    if (oldWidget.source == widget.source &&
        identical(oldWidget.port, widget.port)) {
      return;
    }
    _detach();
    _state.value = ZAudioPlaybackState.loading;
    _position.value = Duration.zero;
    _attach();
  }

  void _attach() {
    // Les flux du port sont nus (AD-11) : une erreur y voyage comme erreur de
    // flux, jamais comme `Left`. On la traduit dans la même tranche d'état.
    _stateSub = widget.port.state.listen(
      (ZAudioPlaybackState s) => _state.value = s,
      onError: (Object _) => _state.value = ZAudioPlaybackState.failed,
    );
    _positionSub = widget.port.position.listen(
      (Duration p) => _position.value = p,
      onError: (Object _) {},
    );
    unawaited(_load());
  }

  void _detach() {
    _stateSub?.cancel();
    _positionSub?.cancel();
    _stateSub = null;
    _positionSub = null;
  }

  Future<void> _load() async {
    final ZResult<Unit> result = await widget.port.load(widget.source);
    if (_closed) return;
    result.fold(
      // AD-10 : un `Left` est un état affiché, jamais une levée.
      (ZFailure _) => _state.value = ZAudioPlaybackState.failed,
      (Unit _) {
        // Le port reste l'autorité sur l'état : on ne quitte `loading` que si
        // aucune transition observée ne l'a déjà remplacé.
        if (_state.value == ZAudioPlaybackState.loading) {
          _state.value = ZAudioPlaybackState.idle;
        }
      },
    );
  }

  Future<void> _toggle(bool playing) async {
    final ZResult<Unit> result =
        playing ? await widget.port.pause() : await widget.port.play();
    if (_closed) return;
    result.fold(
      (ZFailure _) => _state.value = ZAudioPlaybackState.failed,
      (Unit _) {},
    );
  }

  Future<void> _seek(double milliseconds) async {
    final ZResult<Unit> result = await widget.port.seek(
      Duration(milliseconds: milliseconds.round()),
    );
    if (_closed) return;
    result.fold(
      (ZFailure _) => _state.value = ZAudioPlaybackState.failed,
      (Unit _) {},
    );
  }

  @override
  void dispose() {
    _closed = true;
    _detach();
    _state.dispose();
    _position.dispose();
    // Le port appartient à l'hôte : jamais de `widget.port.dispose()` ici.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ZAudioPlaybackState>(
      valueListenable: _state,
      builder: (BuildContext context, ZAudioPlaybackState state, Widget? _) {
        if (state == ZAudioPlaybackState.failed) return _buildFailure(context);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _buildToggle(context, state),
            Flexible(
              child: ValueListenableBuilder<Duration>(
                valueListenable: _position,
                builder:
                    (BuildContext context, Duration position, Widget? _) =>
                        _buildProgress(context, position),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFailure(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? label = widget.failedLabel;
    // Rôle M3 `error` — jamais une couleur littérale (FR-26). L'échec reste
    // visible même sans libellé injecté : le glyphe seul le porte.
    return Semantics(
      liveRegion: true,
      label: label,
      child: Row(
        key: ZPodcastAudioPlayer.failureKey,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
          if (label != null)
            Flexible(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 8),
                child: Text(
                  label,
                  textAlign: TextAlign.start,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToggle(BuildContext context, ZAudioPlaybackState state) {
    final bool playing = state == ZAudioPlaybackState.playing;
    final bool loading = state == ZAudioPlaybackState.loading;
    final String? label = loading
        ? widget.loadingLabel
        : (playing ? widget.pauseLabel : widget.playLabel);
    return Semantics(
      button: true,
      enabled: !loading,
      label: label,
      excludeSemantics: label != null,
      child: IconButton(
        key: ZPodcastAudioPlayer.toggleKey,
        // Cible tactile ≥ 48 dp dans les deux axes (AD-13).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        onPressed: loading ? null : () => _toggle(playing),
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, Duration position) {
    final Duration? total = widget.port.duration;
    final String elapsed = zFormatPodcastAudioTime(position);
    final String text = total == null
        ? elapsed
        : '$elapsed$kZPodcastAudioTimeSeparator'
            '${zFormatPodcastAudioTime(total)}';
    final Widget stamp = Semantics(
      label: widget.elapsedLabel,
      child: Text(
        text,
        key: ZPodcastAudioPlayer.stampKey,
        textAlign: TextAlign.start,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
    if (total == null || total <= Duration.zero) {
      // Durée inconnue (flux, préparation en cours) : pas de curseur — un
      // curseur sans échelle serait un geste sans signification.
      return stamp;
    }
    final double max = total.inMilliseconds.toDouble();
    final double value = position.inMilliseconds.toDouble().clamp(0, max);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flexible(
          child: Semantics(
            container: true,
            label: widget.seekLabel,
            child: Slider(
              key: ZPodcastAudioPlayer.sliderKey,
              value: value,
              max: max,
              onChanged: (double v) =>
                  _position.value = Duration(milliseconds: v.round()),
              onChangeEnd: _seek,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 8),
          child: stamp,
        ),
      ],
    );
  }
}
