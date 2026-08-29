/// Normalisation de **sources LaTeX héritées** — fonctions PURES sur `String`.
///
/// Un corpus rich-text écrit avant migration porte des malformations qui
/// empêchent le moteur de rendu d'analyser la formule : elle s'affiche alors
/// comme une erreur, alors que le contenu, lui, est intact. Ces fonctions
/// réparent la SOURCE au moment de la LECTURE. Elles ne modifient jamais la
/// valeur du champ ni le format persisté : la migration reste à sens unique.
///
/// Trois réparations, indépendantes et composables :
///
/// 1. [zFixLatexLineBreaks] — un `\` isolé en fin de ligne devient `\\`, et une
///    formule à sauts de ligne SANS environnement est enveloppée dans
///    `\begin{cases}…\end{cases}`.
/// 2. [zUnescapeLatexCommands] — `\\frac` redevient `\frac`, sur un
///    dictionnaire de commandes ([kZLatexCommands]) : trace d'un double
///    échappement dans un pipeline d'écriture historique.
/// 3. [zAutoDelimitLatex] — du LaTeX **nu** dans un TEXTE est entouré de `$…$`
///    pour devenir rendable ; les régions déjà délimitées (`$…$`, `$$…$$`,
///    `\[…\]`, `\(…\)`) et les lignes de tableau Markdown sont repérées puis
///    EXCLUES, jamais doublées.
///
/// ⚠️ **Deux niveaux distincts, à ne pas confondre.** Les réparations 1 et 2
/// portent sur une **source de formule nue** (le contenu d'un embed) ; la 3
/// porte sur un **texte** susceptible de contenir des formules. Entourer une
/// source de formule nue de `$…$` la rendrait au contraire illisible pour le
/// moteur — `$` n'est pas un caractère valide en mode mathématique. D'où deux
/// compositions prêtes à l'emploi :
///
/// - [zNormalizeLegacyLatexSource] — 1 puis 2, pour une source de formule.
/// - [zNormalizeLatexInText] — le pipeline complet, pour du texte (Markdown).
///
/// Toutes sont **idempotentes** sur une entrée déjà correcte : une source
/// valide traverse **octet pour octet**.
library;

/// Commandes LaTeX reconnues par [zUnescapeLatexCommands] et
/// [zAutoDelimitLatex].
///
/// La liste est une **donnée**, pas une règle : elle borne ce que la
/// normalisation ose toucher. Une commande absente de la liste n'est ni
/// dé-échappée, ni prise pour le début d'une formule nue.
const List<String> kZLatexCommands = <String>[
  // Fractions et racines.
  'frac', 'dfrac', 'tfrac', 'cfrac',
  'sqrt', 'root',
  // Grands opérateurs.
  'int', 'oint', 'iint', 'iiint',
  'sum', 'prod', 'coprod',
  'lim', 'limsup', 'liminf',
  // Fonctions.
  'sin', 'cos', 'tan', 'cot', 'sec', 'csc',
  'log', 'ln', 'exp',
  // Lettres grecques.
  'alpha', 'beta', 'gamma', 'delta', 'epsilon', 'theta', 'lambda', 'mu', 'pi',
  'sigma', 'omega',
  'infty', 'partial', 'nabla',
  // Relations et opérateurs.
  'le', 'ge', 'ne', 'approx', 'equiv', 'sim',
  'times', 'cdot', 'div',
  'to', 'rightarrow', 'leftarrow', 'Rightarrow', 'Leftarrow',
  // Texte et polices.
  'text', 'textbf', 'textit', 'mathrm', 'mathbf', 'mathit',
  // Environnements et délimiteurs.
  'begin', 'end',
  'left', 'right', 'big', 'Big', 'bigg', 'Bigg',
  // Accents.
  'vec', 'hat', 'bar', 'dot', 'ddot', 'tilde',
  'over', 'under', 'underset', 'overset',
  // Notation chimique.
  'ce', 'pu',
];

