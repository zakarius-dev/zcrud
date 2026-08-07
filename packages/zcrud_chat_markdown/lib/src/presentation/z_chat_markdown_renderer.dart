/// Backend de **rendu riche** du port `ZChatRenderer` — CR-IFFD-73.
///
/// ## Ce que ce paquet est, et pourquoi il n'existait pas
///
/// Le dartdoc de `ZChatRenderer` publiait une table de trois implémentations
/// dont la ligne « rendu riche Markdown/LaTeX — satellite adossé à
/// `zcrud_markdown` » **n'avait aucun paquet**. La couture était offerte et
/// VIDE : sur appareil, une réponse de modèle s'affichait en **texte source**
/// (`**Introduction**Le commerce…`) parce que le rendu neutre — qui est correct
/// dans son rôle — ne fait volontairement ni Markdown, ni LaTeX, ni Mermaid.
///
/// Ce fichier est au chat ce que `ZSfDataGridRenderer` est à `ZListRenderer` :
/// **l'implémentation au bout du port**. Aucun hôte n'écrit sa propre liste ;
/// aucun hôte ne devrait écrire son propre rendu Markdown.
///
/// ## 🔴 Le STREAMING — la seule question difficile, et elle est MESURÉE
///
/// Pendant le flux, le Markdown est incomplet à chaque fragment. Trois faits
/// mesurés (bancs `z_chat_markdown_streaming_test.dart`, rejouables) :
///
/// 1. **Aucune dégradation violente.** 21 fragments tronqués aux endroits qui
///    font mal (`**` non fermé, table à une ligne, fence non refermée, lien
///    coupé, `$$` ouvert) : `ZMarkdownCodec.decode` **ne lève jamais** et rend
///    le texte littéral. Un fuzz de 66 décodages sur un corpus agressif donne
///    **0 throw**. AD-10 est donc tenu par le décodeur lui-même.
/// 2. **Mais les artefacts CLIGNOTENT, et c'est visible.** Sur
///    `Le **commerce** est *libre*`, la sortie change de forme trois fois. À
///    **14 caractères** (`Le **commerce*` — le troisième astérisque vient
///    d'arriver, le quatrième pas encore) le texte s'affiche en **ITALIQUE**,
///    `Le *commerce`, astérisque orphelin compris ; **un caractère plus tard**
///    il bascule en gras et l'astérisque disparaît. Le futur gras « clignote »
///    en italique avant de se fixer. Ce n'est pas une hypothèse : c'est la
///    trace du banc, et elle est assertée.
/// 3. **Et re-parser coûte cher.** Un cycle complet de ré-hydratation du
///    lecteur (parse + `Document` + ré-encodage de dédup + layout Quill) sur un
///    message réaliste de ~670 caractères coûte **~10,8 ms par fragment**
///    (mesuré 172 ms pour 16 ré-hydratations) — les deux tiers d'une trame de
///    16 ms, sur un poste de développement en JIT. Le parse seul croît avec la
///    longueur (~0,9 ms à 670 c., ~3,1 ms à 5 344 c.) et le message GRANDIT à
///    chaque jeton : le coût cumulé est **quadratique**. Sur l'appareil de la
///    CR (TECNO KN4), il n'y a pas de marge.
///
///    ⚠️ **Ce que ces chiffres ne sont PAS.** Ils viennent du binding de test,
///    en JIT, sur un poste de bureau : ils donnent un ORDRE DE GRANDEUR et un
///    rapport, pas une prédiction pour l'appareil. Le sens de l'écart est
///    toutefois défavorable (un mobile bas de gamme est plus lent, pas moins),
///    ce qui suffit à trancher. **Non mesuré** : le coût réel sur appareil, et
///    le poids de Quill dans un binaire — la CR le signale déjà comme non
///    chiffré, et ce lot ne le chiffre pas davantage.
///
/// ⇒ **Décision : neutre pendant le flux, riche à la complétion.** C'est
/// [ZChatMarkdownStreamingMode.neutralWhileStreaming], le défaut.
///
/// 🔵 **Et la mise en œuvre est GRATUITE** — c'est ce qui rend la décision
/// solide plutôt que prudente. Pendant le flux, `zcrud_chat` construit une
/// tuile SYNTHÉTIQUE (`ZTextBlock()` vide + `isStreaming: true` +
/// `streamingText`) ; le renderer se contente de **rendre `null`**, et la
/// chaîne retombe sur le rendu neutre, qui prend déjà l'abonnement au plus près
/// du `Text` (SM-1 : un jeton ne reconstruit que ce `builder`) et porte déjà sa
/// contrainte de 48 dp et son `Semantics`. Aucune tuile parallèle n'est écrite
/// — motif **CR-LEX-78**, que le satellite Syncfusion a déjà payé une fois.
/// À la complétion, les vrais `contentBlocks` arrivent avec
/// `isStreaming: false` : le rendu riche prend le relais, **une seule fois**.
///
/// [ZChatMarkdownStreamingMode.richWhileStreaming] existe pour l'hôte qui a
/// mesuré son propre appareil et accepte la facture. Il n'est pas le défaut, et
/// le dartdoc dit pourquoi.
///
/// ## Le périmètre de blocs, et pourquoi il s'arrête là
///
/// Relevé sur le dépôt (grep des constructeurs) : **`ZTextBlock` est le SEUL
/// `kind` qu'une ligne de code de ce dépôt PRODUIT** — dans
/// `ZChatController` (brouillon, réponse) et dans le normalisateur de flux
/// textuel d'IFFD (`z_iffd_stream_port.dart:137`). Toutes les autres variantes
/// (`ZTableBlock`, `ZKeyDefinitionBlock`, `ZComparisonTableBlock`,
/// `ZTimelineBlock`, `ZAlertBlock`, `ZMermaidDiagramBlock`, `ZSourcesBlock`,
/// `ZSuggestionsBlock`) n'existent qu'au bout d'une **désérialisation**
/// (`ZContentBlock.fromMap`), c'est-à-dire d'un backend qui émet du JSON typé.
///
/// Ce satellite couvre donc **`ZTextBlock`, et lui seul**. Ce n'est pas une
/// économie : c'est que les autres portent de la **donnée déjà structurée**, et
/// qu'un passage Markdown ne leur apporterait rien tout en pouvant leur nuire —
/// `ZMermaidDiagramBlock.code` serait activement **détruit** (les `_` d'un
/// identifiant deviennent de l'italique, un `-->` peut se faire manger). Tout
/// bloc non couvert rend `null` et **retombe proprement** sur le rendu neutre,
/// qui le rend structurellement (AD-10, AD-57).
///
/// ## LaTeX — pourquoi le pont est déclaré, et pourquoi c'est SANS RISQUE ici
///
/// CR-IFFD-69 a établi que la corruption du LaTeX bloc vit sur le chemin
/// **SANS pont**, et `ZMarkdownCodec` la neutralise depuis par un bouclier
/// littéral. Deux mesures tranchent la question pour ce paquet :
///
/// * **La classe de défaut de CR-IFFD-69 est hors d'atteinte par
///   construction** : elle est un défaut d'**ENCODAGE** (Delta → Markdown), et
///   ce satellite ne fait **que décoder**. Il n'écrit rien, ne persiste rien,
///   n'altère aucune donnée. Déclarer le pont ici est une décision d'AFFICHAGE.
/// * **Sans pont, `$$V = P + F$$` s'affiche littéralement** — exactement le
///   défaut que CR-IFFD-73 rapporte pour `**`. Défaut désactivé, on livrerait
///   une seconde fois « offert et vide », un cran plus bas.
///
/// L'ambiguïté du `$` (prix vs formule) est arbitrée par la garde
/// `zLatexPayloadLooksLikeFormula`, déjà embarquée dans
/// `ZMarkdownBridges.latex`. Mesurée sur ce banc : `5$ a 9$`, `250$ CAD a
/// 300$ US`, `100$$ a 200$$ USD` et `Prix $5 et $9` restent **du texte**, au
/// caractère près ; `$E = mc^2$`, `$$V = P + F + A$$`, `$\sum_{i=1}^{n} x_i$`
/// et `$\ce{H2O}$` deviennent des formules. [latex] permet de le couper.
///
/// ## Confinement (AD-1 / AD-57)
///
/// Ce fichier ne nomme **aucun** type Quill, et le pubspec ne déclare **aucune**
/// arête `flutter_quill`. Quill n'est atteint qu'à travers l'API neutre de
/// `zcrud_markdown` (`ZMarkdownReader` + `ZCodec`), dont le barrel n'exporte
/// aucun symbole Quill. Garde : `z_quill_confinement_test.dart` (source ET
/// fermeture de dépendances, avec contrôle positif).
library;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Politique de rendu **pendant le flux** — cf. les trois mesures du dartdoc
/// de tête.
enum ZChatMarkdownStreamingMode {
  /// **Défaut.** Le renderer décline pendant le flux : le rendu neutre affiche
  /// le texte en cours (granulaire, SM-1), et le rendu riche prend le relais
  /// **une seule fois**, à la complétion.
  ///
  /// Évite l'artefact mesuré (le gras qui clignote en italique) et la facture
  /// de ~10,9 ms par fragment.
  neutralWhileStreaming,

