/// Gardes **AD-13** : cibles ≥ 48 dp, variantes DIRECTIONNELLES, `Semantics`
/// annoncées EXACTEMENT une fois.
///
/// Un menu contextuel est le cas où le RTL se voit : la garde le mesure sur
/// l'arbre rendu, pas seulement par grep.
library;

import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:zcrud_menu/zcrud_menu.dart';

import 'menu_test_support.dart';

const IconData _glyphe = Icons.circle;
const IconData _glypheEntree = Icons.star;

/// 🔴 **Défaut de harnais MESURÉ, et corrigé ici.** Un `Directionality` posé
/// SOUS `MaterialApp` ne s'applique PAS à la surface flottante du menu : celle-ci
/// est rendue dans l'`Overlay` du `Navigator`, donc AU-DESSUS du widget de test.
/// La première version de cette garde mesurait un glyphe à `dx = 400` contre un
/// libellé à `dx = 504` en « RTL » — elle testait en réalité un rendu LTR. Un
/// rouge mal diagnostiqué aurait fait « corriger » le code au lieu du test.
/// La direction est donc imposée là où `WidgetsApp` la lit vraiment : par les
/// `WidgetsLocalizations` de l'application.
class _RtlWidgetsLocalizations extends DefaultWidgetsLocalizations {
  const _RtlWidgetsLocalizations();

  @override
  TextDirection get textDirection => TextDirection.rtl;
}

class _RtlDelegate extends LocalizationsDelegate<WidgetsLocalizations> {
  const _RtlDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<WidgetsLocalizations> load(Locale locale) =>
      SynchronousFuture<WidgetsLocalizations>(const _RtlWidgetsLocalizations());

  @override
  bool shouldReload(_RtlDelegate old) => false;
}

Widget _hote(Widget child, TextDirection direction) => MaterialApp(
      localizationsDelegates: direction == TextDirection.rtl
          ? const <LocalizationsDelegate<dynamic>>[_RtlDelegate()]
          : null,
      home: Scaffold(body: Center(child: child)),
    );

ZActionMenu _menu() => ZActionMenu(
      trigger: const ZMenuTrigger(icon: _glyphe, semanticLabel: 'SL-TRIG'),
      entries: [
        ZMenuEntry(
          id: ZMenuEntryIds.open,
          label: 'LBL-A',
          icon: _glypheEntree,
          onSelected: () {},
        ),
        const ZMenuEntry(
          id: ZMenuEntryIds.edit,
          label: 'LBL-DESACTIVEE',
          disabledReason: 'MOTIF',
        ),
      ],
    );