/// Environnements LaTeX qui portent DÉJÀ des sauts de ligne : leur présence
/// interdit l'enveloppement automatique en `cases`.
final RegExp _kEnvironment = RegExp(
  r'\\begin\s*\{(cases|align|aligned|gather|gathered|array|matrix|pmatrix'
  r'|bmatrix|vmatrix|split|equation|eqnarray)\}',
  caseSensitive: false,
);

/// Un `\` isolé (non précédé d'un `\`) immédiatement suivi d'un saut de ligne.
final RegExp _kLoneBackslashBeforeNewline = RegExp(r'(?<!\\)\\(?=\n)');

/// Un saut de ligne LaTeX RÉEL : `\\` suivi d'un blanc ou de la fin.
/// Distingué d'une commande échappée (`\\frac`), qui n'en est pas un.
final RegExp _kRealLineBreak = RegExp(r'\\\\(\s|$)');

/// Répare les sauts de ligne d'une **source de formule**.
///
/// Un `\` isolé en fin de ligne devient `\\` (le saut de ligne LaTeX). Puis,
/// si la formule porte des sauts de ligne réels sans être dans un
/// environnement, elle est enveloppée dans `\begin{cases}…\end{cases}` — un
/// système d'équations, la lecture la plus probable d'une formule multi-lignes
/// nue, et la seule qui se rende.
///
/// Une source sans `\` en fin de ligne et sans saut de ligne réel est rendue
/// **à l'identique**.
String zFixLatexLineBreaks(String source) {
  final String fixed =
      source.replaceAllMapped(_kLoneBackslashBeforeNewline, (_) => r'\\');
  return _wrapInCasesIfNeeded(fixed);
}

/// Enveloppe [content] dans `cases` s'il porte des sauts de ligne réels et
/// aucun environnement. Sinon rend [content] inchangé.
String _wrapInCasesIfNeeded(String content) {
  if (!_kRealLineBreak.hasMatch(content)) return content;
  if (_kEnvironment.hasMatch(content)) return content;
  // Le `trim` n'est appliqué QUE sur le chemin d'enveloppement : sans lui, les
  // blancs de bord d'une source déjà correcte seraient réécrits pour rien.
  return '\\begin{cases}\n${content.trim()}\n\\end{cases}';
}

/// Dé-échappe les commandes de [kZLatexCommands] : `\\frac` → `\frac`.
///
/// Une source qui ne contient aucune commande doublement échappée est rendue
/// **à l'identique**.
///
/// ⚠️ Limite assumée : `\\` suivi SANS blanc d'une commande de la liste est
/// traité comme un double échappement, jamais comme un saut de ligne suivi
/// d'une commande. C'est la lecture qui répare le corpus réel ; l'autre
/// s'écrit `\\ \frac`, avec le blanc, et traverse alors intacte.
String zUnescapeLatexCommands(String source) {
  var result = source;
  for (final String command in kZLatexCommands) {
    result = result.replaceAll('\\\\$command', '\\$command');
  }
  return result;
}

/// Normalisation d'une **source de formule** héritée : [zFixLatexLineBreaks]
/// puis [zUnescapeLatexCommands].
///
/// N'ajoute JAMAIS de délimiteur : une source de formule se rend nue.
String zNormalizeLegacyLatexSource(String source) =>
    zUnescapeLatexCommands(zFixLatexLineBreaks(source));

// ───────────────────────────── niveau TEXTE ─────────────────────────────

/// Régions d'un texte déjà délimitées comme formule, et donc à ne pas toucher.
final RegExp _kDollarRegion = RegExp(r'\$\$[\s\S]*?\$\$|\$[^$]+?\$');
final RegExp _kBracketRegion = RegExp(r'\\\[[\s\S]*?\\\]');
final RegExp _kParenRegion = RegExp(r'\\\([\s\S]*?\\\)');

/// Ligne de tableau Markdown — une cellule ne reçoit jamais de délimiteur
/// inséré (le `|` de structure serait pris dans la formule).
final RegExp _kTableRow = RegExp(r'^\s*\|[^\n]+\|[ \t]*$', multiLine: true);

