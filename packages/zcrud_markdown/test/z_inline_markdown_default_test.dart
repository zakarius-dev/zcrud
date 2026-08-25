// Le champ `inlineMarkdown` rend sa CARTE et sa BARRE HABILLÉE sans qu'un hôte
// ne déclare quoi que ce soit — et tout reste remplaçable par paramètre et par
// jeton.
//
// 🔴 POURQUOI CE FICHIER EXISTE (motif mesuré, pas une précaution) :
//
// 1. `themedBarBackground` était INERTE sur la surface qui compte. En une
//    rangée — le cas de TOUTE barre rendue dans le flux d'un formulaire — la
//    barre peint un `Container` opaque (`config.color ?? canvasColor`) AUX
//    MÊMES BORNES que la décoration posée autour d'elle, et APRÈS elle.
//    Mesuré avant correctif : basculer le drapeau changeait **0 pixel sur
//    1 823 500**. Les gardes qui citaient le drapeau montaient un
//    `SizedBox(10×10)` à la place de la vraie barre et assertaient l'existence
//    d'un `DecoratedBox` : elles seraient restées VERTES si le défaut
//    revenait. D'où la garde PIXEL ci-dessous — elle lit la couleur RENDUE de
//    la vraie barre, pas la présence d'un widget.
//
// 2. Deux applications hôtes écrivaient spontanément le MÊME bloc de
//    configuration pour obtenir ce rendu. Un défaut absent est un défaut que
//    chaque hôte réinvente.
//
// Méthode de la garde pixel : thème de sonde à trois couleurs DISCRIMINANTES
// (`canvasColor` ROUGE — ce que la barre peint elle-même ;
// `surfaceContainerLow` VERT — ce que le socle peint ; `outlineVariant` BLEU —
// le liseré), capture par `RenderRepaintBoundary.toImage()` et lecture directe
// des octets RGBA. Capture à `pixelRatio: 5` pour que la hauteur
// fractionnaire de la rangée (67,2 dp) tombe sur un ENTIER de pixels device et
// élimine tout artefact d'antialiasing de bord.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart'
    show CupertinoLocalizations, DefaultCupertinoLocalizations;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show QuillEditor, QuillSimpleToolbar, QuillSimpleToolbarConfig;
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_markdown/zcrud_markdown.dart';

// ── Couleurs de SONDE (jamais du rendu : elles n'existent que pour être
// distinguables à l'octet près). ────────────────────────────────────────────
const int _kRed = 0xff0000; // canvasColor — peint par la barre elle-même
const int _kGreen = 0x00ff00; // surfaceContainerLow — peint par le socle
const int _kBlue = 0x0000ff; // outlineVariant — le liseré bas
const Key _kProbe = Key('z-pixel-probe');

ThemeData _discriminatingTheme() {
  final ThemeData base = ThemeData(useMaterial3: true);
  return base.copyWith(
    canvasColor: const Color(0xFF000000 | _kRed),
    colorScheme: base.colorScheme.copyWith(
      surfaceContainerLow: const Color(0xFF000000 | _kGreen),
      outlineVariant: const Color(0xFF000000 | _kBlue),
    ),
  );
}

// `zcrud_markdown` ne dépend PAS de `flutter_localizations` (AD-1 : le socle
// n'impose aucune dépendance lourde). Monter une locale non anglaise sous
// `MaterialApp` déclenche donc l'avertissement « MaterialLocalizations
// delegate that supports the fr locale was not found », que le harnais promeut
// en échec. Ces deux relais déclarent supporter toute locale et servent les
// ressources anglaises intégrées : le test ne mesure QUE les libellés de
// zcrud, jamais ceux de Material.
class _AnyLocaleMaterial extends LocalizationsDelegate<MaterialLocalizations> {
  const _AnyLocaleMaterial();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      DefaultMaterialLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_AnyLocaleMaterial old) => false;
}

