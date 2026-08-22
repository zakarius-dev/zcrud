/// Backend de rendu riche Markdown/LaTeX pour le port `ZChatRenderer` de
/// `zcrud_chat`.
///
/// Le rendu neutre du socle affiche volontairement le Markdown, le LaTeX et
/// les diagrammes Mermaid comme du texte source (aucune interprétation, pour
/// rester libre de toute dépendance riche). Ce fichier fournit
/// l'implémentation branchée au bout de ce port pour les blocs de texte —
/// sur le même principe que le renderer par défaut d'une liste : un hôte
/// n'a pas à réécrire son propre rendu Markdown.
///
/// ## Streaming
///
/// Pendant un flux, le Markdown reçu est incomplet à chaque fragment. Trois
/// propriétés mesurées par les bancs de ce paquet en découlent :
///
/// 1. **Aucune dégradation violente.** Un motif tronqué à un endroit délicat
///    (`**` non fermé, table à une ligne, bloc de code non refermé, lien
///    coupé, `$$` ouvert) ne fait jamais lever le décodeur : le texte
///    littéral est rendu tel quel (invariant AD-10).
/// 2. **Mais le rendu peut clignoter visuellement** le temps qu'un motif se
///    complète — un gras en cours de réception peut transiter par un état
///    italique avant de se fixer, le temps que le second marqueur arrive.
/// 3. **Et re-décoder à chaque fragment a un coût qui croît avec la
///    longueur du message** : chaque jeton reçu déclenche, en mode riche
///    pendant le flux, un cycle complet de parsing et de mise en page — sur
///    un message qui grandit à chaque jeton, ce coût cumulé n'est pas
///    négligeable sur un appareil d'entrée de gamme.
///
/// Le défaut, [ZChatMarkdownStreamingMode.neutralWhileStreaming], évite ce
/// clignotement et ce coût : le renderer décline pendant le flux (rendu
/// neutre du socle, qui affiche déjà le texte en cours de façon granulaire),
/// et le rendu riche ne s'applique qu'**une seule fois**, à la complétion du
/// message. [ZChatMarkdownStreamingMode.richWhileStreaming] existe pour
/// l'hôte qui a mesuré son propre appareil et accepte cette facture.
///
/// ## Périmètre de blocs
///
/// Ce satellite ne rend en Markdown que [ZTextBlock] — les autres variantes
/// de [ZContentBlock] (tableau, chronologie, alerte, diagramme, sources,
/// suggestions…) portent une donnée déjà structurée qu'un passage Markdown
/// n'améliorerait pas, et pourrait activement corrompre (un identifiant de
/// diagramme dont les soulignés deviendraient de l'italique, par exemple).
/// Tout bloc hors périmètre fait décliner le renderer (`null`), qui retombe
/// proprement sur le rendu neutre du socle — c'est le même mécanisme que
/// pour le streaming.
///
/// ## LaTeX
///
/// Le pont LaTeX de `zcrud_markdown` est activé par défaut ([latex]). Ce
/// satellite ne fait que décoder du texte déjà persisté vers un rendu — il
/// n'écrit et ne transforme aucune donnée — si bien qu'activer le pont ici
/// n'est qu'une décision d'affichage, sans risque sur le contenu stocké.
/// L'ambiguïté entre un prix (`5$`) et une formule (`$E = mc^2$`) est
/// arbitrée par `zcrud_markdown` lui-même.
///
/// ## Typographie du rendu
///
/// Deux canaux, de portées différentes, et ils se composent :
///
/// * [ZChatMarkdownRenderer.textStyle] est un style **global** : il devient la
///   base de tout ce qui est peint dans la bulle (paragraphes, listes,
///   citation, et le point de départ des titres).
/// * [ZChatMarkdownRenderer.styleSet] est un jeu de styles **par axe
///   Markdown** : `h2`, gras, italique, citation, code… Chaque slot fourni est
///   fusionné **par-dessus** la base.
///
/// ⇒ **Sur un axe couvert par [ZChatMarkdownRenderer.styleSet], c'est le jeu de
/// styles qui l'emporte** ; sur les axes qu'il ne couvre pas,
/// [ZChatMarkdownRenderer.textStyle] (puis le thème) reste seul en vigueur.
/// La règle est celle d'un `merge` : un slot ne portant qu'une couleur ne
/// change que la couleur, la taille et la graisse héritées restant en place.
///
/// Aucun de ces deux canaux n'a de valeur par défaut : sans déclaration, le
/// rendu est celui du thème injecté, et ce paquet n'invente ni couleur ni
/// taille (FR-26).
///
/// ## Confinement de la dépendance riche
///
/// Ce fichier ne référence aucun type de l'éditeur riche sous-jacent : il
/// n'atteint le rendu Markdown qu'à travers l'API neutre de `zcrud_markdown`
/// (`ZMarkdownReader` + `ZCodec`). Un hôte de `zcrud_chat` qui ne monte pas
/// ce satellite ne tire donc aucune dépendance riche supplémentaire — c'est
/// la propriété opt-in décrite pour l'ensemble des satellites du chat (voir
/// le README du paquet).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Politique de rendu pendant un flux en cours — voir la section streaming
/// de la dartdoc de tête de ce fichier.
enum ZChatMarkdownStreamingMode {
  /// Défaut. Le renderer décline pendant le flux : le rendu neutre du socle
  /// affiche le texte en cours de façon granulaire, et le rendu riche prend
  /// le relais une seule fois, à la complétion du message.
  ///
  /// Évite le clignotement visuel d'un motif Markdown en cours de réception
  /// et le coût d'un re-décodage à chaque fragment.
  neutralWhileStreaming,