  /// Rendu riche **à chaque fragment**. Réservé à l'hôte qui a mesuré son
  /// appareil : il paie un re-parse complet par jeton, sur un message qui
  /// grandit, et voit les artefacts de Markdown incomplet.
  richWhileStreaming,
}

/// Rôles dont le texte est interprété comme du Markdown — **tout sauf `user`**.
///
/// 🔴 **Pourquoi `user` en est exclu par défaut.** Ce que l'utilisateur a TAPÉ
/// est littéral : il a écrit `**important**` parce qu'il voulait ces
/// astérisques, ou il a collé un extrait. Le rendre en Markdown les **mange**,
/// et l'écho de sa propre saisie cesse de ressembler à sa saisie. C'est une
/// perte silencieuse sur la seule donnée dont l'utilisateur connaît la forme
/// exacte.
///
/// `unknown` est INCLUS : un rôle qui n'a pas su se parser vient, dans les faits
/// mesurés de ce dépôt, d'un flux d'assistant (`ZChatRole.fromJson` replie sur
/// `unknown`, jamais sur `user`). L'exclure ferait réapparaître le défaut de
/// CR-IFFD-73 sur ce chemin ; l'inclure ne risque, au pire, qu'une perte
/// cosmétique et réversible.
const Set<ZChatRole> kZChatMarkdownDefaultRoles = <ZChatRole>{
  ZChatRole.assistant,
  ZChatRole.system,
  ZChatRole.unknown,
};

