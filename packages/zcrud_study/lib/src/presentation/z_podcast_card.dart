/// `ZPodcastCard` — carte de podcast du socle, au rendu de référence.
///
/// Le kernel portait déjà l'entité `ZStudyPodcast` (statut, empreinte de
/// source, référence de résultat) et le paquet portait déjà le seam de
/// génération ; il ne manquait qu'une **présentation**. Cette carte la fournit,
/// au chrome commun de [ZStudyCardReference] (rayon, padding, marge, liseré,
/// styles de titre/sous-titre), sans une couleur ni un libellé en dur
/// (invariant FR-26).
///
/// ## Ce que la carte rend, et à quelle condition
///
/// | Élément | Monté si… | Sinon |
/// |---|---|---|
/// | Puce de statut | [statusLabel] fourni | puce absente |
/// | Puce de fraîcheur | [freshnessLabel] fourni | puce absente |
/// | Action « régénérer » | [onRegenerate] fourni | action absente |
/// | Mini-lecteur | [audioPort] fourni **et** disponible **et** le podcast porte un audio | lecteur absent |
///
/// Aucune de ces absences n'est un no-op silencieux : c'est une capacité
/// absente de l'arbre (invariant AD-4). Une carte construite sans aucun de ces
/// paramètres rend exactement le socle commun — titre, sous-titre, tuile.
///
/// ## Les clés de l'entité ne sont pas des libellés
///
/// `ZPodcastStatus` et [ZPodcastFreshness] sont des **clés opaques** : le socle
/// ne les traduit jamais. La carte reçoit deux fabriques de libellés
/// ([statusLabel], [freshnessLabel]) qui projettent la clé vers le texte
/// localisé de l'hôte. Sans fabrique, aucune clé nue n'est affichée.
///
/// ## Fraîcheur
///
/// La fraîcheur est **dérivée**, jamais stockée : `podcastFreshness` du kernel
/// compare l'empreinte du podcast à [currentSourceHash] — comparaison pure,
/// sans hachage ni horloge. Sans [currentSourceHash], la comparaison reste
/// définie (une empreinte présente face à une source inconnue vaut « obsolète »).
///
/// Priorité de chrome, partout : paramètre > jeton `studyCard*` >
/// défaut-référence (résolution centralisée dans [zStudyCardChromeOf]).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show ZAudioPlaybackPort, ZAudioSource, ZColorPair, ZcrudTheme,
        zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZColorPalette,
        ZPodcastFreshness,
        ZPodcastStatus,
        ZStudyPodcast,
        podcastFreshness,
        remapColorKey;

import 'z_content_hub_reference.dart';
import 'z_podcast_audio_player.dart';
import 'z_study_card_reference.dart';
import 'z_study_tools_item_card.dart';

/// Glyphe du rendu de référence — neutre, surchargeable par
/// [ZPodcastCard.icon].
const IconData zPodcastCardReferenceIcon = Icons.podcasts_outlined;

/// Glyphe de référence de l'action « régénérer » — surchargeable par
/// [ZPodcastCard.regenerateIcon].
const IconData zPodcastCardRegenerateIcon = Icons.refresh;

/// Carte de podcast du socle.
///
/// ```dart
/// ZPodcastCard(
///   podcast: podcast,
///   title: note.title,                              // libellé visible ⇒ injecté
///   statusLabel: (s) => l10n.podcastStatus(s.name), // clé ⇒ libellé
///   currentSourceHash: hashOfNote,
///   freshnessLabel: (f) => l10n.podcastFreshness(f.name),
///   onRegenerate: _regenerate,
///   regenerateLabel: l10n.regenerate,
///   audioPort: hostAudioPort,                        // opt-in
/// )
/// ```
class ZPodcastCard extends StatelessWidget {
  /// Construit la carte ; [podcast] et [title] sont requis.
  ///
  /// [title] est requis parce que l'entité n'en porte pas : un podcast est
  /// nommé par sa source, que seul l'hôte connaît. Le socle n'invente aucun
  /// texte de repli (invariant FR-26).
  const ZPodcastCard({
    required this.podcast,
    required this.title,
    this.subtitle,
    this.statusLabel,
    this.freshnessLabel,
    this.currentSourceHash,
    this.onRegenerate,
    this.regenerateLabel,
    this.regenerateIcon,
    this.regenerating = false,
    this.audioPort,
    this.playLabel,
    this.pauseLabel,
    this.loadingLabel,
    this.playbackFailedLabel,
    this.elapsedLabel,
    this.seekLabel,
    this.icon,
    this.palette = const ZColorPalette.defaultStudy(),
    this.colorKey,
    this.titleMaxLines,
    this.titleStyle,
    this.subtitleStyle,
    this.contentPadding,
    this.margin,
    this.borderSide,
    this.borderRadius,
    this.progress,
    this.progressMaxWidth = 120,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    super.key,
  }) : assert(
          titleMaxLines == null || titleMaxLines > 0,
          'titleMaxLines doit être ≥ 1 (le titre est le contenu principal).',
        );