/// Entoure de `$…$` le LaTeX **nu** d'un texte, hors des régions déjà
/// délimitées.
///
/// Sont repérées puis EXCLUES : `$…$`, `$$…$$`, `\[…\]`, `\(…\)` et les lignes
/// de tableau Markdown. Un texte dont toutes les formules sont déjà délimitées
/// est rendu **à l'identique** — aucun délimiteur n'est jamais doublé.
String zAutoDelimitLatex(String text) {
  final List<List<int>> delimited = <List<int>>[];
  for (final RegExp region in <RegExp>[
    _kDollarRegion,
    _kBracketRegion,
    _kParenRegion,
    _kTableRow,
  ]) {
    for (final RegExpMatch m in region.allMatches(text)) {
      delimited.add(<int>[m.start, m.end]);
    }
  }
  bool isDelimited(int position) {
    for (final List<int> region in delimited) {
      if (position >= region[0] && position < region[1]) return true;
    }
    return false;
  }

  final RegExp expression = RegExp(
    '\\\\(${kZLatexCommands.join('|')})'
    r'(\{[^}]*\}|_\{[^}]*\}|\^\{[^}]*\}|_[a-zA-Z0-9]|\^[a-zA-Z0-9]'
    r'|\\[a-zA-Z]+|\s)*'
    r'(\{[^}]*\})?',
  );

  final StringBuffer out = StringBuffer();
  var last = 0;
  for (final RegExpMatch m in expression.allMatches(text)) {
    if (isDelimited(m.start)) continue;
    final String before = m.start > 0 ? text[m.start - 1] : '';
    if (before == r'$' || before == '(' || before == '[') continue;
    final String after = m.end < text.length ? text[m.end] : '';
    if (after == r'$') continue;
    out.write(text.substring(last, m.start));
    final String raw = m.group(0)!;
    final String formula = raw.trim();
    if (formula.isEmpty) {
      out.write(raw);
    } else {
      // Les blancs de bord capturés par l'expression appartiennent au TEXTE,
      // pas à la formule : ils sont ré-émis HORS des délimiteurs. Les avaler
      // recollerait la formule au mot suivant.
      final int avant = raw.length - raw.trimLeft().length;
      final int apres = raw.length - raw.trimRight().length;
      out
        ..write(raw.substring(0, avant))
        ..write('\$$formula\$')
        ..write(raw.substring(raw.length - apres));
    }
    last = m.end;
  }
  out.write(text.substring(last));
  return out.toString();
}

/// Répare les sauts de ligne à l'INTÉRIEUR des blocs `$$…$$` et `\[…\]` d'un
/// texte, sans toucher au reste.
String _fixLineBreaksInBlocks(String text) {
  String fixBlock(String open, String close, String body) =>
      '$open${zFixLatexLineBreaks(body)}$close';
  var result = text.replaceAllMapped(
    RegExp(r'\$\$([\s\S]*?)\$\$'),
    (Match m) => fixBlock(r'$$', r'$$', m.group(1) ?? ''),
  );
  result = result.replaceAllMapped(
    RegExp(r'\\\[([\s\S]*?)\\\]'),
    (Match m) => fixBlock(r'\[', r'\]', m.group(1) ?? ''),
  );
  return result;
}

/// Normalisation complète d'un **texte** (typiquement du Markdown) contenant
/// des formules : réparation des sauts de ligne dans les blocs délimités,
/// dé-échappement des commandes ET des délimiteurs/accolades, puis
/// auto-délimitation du LaTeX resté nu.
///
/// À appliquer AVANT décodage, jamais à l'écriture. Un texte dont les formules
/// sont déjà correctes est rendu **à l'identique**.
String zNormalizeLatexInText(String text) {
  var result = _fixLineBreaksInBlocks(text);
  result = zUnescapeLatexCommands(result);
  // Délimiteurs et accolades doublement échappés — même origine que les
  // commandes, même réparation.
  for (final String token in const <String>['[', ']', '(', ')', '{', '}']) {
    result = result.replaceAll('\\\\$token', '\\$token');
  }
  return zAutoDelimitLatex(result);
}
