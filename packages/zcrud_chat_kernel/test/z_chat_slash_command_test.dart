// Vocabulaire des COMMANDES : la commande déclarée, son catalogue, et
// l'invocation remise à l'hôte. Quatre propriétés, et rien d'autre :
//   (1) aller-retour de sérialisation FIDÈLE, catalogue compris (AD-4) ;
//   (2) décodage DÉFENSIF (AD-10) — une entrée illisible est SAUTÉE sans
//       emporter les autres, une racine illisible rend un catalogue VIDE ;
//   (3) `extra` FILTRÉ sur la commande ET sur le catalogue (AD-19.1) ;
//   (4) 🔴 le socle N'EXÉCUTE RIEN et NE DEVINE RIEN : un jeton inconnu rend
//       `null`, pas une commande approchée ni une commande par défaut.
//
// R3 (rouge par ASSERTION) :
//  • correspondance par préfixe au lieu d'exacte ⇒ (4) rougit ;
//  • repli sur la première commande quand le jeton est inconnu ⇒ (4) rougit ;
//  • `fromJson` du catalogue rendant `null` sur racine illisible ⇒ (2) rougit ;
//  • `zJsonDecodeList` remplacé par un `map`/`cast` ⇒ (2) rougit ;
//  • `zSanitizeExtra` retiré ⇒ (3) rougit (identité de lecture) ;
//  • `...ZSyncMeta.reservedKeys` retiré ⇒ (3) rougit.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

const Map<String, dynamic> _polluted = <String, dynamic>{
  'host': 'kept',
  ZSyncMeta.kUpdatedAt: '2026-01-01T00:00:00Z',
  ZSyncMeta.kIsDeleted: true,
  'key': 'smuggled',
  'commands': 'smuggled',
};