  /// Podcast rendu. Le dessin lit `status`, `sourceHash`, `resultRef`, `id`.
  final ZStudyPodcast podcast;

  /// Libellé principal INJECTÉ (l'entité n'en porte aucun).
  final String title;

  /// Sous-titre injecté. `null` ⇒ absent.
  final String? subtitle;

  /// Fabrique le libellé localisé du statut. `null` ⇒ puce de statut absente
  /// (invariant AD-4) — jamais une clé d'enum affichée nue.
  final String Function(ZPodcastStatus status)? statusLabel;

  /// Fabrique le libellé localisé de la fraîcheur. `null` ⇒ puce de fraîcheur
  /// absente.
  final String Function(ZPodcastFreshness freshness)? freshnessLabel;

  /// Empreinte opaque de la source **courante**, pour dériver la fraîcheur.
  ///
  /// Jamais calculée ici : le hachage est un seam de l'hôte. `null` ⇒ la
  /// comparaison reste définie (voir `podcastFreshness`).
  final String? currentSourceHash;

  /// Demande de régénération. `null` ⇒ action absente de l'arbre.
  final VoidCallback? onRegenerate;

  /// Annonce de l'action « régénérer ». `null` ⇒ annonce absente.
  final String? regenerateLabel;

  /// Glyphe de l'action. `null` ⇒ [zPodcastCardRegenerateIcon].
  final IconData? regenerateIcon;

  /// Régénération en cours : l'action reste **présente** mais inerte
  /// (anti-double-soumission visible, jamais un bouton qui disparaît sous le
  /// doigt).
  final bool regenerating;

  /// Moteur de lecture apporté par l'hôte. `null` ⇒ lecteur absent.
  ///
  /// Propriété de l'appelant : ni ouvert ni disposé par cette carte.
  final ZAudioPlaybackPort? audioPort;

  /// Annonce du bouton « lecture » du mini-lecteur.
  final String? playLabel;

  /// Annonce du bouton « pause » du mini-lecteur.
  final String? pauseLabel;

  /// Annonce du bouton pendant la préparation du média.
  final String? loadingLabel;

  /// Message d'échec de **lecture** (distinct du statut du podcast).
  final String? playbackFailedLabel;

  /// Annonce de l'horodatage du mini-lecteur.
  final String? elapsedLabel;

  /// Annonce du curseur de déplacement du mini-lecteur.
  final String? seekLabel;

  /// Glyphe de la tuile. `null` ⇒ [zPodcastCardReferenceIcon].
  final IconData? icon;

  /// Palette injectée bornant la clé d'accent.
  final ZColorPalette palette;

  /// Clé d'identité de l'accent (`String` opaque). `null` ⇒ la clé stable de
  /// la famille « podcast » ([ZContentHubReference.colorKeyPodcast]), pour que
  /// la carte et l'entrée de hub portent la **même** teinte.
  final String? colorKey;

  /// Nombre maximal de lignes du titre. `null` ⇒ référence.
  final int? titleMaxLines;

  /// Style du titre. `null` ⇒ jeton, puis référence.
  final TextStyle? titleStyle;