class _AnyLocaleCupertino extends LocalizationsDelegate<CupertinoLocalizations> {
  const _AnyLocaleCupertino();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.delegate.load(const Locale('en'));
  @override
  bool shouldReload(_AnyLocaleCupertino old) => false;
}

const List<LocalizationsDelegate<dynamic>> _l10nDelegates =
    <LocalizationsDelegate<dynamic>>[
  ZcrudLocalizationsDelegate(),
  _AnyLocaleMaterial(),
  _AnyLocaleCupertino(),
];

ZFieldSpec _inline({String name = 'note', String? label = 'Contenu'}) =>
    ZFieldSpec(
        name: name, type: EditionFieldType.inlineMarkdown, label: label);

ZFieldSpec _block({String name = 'body', String? label = 'Corps'}) =>
    ZFieldSpec(name: name, type: EditionFieldType.markdown, label: label);

/// Champ servi par le REGISTRE (seule voie de construction d'un hôte réel).
Widget _registryApp(
  ZFormController c,
  List<ZFieldSpec> fields, {
  ZWidgetRegistry? registry,
  ThemeData? theme,
  ZcrudTheme? zTheme,
  Locale? locale,
  List<LocalizationsDelegate<dynamic>> delegates =
      const <LocalizationsDelegate<dynamic>>[],
  double width = 800,
}) {
  final ZWidgetRegistry r = registry ?? (ZWidgetRegistry()..let());
  return MaterialApp(
    theme: theme,
    locale: locale,
    localizationsDelegates: delegates.isEmpty ? null : delegates,
    supportedLocales: const <Locale>[Locale('en'), Locale('fr')],
    home: Directionality(
      textDirection: TextDirection.ltr,
      child: ZcrudScope(
        widgetRegistry: r,
        theme: zTheme,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(
              key: _kProbe,
              child: SizedBox(
                width: width,
                child: DynamicEdition(controller: c, fields: fields),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

extension _RegisterOnce on ZWidgetRegistry {
  void let() => registerZMarkdownFields(this);
}

ZFormController _controller(Map<String, Object?> values) => ZFormController(
      initialValues: values,
      visibleFields: values.keys.toList(),
    );

Future<void> _settle(WidgetTester t) async {
  await t.pump(const Duration(milliseconds: 50));
  await t.pumpWidget(const SizedBox.shrink());
  await t.pump();
}

/// Couleur RGB effectivement PEINTE au point ([x], [y]) local à la sonde.
Future<int Function(int, int)> _pixels(WidgetTester t,
    {double ratio = 5}) async {
  final RenderRepaintBoundary b =
      t.renderObject(find.byKey(_kProbe)) as RenderRepaintBoundary;
  final ui.Image img = (await t.runAsync(() => b.toImage(pixelRatio: ratio)))!;
  final ByteData data = (await t.runAsync(() async =>
      (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!))!;
  final Uint8List px = data.buffer.asUint8List();
  final int w = img.width;
  return (int x, int y) {
    final int i = (y * w + x) * 4;
    return (px[i] << 16) | (px[i + 1] << 8) | px[i + 2];
  };
}

/// Les `DecoratedBox` ancêtres de [of] qui dessinent une bordure.
List<BoxDecoration> _framesAround(WidgetTester t, Finder of) => t
    .widgetList<DecoratedBox>(
        find.ancestor(of: of, matching: find.byType(DecoratedBox)))
    .map((DecoratedBox w) => w.decoration)
    .whereType<BoxDecoration>()
    .where((BoxDecoration d) => d.border != null)
    .toList();

/// Icônes RENDUES par la barre, **dans l'ordre de l'arbre** — la propriété
/// mesurée est l'ORDRE, jamais un nom de classe.
List<IconData?> _barIcons(WidgetTester t) => t
    .widgetList<Icon>(find.descendant(
        of: find.byType(QuillSimpleToolbar), matching: find.byType(Icon)))
    .map((Icon i) => i.icon)
    .toList();

QuillSimpleToolbarConfig _barConfig(WidgetTester t) =>
    t.widget<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar)).config;

void main() {
  group('DÉFAUT — la barre du champ compact est HABILLÉE, prouvé au PIXEL', () {
    testWidgets('sans aucune déclaration : le fond RENDU est celui du socle '
        '(`surfaceContainerLow`), pas celui que la barre peint elle-même '
        '(`canvasColor`) ; le liseré bas est RENDU', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()],
          theme: _discriminatingTheme(), width: 600));
      await t.pump(const Duration(milliseconds: 50));

      final Rect bar = t.getRect(find.byType(QuillSimpleToolbar));
      final Rect probe = t.getRect(find.byKey(_kProbe));
      final int Function(int, int) at = await _pixels(t);
      final int cx = (((bar.left + bar.right) / 2 - probe.left) * 5).round();
      final int top = ((bar.top - probe.top) * 5).round();
      final int bottom = ((bar.bottom - probe.top) * 5).round();

      // Bande de fond : au-dessus des boutons (ils sont centrés dans la
      // rangée), donc du fond PUR — aucune icône ne peut la polluer.
      for (final int dy in <int>[1, 5, 15]) {
        expect(at(cx, top + dy), _kGreen,
            reason: '🔴 y=${top + dy} : le fond RENDU doit être celui du '
                'socle. Un rouge ici signifie que la barre repeint par-dessus '
                'la décoration — le drapeau redevient inerte.');
      }
      // Liseré bas : les dernières rangées de pixels device de la barre.
      expect(at(cx, bottom - 1), _kBlue,
          reason: '🔴 le liseré bas doit être RENDU, pas recouvert');
      await _settle(t);
    });

    testWidgets('`themedBarBackground: false` posé par l\'hôte : le fond RENDU '
        'redevient celui de la barre — le drapeau agit dans les DEUX sens',
        (t) async {
      final ZWidgetRegistry r = ZWidgetRegistry();
      registerZMarkdownFields(r,
          toolbarConfig: ZRichTextToolbarConfig.inline
              .copyWith(themedBarBackground: false));
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()],
          registry: r, theme: _discriminatingTheme(), width: 600));
      await t.pump(const Duration(milliseconds: 50));

      final Rect bar = t.getRect(find.byType(QuillSimpleToolbar));
      final Rect probe = t.getRect(find.byKey(_kProbe));
      final int Function(int, int) at = await _pixels(t);
      final int cx = (((bar.left + bar.right) / 2 - probe.left) * 5).round();
      final int top = ((bar.top - probe.top) * 5).round();
      expect(at(cx, top + 5), _kRed,
          reason: 'drapeau éteint ⇒ la barre peint son propre fond');
      expect(at(cx, ((bar.bottom - probe.top) * 5).round() - 1), _kRed,
          reason: 'drapeau éteint ⇒ aucun liseré');
      await _settle(t);
    });
  });

  group('DÉFAUT — le chrome carte, mesuré par PROPRIÉTÉS', () {
    testWidgets('carte unique au rayon de référence, en-tête (icône + libellé) '
        'et pilule d\'action, SANS aucune déclaration hôte', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()]));
      await t.pump(const Duration(milliseconds: 50));

      final List<BoxDecoration> frames =
          _framesAround(t, find.byType(QuillEditor).first);
      expect(frames, hasLength(1),
          reason: 'un SEUL cadre : la carte — jamais carte + bordure de zone');
      expect(frames.single.borderRadius,
          const BorderRadius.all(ZMarkdownChromeReference.cardRadius));
      expect(frames.single.border, isA<Border>());
      expect((frames.single.border! as Border).top.width,
          ZMarkdownChromeReference.borderWidthEmpty,
          reason: 'champ vide ⇒ largeur de bordure « vide »');
      expect(frames.single.boxShadow, isNotEmpty,
          reason: 'la carte porte une ombre');
      expect(frames.single.boxShadow!.single.blurRadius,
          ZMarkdownChromeReference.shadowBlurRadius);
      expect(frames.single.boxShadow!.single.offset,
          ZMarkdownChromeReference.shadowOffset);

      expect(find.byIcon(Icons.article_rounded), findsOneWidget,
          reason: 'icône d\'en-tête par défaut');
      expect(find.text('Contenu'), findsOneWidget,
          reason: 'le libellé vit dans l\'en-tête, UNE seule fois');
      expect(find.byKey(const Key('z-markdown-chrome-action')), findsOneWidget,
          reason: 'pilule d\'action présente');
      await _settle(t);
    });

    testWidgets('la barre est À FLEUR de la carte : elle en occupe toute la '
        'largeur utile, sans encart latéral', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()], width: 600));
      await t.pump(const Duration(milliseconds: 50));

      final Rect bar = t.getRect(find.byType(QuillSimpleToolbar));
      final Rect toggle =
          t.getRect(find.byKey(const Key('z-markdown-fullscreen-toggle')));
      final Rect card = t.getRect(find
          .ancestor(
              of: find.byType(QuillEditor).first,
              matching: find.byType(DecoratedBox))
          .first);
      expect(bar.left, card.left,
          reason: '🔴 la barre doit partir du bord de la carte — un encart la '
              'ferait flotter au milieu, là où la référence la met à fleur');
      expect(toggle.right, closeTo(card.right, 0.5),
          reason: 'la rangée de barre occupe toute la largeur de la carte');
      // Le contenu SOUS la barre, lui, est bien rembourré.
      final Rect editor = t.getRect(find.byType(QuillEditor).first);
      expect(editor.left, greaterThan(card.left),
          reason: 'le texte, lui, ne colle pas au bord');
      await _settle(t);
    });

    testWidgets('les boutons rendus, leur ORDRE et leurs ABSENTS', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()], width: 1400));
      await t.pump(const Duration(milliseconds: 50));

      // ORDRE RENDU, groupe par groupe. `arrow_drop_down` est le sélecteur de
      // style de titre (menu déroulant, pas une icône de bouton) ; la dernière
      // flèche est l'indicateur de défilement de la barre.
      expect(
        _barIcons(t).take(16).toList(),
        <IconData>[
          Icons.undo_rounded,
          Icons.redo_rounded,
          Icons.format_bold_rounded,
          Icons.format_italic_rounded,
          Icons.format_underlined_rounded,
          Icons.code_rounded,
          Icons.arrow_drop_down,
          Icons.format_list_numbered_rounded,
          Icons.format_list_bulleted_rounded,
          Icons.checklist_rounded,
          Icons.format_indent_increase_rounded,
          Icons.format_indent_decrease_rounded,
          Icons.copy_rounded,
          Icons.paste_rounded,
          Icons.functions_rounded,
          Icons.table_chart_rounded,
        ],
        reason: '🔴 ordre RENDU de la barre compacte par défaut',
      );

      // ABSENTS assumés : un préset est une donnée, ce qu'il ne montre pas
      // compte autant que ce qu'il montre.
      final QuillSimpleToolbarConfig cfg = _barConfig(t);
      expect(cfg.showStrikeThrough, isFalse);
      expect(cfg.showColorButton, isFalse);
      expect(cfg.showBackgroundColorButton, isFalse);
      expect(cfg.showClearFormat, isFalse);
      expect(cfg.showAlignmentButtons, isFalse);
      expect(cfg.showQuote, isFalse);
      expect(cfg.showCodeBlock, isFalse);
      expect(cfg.showLink, isFalse);
      expect(cfg.showSearchButton, isFalse);
      expect(cfg.showSubscript, isFalse);
      expect(cfg.showSuperscript, isFalse);
      expect(cfg.showFontFamily, isFalse);
      expect(cfg.showFontSize, isFalse);
      expect(
          cfg.customButtons.where((b) => b.tooltip == 'Insérer une image'),
          isEmpty,
          reason: 'aucun bouton média dans la barre compacte');
      // GROUPEMENT : les séparateurs verticaux entre groupes sont rendus.
      expect(cfg.showDividers, isTrue);
      // Une seule rangée défilante : un champ de formulaire ne consomme
      // jamais la hauteur de l'écran.
      expect(cfg.multiRowsDisplay, isFalse);
      await _settle(t);
    });

    testWidgets('géométrie de barre : glyphe de 24 dp et hauteur de rangée '
        'dérivée de la cible de tap', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()], width: 1400));
      await t.pump(const Duration(milliseconds: 50));

      final QuillSimpleToolbarConfig cfg = _barConfig(t);
      expect(cfg.buttonOptions.base.iconSize, 20);
      expect(cfg.buttonOptions.base.iconButtonFactor, 1.2);
      // Le glyphe RENDU est le produit des deux — c'est la propriété qui
      // compte, pas les facteurs pris séparément.
      final Icon bold = t.widget<Icon>(find.descendant(
          of: find.byType(QuillSimpleToolbar),
          matching: find.byIcon(Icons.format_bold_rounded)));
      expect(bold.size, 24);
      // 67,2 dp = cible de tap minimale (48) × facteur de rangée de la barre
      // sous-jacente (1,4). La valeur est écrite en clair EXPRÈS : si l'un des
      // deux change en amont, cette garde rougit et le dit.
      expect(t.getRect(find.byType(QuillSimpleToolbar)).height, closeTo(67.2, 0.01),
          reason: 'hauteur de rangée dérivée de la cible de tap minimale');
      await _settle(t);
    });
  });

  group('PRIORITÉ — un paramètre ou un jeton PRIME sur le défaut', () {
    testWidgets('paramètre : `chrome` posé au registre remplace l\'icône '
        'd\'en-tête du défaut', (t) async {
      final ZWidgetRegistry r = ZWidgetRegistry();
      registerZMarkdownFields(r,
          chrome: const ZMarkdownFieldChrome(icon: Icons.science_rounded));
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(
          _registryApp(c, <ZFieldSpec>[_inline()], registry: r));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.science_rounded), findsOneWidget);
      expect(find.byIcon(Icons.article_rounded), findsNothing,
          reason: '🔴 le paramètre hôte doit REMPLACER le défaut, pas s\'y '
              'ajouter');
      await _settle(t);
    });

    testWidgets('jeton : `ZcrudTheme.surfaceColor` peint le corps de la carte '
        'du défaut', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      const Color token = Color(0xFF123456);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()],
          zTheme: const ZcrudTheme(surfaceColor: token)));
      await t.pump(const Duration(milliseconds: 50));
      final List<BoxDecoration> frames =
          _framesAround(t, find.byType(QuillEditor).first);
      expect(frames.single.color, token,
          reason: '🔴 le jeton injecté doit primer sur le rôle de thème');
      await _settle(t);
    });

    testWidgets('paramètre : `barHeight` posé par l\'hôte gouverne la hauteur '
        'RENDUE de la rangée', (t) async {
      final ZWidgetRegistry r = ZWidgetRegistry();
      registerZMarkdownFields(r,
          toolbarConfig: ZRichTextToolbarConfig.inline.copyWith(barHeight: 56));
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(
          _registryApp(c, <ZFieldSpec>[_inline()], registry: r, width: 1400));
      await t.pump(const Duration(milliseconds: 50));
      expect(t.getRect(find.byType(QuillSimpleToolbar)).height, 56,
          reason: '🔴 la hauteur demandée doit être la hauteur RENDUE — sinon '
              'le réglage est un drapeau inerte de plus');
      await _settle(t);
    });

    testWidgets('paramètre : couleurs de glyphe posées par l\'hôte atteignent '
        'les boutons', (t) async {
      const Color off = Color(0xFF112233);
      const Color on = Color(0xFF445566);
      final ZWidgetRegistry r = ZWidgetRegistry();
      registerZMarkdownFields(r,
          toolbarConfig: ZRichTextToolbarConfig.inline
              .copyWith(iconColor: off, selectedIconColor: on));
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(
          _registryApp(c, <ZFieldSpec>[_inline()], registry: r, width: 1400));
      await t.pump(const Duration(milliseconds: 50));
      final QuillSimpleToolbarConfig cfg = _barConfig(t);
      // 🔴 Les couleurs DOIVENT transiter par les options de BASE : la
      // propriété `iconTheme` de la config globale n'atteint que les boutons
      // d'embed — l'y poser produirait un réglage inerte.
      expect(cfg.buttonOptions.base.iconTheme?.iconButtonUnselectedData?.color,
          off);
      expect(
          cfg.buttonOptions.base.iconTheme?.iconButtonSelectedData?.color, on);
      await _settle(t);
    });
  });

  group('NON-RÉGRESSION — mode bloc et plein écran', () {
    testWidgets('mode bloc : aucune carte, aucune barre, affordance basse '
        'conservée', (t) async {
      final ZFormController c = _controller(<String, Object?>{'body': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_block()]));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byType(QuillSimpleToolbar), findsNothing,
          reason: 'le mode bloc n\'édite pas en place');
      expect(find.byKey(const Key('z-markdown-block-edit')), findsOneWidget,
          reason: 'affordance basse conservée (aucune carte pour la porter)');
      expect(find.byIcon(Icons.article_rounded), findsNothing,
          reason: '🔴 le défaut de carte NE DOIT PAS déborder sur le mode bloc');
      expect(find.byKey(const Key('z-markdown-chrome-action')), findsNothing);
      await _settle(t);
    });

    testWidgets('un AUTRE champ compact (même widget, même mode) ne reçoit NI '
        'carte NI barre compacte : la portée du défaut tient au TYPE', (t) async {
      // 🔴 Mesuré : le même widget compact sert des surfaces qui ne sont pas
      // des formulaires — l'éditeur de contenu d'un nœud dans un panneau
      // construit un `ZMarkdownField.fromContext(mode: inline)` avec un champ
      // de type `markdown`. Une carte à en-tête et pilule y serait intrusive.
      // Sans cette garde, élargir la portée du défaut au seul MODE passerait
      // inaperçu.
      Object? written;
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            child: Scaffold(
              body: ZMarkdownField.fromContext(
                key: const ValueKey<String>('autre'),
                ctx: ZFieldWidgetContext(
                  field: const ZFieldSpec(
                      name: 'autre',
                      type: EditionFieldType.markdown,
                      label: 'Contenu'),
                  value: null,
                  onChanged: (Object? v) => written = v,
                ),
                mode: ZMarkdownFieldMode.inline,
              ),
            ),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.article_rounded), findsNothing,
          reason: '🔴 la carte NE DOIT PAS déborder sur les surfaces qui ne '
              'sont pas des formulaires');
      expect(find.byKey(const Key('z-markdown-chrome-action')), findsNothing);
      expect(_barConfig(t).showUndo, isFalse,
          reason: 'sa barre garde le préset compact minimal, pas celui du '
              'champ de formulaire');
      expect(written, isNull);
      await _settle(t);
    });

    testWidgets('voie `controller` : aucune carte — le chrome y reste un '
        'paramètre', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(MaterialApp(
        home: ZcrudScope(
          child: Scaffold(
            body: ZMarkdownField(
              key: const ValueKey<String>('note'),
              controller: c,
              field: _inline(),
            ),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.byIcon(Icons.article_rounded), findsNothing);
      expect(find.byKey(const Key('z-markdown-chrome-action')), findsNothing);
      // …et sa barre reste le préset complet.
      expect(_barConfig(t).showLink, isTrue,
          reason: 'la voie `controller` garde le préset complet');
      await _settle(t);
    });

    testWidgets('plein écran ouvert depuis le champ compact : préset COMPLET, '
        'multi-rangées — le préset compact ne déborde pas', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()], width: 1400));
      await t.pump(const Duration(milliseconds: 50));
      await t.tap(find.byKey(const Key('z-markdown-fullscreen-toggle')));
      await t.pumpAndSettle();
      expect(find.byType(ZRichTextFullscreenDialog), findsOneWidget);
      final QuillSimpleToolbarConfig dialogBar = t
          .widgetList<QuillSimpleToolbar>(find.byType(QuillSimpleToolbar))
          .last
          .config;
      expect(dialogBar.showLink, isTrue, reason: 'préset complet en plein écran');
      expect(dialogBar.showColorButton, isTrue);
      expect(dialogBar.multiRowsDisplay, isTrue,
          reason: 'la place existe en plein écran');
      await t.tap(find.byKey(const Key('z-richtext-dialog-cancel')));
      await t.pumpAndSettle();
      await _settle(t);
    });
  });

  group('DÉFAUT — les écritures ne sont PAS différées', () {
    testWidgets('la frappe écrit la tranche IMMÉDIATEMENT, sans perte de focus '
        'ni appui sur la pilule', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(c, <ZFieldSpec>[_inline()]));
      await t.pump(const Duration(milliseconds: 50));

      t.widget<QuillEditor>(find.byType(QuillEditor).first)
          .focusNode
          .requestFocus();
      await t.pump();
      t
          .widget<QuillEditor>(find.byType(QuillEditor).first)
          .controller
          .replaceText(0, 0, 'X', const TextSelection.collapsed(offset: 1));
      await t.pump();

      // 🔴 Le différé a été mesuré DESTRUCTEUR chez un hôte : un utilisateur
      // qui rédige puis soumet directement — sans que le champ perde le focus
      // — perd son texte, sans message. Le défaut ne l'active donc pas.
      expect(c.valueOf('note'), isA<List<Object?>>(),
          reason: '🔴 la tranche doit être écrite DÈS la frappe : le défaut '
              'ne diffère pas les écritures');
      expect((c.valueOf('note')! as List).isNotEmpty, isTrue);
      await _settle(t);
    });
  });

  group('DÉFAUT — les libellés viennent du système l10n, pas du paquet', () {
    testWidgets('locale fr (delegate monté) : la pilule et l\'agrandissement '
        'parlent français', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(
        c,
        <ZFieldSpec>[_inline()],
        locale: const Locale('fr'),
        delegates: _l10nDelegates,
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Valider'), findsOneWidget,
          reason: '🔴 la table `fr` doit être ATTEINTE — un libellé codé dans '
              'le paquet rendrait la même chose et masquerait le défaut');
      expect(
          t
              .widget<IconButton>(
                  find.byKey(const Key('z-markdown-fullscreen-toggle')))
              .tooltip,
          'Agrandir');
      await _settle(t);
    });

    testWidgets('locale en : le MÊME champ parle anglais — la preuve que le '
        'libellé n\'est pas figé', (t) async {
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(_registryApp(
        c,
        <ZFieldSpec>[_inline()],
        locale: const Locale('en'),
        delegates: _l10nDelegates,
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Confirm'), findsOneWidget);
      expect(find.text('Valider'), findsNothing);
      await _settle(t);
    });

    testWidgets('surcharge par `ZcrudScope(labels:)` : l\'hôte a le dernier '
        'mot sur le libellé', (t) async {
      final ZWidgetRegistry r = ZWidgetRegistry()..let();
      final ZFormController c = _controller(<String, Object?>{'note': null});
      addTearDown(c.dispose);
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: ZcrudScope(
            widgetRegistry: r,
            labels: ZcrudLabels(<String, String>{
              'z.markdown.commit': 'Enregistrer la note',
            }),
            child: Scaffold(
              body: DynamicEdition(
                  controller: c, fields: <ZFieldSpec>[_inline()]),
            ),
          ),
        ),
      ));
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Enregistrer la note'), findsOneWidget);
      await _settle(t);
    });
  });
}
