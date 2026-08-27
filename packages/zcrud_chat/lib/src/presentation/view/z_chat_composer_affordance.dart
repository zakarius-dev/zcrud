/// **Les déclencheurs de contexte** — reconnaître `@` et `/`, demander à
/// l'hôte, rendre ce qu'il donne.
///
/// ## Ce que ce contrôleur fait
///
/// 1. il lit la saisie et interroge les déclencheurs **déclarés par l'hôte**
///    (`ZChatMentionTrigger.matchIn`, analyse pure du kernel) ;
/// 2. quand une amorce est reconnue, il demande ses candidats à la **source**
///    de l'hôte (`ZChatMentionSource`) ;
/// 3. il expose l'état de la superposition dans une tranche à part, pour que
///    l'ouverture d'un panneau ne reconstruise pas le champ ;
/// 4. il **transmet** la sélection.
///
/// ## Ce qu'il ne fait pas — et ne fera pas
///
/// * il ne **filtre** pas, ne **trie** pas et ne **tronque** pas la liste
///   rendue par la source. En particulier `ZChatMentionTrigger.maxCandidates`
///   est **transporté** dans l'état ([ZChatComposerAffordanceState.maxCandidates])
///   et jamais appliqué : le plafond est une intention déclarée par l'hôte, et
///   c'est l'hôte — ou sa source — qui décide de la respecter. Un socle qui
///   couperait la liste ferait disparaître des candidats sans que personne ne
///   sache lesquels ;
/// * il n'a **aucun annuaire** : ni index de fichiers, ni liste d'agents, ni
///   catalogue de connecteurs ;
/// * il n'**exécute** aucune commande. Une invocation reconnue est remise
///   telle quelle ; le socle n'est pas un interpréteur.
///
/// ## Le vocabulaire n'est pas redéfini ici
///
/// Candidat, déclencheur, correspondance, source, commande et catalogue vivent
/// dans `zcrud_chat_kernel` et sont consommés tels quels.
/// [ZChatComposerAffordanceEntry] n'est pas un second modèle : c'est la
/// **projection de rendu** qui permet à un seul panneau de montrer les deux
/// familles, et elle conserve l'objet d'origine pour le rendre à l'hôte.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

import 'z_chat_composer_edit.dart';

/// Intention « candidat précédent ».
class ZChatComposerAffordancePreviousIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerAffordancePreviousIntent();
}

/// Intention « candidat suivant ».
class ZChatComposerAffordanceNextIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerAffordanceNextIntent();
}

/// Intention « retenir le candidat mis en avant ».
class ZChatComposerAffordanceCommitIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerAffordanceCommitIntent();
}

/// Intention « fermer sans rien choisir ».
class ZChatComposerAffordanceDismissIntent extends Intent {
  /// Construit l'intention.
  const ZChatComposerAffordanceDismissIntent();
}

/// Une ligne de la superposition — projection de rendu d'un candidat de
/// mention **ou** d'une commande.
@immutable
class ZChatComposerAffordanceEntry {
  /// Projette un candidat de mention.
  ZChatComposerAffordanceEntry.mention(ZChatMentionCandidate this.candidate)
    : command = null,
      key = candidate.key,
      label = candidate.label,
      sublabel = candidate.sublabel,
      isEnabled = candidate.isEnabled;

  /// Projette une commande du catalogue.
  ZChatComposerAffordanceEntry.command(ZChatSlashCommand this.command)
    : candidate = null,
      key = command.key,
      label = command.label,
      sublabel = command.description,
      isEnabled = command.isEnabled;

  /// Le candidat d'origine, ou `null` s'il s'agit d'une commande.
  final ZChatMentionCandidate? candidate;

  /// La commande d'origine, ou `null` s'il s'agit d'un candidat.
  final ZChatSlashCommand? command;

  /// Clé opaque, telle que l'hôte l'a donnée.
  final String key;

  /// Libellé d'hôte, ou `null` — le socle n'en invente aucun (invariant
  /// FR-26) ; un rendu qui n'a rien à dire retombe sur [key].
  final String? label;

  /// Ligne secondaire d'hôte, ou `null`.
  final String? sublabel;

  /// `false` si l'hôte a déclaré un motif d'indisponibilité.
  final bool isEnabled;
}

/// L'état de la superposition.
@immutable
class ZChatComposerAffordanceState {
  /// Construit un état.
  const ZChatComposerAffordanceState({
    this.match,
    this.entries = const <ZChatComposerAffordanceEntry>[],
    this.selectedIndex = -1,
    this.maxCandidates,
    this.failure,
  });

  /// L'état fermé — aucune amorce reconnue.
  static const ZChatComposerAffordanceState closed =
      ZChatComposerAffordanceState();