  /// Rendu riche à chaque fragment reçu. Réservé à l'hôte qui a mesuré son
  /// propre appareil et accepte de payer un cycle de décodage complet par
  /// jeton, sur un message qui grandit, avec les artefacts visuels d'un
  /// Markdown encore incomplet.
  richWhileStreaming,
}

/// Rôles dont le texte est interprété comme du Markdown — tout sauf `user`.
///
/// Le texte tapé par l'utilisateur reste littéral : il a écrit
/// `**important**` parce qu'il voulait ces astérisques, ou a collé un
/// extrait. Le rendre en Markdown les mangerait, et l'écho de sa propre
/// saisie cesserait de ressembler à sa saisie — une perte silencieuse sur la
/// seule donnée dont l'utilisateur connaît la forme exacte.
///
/// `unknown` est inclus : un rôle qui n'a pas su se parser vient en pratique
/// d'un flux d'assistant (`ZChatRole.fromJson` replie sur `unknown`, jamais
/// sur `user`) ; l'exclure ferait réapparaître le texte source sur ce
/// chemin, alors que l'inclure ne risque, au pire, qu'une perte cosmétique
/// et réversible.
const Set<ZChatRole> kZChatMarkdownDefaultRoles = <ZChatRole>{
  ZChatRole.assistant,
  ZChatRole.system,
  ZChatRole.unknown,
};

/// Rend en Markdown riche les blocs de texte d'une conversation.
///
/// Injecté par l'hôte via `ZChatRendererScope` :
///
/// ```dart
/// ZChatRendererScope(
///   renderer: const ZChatMarkdownRenderer(),
///   child: ZChatConversationView(controller: c),
/// )
/// ```
///
/// Ce renderer est comparé par identité par
/// `ZChatRendererScope.updateShouldNotify` : le garder `const`, ou le
/// mémoïser hors de `build`, évite de reconstruire la conversation à chaque
/// trame.
@immutable
class ZChatMarkdownRenderer extends ZChatRenderer {
  /// Construit le backend de rendu riche.
  const ZChatMarkdownRenderer({
    this.streamingMode = ZChatMarkdownStreamingMode.neutralWhileStreaming,
    this.latex = true,
    this.roles = kZChatMarkdownDefaultRoles,
    this.textStyle,
    this.styleSet,
    this.textScaleFactor,
  });

  /// Politique de rendu pendant le flux (défaut : neutre pendant, riche après).
  final ZChatMarkdownStreamingMode streamingMode;

  /// Reconnaît `$…$` / `$$…$$` / `\(…\)` / `\[…\]` comme des formules (défaut).
  ///
  /// `false` ⇒ le LaTeX reste du texte littéral. Aucune donnée n'est en jeu
  /// dans les deux cas : ce satellite ne fait que décoder (voir la dartdoc de
  /// tête, section LaTeX).
  final bool latex;

  /// Les rôles dont le texte est interprété comme du Markdown.
  ///
  /// Défaut [kZChatMarkdownDefaultRoles] : tout sauf `user`.
  final Set<ZChatRole> roles;

  /// Style de base fourni par l'hôte, ou `null` pour hériter du thème.
  ///
  /// Aucune couleur ni taille n'est décidée par ce paquet : `null` laisse
  /// `zcrud_markdown` dériver ses styles du thème injecté.
  ///
  /// Portée **globale** : il ne distingue pas un titre d'un gras. Pour viser un
  /// axe Markdown précis, voir [styleSet], qui l'emporte sur les axes qu'il
  /// couvre (section typographie de la dartdoc de tête).
  final TextStyle? textStyle;

