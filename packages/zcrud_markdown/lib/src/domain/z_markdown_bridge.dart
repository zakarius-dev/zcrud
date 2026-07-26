/// Ponts **Markdown ↔ embed** injectables — CR-IFFD-23 §3 / CR-IFFD-24 §2.
///
/// Le paquet savait RENDRE des embeds (formule LaTeX, tableau) qu'il ne savait
/// pas PRODUIRE depuis du Markdown : un embed était un aller simple. L'auteur
/// insérait une formule, enregistrait, rouvrait — il trouvait `[embed:latex]`.
///
/// AD-57 : la capacité est **opt-in**, le défaut reste zéro-extension. Un hôte
/// qui n'en veut pas garde exactement le comportement d'avant, et les pertes
/// documentées restent des pertes.
///
/// ISOLATION (AD-1) : ce fichier est PUR DART (`RegExp`, `Match`, closures).
/// Aucun type `markdown`/`markdown_quill`/`flutter_quill` n'y apparaît — c'est
/// ce qui permet de l'exporter par le barrel sans casser le gate d'isolation.
library;

// `foundation` seulement pour `@immutable` — `package:meta` n'est PAS une
// dépendance déclarée de ce paquet, l'utiliser serait s'appuyer sur une
// transitive.
import 'package:flutter/foundation.dart';

/// Décrit comment une **syntaxe Markdown INLINE** correspond à un **embed
/// Delta**, dans les deux sens.
///
/// ```dart
/// // `$E=mc^2$` ↔ {"insert": {"latex": "E=mc^2"}}
/// ZMarkdownEmbedBridge(
///   embedType: 'latex',
///   pattern: RegExp(r'\$([^$\n]+)\$'),
///   toMarkdown: (data) => '\$$data\$',
/// )
/// ```
///
/// ⚠️ **Un pont change le sens d'un texte ordinaire.** Une fois `$…$` déclaré,
/// une phrase contenant deux `$` devient une formule. C'est précisément pourquoi
/// la déclaration est explicite et jamais implicite.
@immutable
final class ZMarkdownEmbedBridge {
  const ZMarkdownEmbedBridge({
    required this.embedType,
    required this.pattern,
    required this.toMarkdown,
    this.dataFromMatch,
    this.escapedCharacters = const <String>{},
    this.accepts,
  });

  /// Type de l'embed Delta produit — la clé de l'`insert` (`'latex'`,
  /// `'latexBlock'`, …). C'est ce que le `EmbedBuilder` correspondant rendra.
  final String embedType;

  /// Motif reconnaissant la syntaxe dans le Markdown persisté. Par convention le
  /// **groupe 1** porte la donnée de l'embed, sauf si [dataFromMatch] est fourni.
  final RegExp pattern;

  /// Réémet le Markdown depuis la donnée de l'embed. C'est la moitié qui
  /// manquait : sans elle, l'encodeur dégrade en `[embed:<type>]`.
  final String Function(Object? data) toMarkdown;

  /// Extrait la donnée de l'embed depuis la correspondance. Défaut : groupe 1.
  ///
  /// Le type de retour est `String`, et non `Object`, parce que la donnée
  /// TRANSITE PAR LE MARKDOWN : elle finit forcément en texte. Un typage
  /// `Object` aurait laissé croire qu'une `Map` structurée survit, alors
  /// qu'elle serait écrasée en `toString()` sans avertissement.
  final String Function(Match match)? dataFromMatch;

  /// Caractères que ce pont rend SIGNIFICATIFS, et qu'il faut donc échapper à
  /// l'encodage d'un texte ordinaire.
  ///
  /// Sans cette déclaration, activer un pont `$…$` transforme un prix
  /// `5$ … 9$` en formule. C'est la règle « échapper ce que le décodeur sait
  /// relire », déjà appliquée à `~` pour le barré.
  final Set<String> escapedCharacters;

  /// Garde au **DÉCODAGE** (CR-LEX-48). `null` (défaut) = tout accepter, donc
  /// comportement inchangé pour un hôte existant (AD-57).
  ///
  /// [escapedCharacters] protège l'**écriture** : un texte ordinaire est réécrit
  /// `\$`. Mais un markdown **source** — écrit à la main, importé, produit par
  /// un générateur — ne contient aucun `$` échappé, et rien ne refusait alors la
  /// correspondance : `de 5 $ à 9 $` devenait un embed `latex` de charge
  /// `« à 9 »`. Le pont était **tout ou rien**.
  ///
  /// Ce prédicat n'est PAS un second motif : il se compose avec le MÊME
  /// [pattern], dans le MÊME objet. Le motif dit *ce qui peut correspondre*,
  /// [accepts] dit *et seulement si*. Il n'ARBITRE pas l'ambiguïté intrinsèque
  /// (un montant et une formule restent indiscernables dans l'absolu) : il rend
  /// l'arbitrage POSSIBLE côté hôte.
  ///
  /// Un refus **préserve le texte littéral** : le premier caractère du
  /// délimiteur est réémis tel quel et l'analyse reprend juste après (jamais de
  /// texte mangé).
  final bool Function(Match match)? accepts;

  /// Donnée d'embed pour [match], défensivement (AD-10 : jamais de throw — un
  /// motif sans groupe 1 rend une chaîne vide plutôt que de casser le décodage).
  String dataOf(Match match) {
    final extractor = dataFromMatch;
    if (extractor != null) return extractor(match);
    if (match.groupCount < 1) return '';
    return match.group(1) ?? '';
  }

