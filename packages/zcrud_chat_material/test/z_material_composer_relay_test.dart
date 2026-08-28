// Gardes du relais des créneaux de `ZChatMaterialComposer` vers
// `ZDefaultChatComposer` : inertie (aucun créneau ⇒ arbre Material intact),
// relais (chaque créneau fourni RENDU à la place de la pièce Material, les
// autres pièces conservant leur glyphe) et précédence (builder d'hôte >
// glyphe du satellite, envoi compris).
@TestOn('vm')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_chat/zcrud_chat.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart' show ZChatSuggestion;
import 'package:zcrud_chat_material/zcrud_chat_material.dart';

import 'support/z_chat_material_fakes.dart';

/// Le marqueur d'hôte : un widget que le satellite ne produit jamais.
class _HostMark extends StatelessWidget {
  const _HostMark(this.slot);
  final String slot;
  @override
  Widget build(BuildContext context) => Text('host:$slot');
}

/// Un créneau relayé : son nom, la façon de le poser, et la pièce Material
/// (glyphe) que son remplacement doit faire DISPARAÎTRE — `null` quand la
/// pièce par défaut n'a pas de glyphe Material propre.
class _Slot {
  const _Slot(this.name, this.apply, {this.defaultGlyph, this.defaultType});
  final String name;
  final ZChatMaterialComposer Function(
    ZChatComposerSlotBuilder b,
    _Ctx ctx,
  ) apply;
  final IconData? defaultGlyph;
  final Type? defaultType;
}

class _Ctx {
  _Ctx(this.controller, this.settings, this.attachments);
  final ZChatController controller;
  final ZChatSettingsController settings;
  final ZChatAttachmentController attachments;
}

/// L'assemblé « tout monté » : chaque pièce Material existe, donc chaque
/// remplacement est mesurable.
ZChatMaterialComposer _full(
  _Ctx ctx, {
  ZChatComposerSlotBuilder? plusBuilder,
  ZChatComposerSlotBuilder? thinkingBuilder,
  ZChatComposerSlotBuilder? webSearchBuilder,
  ZChatComposerSlotBuilder? toolsBuilder,
  ZChatComposerSlotBuilder? effortBuilder,
  ZChatComposerSlotBuilder? modelBuilder,
  ZChatComposerSlotBuilder? stopBuilder,
  ZChatComposerSlotBuilder? sendBuilder,
  ZChatComposerSlotBuilder? hintBuilder,
  ZChatComposerSlotBuilder? attachmentsBuilder,
  ZChatComposerSlotBuilder? dictationBuilder,
  ZChatComposerSlotBuilder? draftNoticeBuilder,
  ZChatComposerSlotBuilder? editingBannerBuilder,
  ZChatComposerSlotBuilder? progressBuilder,
  ZChatComposerSlotBuilder? suggestionsBuilder,
  ZChatAttachmentThumbnailBuilder? attachmentThumbnailBuilder,
  Widget? Function(BuildContext, ZChatSuggestion)? suggestionGlyphBuilder,
}) => ZChatMaterialComposer(
  controller: ctx.controller,
  settings: ctx.settings,
  hints: const <String>['un', 'deux'],
  pickers: <ZChatComposerPickerAction>[
    ZChatComposerPickerAction(label: 'fichier', onTap: () {}),
  ],
  onOpenTools: () {},
  modelOptions: const <ZChatModelOption>[
    ZChatModelOption(id: 'm1', label: 'M1'),
  ],
  modelActiveId: 'm1',
  onSelectModel: (_) {},
  onDictate: () {},
  attachments: ctx.attachments,
  plusBuilder: plusBuilder,
  thinkingBuilder: thinkingBuilder,
  webSearchBuilder: webSearchBuilder,
  toolsBuilder: toolsBuilder,
  effortBuilder: effortBuilder,
  modelBuilder: modelBuilder,
  stopBuilder: stopBuilder,
  sendBuilder: sendBuilder,
  hintBuilder: hintBuilder,
  attachmentsBuilder: attachmentsBuilder,
  dictationBuilder: dictationBuilder,
  draftNoticeBuilder: draftNoticeBuilder,
  editingBannerBuilder: editingBannerBuilder,
  progressBuilder: progressBuilder,
  suggestionsBuilder: suggestionsBuilder,
  attachmentThumbnailBuilder: attachmentThumbnailBuilder,
  suggestionGlyphBuilder: suggestionGlyphBuilder,
);

