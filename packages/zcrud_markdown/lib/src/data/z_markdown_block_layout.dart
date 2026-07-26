/// Passes de **mise en page de bloc** appliquées au Markdown émis par
/// `DeltaToMarkdown` — réponses à CR-LEX-49 et CR-LEX-51 §B.
///
/// Pourquoi ICI et pas dans la lib de conversion : les deux défauts vivent dans
/// `markdown_quill`, à des endroits que sa surface publique **n'expose pas**.
///
/// - CR-LEX-49 : `DeltaToMarkdown.visitLine` écrit DEUX `writeln()` pour une
///   ligne sans attribut de bloc (donc une ligne vide, frontière de bloc) mais
///   un SEUL pour une ligne à attribut de scope `block` — c'est le cas du
///   blockquote. Le cas `list` dispose d'une clause de sortie de bloc explicite ;
///   **le blockquote n'a aucun équivalent**. Le seul point d'injection offert,
///   `visitLineHandleNewLine`, ne reçoit QUE le `Style` de la ligne : il ne peut
///   pas reproduire la clause `list` (qui interroge `line.nextLine`). L'utiliser
///   échangerait donc un défaut de frontière contre un autre.
/// - CR-LEX-51 §B : la numérotation vient de `_prefixNumber`, fonction privée
///   sans hameçon, qui compte les frères précédents et repart donc TOUJOURS de 1.
///
/// Ces passes sont **conservatrices par construction** : chacune rend la chaîne
/// d'entrée À L'IDENTIQUE quand elle n'a rien à corriger.
library;

/// Ouvre/ferme un bloc clôturé (``` ou ~~~, indentation ≤ 3).
final RegExp _kFence = RegExp(r'^ {0,3}(`{3,}|~{3,})');

/// Ligne de citation (le `>` peut être précédé de 3 espaces au plus).
final RegExp _kQuoteLine = RegExp(r'^ {0,3}>');

/// Item de liste ordonnée, tel que `DeltaToMarkdown` l'écrit (`1. `).
final RegExp _kOrderedItem = RegExp(r'^(\s*)(\d+)([.)])(\s)');

/// Insère la **ligne vide de sortie de bloc** après une citation (CR-LEX-49).
///
/// Sans elle, `> …\n` est immédiatement suivi du paragraphe, et CommonMark
/// applique la *lazy continuation* : le paragraphe est AVALÉ DANS la citation au
/// re-décodage — le commentaire de l'auteur devenait du texte cité, et la
/// conversion n'était pas idempotente (le blockquote s'ACQUÉRAIT au cycle 2).
///
/// La règle est volontairement large (toute ligne non vide qui n'est pas une
/// citation ouvre un nouveau bloc) : elle est **idempotente**, et elle rend
/// EXPLICITE une frontière que le lecteur devait deviner. Le contenu des blocs
/// clôturés est laissé intact — un bloc de code peut contenir `> `.
String zSeparateBlocksAfterQuote(String markdown) {
  if (!markdown.contains('>')) return markdown;
  final List<String> lines = markdown.split('\n');
  final out = <String>[];
  var inFence = false;
  for (var i = 0; i < lines.length; i++) {
    final String line = lines[i];
    out.add(line);
    if (_kFence.hasMatch(line)) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (!_kQuoteLine.hasMatch(line)) continue;
    if (i + 1 >= lines.length) continue;
    final String next = lines[i + 1];
    if (next.trim().isEmpty) continue;
    if (_kQuoteLine.hasMatch(next)) continue;
    out.add('');
  }
  return out.join('\n');
}

/// Une ligne logique du Delta et ses attributs de BLOC (portés par le `\n`
/// terminal, convention Quill).
class _BlockLine {
  _BlockLine(this.attrs);

  final Map<String, dynamic> attrs;

  String? get list {
    final Object? value = attrs['list'];
    return value is String ? value : null;
  }

  int get indent {
    final Object? value = attrs['indent'];
    return value is int ? value : 0;
  }

  int? get start {
    final Object? value = attrs['start'];
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}

/// Projette des ops neutres en lignes logiques.
List<_BlockLine> _blockLines(List<Map<String, dynamic>> ops) {
  final out = <_BlockLine>[];
  for (final op in ops) {
    final Object? insert = op['insert'];
    if (insert is! String) continue;
    final Map<String, dynamic> attrs = op['attributes'] is Map
        ? Map<String, dynamic>.from(op['attributes'] as Map)
        : <String, dynamic>{};
    for (var i = 0; i < insert.length; i++) {
      if (insert[i] == '\n') out.add(_BlockLine(attrs));
    }
  }
  return out;
}

/// Restitue le **numéro de départ** d'une liste ordonnée (CR-LEX-51 §B).
///
/// `_prefixNumber` de `DeltaToMarkdown` compte les frères précédents : une liste
/// reprise en cours de séquence (« 3. … 4. … ») est renumérotée à partir de 1,
/// ce qui **change la référence citée** dans un texte juridique.
///
/// Trois garde-fous, tous mesurables :
/// 1. **Identité** si aucune ligne ne porte de `start` autre que 1 — la passe est
///    alors un no-op strict, donc aucun corpus existant ne peut bouger ;
/// 2. **abandon** si une liste ordonnée est INDENTÉE : la correspondance
///    « run Delta ↔ run Markdown » n'est plus triviale pour une liste imbriquée,
///    et renuméroter de travers serait pire que ne rien faire ;
/// 3. **abandon** si le nombre d'items ordonnés du Markdown ne coïncide pas avec
///    celui du Delta — auto-vérification, jamais une correspondance supposée.
String zRestoreOrderedListStart(
  String markdown,
  List<Map<String, dynamic>> ops,
) {
  final List<_BlockLine> lines = _blockLines(ops);
  final expected = <int>[];
  var next = 1;
  var previousWasOrdered = false;
  var sawExplicitStart = false;
  for (final line in lines) {
    if (line.list != 'ordered') {
      previousWasOrdered = false;
      continue;
    }
    if (line.indent != 0) return markdown; // garde-fou 2
    if (!previousWasOrdered) {
      final int? start = line.start;
      next = start ?? 1;
      if (start != null && start != 1) sawExplicitStart = true;
    }
    expected.add(next);
    next++;
    previousWasOrdered = true;
  }
  if (!sawExplicitStart) return markdown; // garde-fou 1 : identité

  final List<String> outLines = markdown.split('\n');
  final matches = <int>[];
  var inFence = false;
  for (var i = 0; i < outLines.length; i++) {
    if (_kFence.hasMatch(outLines[i])) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;
    if (_kOrderedItem.hasMatch(outLines[i])) matches.add(i);
  }
  if (matches.length != expected.length) return markdown; // garde-fou 3

  for (var k = 0; k < matches.length; k++) {
    final int index = matches[k];
    outLines[index] = outLines[index].replaceFirstMapped(
      _kOrderedItem,
      (m) => '${m[1]}${expected[k]}${m[3]}${m[4]}',
    );
  }
  return outLines.join('\n');
}