  /// Style du sous-titre. `null` ⇒ jeton, puis référence.
  final TextStyle? subtitleStyle;

  /// Padding interne. `null` ⇒ jeton, puis référence.
  final EdgeInsetsGeometry? contentPadding;

  /// Marge externe. `null` ⇒ jeton, puis `CardTheme.margin`, puis référence.
  final EdgeInsetsGeometry? margin;

  /// Liseré. `null` ⇒ jeton, puis référence.
  final BorderSide? borderSide;

  /// Rayon de carte. `null` ⇒ jeton, puis référence.
  final Radius? borderRadius;

  /// Indicateur de traitement — relayé à la carte de base.
  final Widget? progress;

  /// Largeur maximale du slot [progress].
  final double progressMaxWidth;

  /// Activation de la carte. `null` et [onLongPress] `null` ⇒ non interactive.
  final VoidCallback? onTap;

  /// Appui long. `null` ⇒ capacité absente (invariant AD-4).
  final VoidCallback? onLongPress;

  /// Libellé sémantique de la carte entière. Repli : titre, complété du
  /// sous-titre puis des libellés de statut et de fraîcheur effectivement
  /// rendus (invariant AD-13).
  final String? semanticLabel;

  /// Clé de la tuile de glyphe (testabilité).
  static const ValueKey<String> iconTileKey =
      ValueKey<String>('zPodcastCard_iconTile');

  /// Clé de la puce de statut (testabilité).
  static const ValueKey<String> statusChipKey =
      ValueKey<String>('zPodcastCard_statusChip');

  /// Clé du texte de statut (testabilité — invariant AD-13).
  static const ValueKey<String> statusLabelKey =
      ValueKey<String>('zPodcastCard_statusLabel');

  /// Clé de la puce de fraîcheur (testabilité).
  static const ValueKey<String> freshnessChipKey =
      ValueKey<String>('zPodcastCard_freshnessChip');

  /// Clé du texte de fraîcheur (testabilité).
  static const ValueKey<String> freshnessLabelKey =
      ValueKey<String>('zPodcastCard_freshnessLabel');

  /// Clé de l'action « régénérer » (testabilité).
  static const ValueKey<String> regenerateKey =
      ValueKey<String>('zPodcastCard_regenerate');

  /// Clé du mini-lecteur (testabilité).
  static const ValueKey<String> playerKey =
      ValueKey<String>('zPodcastCard_player');

  /// Fraîcheur RENDUE par cette carte — dérivée, jamais stockée.
  ZPodcastFreshness get freshness => podcastFreshness(
        storedHash: podcast.sourceHash,
        currentSourceHash: currentSourceHash,
      );