/// Les glyphes Material que l'assemblé « tout monté » pose sans créneau :
/// la mesure ABSOLUE de l'inertie, et le témoin « les autres restent ».
const Map<String, IconData> _materialGlyphs = <String, IconData>{
  'plus': Icons.add,
  'thinking': Icons.psychology,
  'webSearch': Icons.public,
  'tools': Icons.settings,
  'effort': Icons.auto_awesome, // partagé avec le placeholder animé
  'dictation': Icons.mic,
};

Finder _icon(IconData glyph) =>
    find.byWidgetPredicate((Widget w) => w is Icon && w.icon == glyph);

final List<_Slot> _slots = <_Slot>[
  _Slot('plus', (b, c) => _full(c, plusBuilder: b), defaultGlyph: Icons.add),
  _Slot('thinking', (b, c) => _full(c, thinkingBuilder: b),
      defaultGlyph: Icons.psychology),
  _Slot('webSearch', (b, c) => _full(c, webSearchBuilder: b),
      defaultGlyph: Icons.public),
  _Slot('tools', (b, c) => _full(c, toolsBuilder: b),
      defaultGlyph: Icons.settings, defaultType: ZChatMaterialToolsBadge),
  _Slot('effort', (b, c) => _full(c, effortBuilder: b),
      defaultType: ZChatComposerEffortSelector),
  _Slot('model', (b, c) => _full(c, modelBuilder: b),
      defaultType: ZChatComposerModelSelector),
  _Slot('stop', (b, c) => _full(c, stopBuilder: b),
      defaultType: ZChatComposerStopTarget),
  _Slot('send', (b, c) => _full(c, sendBuilder: b),
      defaultType: ZChatMaterialSendFab),
  _Slot('hint', (b, c) => _full(c, hintBuilder: b),
      defaultType: ZChatComposerAnimatedHint),
  _Slot('attachments', (b, c) => _full(c, attachmentsBuilder: b),
      defaultType: ZChatAttachmentStrip),
  _Slot('dictation', (b, c) => _full(c, dictationBuilder: b),
      defaultGlyph: Icons.mic),
  _Slot('draftNotice', (b, c) => _full(c, draftNoticeBuilder: b)),
  _Slot('editingBanner', (b, c) => _full(c, editingBannerBuilder: b),
      defaultType: ZChatComposerEditingBanner),
  _Slot('progress', (b, c) => _full(c, progressBuilder: b)),
  _Slot('suggestions', (b, c) => _full(c, suggestionsBuilder: b)),
];

