/// `ZMarkdownRichTextRenderer` — moteur **Markdown** du port `ZRichTextRenderer`
/// de `zcrud_core` (AD-1/AD-8).
///
/// `zcrud_core` v0.66.0 a livré le PORT et rien d'autre : sans implémentation,
/// un `ZcrudScope` n'a aucun moteur à injecter et tout libellé riche retombe sur
/// le texte simple. Ce fichier est l'implémentation — le pendant exact de
/// `zcrud_list` pour `ZListRenderer`.
///
/// ## Aucune arête nouvelle (AD-1)
///
/// Ce renderer n'introduit **aucune** dépendance : il branche bout à bout les
/// deux moitiés de moteur que `zcrud_markdown` possédait déjà, et qui n'avaient
/// jamais été raccordées pour une source Markdown NUE :
///
///   * `ZMarkdownCodec` — le PARSEUR (Markdown → ops Delta neutres), défensif
///     par contrat (`decode` ne lève jamais, `[]` sur illisible) ;
///   * `ZMarkdownReader` — le RENDU (ops Delta neutres → widget), via un
///     `QuillEditor` readOnly, controller créé une seule fois (AD-2), mêmes
///     `EmbedBuilder`s qu'en édition, repli d'embed inconnu (AD-10).
///
/// `gpt_markdown` — le paquet que l'éditeur historique importe aujourd'hui dans
/// `dynamic_stepper.dart` — n'entre PAS au pubspec, et n'avait pas à y entrer :
/// tout ce qu'il rend d'utile ici, le couple codec+lecteur le rendait déjà.
///
/// ## Ce que l'éditeur historique met VRAIMENT dans un sous-titre d'étape (mesuré)
///
/// Relevé en lecture seule sur `dodlp-otr` (`stepSubtitle`, ~40 sites) :
/// l'écrasante majorité est du **texte pur** ; le balisage réel se réduit à
/// quatre constructions, toutes dans les longues descriptions de procédure
/// (`neVarietur`, `bondStoreDescription` de `ship_handling_form.dart`) :
/// paragraphes, `**gras**`, listes `- ` et listes `1. `. Mesuré à zéro
/// occurrence : titres `#`, citations `>`, tableaux, images, filets `---`.
/// Le CommonMark complet n'est donc PAS l'objectif — et ce constat justifie
/// que le renderer DÉCLINE largement plutôt qu'il n'approxime.
///
/// ## Décliner (`null`) est un CHEMIN, pas un échec
///
/// Le port dit : rendre `null` = décliner, l'appelant retombe sur un rendu texte
/// simple. Ce renderer s'en sert quatre fois — cf. [ZMarkdownRichTextRenderer.build].
library;

import 'package:flutter/widgets.dart';
import 'package:zcrud_core/zcrud_core.dart';

import '../data/z_markdown_codec.dart';
import '../domain/z_codec.dart';
import 'z_markdown_reader.dart';

/// Moteur de rendu Markdown branché sur le port `ZRichTextRenderer`.
///
/// `const`-constructible (comme le port) : un hôte l'injecte en
/// `ZcrudScope(richTextRenderer: const ZMarkdownRichTextRenderer(), …)` sans
/// allouer quoi que ce soit à chaque build.
@immutable
class ZMarkdownRichTextRenderer implements ZRichTextRenderer {
  /// Construit le renderer.
  ///
  /// [codec] est le parseur de la source (défaut `ZMarkdownCodec`). Le rendre
  /// remplaçable est la couture d'extension (AD-4) : un hôte qui a enrichi son
  /// Markdown de ponts d'embed (`ZMarkdownBridge`) injecte SON codec ici sans
  /// que ce fichier ait à connaître sa syntaxe.
  const ZMarkdownRichTextRenderer({this.codec = const ZMarkdownCodec()});

  /// Parseur Markdown → ops Delta neutres.
  final ZCodec codec;

  /// Rend [source] en Markdown, ou **décline** (`null`).
  ///
  /// Décline dans exactement quatre cas — chacun parce que le repli texte simple
  /// de l'appelant y est meilleur qu'un rendu riche :
  ///
  ///  1. **Source vide** (ou uniquement des blancs) : il n'y a rien à rendre.
  ///  2. **Rien à décoder** : le parseur rend zéro op — source illisible pour
  ///     lui. Contrat `ZCodec` : il n'aura pas levé, il aura rendu `[]`.
  ///     Un `catch` couvre malgré tout un codec injecté qui, lui, lèverait —
  ///     AUCUNE exception ne doit s'échapper d'un `build` (AD-10).
  ///  3. **Le balisage dépasse le texte enrichi** : la source porte un EMBED
  ///     (tableau, LaTeX, image, vidéo, filet). Ces ops réclament une place de
  ///     bloc et un `EmbedBuilder` ; les rendre dans un libellé — un sous-titre
  ///     d'étape — donnerait une boîte dans une ligne. Mesuré à zéro occurrence
  ///     chez l'éditeur historique : on décline plutôt qu'on approxime.
  ///  4. **Aucun balisage du tout** : la source est du texte pur. Le repli de
  ///     l'appelant est alors **strictement équivalent**, et bien moins cher
  ///     qu'un `QuillEditor`. C'est le cas de la grande majorité des
  ///     `stepSubtitle` l'éditeur historique : décliner y est la bonne réponse, pas un renoncement.
  ///
  /// [baseStyle] est pris pour BASE du corps (paragraphe, listes, citation) ; les
  /// rôles matérialisés (gras, code inline, titres) en dévient délibérément.
  @override
  Widget? build(BuildContext context, String source, {TextStyle? baseStyle}) {
    // (1) Source vide ⇒ décliner.
    if (source.trim().isEmpty) return null;

    // (2) Décodage défensif. Le contrat `ZCodec` promet de ne pas lever ; le
    //     `catch` protège d'un codec injecté qui ne tiendrait pas la promesse.
    final List<Map<String, dynamic>> ops;
    try {
      ops = codec.decode(source);
    } catch (_) {
      return null;
    }
    if (ops.isEmpty) return null;

    // (3)/(4) Qualification du balisage décodé.
    var hasMarkup = false;
    for (final Map<String, dynamic> op in ops) {
      // Une op dont l'`insert` n'est PAS une String est un embed.
      if (op['insert'] is! String) return null;
      final Object? attributes = op['attributes'];
      if (attributes is Map && attributes.isNotEmpty) hasMarkup = true;
    }
    if (!hasMarkup) return null;

    // Rendu : le lecteur existant, sans habillage (l'appelant place le libellé)
    // et SANS nœud sémantique propre — le texte rendu est déjà annoncé par ses
    // propres feuilles ; un `Semantics` de plus ne ferait que fusionner ou
    // doubler l'annonce (AD-13).
    return ZMarkdownReader(
      value: ops,
      chrome: ZMarkdownReaderChrome.none,
      semanticsEnabled: false,
      baseStyle: baseStyle,
    );
  }
}