void main() {
  group('ZChatSlashCommand', () {
    test('aller-retour FIDÈLE : chaque champ déclaré revient', () {
      final ZChatSlashCommand c = ZChatSlashCommand(
        key: 'resume',
        label: 'Résumer',
        description: 'Résume la conversation',
        iconKey: 'summary',
        sectionKey: 'texte',
        aliases: <String>['sum', 'tldr'],
        argumentHint: 'sujet',
        requiresArgument: true,
        disabledReasonToken: 'quota',
        order: 4,
        extra: <String, dynamic>{'host': 1},
      );
      final ZChatSlashCommand back = ZChatSlashCommand.fromJson(c.toJson())!;
      expect(back.key, 'resume');
      expect(back.label, 'Résumer');
      expect(back.description, 'Résume la conversation');
      expect(back.iconKey, 'summary');
      expect(back.sectionKey, 'texte');
      expect(back.aliases, <String>['sum', 'tldr']);
      expect(back.argumentHint, 'sujet');
      expect(back.requiresArgument, isTrue);
      expect(back.disabledReasonToken, 'quota');
      expect(back.isEnabled, isFalse);
      expect(back.order, 4);
      expect(back.extra, <String, dynamic>{'host': 1});
      expect(
        ZChatSlashCommand(key: 'k').toJson(),
        <String, dynamic>{'key': 'k'},
        reason: 'les défauts sont OMIS',
      );
    });

    test('les alias sont rognés, dédupliqués, les vides écartés', () {
      final ZChatSlashCommand c = ZChatSlashCommand(
        key: 'k',
        aliases: <String>[' a ', 'a', '', '   ', 'b'],
      );
      expect(c.aliases, <String>['a', 'b']);
    });

    test('AD-10 — clé absente / blanche / du mauvais type ⇒ écartée', () {
      expect(ZChatSlashCommand.fromJson(null), isNull);
      expect(ZChatSlashCommand.fromJson('pas une map'), isNull);
      expect(ZChatSlashCommand.fromJson(<String, dynamic>{}), isNull);
      expect(ZChatSlashCommand.fromJson(<String, dynamic>{'key': '  '}), isNull);
      expect(ZChatSlashCommand.fromJson(<String, dynamic>{'key': 7}), isNull);
      final ZChatSlashCommand c = ZChatSlashCommand.fromJson(
        <String, dynamic>{
          'key': 'k',
          'aliases': 'pas une liste',
          'requires_argument': 'pas un booleen',
          'order': <int>[1],
          'extra': 42,
        },
      )!;
      expect(c.aliases, isEmpty);
      expect(c.requiresArgument, isFalse, reason: 'repli documenté');
      expect(c.order, 0, reason: 'repli documenté');
      expect(c.extra, isEmpty);
    });

    test('une liste d\'alias PARTIELLEMENT typée garde ses éléments lisibles',
        () {
      final ZChatSlashCommand c = ZChatSlashCommand.fromJson(
        <String, dynamic>{
          'key': 'k',
          'aliases': <Object?>['a', 7, null, 'b'],
        },
      )!;
      expect(c.aliases, <String>['a', 'b'], reason: 'AD-10 : rien n\'est perdu');
    });

    test('🔴 `answersTo` est EXACT : ni préfixe, ni approximation', () {
      final ZChatSlashCommand c =
          ZChatSlashCommand(key: 'resume', aliases: <String>['tldr']);
      expect(c.answersTo('resume'), isTrue);
      expect(c.answersTo('  RESUME '), isTrue, reason: 'casse et blancs');
      expect(c.answersTo('tldr'), isTrue);
      expect(c.answersTo('res'), isFalse, reason: 'aucun préfixe');
      expect(c.answersTo('resumer'), isFalse);
      expect(c.answersTo('resmue'), isFalse, reason: 'aucune approximation');
      expect(c.answersTo(''), isFalse);
      expect(c.answersTo('   '), isFalse);
    });

    test('AD-19.1 — `extra` filtré sur la commande', () {
      final ZChatSlashCommand c = ZChatSlashCommand.fromJson(
        <String, dynamic>{'key': 'k', 'extra': _polluted},
      )!;
      expect(c.extra, <String, dynamic>{
        'host': 'kept',
        'commands': 'smuggled',
      }, reason: '`commands` n\'est PAS une clé propre de la commande');
      expect(c.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(c.extra.containsKey('key'), isFalse);
      expect(
        (c.toJson()['extra']! as Map<String, dynamic>)
            .containsKey(ZSyncMeta.kIsDeleted),
        isFalse,
      );
      expect(identical(c.extra, c.extra), isTrue,
          reason: 'filtrage EAGER au constructeur ⇒ lecture sans copie');
      expect(
        ZChatSlashCommand(key: 'x', extra: _polluted)
            .extra
            .containsKey(ZSyncMeta.kIsDeleted),
        isFalse,
        reason: 'voie constructeur : même garde',
      );
    });
  });

  group('ZChatSlashCatalog', () {
    ZChatSlashCatalog build() => ZChatSlashCatalog(
          trigger: ZChatMentionTrigger(
            character: '/',
            allowsWhitespace: true,
          ),
          commands: <ZChatSlashCommand>[
            ZChatSlashCommand(key: 'resume', order: 2, aliases: <String>['r']),
            ZChatSlashCommand(key: 'traduire', order: 1, requiresArgument: true),
          ],
        );

    test('aller-retour FIDÈLE, amorce comprise', () {
      final Map<String, dynamic> json = build().toJson();
      final ZChatSlashCatalog back = ZChatSlashCatalog.fromJson(json);
      expect(back.commands.map((ZChatSlashCommand c) => c.key),
          <String>['resume', 'traduire']);
      expect(back.trigger!.character, '/');
      expect(back.trigger!.allowsWhitespace, isTrue);
      expect(ZChatSlashCatalog().toJson(), isEmpty, reason: 'défauts omis');
    });

    test('déduplication par clé : la PREMIÈRE déclaration gagne', () {
      final ZChatSlashCatalog cat = ZChatSlashCatalog(
        commands: <ZChatSlashCommand>[
          ZChatSlashCommand(key: 'a', label: 'premier'),
          ZChatSlashCommand(key: 'a', label: 'second'),
          ZChatSlashCommand(key: 'b'),
        ],
      );
      expect(cat.commands.length, 2);
      expect(cat.commands.first.label, 'premier');
    });

    test('`ordered` applique le rang DÉCLARÉ, jamais un rang inventé', () {
      expect(build().ordered.map((ZChatSlashCommand c) => c.key),
          <String>['traduire', 'resume']);
      // À rang égal, l'ordre de DÉCLARATION décide (tri stable) — et l'ordre
      // alphabétique, lui, n'a jamais son mot à dire.
      final ZChatSlashCatalog egal = ZChatSlashCatalog(
        commands: <ZChatSlashCommand>[
          ZChatSlashCommand(key: 'zeta'),
          ZChatSlashCommand(key: 'alpha'),
        ],
      );
      expect(egal.ordered.map((ZChatSlashCommand c) => c.key),
          <String>['zeta', 'alpha']);
      expect(egal.commands.map((ZChatSlashCommand c) => c.key),
          <String>['zeta', 'alpha'],
          reason: '`commands` reste l\'ordre de déclaration');
    });

    test('AD-10 — racine illisible ⇒ catalogue VIDE, jamais null ni exception',
        () {
      expect(ZChatSlashCatalog.fromJson(null).isEmpty, isTrue);
      expect(ZChatSlashCatalog.fromJson('pas une map').isEmpty, isTrue);
      expect(ZChatSlashCatalog.fromJson(<Object?>[1]).isEmpty, isTrue);
      expect(ZChatSlashCatalog.fromJson(null).trigger, isNull);
    });

    test('AD-10 — une entrée illisible est SAUTÉE sans emporter les autres',
        () {
      final ZChatSlashCatalog cat = ZChatSlashCatalog.fromJson(
        <String, dynamic>{
          'trigger': 'pas une amorce',
          'commands': <Object?>[
            <String, dynamic>{'key': 'ok'},
            'pas une map',
            null,
            42,
            <String, dynamic>{'label': 'sans cle'},
            <String, dynamic>{'key': 'ok2'},
          ],
        },
      );
      expect(cat.commands.map((ZChatSlashCommand c) => c.key),
          <String>['ok', 'ok2']);
      expect(cat.trigger, isNull, reason: 'amorce illisible ⇒ absente');
      expect(
        ZChatSlashCatalog.fromJson(
          <String, dynamic>{'commands': 'pas une liste'},
        ).isEmpty,
        isTrue,
      );
    });

    test('🔴 un jeton INCONNU ne désigne RIEN — aucune commande par défaut',
        () {
      final ZChatSlashCatalog cat = build();
      expect(cat.commandFor('resume')!.key, 'resume');
      expect(cat.commandFor('r')!.key, 'resume', reason: 'par alias');
      expect(cat.commandFor('inconnue'), isNull);
      expect(cat.commandFor('resum'), isNull, reason: 'aucun préfixe');
      expect(cat.commandFor(''), isNull);
      expect(ZChatSlashCatalog().commandFor('resume'), isNull);
    });

    test('🔴 l\'invocation IDENTIFIE, elle n\'exécute pas : commande + '
        'arguments bruts, bornes du segment', () {
      final ZChatSlashCatalog cat = build();
      final ZChatSlashInvocation inv =
          cat.invocationIn('/traduire en anglais', 20)!;
      expect(inv.command.key, 'traduire');
      expect(inv.arguments, 'en anglais');
      expect(inv.start, 0);
      expect(inv.end, 20);
      expect(inv.isComplete, isTrue);
      // Argument exigé mais absent : CONSTAT rendu, aucun refus.
      final ZChatSlashInvocation nu = cat.invocationIn('/traduire', 9)!;
      expect(nu.arguments, isEmpty);
      expect(nu.isComplete, isFalse);
      // Une commande sans exigence est toujours « complète ».
      expect(cat.invocationIn('/resume', 7)!.isComplete, isTrue);
    });

    test('l\'invocation rend `null` — sans lever — quand rien n\'est reconnu',
        () {
      final ZChatSlashCatalog cat = build();
      expect(cat.invocationIn('bonjour', 7), isNull);
      expect(cat.invocationIn('/inconnue', 9), isNull,
          reason: 'jeton inconnu : le texte reste du texte');
      expect(cat.invocationIn('a/resume', 8), isNull,
          reason: 'frontière de mot exigée par l\'amorce');
      expect(cat.invocationIn('/resume', -1), isNull);
      expect(cat.invocationIn('/resume', 99), isNull);
      // Sans amorce déclarée, aucune reconnaissance — et pas d\'exception.
      expect(
        ZChatSlashCatalog(
          commands: <ZChatSlashCommand>[ZChatSlashCommand(key: 'resume')],
        ).invocationIn('/resume', 7),
        isNull,
      );
    });

    test('AD-19.1 — `extra` filtré sur le CATALOGUE aussi', () {
      final ZChatSlashCatalog cat = ZChatSlashCatalog.fromJson(
        <String, dynamic>{'extra': _polluted},
      );
      expect(cat.extra, <String, dynamic>{'host': 'kept', 'key': 'smuggled'},
          reason: '`key` n\'est PAS une clé propre du catalogue');
      expect(cat.extra.containsKey('commands'), isFalse);
      expect(cat.extra.containsKey(ZSyncMeta.kUpdatedAt), isFalse);
      expect(
        (cat.toJson()['extra']! as Map<String, dynamic>)
            .containsKey(ZSyncMeta.kIsDeleted),
        isFalse,
      );
      expect(identical(cat.extra, cat.extra), isTrue,
          reason: 'filtrage EAGER au constructeur ⇒ lecture sans copie');
    });
  });
}