  ZColorPair _accent(BuildContext context) {
    final String key = remapColorKey(
      palette: palette,
      rawColorKey: colorKey ?? ZContentHubReference.colorKeyPodcast,
      seedTitle: podcast.id ?? title,
    );
    return zResolveColorKeyOrSlot(
      context,
      key,
      slotIndex: palette.indexOf(key),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ZcrudTheme theme = ZcrudTheme.of(context);
    final ZStudyCardChrome chrome = zStudyCardChromeOf(
      context,
      borderSide: borderSide,
      borderRadius: borderRadius,
      contentPadding: contentPadding,
      margin: margin,
      titleStyle: titleStyle,
      subtitleStyle: subtitleStyle,
    );
    final ZColorPair pair = _accent(context);
    final String? statusText = statusLabel?.call(podcast.status);
    final String? freshnessText = freshnessLabel?.call(freshness);
    final ZAudioSource? audioSource =
        ZPodcastAudioPlayer.canPlay(podcast, audioPort)
            ? ZPodcastAudioPlayer.sourceOf(podcast)
            : null;

    return ZStudyToolsItemCard(
      leading: ExcludeSemantics(
        child: SizedBox(
          key: iconTileKey,
          width: chrome.iconTileSize,
          height: chrome.iconTileSize,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: chrome.tileColor,
              borderRadius: BorderRadius.all(chrome.iconTileRadius),
            ),
            child: Center(
              child: Icon(
                icon ?? zPodcastCardReferenceIcon,
                color: chrome.neutralGlyphColor,
              ),
            ),
          ),
        ),
      ),
      title: title,
      titleMaxLines: titleMaxLines ?? ZStudyCardReference.titleMaxLines,
      titleStyle: chrome.titleStyle,
      subtitle: subtitle,
      subtitleStyle: chrome.subtitleStyle,
      contentPadding: chrome.contentPadding,
      margin: chrome.margin,
      borderSide: chrome.borderSide,
      borderRadius: chrome.borderRadius,
      leadingGap: chrome.leadingGap,
      elevation: chrome.elevation,
      belowSubtitle: _buildBelowSubtitle(
        context,
        theme,
        pair,
        statusText,
        freshnessText,
        audioSource,
      ),
      trailing: _buildRegenerate(context),
      progress: progress,
      progressMaxWidth: progressMaxWidth,
      onTap: onTap,
      onLongPress: onLongPress,
      semanticLabel:
          semanticLabel ?? _defaultSemanticLabel(statusText, freshnessText),
    );
  }

  String _defaultSemanticLabel(String? statusText, String? freshnessText) {
    final StringBuffer buffer = StringBuffer(title);
    if (subtitle != null) buffer.write(', $subtitle');
    if (statusText != null) buffer.write(', $statusText');
    if (freshnessText != null) buffer.write(', $freshnessText');
    return buffer.toString();
  }

  /// Bloc sous le sous-titre : puces (statut, fraîcheur) puis mini-lecteur.
  ///
  /// `null` quand aucun des trois n'est monté — la carte retrouve alors
  /// exactement la géométrie d'une carte sans slot bas.
  Widget? _buildBelowSubtitle(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    String? statusText,
    String? freshnessText,
    ZAudioSource? audioSource,
  ) {
    final List<Widget> chips = <Widget>[
      if (statusText != null)
        _buildChip(context, theme, pair, statusText, statusChipKey,
            statusLabelKey),
      if (freshnessText != null)
        _buildChip(context, theme, pair, freshnessText, freshnessChipKey,
            freshnessLabelKey),
    ];
    final Widget? player = audioSource == null
        ? null
        : ZPodcastAudioPlayer(
            key: playerKey,
            source: audioSource,
            port: audioPort!,
            playLabel: playLabel,
            pauseLabel: pauseLabel,
            loadingLabel: loadingLabel,
            failedLabel: playbackFailedLabel,
            elapsedLabel: elapsedLabel,
            seekLabel: seekLabel,
          );
    if (chips.isEmpty && player == null) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (chips.isNotEmpty)
          Wrap(spacing: theme.gapS, runSpacing: theme.gapS, children: chips),
        ?player,
      ],
    );
  }

  Widget _buildChip(
    BuildContext context,
    ZcrudTheme theme,
    ZColorPair pair,
    String label,
    ValueKey<String> chipKey,
    ValueKey<String> labelKey,
  ) =>
      DecoratedBox(
        key: chipKey,
        decoration: BoxDecoration(
          color: pair.color,
          borderRadius: BorderRadius.all(theme.radiusM),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: theme.gapM,
            vertical: theme.gapS,
          ),
          child: Text(
            label,
            key: labelKey,
            textAlign: TextAlign.start,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: (Theme.of(context).textTheme.labelSmall ?? const TextStyle())
                .copyWith(color: pair.onColor),
          ),
        ),
      );

  /// Action « régénérer », ou `null` quand [onRegenerate] est absent.
  Widget? _buildRegenerate(BuildContext context) {
    final VoidCallback? action = onRegenerate;
    if (action == null) return null;
    return Semantics(
      button: true,
      enabled: !regenerating,
      label: regenerateLabel,
      excludeSemantics: regenerateLabel != null,
      child: IconButton(
        key: regenerateKey,
        // Cible tactile ≥ 48 dp dans les deux axes (AD-13).
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: EdgeInsets.zero,
        tooltip: regenerateLabel,
        onPressed: regenerating ? null : action,
        icon: Icon(regenerateIcon ?? zPodcastCardRegenerateIcon),
      ),
    );
  }
}