  /// La correspondance reconnue, ou `null` quand rien n'est ouvert.
  final ZChatMentionMatch? match;

  /// Les candidats, **dans l'ordre où la source les a rendus**.
  final List<ZChatComposerAffordanceEntry> entries;

  /// L'indice mis en avant, ou `-1`.
  final int selectedIndex;

  /// Le plafond **déclaré** par le déclencheur — transporté, jamais appliqué.
  final int? maxCandidates;

  /// La panne de la source, quand elle en a signalé une. Une liste vide n'est
  /// pas une panne : c'est « rien à proposer ».
  final ZFailure? failure;

  /// `true` si une amorce est reconnue.
  bool get isOpen => match != null;

  /// L'entrée mise en avant, ou `null`.
  ZChatComposerAffordanceEntry? get selected =>
      selectedIndex >= 0 && selectedIndex < entries.length
          ? entries[selectedIndex]
          : null;
}

/// Reconnaît les déclencheurs dans la saisie et porte l'état du panneau.
///
/// Le contrôleur n'est ni créé ni disposé par le composer : son cycle de vie
/// appartient à l'hôte (invariant AD-2).
class ZChatComposerAffordanceController {
  /// Construit le contrôleur et s'abonne à [composer].
  ZChatComposerAffordanceController({
    required this.composer,
    List<ZChatMentionTrigger> triggers = const <ZChatMentionTrigger>[],
    ZChatMentionSources? sources,
    this.catalog,
    this.onCandidate,
    this.onCommand,
  }) : triggers = List<ZChatMentionTrigger>.unmodifiable(triggers),
       sources = sources ?? ZChatMentionSources() {
    composer.addListener(_onChanged);
  }

  /// La tranche de saisie observée.
  final TextEditingController composer;

  /// Les déclencheurs déclarés, dans l'ordre de déclaration. Le **premier**
  /// qui reconnaît l'amorce l'emporte — c'est l'ordre de l'hôte, pas une
  /// priorité inventée ici.
  final List<ZChatMentionTrigger> triggers;

  /// Les sources d'hôte, indexées par clé de déclencheur.
  final ZChatMentionSources sources;

  /// Le catalogue de commandes, ou `null`.
  ///
  /// Son propre déclencheur est consulté **après** [triggers]. Quand aucune
  /// source n'est branchée sur ce déclencheur, le panneau montre les commandes
  /// dans l'ordre **déclaré** par l'hôte (`ZChatSlashCatalog.ordered`), sans
  /// les réduire à ce qui est déjà tapé : réduire serait filtrer.
  final ZChatSlashCatalog? catalog;

  /// Appelé quand un candidat de mention est retenu.
  final void Function(
    ZChatMentionCandidate candidate,
    ZChatMentionMatch match,
  )?
  onCandidate;

  /// Appelé quand une commande est retenue. Le socle ne l'exécute pas.
  final void Function(ZChatSlashCommand command, ZChatMentionMatch match)?
  onCommand;

  final ValueNotifier<ZChatComposerAffordanceState> _state =
      ValueNotifier<ZChatComposerAffordanceState>(
        ZChatComposerAffordanceState.closed,
      );

  /// L'état de la superposition — une tranche À PART de la saisie : ouvrir ou
  /// fermer le panneau ne reconstruit pas le champ (invariant AD-2).
  ValueListenable<ZChatComposerAffordanceState> get state => _state;

  /// Numéro de la demande en cours — une réponse en retard est ignorée plutôt
  /// que de faire clignoter une liste périmée.
  int _epoch = 0;
  bool _disposed = false;

  /// L'amorce fermée à la main : tant que la correspondance ne change pas, le
  /// panneau reste fermé (sinon `Échap` rouvrirait au caractère suivant).
  ZChatMentionMatch? _dismissed;

  void _onChanged() {
    if (_disposed) return;
    final String texte = composer.text;
    final int curseur = composer.selection.baseOffset;
    final ZChatMentionMatch? m = _matchIn(texte, curseur);
    if (m == null) {
      _dismissed = null;
      if (_state.value.isOpen) _state.value = ZChatComposerAffordanceState.closed;
      return;
    }
    if (_dismissed == m) return;
    _dismissed = null;
    if (!m.isReady) {
      _state.value = ZChatComposerAffordanceState.closed;
      return;
    }
    unawaited(_ask(m));
  }

  ZChatMentionMatch? _matchIn(String texte, int curseur) {
    for (final ZChatMentionTrigger t in triggers) {
      final ZChatMentionMatch? m = t.matchIn(texte, curseur);
      if (m != null) return m;
    }
    return catalog?.trigger?.matchIn(texte, curseur);
  }