  /// [accepts] appliqué DÉFENSIVEMENT (AD-10) : un prédicat hôte qui lève ne
  /// doit jamais casser le décodage. L'exception est traitée comme un **REFUS**
  /// — le texte littéral est préservé, la perte est bornée —, posture identique
  /// à celle déjà tenue par [dataOf].
  bool acceptsMatch(Match match) {
    final predicate = accepts;
    if (predicate == null) return true;
    try {
      return predicate(match);
    } on Object {
      return false;
    }
  }
}

/// Garde par défaut des ponts LaTeX fournis : une charge **vide** ou **bordée
/// d'espaces** n'est pas une formule (CR-LEX-48).
///
/// C'est la règle de flanquement que CommonMark applique déjà à ses propres
/// délimiteurs d'emphase (`*`/`_` ne peuvent pas ouvrir devant une espace), et
/// c'est aussi celle des extensions math usuelles. Elle sépare les quatre vraies
/// formules mesurées (`V = P + F + A`, `\frac{a}{b}`, `x^2`, `\alpha + \beta`)
/// des deux fausses (`« à 9 »`, `« CAD à 250 »`) sans heuristique sur le contenu
/// LaTeX lui-même — donc sans rejeter `$x$`.
bool zLatexPayloadLooksLikeFormula(Match match) {
  final String? data = match.groupCount < 1 ? null : match.group(1);
  if (data == null || data.isEmpty) return false;
  return data.trim().length == data.length;
}

/// Ponts prêts à l'emploi, **opt-in** (AD-57).
///
/// Ils n'ajoutent AUCUNE dépendance : `flutter_math_fork` est déjà au pubspec de
/// `zcrud_markdown` pour le RENDU des formules. Ce qui manquait n'était pas une
/// bibliothèque, c'était les quinze lignes de correspondance — raison pour
/// laquelle ces ponts vivent ici plutôt que dans un satellite : un paquet séparé
/// n'aurait isolé aucune dépendance, il n'aurait ajouté que de la cérémonie.
abstract final class ZMarkdownBridges {
  /// LaTeX **bloc** (`$$…$$`, `\[…\]`) ↔ embed `latexBlock`.
  ///
  /// À déclarer AVANT [latexInline] : `$$x$$` doit être essayé avant `$x$`,
  /// sinon la forme bloc serait capturée comme deux formules inline vides.
  static List<ZMarkdownEmbedBridge> get latexBlock => <ZMarkdownEmbedBridge>[
        ZMarkdownEmbedBridge(
          embedType: 'latexBlock',
          pattern: RegExp(r'(?<!\\)\$\$([^$]+?)(?<!\\)\$\$'),
          toMarkdown: (data) => '\$\$$data\$\$',
          escapedCharacters: const <String>{r'$'},
          accepts: zLatexPayloadLooksLikeFormula,
        ),
        ZMarkdownEmbedBridge(
          embedType: 'latexBlock',
          // CR-LEX-50 : `(?<!\\)` sur les DEUX délimiteurs. Sans ces gardes, le
          // `\]` né d'un backslash littéral doublé par l'encodeur (`a\]` →
          // `a\\]`) refermait un bloc ouvert par un crochet échappé.
          pattern: RegExp(r'(?<!\\)\\\[(.+?)(?<!\\)\\\]'),
          toMarkdown: (data) => '\$\$$data\$\$',
          escapedCharacters: const <String>{r'$'},
          accepts: zLatexPayloadLooksLikeFormula,
        ),
      ];

  /// LaTeX **inline** (`$…$`, `\(…\)`) ↔ embed `latex`.
  ///
  /// Couvre de fait `\ce{}` et `\pu{}` (notation chimique / unités) : ce sont des
  /// commandes LaTeX comme les autres, portées telles quelles dans la donnée de
  /// l'embed. Rien de spécifique n'est requis pour elles.
  static List<ZMarkdownEmbedBridge> get latexInline => <ZMarkdownEmbedBridge>[
        ZMarkdownEmbedBridge(
          embedType: 'latex',
          // Les délimiteurs ÉCHAPPÉS (`\$`) ne sont pas des délimiteurs : sans
          // ces gardes, `\$a\$b\$` capturait `a\` et l'échappement du texte
          // ordinaire devenait inopérant.
          pattern: RegExp(r'(?<!\\)\$([^$\n]+?)(?<!\\)\$'),
          toMarkdown: (data) => '\$$data\$',
          escapedCharacters: const <String>{r'$'},
          accepts: zLatexPayloadLooksLikeFormula,
        ),
        ZMarkdownEmbedBridge(
          embedType: 'latex',
          // CR-LEX-50 : mêmes gardes que la forme bloc `\[…\]`.
          pattern: RegExp(r'(?<!\\)\\\((.+?)(?<!\\)\\\)'),
          toMarkdown: (data) => '\$$data\$',
          escapedCharacters: const <String>{r'$'},
          accepts: zLatexPayloadLooksLikeFormula,
        ),
      ];

  /// Jeu LaTeX complet, dans l'ordre correct (bloc avant inline).
  static List<ZMarkdownEmbedBridge> get latex => <ZMarkdownEmbedBridge>[
        ...latexBlock,
        ...latexInline,
      ];
}
