/// P1-H — gardes de comportement des surfaces de partage et de galerie.
///
/// Ce que ces gardes affirment, et qui casserait si la livraison régressait :
/// l'inertie absolue sans câblage, le refus fail-closed ANNONCÉ (jamais une
/// surface vide), l'unicité des appels de port, la remise VERBATIM de la
/// valeur résolue à `grantMembership`, la virtualisation de la galerie, le
/// montage conditionnel du signalement et la granularité du rebuild.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart'
    show
        Left,
        Right,
        Unit,
        ZAcl,
        ZAllowAllAcl,
        ZDenyAllAcl,
        ZDomainFailure,
        ZFailure,
        ZResult,
        ZcrudScope,
        unit;
import 'package:zcrud_study/zcrud_study.dart';

/// Port de partage ENREGISTREUR : compte chaque appel et rend la réponse
/// programmée. Aucune logique, aucun délai — les gardes mesurent la surface,
/// pas un backend.
class _RecordingSharingPort implements ZStudySharingPort {
  _RecordingSharingPort({
    this.linkResult,
    this.revokeResult,
    this.grantResult,
    this.publishResult,
    this.unpublishResult,
  });

  final ZResult<ZShareLink>? linkResult;
  final ZResult<Unit>? revokeResult;
  final ZResult<ZStudyMembership>? grantResult;
  final ZResult<ZPublicStudyFolder>? publishResult;
  final ZResult<Unit>? unpublishResult;

  final StreamController<List<ZStudyMembership>> members =
      StreamController<List<ZStudyMembership>>.broadcast();

  int createCalls = 0;
  int revokeCalls = 0;
  int grantCalls = 0;
  int publishCalls = 0;
  int unpublishCalls = 0;
  final List<String> revokedIds = <String>[];
  final List<ZStudyMembership> granted = <ZStudyMembership>[];

  @override
  Future<ZResult<ZShareLink>> createShareLink(String folderId) async {
    createCalls++;
    return linkResult ??
        Right<ZFailure, ZShareLink>(ZShareLink(folderId: folderId));
  }

  @override
  Future<ZResult<Unit>> revokeShareLink(String linkId) async {
    revokeCalls++;
    revokedIds.add(linkId);
    return revokeResult ?? const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<ZStudyMembership>> grantMembership(
    ZStudyMembership membership,
  ) async {
    grantCalls++;
    granted.add(membership);
    return grantResult ?? Right<ZFailure, ZStudyMembership>(membership);
  }

  @override
  Stream<List<ZStudyMembership>> watchMemberships(String folderId) =>
      members.stream;

  @override
  Future<ZResult<ZPublicStudyFolder>> publishToGallery(String folderId) async {
    publishCalls++;
    return publishResult ??
        Right<ZFailure, ZPublicStudyFolder>(
          ZPublicStudyFolder(folderId: folderId),
        );
  }

  @override
  Future<ZResult<Unit>> unpublish(String folderId) async {
    unpublishCalls++;
    return unpublishResult ?? const Right<ZFailure, Unit>(unit);
  }
}

/// Port de modération ENREGISTREUR.
class _RecordingModerationPort implements ZStudyModerationPort {
  _RecordingModerationPort({this.reportResult});

  final ZResult<Unit>? reportResult;
  final List<ZStudyFolderReport> reports = <ZStudyFolderReport>[];

  @override
  Future<ZResult<Unit>> report(ZStudyFolderReport report) async {
    reports.add(report);
    return reportResult ?? const Right<ZFailure, Unit>(unit);
  }

  @override
  Stream<List<ZStudyFolderReport>> watchReports(String folderId) =>
      const Stream<List<ZStudyFolderReport>>.empty();