void main() {
  late _Ctx ctx;
  setUp(() {
    final c = buildController();
    ctx = _Ctx(c.controller, ZChatSettingsController(),
        ZChatAttachmentController());
    addTearDown(ctx.controller.dispose);
    addTearDown(ctx.settings.dispose);
    addTearDown(ctx.attachments.dispose);
  });

  group('🔴 MCR — relais des créneaux du satellite', () {
    testWidgets('MCR-0 — inertie : aucun créneau ⇒ chaque pièce Material '
        'est rendue, aucun marqueur d\'hôte', (WidgetTester tester) async {
      await tester.pumpWidget(harness(_full(ctx)));
      for (final MapEntry<String, IconData> e in _materialGlyphs.entries) {
        expect(_icon(e.value), findsWidgets,
            reason: '🔴 glyphe Material « ${e.key} » absent sans créneau.');
      }
      expect(find.byType(ZChatMaterialSendFab), findsOneWidget);
      expect(find.byType(ZChatMaterialToolsBadge), findsOneWidget);
      expect(find.byType(ZChatComposerAnimatedHint), findsOneWidget);
      expect(find.byType(ZChatAttachmentStrip), findsOneWidget);
      expect(find.byType(_HostMark), findsNothing);
      // Le neutre ne reçoit AUCUN builder de l'hôte.
      final ZDefaultChatComposer neutral =
          tester.widget(find.byType(ZDefaultChatComposer));
      for (final ZChatComposerSlotBuilder? b in <ZChatComposerSlotBuilder?>[
        neutral.plusBuilder, neutral.thinkingBuilder, neutral.webSearchBuilder,
        neutral.toolsBuilder, neutral.effortBuilder, neutral.modelBuilder,
        neutral.stopBuilder, neutral.hintBuilder, neutral.attachmentsBuilder,
        neutral.dictationBuilder, neutral.draftNoticeBuilder,
        neutral.editingBannerBuilder, neutral.progressBuilder,
        neutral.suggestionsBuilder,
      ]) {
        expect(b, isNull, reason: '🔴 un créneau non fourni est relayé non nul.');
      }
      expect(neutral.attachmentThumbnailBuilder, isNull);
      expect(neutral.suggestionGlyphBuilder, isNull);
      // `sendBuilder` du neutre n'est pas nul : c'est le disque Material.
      expect(neutral.sendBuilder, isNotNull);
    });

    for (final _Slot slot in _slots) {
      testWidgets(
          'MCR-1 [${slot.name}] — le widget de l\'hôte est rendu à la place '
          'de la pièce Material, les autres glyphes restent',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          harness(slot.apply((_, _) => _HostMark(slot.name), ctx)),
        );
        expect(find.text('host:${slot.name}'), findsOneWidget,
            reason: '🔴 relais « ${slot.name} » : le builder de l\'hôte '
                'n\'atteint pas le neutre.');
        // La pièce Material remplacée a disparu — précédence de l'hôte.
        if (slot.defaultGlyph != null) {
          expect(_icon(slot.defaultGlyph!), findsNothing,
              reason: '🔴 précédence : le glyphe Material « ${slot.name} » '
                  'est rendu EN PLUS du builder de l\'hôte.');
        }
        if (slot.defaultType != null) {
          expect(find.byType(slot.defaultType!), findsNothing,
              reason: '🔴 précédence : la pièce ${slot.defaultType} est '
                  'rendue EN PLUS du builder de l\'hôte.');
        }
        // Les AUTRES pièces gardent leur glyphe Material.
        for (final MapEntry<String, IconData> e in _materialGlyphs.entries) {
          if (e.key == slot.name) continue;
          expect(_icon(e.value), findsWidgets,
              reason: '🔴 remplacer « ${slot.name} » a fait perdre le glyphe '
                  'Material de « ${e.key} ».');
        }
        if (slot.name != 'send') {
          expect(find.byType(ZChatMaterialSendFab), findsOneWidget,
              reason: '🔴 remplacer « ${slot.name} » a fait perdre le '
                  'disque d\'envoi.');
        }
        if (slot.name != 'tools') {
          expect(find.byType(ZChatMaterialToolsBadge), findsOneWidget,
              reason: '🔴 remplacer « ${slot.name} » a fait perdre le '
                  'badge d\'outils.');
        }
      });
    }

    testWidgets('MCR-2 — les deux coutures non-créneau '
        '(`attachmentThumbnailBuilder`, `suggestionGlyphBuilder`) arrivent '
        'au neutre par identité', (WidgetTester tester) async {
      Widget? thumb(BuildContext c, ZPendingAttachment a) => null;
      Widget? glyph(BuildContext c, ZChatSuggestion s) => null;
      await tester.pumpWidget(harness(_full(
        ctx,
        attachmentThumbnailBuilder: thumb,
        suggestionGlyphBuilder: glyph,
      )));
      final ZDefaultChatComposer neutral =
          tester.widget(find.byType(ZDefaultChatComposer));
      expect(identical(neutral.attachmentThumbnailBuilder, thumb), isTrue,
          reason: '🔴 `attachmentThumbnailBuilder` n\'est pas relayé.');
      expect(identical(neutral.suggestionGlyphBuilder, glyph), isTrue,
          reason: '🔴 `suggestionGlyphBuilder` n\'est pas relayé.');
    });
  });
}
