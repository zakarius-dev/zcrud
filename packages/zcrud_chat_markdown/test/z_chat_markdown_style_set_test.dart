// CR-IFFD-85 ③ — le jeu de styles déclaré par l'hôte atteint RÉELLEMENT le
// rendu, axe par axe.
//
// 🔴 Ces gardes ne mesurent PAS « le paramètre a été passé au lecteur ». Un
// relais décoratif (paramètre transmis mais ignoré en aval) resterait vert sous
// une telle assertion. Elles mesurent la COULEUR EFFECTIVE des fragments
// réellement peints, résolue par héritage : dans Quill, un style de BLOC (un
// titre) vit sur le `TextSpan` racine du `RichText`, tandis qu'un style INLINE
// (gras, italique) vit sur le span enfant. Une sonde qui ne regarderait que
// l'un des deux niveaux manquerait la moitié des axes — et c'est précisément la
// moitié dont l'hôte se plaignait (titre et intertitre rendus en gris).
//
// Constat d'origine, mesuré côté hôte au pixel : titre `#B8B8B8`, intertitre
// `#B8B8B8`. Le contenu était du Markdown NU : aucune couleur dans la donnée,
// tout le rendu coloré vient de la feuille de style — qu'aucun canal ne
// permettait de déclarer depuis un hôte.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_chat_markdown/zcrud_chat_markdown.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

/// Un fragment peint avec son style EFFECTIF (héritage résolu).
class _Painted {
  const _Painted(this.text, this.style);

  final String text;
  final TextStyle? style;

  Color? get color => style?.color;

  double? get size => style?.fontSize;

  @override
  String toString() =>
      '"$text"(c=${color?.toARGB32().toRadixString(16)},s=$size,'
      'w=${style?.fontWeight},i=${style?.fontStyle})';
}

/// Tous les fragments peints, style effectif résolu du span racine vers les
/// enfants (`merge` — exactement ce que fait le moteur de rendu de Flutter).
List<_Painted> _painted(WidgetTester tester) {
  final List<_Painted> out = <_Painted>[];
  for (final RichText r in tester.widgetList<RichText>(find.byType(RichText))) {
    void visit(InlineSpan span, TextStyle? inherited) {
      if (span is! TextSpan) return;
      final TextStyle? effective = inherited == null
          ? span.style
          : (span.style == null ? inherited : inherited.merge(span.style));
      final String? t = span.text;
      if (t != null && t.isNotEmpty) out.add(_Painted(t, effective));
      for (final InlineSpan c in span.children ?? const <InlineSpan>[]) {
        visit(c, effective);
      }
    }

    visit(r.text, null);
  }
  return out;
}

_Painted _span(WidgetTester tester, String text) => _painted(tester).firstWhere(
  (_Painted p) => p.text.contains(text),
  orElse: () => throw StateError(
    'fragment « $text » absent du rendu. Peint : ${_painted(tester)}',
  ),
);

/// L'échelle réellement appliquée au texte peint, mesurée par son EFFET : ce
/// que devient une taille de 16 dp une fois passée par le `TextScaler` de
/// chaque `RichText`.
///
/// On mesure l'effet, et pas l'identité de l'objet : l'échelle ambiante d'un
/// banc est un `SystemTextScaler`, une échelle déclarée un scaler linéaire —
/// deux types différents pour un même rendu quand le facteur vaut 1.
Set<double> _scaledFrom16(WidgetTester tester) => tester
    .widgetList<RichText>(find.byType(RichText))
    .map((RichText r) => r.textScaler.scale(16))
    .toSet();

// Un message de la forme mesurée côté hôte : un intertitre `h2`, un gras et un
// italique — trois axes que `textStyle` (global) ne sait pas distinguer.
const String kMessage = '## Intertitre\n\nUn **gras** et un *ital*.';

// Thème FIXE : les comptes absolus ci-dessous ne veulent rien dire sous un
// thème qui varie d'une exécution à l'autre.
final ThemeData kTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
);

// La couleur que le thème ci-dessus donne à TOUT le texte quand rien n'est
// déclaré — mesurée, pas supposée. C'est le « gris » du constat d'origine,
// transposé au thème clair du banc.
const Color kUndeclared = Color(0xFF1D1B20);

const Color kTeal = Color(0xFF00796B);
const Color kPink = Color(0xFFE91E63);
const Color kBlue = Color(0xFF2196F3);