  /// Jeu de styles **par axe Markdown**, fourni par l'hôte, ou `null`.
  ///
  /// C'est le seul canal permettant de viser séparément un titre, le gras,
  /// l'italique, la citation ou le code : ni [textStyle] (global) ni le thème
  /// de l'application (qui vise tout l'écran) ne distinguent ces axes.
  ///
  /// Chaque slot est **fusionné par-dessus** le style courant : un slot ne
  /// portant qu'une couleur laisse la taille et la graisse héritées en place,
  /// et un slot non fourni ne change rien — un jeu partiel est donc légitime.
  ///
  /// `null` ⇒ rendu strictement inchangé. Ce paquet ne pose aucune couleur de
  /// lui-même (FR-26) : les couleurs sémantiques d'un hôte lui appartiennent,
  /// et c'est par ici qu'elles entrent.
  final ZRichTextStyleSet? styleSet;

  /// Facteur d'échelle **absolu** du texte rendu, ou `null` pour l'échelle
  /// ambiante.
  ///
  /// Absolu veut dire qu'il **remplace** l'échelle ambiante au lieu de s'y
  /// multiplier : un hôte qui veut composer avec l'échelle d'accessibilité de
  /// l'utilisateur multiplie lui-même avant de la passer ici. C'est le canal
  /// pour aligner la typographie du rendu sans toucher au thème de
  /// l'application.
  final double? textScaleFactor;

  /// Le codec de lecture, dérivé de [latex]. Reconstruit à chaque appel — il
  /// est `const`-compatible et sans état ; le coût est celui d'une allocation
  /// de liste de motifs, hors du chemin chaud (un seul décodage par bloc rendu).
  ZMarkdownCodec get _codec => latex
      ? ZMarkdownCodec(bridges: ZMarkdownBridges.latex)
      : const ZMarkdownCodec();

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    final ZContentBlock block = request.block;
    // Tout `kind` non couvert décline (invariant AD-10) : le rendu neutre le
    // rend structurellement, et il le rend mieux (cf. dartdoc de tête,
    // périmètre de blocs).
    if (block is! ZTextBlock) return null;
    // Le texte tapé par l'utilisateur reste littéral (cf.
    // [kZChatMarkdownDefaultRoles]).
    if (!roles.contains(request.message.role)) return null;

    final ValueListenable<String>? live = request.streamingText;

    // ── Chemin de flux ───────────────────────────────────────────────────
    if (live != null || request.isStreaming) {
      if (streamingMode == ZChatMarkdownStreamingMode.neutralWhileStreaming) {
        // Décliner n'est pas renoncer : c'est réutiliser la tuile de
        // streaming du socle, qui porte déjà l'abonnement granulaire, la
        // contrainte de taille tactile et l'annonce d'accessibilité.
        return null;
      }
      if (live == null) return null; // rien à écouter : neutre.
      return ValueListenableBuilder<String>(
        valueListenable: live,
        builder: (BuildContext context, String value, Widget? _) =>
            _rich(context, value),
      );
    }

    // ── Chemin complet ───────────────────────────────────────────────────
    final String text = block.text;
    // Un bloc vide n'a rien à rendre en riche : décliner laisse le neutre
    // décider, et évite d'inventer un texte de repli.
    if (text.trim().isEmpty) return null;
    return _rich(context, text);
  }

  /// Le rendu riche proprement dit.
  ///
  /// `ValueKey(latex)` : le codec est résolu **une seule fois** par
  /// `ZMarkdownReader` (`late final` en `initState`). Sans clé distincte, un
  /// basculement de [latex] sur un renderer remonté au même endroit
  /// réutiliserait l'ancien codec — silencieusement. La clé force la
  /// reconstruction d'état quand, et seulement quand, le codec change.
  Widget _rich(BuildContext context, String markdown) {
    final Widget reader = ZMarkdownReader(
      key: ValueKey<String>('zcrud_chat_markdown/${latex ? 'tex' : 'plain'}'),
      value: markdown,
      codec: _codec,
      // Aucun libellé inventé : la bulle est déjà annoncée par
      // `ZChatMessageTile` (`ZContentBlock.accessibleText`). Poser un second
      // nœud `Semantics` ferait annoncer le même contenu deux fois.
      semanticsEnabled: false,
      // Le contenu seul : la bulle porte son fond, son rayon et ses marges.
      chrome: ZMarkdownReaderChrome.none,
      // Aucun libellé de repli inventé : un contenu vide ne rend rien.
      placeholder: '',
      // Le chaînon par axe. `null` ⇒ le lecteur ne fusionne rien et rend
      // exactement comme avant : le défaut n'est pas touché.
      styleSet: styleSet,
      // `null` ⇒ aucun wrapper d'échelle n'est posé par le lecteur.
      textScaleFactor: textScaleFactor,
    );
    final TextStyle? style = textStyle;
    if (style == null) return reader;
    return DefaultTextStyle.merge(style: style, child: reader);
  }
}