  @override
  Future<ZResult<Unit>> resolveReport(String reportId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<Unit>> takedown(String folderId) async =>
      const Right<ZFailure, Unit>(unit);
}

const ZFolderSharingLabels _labels = ZFolderSharingLabels(
  accessDenied: 'ACCÈS REFUSÉ',
  linkSectionTitle: 'LIEN',
  noLink: 'AUCUN LIEN',
  createLink: 'CRÉER',
  revokeLink: 'RÉVOQUER',
  copyLink: 'COPIER',
  linkCopied: 'COPIÉ',
  linkRevoked: 'RÉVOQUÉ',
  membersSectionTitle: 'MEMBRES',
  noMembers: 'AUCUN MEMBRE',
  principalFieldLabel: 'INVITER',
  principalFieldHint: 'IDENTIFIANT',
  grantMembership: 'ACCORDER',
  principalUnresolved: 'NON RÉSOLU',
  revokeMembership: 'RETIRER',
  gallerySectionTitle: 'GALERIE',
  notPublished: 'NON PUBLIÉ',
  published: 'PUBLIÉ',
  publishToGallery: 'PUBLIER',
  unpublish: 'DÉPUBLIER',
  joinableWithLink: 'REJOIGNABLE',
  membersCanInvite: 'INVITATION',
);

const ZPublicGalleryLabels _galleryLabels = ZPublicGalleryLabels(
  accessDenied: 'GALERIE REFUSÉE',
  empty: 'GALERIE VIDE',
  join: 'REJOINDRE',
  copy: 'COPIER',
  report: 'SIGNALER',
  reported: 'SIGNALÉ',
);

String _roleLabel(ZMembershipRole role) => 'RÔLE:${role.name}';

/// Monte [child] sous un `ZcrudScope` d'ACL [acl]. `null` ⇒ AUCUN scope (le
/// cas fail-closed le plus dur : rien à lire).
Widget _host(Widget child, {ZAcl? acl = const ZAllowAllAcl()}) {
  final Widget body = MaterialApp(home: Scaffold(body: child));
  if (acl == null) return body;
  return ZcrudScope(acl: acl, child: body);
}

void main() {
  group('P1-H — inertie absolue sans câblage', () {
    testWidgets('les fabriques d\'entrée rendent null sans câblage', (
      WidgetTester tester,
    ) async {
      late ZItemAction? sharing;
      late ZItemAction? gallery;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              sharing = zFolderSharingItemAction(context);
              gallery = zPublicGalleryItemAction(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(sharing, isNull);
      expect(gallery, isNull);
    });

    testWidgets('sans ACL lisible, l\'entrée CÂBLÉE reste absente', (
      WidgetTester tester,
    ) async {
      late ZItemAction? sharing;
      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              sharing = zFolderSharingItemAction(
                context,
                icon: Icons.share,
                label: 'PARTAGER',
                onSelected: () {},
              );
              return const SizedBox.shrink();
            },
          ),
          acl: null,
        ),
      );
      expect(sharing, isNull);
    });

