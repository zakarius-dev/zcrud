/// Ports COMPAGNONS de partage — gardes de comportement.
///
/// Ce que ces gardes affirment, et qui casserait si la livraison régressait :
/// l'INERTIE ABSOLUE des deux surfaces tant qu'aucun compagnon utilisable
/// n'est fourni (arbre STRICTEMENT identique à celui d'avant le port), la
/// PRIORITÉ du flux-paramètre sur le port de lecture, la PRIORITÉ du callback
/// historique sur le port d'administration, l'unicité et l'exactitude des
/// appels de port, l'état INTACT sur `Left`, l'anti-double-soumission des
/// interrupteurs, et le maintien du portail fail-closed même ports fournis.
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
        ZCursor,
        ZDataRequest,
        ZDenyAllAcl,
        ZDomainFailure,
        ZFailure,
        ZResult,
        ZcrudScope,
        unit;
import 'package:zcrud_study/zcrud_study.dart';

/// Port de partage v1 minimal : il ne sert qu'à monter la feuille. Sa surface
/// est INCHANGÉE — aucune méthode ne lui a été ajoutée.
class _V1SharingPort implements ZStudySharingPort {
  final StreamController<List<ZStudyMembership>> members =
      StreamController<List<ZStudyMembership>>.broadcast();

  @override
  Future<ZResult<ZShareLink>> createShareLink(String folderId) async =>
      Right<ZFailure, ZShareLink>(ZShareLink(folderId: folderId));

  @override
  Future<ZResult<Unit>> revokeShareLink(String linkId) async =>
      const Right<ZFailure, Unit>(unit);

  @override
  Future<ZResult<ZStudyMembership>> grantMembership(
    ZStudyMembership membership,
  ) async =>
      Right<ZFailure, ZStudyMembership>(membership);

  @override
  Stream<List<ZStudyMembership>> watchMemberships(String folderId) =>
      members.stream;

  @override
  Future<ZResult<ZPublicStudyFolder>> publishToGallery(String folderId) async =>
      Right<ZFailure, ZPublicStudyFolder>(ZPublicStudyFolder(folderId: folderId));

  @override
  Future<ZResult<Unit>> unpublish(String folderId) async =>
      const Right<ZFailure, Unit>(unit);
}

/// Port compagnon de LECTURE, enregistreur.
class _RecordingReadPort implements ZStudySharingReadPort {
  _RecordingReadPort({this.isAvailable = true});

  @override
  final bool isAvailable;

  final StreamController<List<ZPublicStudyFolder>> controller =
      StreamController<List<ZPublicStudyFolder>>.broadcast();

  int watchCalls = 0;
  final List<ZDataRequest?> requests = <ZDataRequest?>[];
  final List<String> readIds = <String>[];

  @override
  Stream<List<ZPublicStudyFolder>> watchPublicFolders({
    ZDataRequest? request,
  }) {
    watchCalls++;
    requests.add(request);
    return controller.stream;
  }

  @override
  Future<ZResult<ZPublicStudyFolder?>> publicFolderById(String folderId) async {
    readIds.add(folderId);
    return const Right<ZFailure, ZPublicStudyFolder?>(null);
  }
}

/// Port compagnon d'ADMINISTRATION, enregistreur. Chaque appel est retenu
/// avec ses arguments EXACTS ; les réponses sont programmables, et
/// `gate` permet de laisser un appel EN VOL.
class _RecordingAdminPort implements ZStudySharingAdminPort {
  _RecordingAdminPort({
    this.isAvailable = true,
    this.revokeResult,
    this.joinableResult,
    this.gate,
  });

  @override
  final bool isAvailable;

  final ZResult<Unit>? revokeResult;
  final ZResult<Unit>? joinableResult;

  /// Si non `null`, chaque mutation ATTEND ce futur avant de répondre.
  final Future<void>? gate;

  final List<String> revokedMembershipIds = <String>[];
  final List<(String, bool)> joinableCalls = <(String, bool)>[];
  final List<(String, bool)> inviteCalls = <(String, bool)>[];