Future<void> _mount(
  WidgetTester tester, {
  ZRichTextStyleSet? styleSet,
  double? textScaleFactor,
  TextStyle? textStyle,
  String markdown = kMessage,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: kTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ZChatRendererScope(
            renderer: ZChatMarkdownRenderer(
              styleSet: styleSet,
              textScaleFactor: textScaleFactor,
              textStyle: textStyle,
            ),
            child: ZChatBlockView(
              request: ZChatBlockRenderRequest(
                block: ZTextBlock(text: markdown),
                message: ZChatMessage(
                  id: 'm1',
                  conversationId: 'c1',
                  role: ZChatRole.assistant,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('🔴 CR-IFFD-85 ③ — le jeu de styles ATTEINT le rendu, axe par axe', () {
    testWidgets(
      'GARDE PRINCIPALE : h2, gras et italique portent CHACUN leur couleur',
      (WidgetTester tester) async {
        await _mount(
          tester,
          styleSet: const ZRichTextStyleSet(
            h2: TextStyle(color: kTeal),
            bold: TextStyle(color: kPink),
            italic: TextStyle(color: kBlue),
          ),
        );

        // Trois axes, trois couleurs DISTINCTES. Un relais qui n'aboutirait
        // pas laisserait les trois à `kUndeclared` — donc identiques.
        expect(
          _span(tester, 'Intertitre').color,
          kTeal,
          reason:
              '🔴 le slot `h2` du jeu de styles n\'atteint pas le rendu : '
              'peint = ${_painted(tester)}',
        );
        expect(
          _span(tester, 'gras').color,
          kPink,
          reason:
              '🔴 le slot `bold` du jeu de styles n\'atteint pas le rendu : '
              'peint = ${_painted(tester)}',
        );
        expect(
          _span(tester, 'ital').color,
          kBlue,
          reason:
              '🔴 le slot `italic` du jeu de styles n\'atteint pas le rendu : '
              'peint = ${_painted(tester)}',
        );

        // Et les trois diffèrent entre elles : c'est ce qu'un style GLOBAL
        // (`textStyle`) est structurellement incapable de produire.
        expect(
          <Color?>{
            _span(tester, 'Intertitre').color,
            _span(tester, 'gras').color,
            _span(tester, 'ital').color,
          },
          hasLength(3),
          reason:
              'les trois axes peignent la même couleur : le rendu ne les '
              'distingue pas.',
        );
      },
    );

    testWidgets('les axes NON déclarés restent à leur couleur du thème', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        styleSet: const ZRichTextStyleSet(h2: TextStyle(color: kTeal)),
      );
      expect(_span(tester, 'Intertitre').color, kTeal);
      // Le corps de texte n'était pas visé : il ne bouge pas.
      expect(
        _span(tester, 'Un ').color,
        kUndeclared,
        reason:
            'un slot non déclaré a changé la couleur du corps : le jeu de '
            'styles déborde de ses axes.',
      );
    });
  });

  group('🔴 CR-IFFD-85 ③ — le facteur d\'échelle agit sur le rendu', () {
    testWidgets('le facteur déclaré remplace l\'échelle ambiante', (
      WidgetTester tester,
    ) async {
      await _mount(tester, textScaleFactor: 0.9);
      expect(
        _scaledFrom16(tester),
        <double>{16 * 0.9},
        reason:
            '🔴 le facteur d\'échelle déclaré n\'atteint pas le texte peint. '
            'Échelles mesurées (16 dp ⇒ ?) : ${_scaledFrom16(tester)}',
      );
    });

    testWidgets('le facteur est ABSOLU : il ne se multiplie pas à l\'ambiant', (
      WidgetTester tester,
    ) async {
      // Échelle ambiante x2 imposée au-dessus du rendu. Le contrat annoncé en
      // dartdoc est un REMPLACEMENT : la mesure doit rendre 0.9, jamais 1.8.
      await tester.pumpWidget(
        MaterialApp(
          theme: kTheme,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ZChatRendererScope(
                  renderer: const ZChatMarkdownRenderer(textScaleFactor: 0.9),
                  child: ZChatBlockView(
                    request: ZChatBlockRenderRequest(
                      block: const ZTextBlock(text: kMessage),
                      message: ZChatMessage(
                        id: 'm1',
                        conversationId: 'c1',
                        role: ZChatRole.assistant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _scaledFrom16(tester),
        <double>{16 * 0.9},
        reason:
            'le facteur s\'est composé avec l\'ambiant au lieu de le '
            'remplacer (on lirait 28.8) — la dartdoc promet l\'inverse. '
            'Mesuré : ${_scaledFrom16(tester)}',
      );
    });
  });

  group('🔴 CR-IFFD-85 ③ — CONTRE-TÉMOIN : sans déclaration, RIEN ne bouge', () {
    testWidgets('comptes ABSOLUS de l\'arbre et des styles peints', (
      WidgetTester tester,
    ) async {
      await _mount(tester);
      final List<_Painted> painted = _painted(tester);

      // Comptes ABSOLUS (pas une comparaison à un second montage) : ce sont
      // les nombres mesurés AVANT l'ajout des deux paramètres.
      expect(
        tester.widgetList<RichText>(find.byType(RichText)).length,
        2,
        reason: 'l\'arbre peint a changé de forme sans qu\'on ait rien '
            'déclaré : $painted',
      );
      expect(painted, hasLength(6));
      expect(
        painted.map((_Painted p) => p.text).join(),
        'IntertitreUn gras et un ital.',
      );

      // Toutes les couleurs à la valeur du thème — c'est exactement le
      // « tout gris » d'avant, et il doit être PRÉSERVÉ tant que rien n'est
      // déclaré (FR-26 : le socle n'invente aucune couleur).
      expect(
        painted.map((_Painted p) => p.color).toSet(),
        <Color>{kUndeclared},
        reason: 'une couleur est apparue sans déclaration de l\'hôte : '
            '$painted',
      );

      // Tailles absolues : le titre est déjà distingué par le thème.
      expect(_span(tester, 'Intertitre').size, 28.0);
      expect(_span(tester, 'gras').size, 16.0);

      // Et aucune échelle n'est posée : `null` ⇒ échelle ambiante intacte,
      // qui ne touche pas aux tailles sur ce banc.
      expect(_scaledFrom16(tester), <double>{16.0});
    });
  });

  group('🔴 CR-IFFD-85 ③ — PRIORITÉ : `styleSet` l\'emporte par axe', () {
    testWidgets(
      'sur un axe COUVERT, le jeu de styles gagne contre `textStyle`',
      (WidgetTester tester) async {
        await _mount(
          tester,
          textStyle: const TextStyle(color: kPink),
          styleSet: const ZRichTextStyleSet(h2: TextStyle(color: kTeal)),
        );
        expect(
          _span(tester, 'Intertitre').color,
          kTeal,
          reason: '🔴 `textStyle` a écrasé le slot `h2` : la dartdoc promet '
              'que le jeu de styles l\'emporte sur les axes qu\'il couvre. '
              'Peint : ${_painted(tester)}',
        );
      },
    );

    testWidgets(
      'sur un axe NON couvert, `textStyle` reste seul en vigueur',
      (WidgetTester tester) async {
        await _mount(
          tester,
          textStyle: const TextStyle(color: kPink),
          styleSet: const ZRichTextStyleSet(h2: TextStyle(color: kTeal)),
        );
        expect(
          _span(tester, 'Un ').color,
          kPink,
          reason: '🔴 le corps de texte n\'est plus piloté par `textStyle` '
              'alors qu\'aucun slot ne le vise. Peint : ${_painted(tester)}',
        );
      },
    );
  });

  group('🔴 CR-IFFD-85 ③ — AD-10 : un jeu PARTIEL ne casse rien', () {
    testWidgets('un seul axe déclaré : les autres gardent le rendu actuel', (
      WidgetTester tester,
    ) async {
      await _mount(
        tester,
        styleSet: const ZRichTextStyleSet(bold: TextStyle(color: kPink)),
      );
      expect(_span(tester, 'gras').color, kPink);
      // Les axes non couverts sont à la valeur ABSOLUE du contre-témoin.
      expect(_span(tester, 'Intertitre').color, kUndeclared);
      expect(_span(tester, 'Intertitre').size, 28.0);
      expect(_span(tester, 'ital').color, kUndeclared);
      expect(_span(tester, 'ital').style?.fontStyle, FontStyle.italic);
    });

    testWidgets('un jeu VIDE est indiscernable de l\'absence de jeu', (
      WidgetTester tester,
    ) async {
      await _mount(tester, styleSet: const ZRichTextStyleSet());
      expect(_painted(tester), hasLength(6));
      expect(
        _painted(tester).map((_Painted p) => p.color).toSet(),
        <Color>{kUndeclared},
      );
      expect(_scaledFrom16(tester), <double>{16.0});
    });

    testWidgets('un jeu déclaré sur un Markdown DÉGRADÉ ne lève pas', (
      WidgetTester tester,
    ) async {
      // Motif tronqué comme pendant un flux : le jeu de styles ne doit pas
      // transformer une dégradation tolérée en exception.
      await _mount(
        tester,
        markdown: '## Titre\n\n**gras non fermé et *ital',
        styleSet: const ZRichTextStyleSet(
          h2: TextStyle(color: kTeal),
          bold: TextStyle(color: kPink),
          italic: TextStyle(color: kBlue),
        ),
        textScaleFactor: 1.4,
      );
      expect(tester.takeException(), isNull);
      expect(_span(tester, 'Titre').color, kTeal);
    });
  });
}