void main() {
  group('grep négatif — variantes non directionnelles PROSCRITES', () {
    // ⚠️ Motifs cherchés sur le code COMMENTAIRES RETIRÉS : les dartdoc de ce
    // package citent nommément ces motifs pour expliquer pourquoi ils sont
    // interdits. Une garde qui lirait le fichier brut se dénoncerait elle-même.
    const interdits = <String>[
      'EdgeInsets.only(left',
      'EdgeInsets.only(right',
      'EdgeInsets.fromLTRB',
      'Alignment.centerLeft',
      'Alignment.centerRight',
      'Alignment.topLeft',
      'Alignment.topRight',
      'Alignment.bottomLeft',
      'Alignment.bottomRight',
      'TextAlign.left',
      'TextAlign.right',
      'Positioned(left',
      'Positioned(right',
      'BorderRadius.only(topLeft',
      'ListView(children',
    ];

    test('aucun motif directionnellement figé dans lib/', () {
      final code = libCode('zcrud_menu');
      final fautes = <String>[];
      for (final entry in code.entries) {
        for (final motif in interdits) {
          if (entry.value.contains(motif)) {
            fautes.add('${entry.key} : $motif');
          }
        }
      }
      expect(fautes, isEmpty, reason: fautes.join('\n'));
    });

    test('contrôle positif : la garde SAIT voir un motif interdit', () {
      // Sans ce contrôle, un `stripComments` trop gourmand (ou un `lib/` mal
      // localisé) rendrait la garde verte en ne lisant RIEN.
      const sonde = 'Padding(padding: EdgeInsets.only(left: 8))';
      expect(
        interdits.any(sonde.contains),
        isTrue,
        reason: 'le jeu de motifs ne détecte pas un cas trivial',
      );
    });
  });

  testWidgets('cibles ≥ 48 dp — déclencheur ET entrées (LTR)', (tester) async {
    await tester.pumpWidget(_hote(_menu(), TextDirection.ltr));
    final tailleTrigger = tester.getSize(find.byType(ZActionMenu));
    expect(tailleTrigger.width, greaterThanOrEqualTo(kZMenuMinTapTarget));
    expect(tailleTrigger.height, greaterThanOrEqualTo(kZMenuMinTapTarget));

    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    for (final label in ['LBL-A', 'LBL-DESACTIVEE']) {
      final taille = tester.getSize(
        find.ancestor(
          of: find.text(label),
          matching: find.byType(ZMenuEntryTile),
        ),
      );
      expect(
        taille.height,
        greaterThanOrEqualTo(kZMenuMinTapTarget),
        reason: 'entrée « $label » sous la cible minimale',
      );
    }
  });

  testWidgets('RTL — le glyphe se place au DÉBUT, donc à droite', (tester) async {
    await tester.pumpWidget(_hote(_menu(), TextDirection.rtl));
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    final dxIcone = tester.getCenter(find.byIcon(_glypheEntree)).dx;
    final dxLabel = tester.getCenter(find.text('LBL-A')).dx;
    expect(
      dxIcone,
      greaterThan(dxLabel),
      reason: 'en RTL le glyphe de début doit être à DROITE du libellé — '
          'un Row figé (ou un EdgeInsets.only(left:)) le laisserait à gauche',
    );
  });

  testWidgets('LTR — le glyphe se place au DÉBUT, donc à gauche', (tester) async {
    await tester.pumpWidget(_hote(_menu(), TextDirection.ltr));
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(find.byIcon(_glypheEntree)).dx,
      lessThan(tester.getCenter(find.text('LBL-A')).dx),
    );
  });

  testWidgets('Semantics : libellé annoncé EXACTEMENT une fois, motif en hint',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_hote(_menu(), TextDirection.ltr));
    await tester.tap(find.byIcon(_glyphe));
    await tester.pumpAndSettle();

    // ⚠️ `PopupMenuItem` pose une FRONTIÈRE de fusion : le nœud de la tuile est
    // le nœud FILS (celui qui est « merged up »), pas la frontière — laquelle
    // porte un `label` VIDE. Viser la frontière rendrait la garde ininterprétable.
    SemanticsData noeud(String label) => tester
        .getSemantics(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(ZMenuEntryTile),
          ),
        )
        // 🔴 `getSemanticsData()` rend les données FUSIONNÉES — exactement ce
        // qu'un lecteur d'écran énonce. C'est la seule lecture qui puisse voir
        // une double annonce : le nœud frontière porte un `label` VIDE, et le
        // nœud fils pris isolément ne montrerait pas la fusion.
        .getSemanticsData();

    // 🔴 Le défaut SU-8/AC20 était « Ouvrir\nOuvrir » : le libellé fusionné deux
    // fois. L'égalité EXACTE ci-dessous est ce qui mord — une double annonce
    // donnerait « LBL-A\nLBL-A ».
    final actif = noeud('LBL-A');
    expect(actif.label, 'LBL-A');
    expect(actif.flagsCollection.isEnabled, Tristate.isTrue);

    final inerte = noeud('LBL-DESACTIVEE');
    expect(inerte.label, 'LBL-DESACTIVEE');
    expect(inerte.hint, 'MOTIF', reason: 'motif de désactivation non annoncé');
    expect(
      inerte.flagsCollection.isEnabled,
      Tristate.isFalse,
      reason: 'entrée désactivée annoncée comme activée',
    );
    handle.dispose();
  });
}