/// Rend en **Markdown riche** les blocs de texte d'une conversation.
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
/// `const` : il est comparé par **identité** par
/// `ZChatRendererScope.updateShouldNotify` (le garder `const`, ou mémoïsé hors
/// de `build`, évite de reconstruire la conversation à chaque trame).
@immutable
class ZChatMarkdownRenderer extends ZChatRenderer {
  /// Construit le backend de rendu riche.
  const ZChatMarkdownRenderer({
    this.streamingMode = ZChatMarkdownStreamingMode.neutralWhileStreaming,
    this.latex = true,
    this.roles = kZChatMarkdownDefaultRoles,
    this.textStyle,
  });

  /// Politique de rendu pendant le flux (défaut : neutre pendant, riche après).
  final ZChatMarkdownStreamingMode streamingMode;

  /// Reconnaît `$…$` / `$$…$$` / `\(…\)` / `\[…\]` comme des formules (défaut).
  ///
  /// `false` ⇒ le LaTeX reste du texte littéral. Aucune donnée n'est en jeu
  /// dans les deux cas : ce satellite ne fait que décoder (cf. dartdoc de tête).
  final bool latex;

  /// Les rôles dont le texte est interprété comme du Markdown.
  ///
  /// Défaut [kZChatMarkdownDefaultRoles] : **tout sauf `user`**.
  final Set<ZChatRole> roles;

  /// Style de base **fourni par l'hôte**, ou `null` pour hériter du thème.
  ///
  /// FR-26 : aucune couleur, aucune taille n'est décidée ici. `null` laisse
  /// `zcrud_markdown` dériver ses styles du `Theme`/`ZcrudTheme` injecté.
  final TextStyle? textStyle;

  /// Le codec de lecture, dérivé de [latex]. Reconstruit à chaque appel — il
  /// est `const`-compatible et sans état ; le coût est celui d'une allocation
  /// de liste de motifs, hors du chemin chaud (un seul décodage par bloc rendu).
  ZMarkdownCodec get _codec => latex
      ? ZMarkdownCodec(bridges: ZMarkdownBridges.latex)
      : const ZMarkdownCodec();

  @override
  Widget? buildBlock(BuildContext context, ZChatBlockRenderRequest request) {
    final ZContentBlock block = request.block;
    // Tout `kind` non couvert DÉCLINE (AD-10/AD-57) : le rendu neutre le rend
    // structurellement, et il le rend mieux (cf. dartdoc, périmètre de blocs).
    if (block is! ZTextBlock) return null;
    // Le texte TAPÉ par l'utilisateur reste littéral (cf.
    // [kZChatMarkdownDefaultRoles]).
    if (!roles.contains(request.message.role)) return null;

    final ValueListenable<String>? live = request.streamingText;

    // ── Chemin de FLUX ────────────────────────────────────────────────────
    if (live != null || request.isStreaming) {
      if (streamingMode == ZChatMarkdownStreamingMode.neutralWhileStreaming) {
        // 🔴 Décliner N'EST PAS renoncer : c'est réutiliser la tuile de
        // streaming du socle, qui porte déjà l'abonnement granulaire, la
        // contrainte de 48 dp et le `Semantics`. Aucune vue parallèle.
        return null;
      }
      if (live == null) return null; // rien à écouter : neutre.
      return ValueListenableBuilder<String>(
        valueListenable: live,
        builder: (BuildContext context, String value, Widget? _) =>
            _rich(context, value),
      );
    }

    // ── Chemin COMPLET ────────────────────────────────────────────────────
    final String text = block.text;
    // Un bloc vide n'a rien à rendre en riche : décliner laisse le neutre
    // décider (et évite d'inventer un placeholder — FR-26).
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
      // FR-26 : aucun libellé de repli. Un contenu vide ne rend rien.
      placeholder: '',
    );
    final TextStyle? style = textStyle;
    if (style == null) return reader;
    return DefaultTextStyle.merge(style: style, child: reader);
  }
}