  @override
  Future<ZResult<Unit>> revokeMembership(String membershipId) async {
    revokedMembershipIds.add(membershipId);
    if (gate != null) await gate;
    return revokeResult ?? const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> setJoinableByLink(String folderId, bool value) async {
    joinableCalls.add((folderId, value));
    if (gate != null) await gate;
    return joinableResult ?? const Right<ZFailure, Unit>(unit);
  }

  @override
  Future<ZResult<Unit>> setMembersCanInvite(
    String folderId,
    bool value,
  ) async {
    inviteCalls.add((folderId, value));
    if (gate != null) await gate;
    return const Right<ZFailure, Unit>(unit);
  }
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

Widget _host(Widget child, {ZAcl? acl = const ZAllowAllAcl()}) {
  final Widget body = MaterialApp(home: Scaffold(body: child));
  if (acl == null) return body;
  return ZcrudScope(acl: acl, child: body);
}

/// Empreinte STRUCTURELLE d'un sous-arbre : type + clé de CHAQUE widget, dans
/// l'ordre de parcours. Deux rendus d'empreinte identique ont le même arbre.
List<String> _shape(WidgetTester tester, Finder root) => tester
    .widgetList(find.descendant(of: root, matching: find.byWidgetPredicate((_) => true)))
    .map((Widget w) => '${w.runtimeType}#${w.key}')
    .toList(growable: false);

const ZStudyMembership _member = ZStudyMembership(
  id: 'm-42',
  folderId: 'f1',
  actorUid: 'u-9',
  role: ZMembershipRole.viewer,
);

void main() {
  group('compagnons — INERTIE ABSOLUE sans port utilisable', () {
    testWidgets(
      'feuille : sans compagnon et avec un compagnon INERTE, arbre '
      'STRICTEMENT identique',
      (WidgetTester tester) async {
        final _V1SharingPort port = _V1SharingPort();
        Widget sheet(ZStudySharingAdminPort? admin) => ZFolderSharingSheet(
              port: port,
              folderId: 'f1',
              labels: _labels,
              roleLabel: _roleLabel,
              adminPort: admin,
            );
        await tester.pumpWidget(_host(sheet(null)));
        final Finder body =
            find.byKey(const ValueKey<String>('z-folder-sharing-body'));
        final List<String> without = _shape(tester, body);

        await tester.pumpWidget(
          _host(sheet(const ZInertStudySharingAdminPort())),
        );
        await tester.pumpAndSettle();
        expect(_shape(tester, body), equals(without));
        // Et cet arbre ne porte AUCUNE des surfaces d'administration.
        expect(find.byType(SwitchListTile), findsNothing);
        expect(find.text('RETIRER'), findsNothing);
      },
    );

    testWidgets(
      'galerie : port de lecture INERTE ⇒ aucun abonnement, état vide',
      (WidgetTester tester) async {
        final _RecordingReadPort read = _RecordingReadPort(isAvailable: false);
        await tester.pumpWidget(
          _host(
            ZPublicGalleryView(
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              readPort: read,
            ),
          ),
        );
        await tester.pump();
        expect(read.watchCalls, equals(0));
        expect(
          find.byKey(const ValueKey<String>('z-public-gallery-empty')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey<String>('z-public-gallery-list')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'feuille : port d\'administration COUPÉ À CHAUD ⇒ surfaces absentes, '
      'aucun appel',
      (WidgetTester tester) async {
        final _V1SharingPort port = _V1SharingPort();
        final _RecordingAdminPort admin =
            _RecordingAdminPort(isAvailable: false);
        await tester.pumpWidget(
          _host(
            ZFolderSharingSheet(
              port: port,
              folderId: 'f1',
              labels: _labels,
              roleLabel: _roleLabel,
              adminPort: admin,
            ),
          ),
        );
        port.members.add(const <ZStudyMembership>[_member]);
        await tester.pump();
        expect(find.byType(SwitchListTile), findsNothing);
        expect(
          find.byKey(
            const ValueKey<String>('z-folder-sharing-revoke-member-0'),
          ),
          findsNothing,
        );
        expect(admin.joinableCalls, isEmpty);
        expect(admin.revokedMembershipIds, isEmpty);
      },
    );

    testWidgets('galerie : ni flux ni port ⇒ état vide, aucune liste', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          const ZPublicGalleryView(
            labels: _galleryLabels,
            titleFallback: 'SANS TITRE',
          ),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('z-public-gallery-empty')),
        findsOneWidget,
      );
    });
  });

  group('galerie — lecture par port compagnon', () {
    testWidgets(
      'readPort SANS flux-paramètre ⇒ la galerie rend le flux DU PORT, '
      'requête transmise VERBATIM',
      (WidgetTester tester) async {
        final _RecordingReadPort read = _RecordingReadPort();
        const ZDataRequest request = ZDataRequest(
          limit: 7,
          startAfter: ZCursor(values: <Object?>['a']),
        );
        await tester.pumpWidget(
          _host(
            ZPublicGalleryView(
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              readPort: read,
              readRequest: request,
            ),
          ),
        );
        await tester.pump();
        expect(read.watchCalls, equals(1));
        expect(read.requests.single, same(request));

        read.controller.add(const <ZPublicStudyFolder>[
          ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'DU PORT'),
        ]);
        await tester.pump();
        await tester.pump();
        expect(find.text('DU PORT'), findsOneWidget);
        expect(
          find.byKey(const ValueKey<String>('z-public-gallery-list')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'les DEUX fournis ⇒ le flux-PARAMÈTRE prime, le port n\'est JAMAIS '
      'abonné',
      (WidgetTester tester) async {
        final _RecordingReadPort read = _RecordingReadPort();
        await tester.pumpWidget(
          _host(
            ZPublicGalleryView(
              labels: _galleryLabels,
              titleFallback: 'SANS TITRE',
              folders: Stream<List<ZPublicStudyFolder>>.value(
                const <ZPublicStudyFolder>[
                  ZPublicStudyFolder(
                    id: 'p0',
                    folderId: 'f0',
                    title: 'DU PARAMÈTRE',
                  ),
                ],
              ),
              readPort: read,
            ),
          ),
        );
        await tester.pump();
        expect(read.watchCalls, equals(0));
        expect(find.text('DU PARAMÈTRE'), findsOneWidget);

        // Même après un événement du port, rien de lui n'apparaît.
        read.controller.add(const <ZPublicStudyFolder>[
          ZPublicStudyFolder(id: 'p1', folderId: 'f1', title: 'DU PORT'),
        ]);
        await tester.pump();
        expect(find.text('DU PORT'), findsNothing);
      },
    );

    testWidgets('un rebuild ne RÉABONNE pas le port', (
      WidgetTester tester,
    ) async {
      final _RecordingReadPort read = _RecordingReadPort();
      Widget view() => ZPublicGalleryView(
            labels: _galleryLabels,
            titleFallback: 'SANS TITRE',
            readPort: read,
          );
      await tester.pumpWidget(_host(view()));
      await tester.pump();
      await tester.pumpWidget(_host(view()));
      await tester.pump();
      expect(read.watchCalls, equals(1));
    });
  });

  group('feuille — révocation d\'adhésion par port compagnon', () {
    testWidgets('l\'action APPARAÎT et appelle le port UNE fois, id EXACT', (
      WidgetTester tester,
    ) async {
      final _V1SharingPort port = _V1SharingPort();
      final _RecordingAdminPort admin = _RecordingAdminPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
          ),
        ),
      );
      port.members.add(const <ZStudyMembership>[_member]);
      await tester.pump();
      final Finder button =
          find.byKey(const ValueKey<String>('z-folder-sharing-revoke-member-0'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();
      await tester.pump();
      expect(admin.revokedMembershipIds, equals(<String>['m-42']));
    });

    testWidgets('cible tactile de l\'action ≥ 48 dp (AD-13)', (
      WidgetTester tester,
    ) async {
      final _V1SharingPort port = _V1SharingPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: _RecordingAdminPort(),
          ),
        ),
      );
      port.members.add(const <ZStudyMembership>[_member]);
      await tester.pump();
      final Size size = tester.getSize(
        find.byKey(const ValueKey<String>('z-folder-sharing-revoke-member-0')),
      );
      expect(size.height, greaterThanOrEqualTo(48.0));
    });

    testWidgets('Left ⇒ erreur ANNONCÉE et adhésion TOUJOURS listée', (
      WidgetTester tester,
    ) async {
      final _V1SharingPort port = _V1SharingPort();
      final _RecordingAdminPort admin = _RecordingAdminPort(
        revokeResult: const Left<ZFailure, Unit>(ZDomainFailure('REFUS')),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
          ),
        ),
      );
      port.members.add(const <ZStudyMembership>[_member]);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-revoke-member-0')),
      );
      await tester.pump();
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-error')),
        findsOneWidget,
      );
      expect(find.text('REFUS'), findsOneWidget);
      // État INTACT : la ligne d'adhésion est toujours là.
      expect(find.text('u-9'), findsOneWidget);
    });

    testWidgets('le CALLBACK prime : le port n\'est JAMAIS appelé', (
      WidgetTester tester,
    ) async {
      final _V1SharingPort port = _V1SharingPort();
      final _RecordingAdminPort admin = _RecordingAdminPort();
      final List<String> viaCallback = <String>[];
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: port,
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
            onRevokeMembership: (ZStudyMembership m) async {
              viaCallback.add(m.id ?? '');
              return const Right<ZFailure, Unit>(unit);
            },
          ),
        ),
      );
      port.members.add(const <ZStudyMembership>[_member]);
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-revoke-member-0')),
      );
      await tester.pump();
      await tester.pump();
      expect(viaCallback, equals(<String>['m-42']));
      expect(admin.revokedMembershipIds, isEmpty);
    });
  });

  group('feuille — interrupteurs par port compagnon', () {
    testWidgets(
      'les DEUX interrupteurs apparaissent ; la bascule appelle '
      'setJoinableByLink(folderId, valeur) EXACT',
      (WidgetTester tester) async {
        final _RecordingAdminPort admin = _RecordingAdminPort();
        await tester.pumpWidget(
          _host(
            ZFolderSharingSheet(
              port: _V1SharingPort(),
              folderId: 'f1',
              labels: _labels,
              roleLabel: _roleLabel,
              adminPort: admin,
            ),
          ),
        );
        expect(find.byType(SwitchListTile), findsNWidgets(2));
        await tester.tap(
          find.byKey(const ValueKey<String>('z-folder-sharing-joinable')),
        );
        await tester.pump();
        await tester.pump();
        expect(admin.joinableCalls, equals(<(String, bool)>[('f1', true)]));
        expect(admin.inviteCalls, isEmpty);
      },
    );

    testWidgets('l\'autre interrupteur appelle setMembersCanInvite EXACT', (
      WidgetTester tester,
    ) async {
      final _RecordingAdminPort admin = _RecordingAdminPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f9',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
            membersCanInvite: true,
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-can-invite')),
      );
      await tester.pump();
      await tester.pump();
      expect(admin.inviteCalls, equals(<(String, bool)>[('f9', false)]));
      expect(admin.joinableCalls, isEmpty);
    });

    testWidgets('anti-double-soumission : deux bascules ⇒ UN SEUL appel', (
      WidgetTester tester,
    ) async {
      final Completer<void> gate = Completer<void>();
      final _RecordingAdminPort admin = _RecordingAdminPort(gate: gate.future);
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
          ),
        ),
      );
      final Finder sw =
          find.byKey(const ValueKey<String>('z-folder-sharing-joinable'));
      await tester.tap(sw);
      await tester.pump();
      await tester.tap(sw);
      await tester.pump();
      expect(admin.joinableCalls, equals(<(String, bool)>[('f1', true)]));
      gate.complete();
      await tester.pump();
      await tester.pump();
    });

    testWidgets('le MUTATEUR prime : le port n\'est JAMAIS appelé', (
      WidgetTester tester,
    ) async {
      final _RecordingAdminPort admin = _RecordingAdminPort();
      final List<bool> viaCallback = <bool>[];
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
            onSetJoinableWithLink: (bool value) async {
              viaCallback.add(value);
              return const Right<ZFailure, Unit>(unit);
            },
          ),
        ),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('z-folder-sharing-joinable')),
      );
      await tester.pump();
      await tester.pump();
      expect(viaCallback, equals(<bool>[true]));
      expect(admin.joinableCalls, isEmpty);
    });

    testWidgets('Left du port ⇒ l\'interrupteur REVIENT à son état', (
      WidgetTester tester,
    ) async {
      final _RecordingAdminPort admin = _RecordingAdminPort(
        joinableResult: const Left<ZFailure, Unit>(ZDomainFailure('KO-PORT')),
      );
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
          ),
        ),
      );
      final Finder sw =
          find.byKey(const ValueKey<String>('z-folder-sharing-joinable'));
      await tester.tap(sw);
      await tester.pump();
      await tester.pump();
      expect(tester.widget<SwitchListTile>(sw).value, isFalse);
      expect(find.text('KO-PORT'), findsOneWidget);
    });
  });

  group('fail-closed CONSERVÉ malgré les compagnons', () {
    testWidgets('ACL refusant ⇒ feuille REFUSÉE même avec adminPort', (
      WidgetTester tester,
    ) async {
      final _RecordingAdminPort admin = _RecordingAdminPort();
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: admin,
          ),
          acl: const ZDenyAllAcl(),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-denied')),
        findsOneWidget,
      );
      expect(find.byType(SwitchListTile), findsNothing);
      expect(admin.joinableCalls, isEmpty);
    });

    testWidgets('ACL refusant ⇒ galerie REFUSÉE même avec readPort', (
      WidgetTester tester,
    ) async {
      final _RecordingReadPort read = _RecordingReadPort();
      await tester.pumpWidget(
        _host(
          ZPublicGalleryView(
            labels: _galleryLabels,
            titleFallback: 'SANS TITRE',
            readPort: read,
          ),
          acl: const ZDenyAllAcl(),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey<String>('z-public-gallery-denied')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('z-public-gallery-list')),
        findsNothing,
      );
    });

    testWidgets('AUCUN ZcrudScope ⇒ refus, compagnons fournis ou non', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _host(
          ZFolderSharingSheet(
            port: _V1SharingPort(),
            folderId: 'f1',
            labels: _labels,
            roleLabel: _roleLabel,
            adminPort: _RecordingAdminPort(),
          ),
          acl: null,
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('z-folder-sharing-denied')),
        findsOneWidget,
      );
    });
  });

  group('surface AD-5 des compagnons (liaison STATIQUE)', () {
    test('ZStudySharingReadPort — flux NU, ZResult<T?>, isAvailable', () async {
      final ZStudySharingReadPort port = _RecordingReadPort();
      final Stream<List<ZPublicStudyFolder>> stream =
          port.watchPublicFolders(request: const ZDataRequest(limit: 3));
      expect(stream, isA<Stream<List<ZPublicStudyFolder>>>());
      final ZResult<ZPublicStudyFolder?> one =
          await port.publicFolderById('f1');
      expect(one.isRight(), isTrue);
      expect(port.isAvailable, isTrue);
    });

    test('ZStudySharingAdminPort — trois ZResult<Unit>, isAvailable', () async {
      final ZStudySharingAdminPort port = _RecordingAdminPort();
      final ZResult<Unit> a = await port.revokeMembership('m-1');
      final ZResult<Unit> b = await port.setJoinableByLink('f1', true);
      final ZResult<Unit> c = await port.setMembersCanInvite('f1', false);
      expect(<bool>[a.isRight(), b.isRight(), c.isRight()],
          equals(<bool>[true, true, true]));
      expect(port.isAvailable, isTrue);
    });

    test('les inertes se déclarent INDISPONIBLES et n\'agissent pas',
        () async {
      const ZStudySharingReadPort read = ZInertStudySharingReadPort();
      const ZStudySharingAdminPort admin = ZInertStudySharingAdminPort();
      expect(read.isAvailable, isFalse);
      expect(admin.isAvailable, isFalse);
      expect(await read.watchPublicFolders().toList(),
          equals(const <List<ZPublicStudyFolder>>[]));
      final ZResult<ZPublicStudyFolder?> one =
          await read.publicFolderById('f1');
      expect(one.getOrElse(() => const ZPublicStudyFolder()), isNull);
      expect((await admin.revokeMembership('m')).isRight(), isTrue);
    });
  });
}