    testWidgets('arbre FIGÉ : le menu non câblé est IDENTIQUE au menu vide', (
      WidgetTester tester,
    ) async {
      List<Type> typesOf() =>
          tester.allWidgets.map((Widget w) => w.runtimeType).toList();

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) => ZItemActionsMenu(
              actions: const <ZItemAction>[],
              icon: Icons.more_vert,
            ),
          ),
        ),
      );
      final List<Type> baseline = typesOf();

      await tester.pumpWidget(
        _host(
          Builder(
            builder: (BuildContext context) {
              final ZItemAction? a = zFolderSharingItemAction(context);
              final ZItemAction? b = zPublicGalleryItemAction(context);
              return ZItemActionsMenu(
                actions: <ZItemAction>[?a, ?b],
                icon: Icons.more_vert,
              );
            },
          ),
        ),
      );
      final List<Type> wired = typesOf();

      // ÉGALITÉ STRICTE (jamais `contains`/`<=`) : un seul nœud de plus et la
      // garde mord.
      expect(
        wired,
        equals(baseline),
        reason: '🔴 le câblage absent a tout de même ajouté un nœud.',
      );
    });
  });

  group('P1-H — fail-closed ANNONCÉ', () {
    testWidgets('port fourni mais ACL refusant ⇒ « accès refusé »', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
          acl: const ZDenyAllAcl(),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-denied')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-body')),
        findsNothing,
      );
      expect(find.text('ACCÈS REFUSÉ'), findsOneWidget);
    });

    testWidgets('AUCUN scope ⇒ refus (jamais un repli permissif)', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
          acl: null,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-denied')),
        findsOneWidget,
      );
    });

    testWidgets('disponibilité coupée ⇒ refus ANNONCÉ, pas une surface vide', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            availability: const ZMapFeatureAvailability(
              <String, bool>{zFeatureKeyFolderSharing: false},
            ),
          ),
        ),
      );
      expect(find.text('ACCÈS REFUSÉ'), findsOneWidget);
    });

    testWidgets('galerie : ACL refusant ⇒ « accès refusé »', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZPublicGalleryView(
            folders: const Stream<List<ZPublicStudyFolder>>.empty(),
            labels: _galleryLabels,
            titleFallback: 'SANS TITRE',
          ),
          acl: const ZDenyAllAcl(),
        ),
      );
      expect(find.text('GALERIE REFUSÉE'), findsOneWidget);
      expect(find.text('GALERIE VIDE'), findsNothing);
    });
  });

  group('P1-H — lien : un appel, un état', () {
    testWidgets('Right ⇒ 1 appel et lien affiché', (WidgetTester tester) async {
      final _RecordingSharingPort port = _RecordingSharingPort(
        linkResult: const Right<ZFailure, ZShareLink>(
          ZShareLink(id: 'l1', token: 'JETON', folderId: 'f1'),
        ),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      expect(find.text('AUCUN LIEN'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-create-link')),
      );
      await tester.pump();
      expect(port.createCalls, 1);
      expect(find.text('JETON'), findsOneWidget);
    });

    testWidgets('anti-double-soumission : deux pressions ⇒ 1 appel', (
      WidgetTester tester,
    ) async {
      final Completer<ZResult<ZShareLink>> gate =
          Completer<ZResult<ZShareLink>>();
      final _SlowSharingPort port = _SlowSharingPort(gate);
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      final Finder create =
          find.byKey(const ValueKey<String>('z-folder-sharing-create-link'));
      await tester.tap(create);
      await tester.pump();
      // Le bouton est désactivé pendant l'appel : `tap` ne peut plus émettre.
      expect(tester.widget<ElevatedButton>(create).onPressed, isNull);
      gate.complete(
        const Right<ZFailure, ZShareLink>(ZShareLink(id: 'l1', token: 'T')),
      );
      await tester.pump();
      expect(port.createCalls, 1);
    });

    testWidgets('Left ⇒ erreur NOTIFIÉE et état INTACT', (
      WidgetTester tester,
    ) async {
      final List<ZFailure> reported = <ZFailure>[];
      final _RecordingSharingPort port = _RecordingSharingPort(
        linkResult: const Left<ZFailure, ZShareLink>(ZDomainFailure('BOUM')),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            onFailure: reported.add,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-create-link')),
      );
      await tester.pump();
      expect(find.text('BOUM'), findsOneWidget);
      expect(reported.length, 1);
      // État INTACT : toujours « aucun lien », jamais un lien fantôme.
      expect(find.text('AUCUN LIEN'), findsOneWidget);
    });

    testWidgets('révocation : 1 appel sur l\'identité du lien, état révoqué', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            initialLink: const ZShareLink(id: 'l7', token: 'T7'),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-revoke-link')),
      );
      await tester.pump();
      expect(port.revokeCalls, 1);
      expect(port.revokedIds, <String>['l7']);
      expect(find.text('RÉVOQUÉ'), findsOneWidget);
    });

    testWidgets('révocation en échec ⇒ erreur, lien TOUJOURS actif', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort(
        revokeResult: const Left<ZFailure, Unit>(ZDomainFailure('NON')),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            initialLink: const ZShareLink(id: 'l7', token: 'T7'),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-revoke-link')),
      );
      await tester.pump();
      expect(find.text('NON'), findsOneWidget);
      expect(find.text('T7'), findsOneWidget);
      expect(find.text('RÉVOQUÉ'), findsNothing);
    });
  });

  group('P1-H — adhésion : la valeur RÉSOLUE, verbatim', () {
    testWidgets('le résolveur est appelé et sa valeur seule est écrite', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      final List<String> seen = <String>[];
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            principalResolver: (String input) async {
              seen.add(input);
              return 'UID-RÉSOLU';
            },
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('z-folder-sharing-principal')),
        'quelquun@example.test',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-grant')),
      );
      await tester.pump();
      expect(seen, <String>['quelquun@example.test']);
      expect(port.granted.length, 1);
      // Le socle n'interprète JAMAIS la saisie : c'est la valeur RENDUE qui
      // part, jamais l'adresse tapée.
      expect(port.granted.single.actorUid, 'UID-RÉSOLU');
      expect(port.granted.single.folderId, 'f1');
      expect(port.granted.single.role, ZMembershipRole.contributor);
    });

    testWidgets('octroi en échec ⇒ erreur annoncée, saisie CONSERVÉE', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort(
        grantResult: const Left<ZFailure, ZStudyMembership>(
          ZDomainFailure('REFUSÉ'),
        ),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            principalResolver: (String input) async => input,
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey<String>('z-folder-sharing-principal')),
        'UID',
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-grant')),
      );
      await tester.pump();
      expect(find.text('REFUSÉ'), findsOneWidget);
      // La saisie n'est PAS vidée par un échec : l'usager peut réessayer.
      expect(find.text('UID'), findsOneWidget);
    });

    testWidgets('résolveur rendant null ⇒ AUCUNE écriture, motif annoncé', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            principalResolver: (String input) async => null,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-grant')),
      );
      await tester.pump();
      expect(port.grantCalls, 0);
      expect(find.text('NON RÉSOLU'), findsOneWidget);
    });

    testWidgets('sans résolveur, la surface d\'invitation est ABSENTE', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-principal')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-grant')),
        findsNothing,
      );
    });

    testWidgets('les rôles sont NOMMÉS par la fabrique injectée', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            principalResolver: (String input) async => input,
          ),
        ),
      );
      expect(find.text('RÔLE:contributor'), findsOneWidget);
      expect(find.text('RÔLE:viewer'), findsOneWidget);
    });
  });

  group('P1-H — publication', () {
    testWidgets('publier ⇒ 1 appel et état publié', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      expect(find.text('NON PUBLIÉ'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-publish')),
      );
      await tester.pump();
      expect(port.publishCalls, 1);
      expect(find.text('PUBLIÉ'), findsOneWidget);
    });

    testWidgets('dépublication en échec ⇒ erreur, TOUJOURS publié', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort(
        unpublishResult: const Left<ZFailure, Unit>(ZDomainFailure('BLOQUÉ')),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            initialPublicFolder: const ZPublicStudyFolder(folderId: 'f1'),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-unpublish')),
      );
      await tester.pump();
      expect(find.text('BLOQUÉ'), findsOneWidget);
      expect(find.text('PUBLIÉ'), findsOneWidget);
    });

    testWidgets('dépublier ⇒ 1 appel et retour à « non publié »', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            initialPublicFolder: const ZPublicStudyFolder(folderId: 'f1'),
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-unpublish')),
      );
      await tester.pump();
      expect(port.unpublishCalls, 1);
      expect(find.text('NON PUBLIÉ'), findsOneWidget);
    });

    testWidgets('publication en échec ⇒ erreur, état INTACT', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort(
        publishResult: const Left<ZFailure, ZPublicStudyFolder>(
          ZDomainFailure('REFUS'),
        ),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-publish')),
      );
      await tester.pump();
      expect(find.text('REFUS'), findsOneWidget);
      expect(find.text('NON PUBLIÉ'), findsOneWidget);
    });
  });

  group('P1-H — interrupteurs portés par le dossier', () {
    testWidgets('sans mutateur, AUCUN interrupteur n\'est monté', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      expect(find.byType(SwitchListTile), findsNothing);
    });

    testWidgets('mutateur en échec ⇒ l\'interrupteur REVIENT à son état', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _RecordingSharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            onSetJoinableWithLink: (bool value) async =>
                const Left<ZFailure, Unit>(ZDomainFailure('KO')),
          ),
        ),
      );
      final Finder sw =
          find.byKey(const ValueKey<String>('z-folder-sharing-joinable'));
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      await tester.tap(sw);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.text('KO'), findsOneWidget);
    });
  });

  group('P1-H — granularité (invariant AD-2)', () {
    testWidgets(
      'un événement du flux d\'adhésions ne reconstruit PAS la section lien',
      (WidgetTester tester) async {
        final _RecordingSharingPort port = _RecordingSharingPort();
        await tester.pumpWidget(
          _host(
            ZFolderSharingSheet(
              port: port,
              folderId: 'f1',
              labels: _labels,
              roleLabel: _roleLabel,
            ),
          ),
        );
        final Finder section =
            find.byKey(const ValueKey<String>('z-folder-sharing-link-section'));
        final Widget before = tester.widget(section);

        port.members.add(<ZStudyMembership>[
          const ZStudyMembership(id: 'm1', actorUid: 'U1'),
        ]);
        await tester.pump();

        expect(find.text('U1'), findsOneWidget);
        // IDENTITÉ (pas égalité) : si la feuille entière s'était reconstruite,
        // le widget de la section serait une INSTANCE neuve.
        expect(
          identical(tester.widget(section), before),
          isTrue,
          reason: '🔴 le flux a reconstruit la feuille entière (AD-2).',
        );
      },
    );

    testWidgets('les adhésions sont rendues par une liste VIRTUALISÉE', (
      WidgetTester tester,
    ) async {
      final _RecordingSharingPort port = _RecordingSharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
          ),
        ),
      );
      port.members.add(<ZStudyMembership>[
        const ZStudyMembership(id: 'm1', actorUid: 'U1'),
      ]);
      await tester.pump();
      final ListView list = tester.widget<ListView>(find.byType(ListView));
      expect(
        list.childrenDelegate,
        isA<SliverChildBuilderDelegate>(),
        reason: '🔴 liste NON virtualisée (jamais `ListView(children: …)`).',
      );
    });
  });

  group('P1-H — galerie publique', () {
    testWidgets('le flux est rendu par une liste VIRTUALISÉE', (
      WidgetTester tester,
    ) async {
      final StreamController<List<ZPublicStudyFolder>> folders =
          StreamController<List<ZPublicStudyFolder>>();
      addTearDown(folders.close);
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 600,
            child: ZPublicGalleryView(
              folders: folders.stream,
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
            ),
          ),
        ),
      );
      expect(find.text('GALERIE VIDE'), findsOneWidget);
      folders.add(<ZPublicStudyFolder>[
        const ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'ALGÈBRE'),
        const ZPublicStudyFolder(id: 'p2', folderId: 'f2'),
      ]);
      await tester.pump();
      expect(find.text('ALGÈBRE'), findsOneWidget);
      expect(find.text('SANS TITRE'), findsOneWidget);
      final ListView list = tester.widget<ListView>(
        find.byKey(const ValueKey<String>('z-public-gallery-list')),
      );
      expect(list.childrenDelegate, isA<SliverChildBuilderDelegate>());
    });

    testWidgets('sans port de modération, « signaler » est ABSENT', (
      WidgetTester tester,
    ) async {
      final StreamController<List<ZPublicStudyFolder>> folders =
          StreamController<List<ZPublicStudyFolder>>();
      addTearDown(folders.close);
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 600,
            child: ZPublicGalleryView(
              folders: folders.stream,
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
            ),
          ),
        ),
      );
      folders.add(<ZPublicStudyFolder>[
        const ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'T'),
      ]);
      await tester.pump();
      expect(find.text('SIGNALER'), findsNothing);
    });

    testWidgets('avec port de modération, signaler écrit le signalement', (
      WidgetTester tester,
    ) async {
      final StreamController<List<ZPublicStudyFolder>> folders =
          StreamController<List<ZPublicStudyFolder>>();
      addTearDown(folders.close);
      final _RecordingModerationPort moderation = _RecordingModerationPort();
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 600,
            child: ZPublicGalleryView(
              folders: folders.stream,
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              moderationPort: moderation,
              reporterUid: 'MOI',
              reportReason: 'MOTIF',
            ),
          ),
        ),
      );
      folders.add(<ZPublicStudyFolder>[
        const ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'T'),
      ]);
      await tester.pump();
      await tester.tap(find.text('SIGNALER'));
      await tester.pump();
      expect(moderation.reports.length, 1);
      expect(moderation.reports.single.folderId, 'f1');
      expect(moderation.reports.single.reporterUid, 'MOI');
      expect(moderation.reports.single.reason, 'MOTIF');
      expect(find.text('SIGNALÉ'), findsOneWidget);
    });

    testWidgets('signalement en échec ⇒ message d\'erreur, jamais une levée', (
      WidgetTester tester,
    ) async {
      final StreamController<List<ZPublicStudyFolder>> folders =
          StreamController<List<ZPublicStudyFolder>>();
      addTearDown(folders.close);
      final _RecordingModerationPort moderation = _RecordingModerationPort(
        reportResult: const Left<ZFailure, Unit>(ZDomainFailure('NOPE')),
      );
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 600,
            child: ZPublicGalleryView(
              folders: folders.stream,
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              moderationPort: moderation,
            ),
          ),
        ),
      );
      folders.add(<ZPublicStudyFolder>[
        const ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'T'),
      ]);
      await tester.pump();
      await tester.tap(find.text('SIGNALER'));
      await tester.pump();
      expect(find.text('NOPE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('« rejoindre » / « copier » : absents sans geste, remis sinon',
        (WidgetTester tester) async {
      final StreamController<List<ZPublicStudyFolder>> folders =
          StreamController<List<ZPublicStudyFolder>>();
      addTearDown(folders.close);
      final List<String> joined = <String>[];
      await tester.pumpWidget(
        _host(
          SizedBox(
            height: 600,
            child: ZPublicGalleryView(
              folders: folders.stream,
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              onJoin: (ZPublicStudyFolder f) => joined.add(f.folderId),
            ),
          ),
        ),
      );
      folders.add(<ZPublicStudyFolder>[
        const ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'T'),
      ]);
      await tester.pump();
      expect(find.text('COPIER'), findsNothing);
      await tester.tap(find.text('REJOINDRE'));
      await tester.pump();
      expect(joined, <String>['f1']);
    });
  });
}

/// Port dont la création de lien PEND jusqu'à ce que le test la libère —
/// nécessaire pour observer la fenêtre d'anti-double-soumission.
class _SlowSharingPort extends _RecordingSharingPort {
  _SlowSharingPort(this.gate);

  final Completer<ZResult<ZShareLink>> gate;

  @override
  Future<ZResult<ZShareLink>> createShareLink(String folderId) {
    createCalls++;
    return gate.future;
  }
}