  Future<void> _ask(ZChatMentionMatch m) async {
    final int epoch = ++_epoch;
    List<ZChatComposerAffordanceEntry> entrees =
        const <ZChatComposerAffordanceEntry>[];
    ZFailure? panne;

    final ZChatSlashCatalog? cat = catalog;
    final bool estCommande =
        cat != null && identical(m.trigger, cat.trigger);
    final bool sourceDeclaree = sources.keys.contains(m.trigger.sourceKey);

    if (estCommande && !sourceDeclaree) {
      entrees = <ZChatComposerAffordanceEntry>[
        for (final ZChatSlashCommand c in cat.ordered)
          ZChatComposerAffordanceEntry.command(c),
      ];
    } else {
      ZResult<List<ZChatMentionCandidate>> rendus;
      try {
        rendus = await sources.sourceForTrigger(m.trigger).candidates(m);
      } catch (error) {
        // Invariant AD-10 : une source d'hôte qui lève ne fait pas tomber la
        // saisie — le panneau reste vide et la panne est exposée.
        rendus = Left<ZFailure, List<ZChatMentionCandidate>>(
          ZDomainFailure('$error'),
        );
      }
      rendus.fold((ZFailure f) => panne = f, (
        List<ZChatMentionCandidate> liste,
      ) {
        entrees = <ZChatComposerAffordanceEntry>[
          // AUCUN tri, AUCUN filtre, AUCUNE troncature : l'ordre est celui de
          // la source, et la longueur aussi.
          for (final ZChatMentionCandidate c in liste)
            ZChatComposerAffordanceEntry.mention(c),
        ];
      });
    }

    if (_disposed || epoch != _epoch) return;
    _state.value = ZChatComposerAffordanceState(
      match: m,
      entries: List<ZChatComposerAffordanceEntry>.unmodifiable(entrees),
      selectedIndex: entrees.isEmpty ? -1 : 0,
      // TRANSPORTÉ, jamais appliqué.
      maxCandidates: m.trigger.maxCandidates,
      failure: panne,
    );
  }

  /// Déplace la mise en avant de [delta], **bornée** aux extrémités.
  ///
  /// Pas d'enroulement : dépasser le dernier candidat ne doit pas ramener au
  /// premier sans que rien ne l'ait annoncé.
  void moveSelection(int delta) {
    final ZChatComposerAffordanceState s = _state.value;
    if (!s.isOpen || s.entries.isEmpty) return;
    final int cible = (s.selectedIndex + delta).clamp(0, s.entries.length - 1);
    if (cible == s.selectedIndex) return;
    _state.value = ZChatComposerAffordanceState(
      match: s.match,
      entries: s.entries,
      selectedIndex: cible,
      maxCandidates: s.maxCandidates,
      failure: s.failure,
    );
  }

  /// Met [index] en avant (survol, tap au clavier d'un lecteur d'écran).
  void select(int index) => moveSelection(index - _state.value.selectedIndex);

  /// **Transmet** l'entrée mise en avant, puis ferme le panneau.
  ///
  /// Pour un candidat de mention portant un `insertText`, le socle remplace la
  /// tranche reconnue par ce texte — c'est l'hôte qui a écrit ce qu'il fallait
  /// écrire. Sans `insertText`, la saisie n'est pas touchée : le socle ne
  /// fabrique pas de texte.
  ///
  /// Pour une commande, la saisie n'est **jamais** modifiée et rien n'est
  /// exécuté : la commande est remise à l'hôte.
  void commit() {
    final ZChatComposerAffordanceState s = _state.value;
    final ZChatComposerAffordanceEntry? e = s.selected;
    final ZChatMentionMatch? m = s.match;
    if (e == null || m == null || !e.isEnabled) return;
    _state.value = ZChatComposerAffordanceState.closed;
    _dismissed = m;
    final ZChatSlashCommand? cmd = e.command;
    if (cmd != null) {
      onCommand?.call(cmd, m);
      return;
    }
    final ZChatMentionCandidate c = e.candidate!;
    final String? insere = c.insertText;
    if (insere != null) {
      // Seul l'intervalle RECONNU est remplacé : ce qui précède l'amorce et
      // ce qui suit le curseur est préservé.
      zChatReplaceComposerRange(
        composer,
        start: m.start,
        end: m.end,
        text: insere,
      );
    }
    onCandidate?.call(c, m);
  }

  /// Ferme sans rien retenir. Le panneau ne se rouvrira pas sur la **même**
  /// correspondance.
  void dismiss() {
    final ZChatComposerAffordanceState s = _state.value;
    if (!s.isOpen) return;
    _dismissed = s.match;
    _state.value = ZChatComposerAffordanceState.closed;
  }

  /// Détache l'abonnement et libère la tranche.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    composer.removeListener(_onChanged);
    _state.dispose();
  }
}
