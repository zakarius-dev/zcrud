/// `ZNoteAudioPlayer` — mini-lecteur de l'audio **déjà existant** d'une note.
///
/// Ce widget **lit** un média audio ; il ne le **produit** jamais. Aucune
/// synthèse, aucun appel de génération : la note porte déjà son URL ou son
/// chemin ([ZNoteAudio]), et le moteur de lecture est apporté par l'hôte sous la
/// forme d'un [ZAudioPlaybackPort]. Le paquet ne tire donc aucun plugin natif.
///
/// ## Contrat de montage
///
/// Le lecteur n'a de sens que si **trois** conditions sont réunies : un port est
/// fourni, ce port se déclare disponible ([ZAudioPlaybackPort.isAvailable]), et
/// la note porte réellement une source ([sourceOf]). Les assemblages du paquet
/// ([ZSmartNoteReader], [ZSmartNoteEditor]) appliquent cette règle : sans port,
/// leur arbre de rendu est **strictement celui d'avant** — le lecteur est un
/// ajout opt-in, jamais une modification du chemin par défaut.
///
/// ## Propriété du port
///
/// Le port **appartient à l'appelant**. Ce widget ne l'ouvre pas et ne le ferme
/// pas : il ne rappelle **jamais** [ZAudioPlaybackPort.dispose]. Un même port
/// peut donc survivre au démontage du lecteur, être partagé, ou être réutilisé
/// pour une autre note. Ce qui est libéré au démontage, ce sont les
/// **abonnements** de ce widget aux flux du port, et rien d'autre.
///
/// ## Chargement
///
/// [ZAudioPlaybackPort.load] est appelé **une fois** au montage — jamais depuis
/// `build` — puis à nouveau seulement si la source ou le port change
/// d'identité. Un `Left` au chargement n'est pas une exception : il bascule
/// l'affichage sur l'état d'échec, conformément au repli défensif du socle.
///
/// ## Rebuild granulaire
///
/// Un événement de position ne reconstruit que l'horodatage et le curseur : le
/// bouton de lecture, le reste du lecteur et l'arbre autour du lecteur sont
/// hors du `builder` concerné.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../domain/z_note_audio.dart';
import '../domain/z_smart_note.dart';
import 'z_note_audio_labels.dart';

/// Mini-lecteur audio d'une note, branché sur un [ZAudioPlaybackPort].
///
/// Rend une ligne de contrôles : bascule lecture/pause, horodatage
/// `position / durée`, curseur de déplacement. En échec, il rend un message
/// unique et aucun contrôle actionnable.
class ZNoteAudioPlayer extends StatefulWidget {
  /// Construit le lecteur pour [source], piloté par [port].
  ///
  /// L'appelant reste propriétaire de [port] : il n'est jamais disposé ici.
  const ZNoteAudioPlayer({
    required this.source,
    required this.port,
    super.key,
  });

  /// Média à lire, déjà résolu (voir [sourceOf] / [sourceOfAudio]).
  final ZAudioSource source;

  /// Moteur de lecture apporté par l'hôte. Propriété de l'appelant.
  final ZAudioPlaybackPort port;

  /// Source de lecture d'une [ZNoteAudio], ou `null` si elle n'en porte aucune.
  ///
  /// Le **chemin local** l'emporte sur l'**URL** : un média déjà téléchargé se
  /// lit hors-ligne et sans coût réseau. Une chaîne vide compte pour absente.
  static ZAudioSource? sourceOfAudio(ZNoteAudio? audio) {
    if (audio == null) return null;
    final String? path = audio.path;
    if (path != null && path.isNotEmpty) return ZAudioSource.file(path);
    final String? url = audio.url;
    if (url != null && url.isNotEmpty) return ZAudioSource.url(url);
    return null;
  }

  /// Source de lecture d'une [ZSmartNote], ou `null`.
  ///
  /// Rend `null` tant que le slot `extension` n'est pas **typé** en
  /// [ZNoteAudio] : un payload resté opaque n'est pas une source de lecture.
  static ZAudioSource? sourceOf(ZSmartNote note) {
    final ZExtension? extension = note.extension;
    return sourceOfAudio(extension is ZNoteAudio ? extension : null);
  }

  /// `true` si [port] permet réellement de proposer un lecteur pour [note].
  ///
  /// Les trois conditions du contrat de montage, en une seule question — c'est
  /// la forme utilisée par les assemblages du paquet.
  static bool canPlay(ZSmartNote note, ZAudioPlaybackPort? port) =>
      port != null && port.isAvailable && sourceOf(note) != null;

  @override
  State<ZNoteAudioPlayer> createState() => _ZNoteAudioPlayerState();
}

class _ZNoteAudioPlayerState extends State<ZNoteAudioPlayer> {
  /// Tranche « état de lecture » — seule source de rebuild des contrôles.
  final ValueNotifier<ZAudioPlaybackState> _state =
      ValueNotifier<ZAudioPlaybackState>(ZAudioPlaybackState.loading);

  /// Tranche « position » — isolée pour que son flux ne reconstruise que
  /// l'horodatage et le curseur (AD-2).
  final ValueNotifier<Duration> _position = ValueNotifier<Duration>(
    Duration.zero,
  );

  StreamSubscription<ZAudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  @override
  void didUpdateWidget(ZNoteAudioPlayer oldWidget) {
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
    final ZResult<Unit> result = playing
        ? await widget.port.pause()
        : await widget.port.play();
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
                        _buildProgress(context, position, state),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFailure(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = zResolveNoteAudioLabel(
      context,
      kZNoteAudioFailedLabelKey,
    );
    // Rôle M3 `error` — jamais une couleur littérale (FR-26).
    return Semantics(
      liveRegion: true,
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.error,
        ),
      ),
    );
  }

  Widget _buildToggle(BuildContext context, ZAudioPlaybackState state) {
    final bool playing = state == ZAudioPlaybackState.playing;
    final bool loading = state == ZAudioPlaybackState.loading;
    final String label = zResolveNoteAudioLabel(
      context,
      loading
          ? kZNoteAudioLoadingLabelKey
          : (playing ? kZNoteAudioPauseLabelKey : kZNoteAudioPlayLabelKey),
    );
    return Semantics(
      button: true,
      enabled: !loading,
      label: label,
      excludeSemantics: true,
      child: IconButton(
        // Cible tactile ≥ 48 dp dans les deux axes (AD-13).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        onPressed: loading ? null : () => _toggle(playing),
        icon: Icon(playing ? Icons.pause : Icons.play_arrow),
      ),
    );
  }

  Widget _buildProgress(
    BuildContext context,
    Duration position,
    ZAudioPlaybackState state,
  ) {
    final Duration? total = widget.port.duration;
    final String elapsed = zFormatNoteAudioTime(position);
    final String text = total == null
        ? elapsed
        : '$elapsed$kZNoteAudioTimeSeparator${zFormatNoteAudioTime(total)}';
    final Widget stamp = Semantics(
      label: zResolveNoteAudioLabel(context, kZNoteAudioElapsedLabelKey),
      child: Text(text, style: Theme.of(context).textTheme.bodySmall),
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
            label: zResolveNoteAudioLabel(context, kZNoteAudioSeekLabelKey),
            child: Slider(
              value: value,
              max: max,
              onChanged: (double v) => _position.value = Duration(
                milliseconds: v.round(),
              ),
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
