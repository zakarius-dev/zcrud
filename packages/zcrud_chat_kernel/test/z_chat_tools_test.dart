// Gardes du vocabulaire déclaratif de la feuille d'outils.
//
// Chaque groupe vise un défaut PRÉCIS relevé sur les applications de
// référence, et non une propriété générique du code :
//   * la feuille écrite en dur (aiguillage + compteur d'items) qu'on remplace
//     par une donnée ;
//   * le cycle 0..N qui doit revenir à 0 (les deux références le font, aucune
//     ne le teste) ;
//   * l'entrée indisponible qui doit rester VISIBLE et porter sa raison ;
//   * la révélation conditionnelle du réglage fin ;
//   * le badge de comptage qui promet une liste d'actifs que personne ne tient.
import 'package:test/test.dart';
import 'package:zcrud_chat_kernel/zcrud_chat_kernel.dart';
import 'package:zcrud_core/domain.dart';

ZChatToolEntry _toggle(
  String key, {
  bool value = false,
  ZChatToolProminence prominence = ZChatToolProminence.auto,
  String? section,
  List<ZChatToolRule> disabledWhen = const <ZChatToolRule>[],
  List<String> deactivates = const <String>[],
  String? label,
  bool counts = true,
}) =>
    ZChatToolEntry(
      key: key,
      state: ZChatToggleState(value: value),
      label: label,
      sectionKey: section,
      prominence: prominence,
      disabledWhen: disabledWhen,
      deactivates: deactivates,
      countsTowardActive: counts,
    );

void main() {
  group('TOOL-1 — le cycle 0..N revient à 0 (jamais un cran hors bornes)', () {
    test('un tap par cran, puis retour à 0', () {
      ZChatCycleState s = ZChatCycleState(stepCount: 6);
      final List<int> seen = <int>[s.step];
      for (int i = 0; i < 6; i++) {
        s = s.next();
        seen.add(s.step);
      }
      expect(seen, <int>[0, 1, 2, 3, 4, 5, 0]);
    });

    test('le cran 0 est INACTIF, tous les autres sont actifs', () {
      expect(ZChatCycleState(stepCount: 6).isActive, isFalse);
      for (int i = 1; i < 6; i++) {
        expect(ZChatCycleState(step: i, stepCount: 6).isActive, isTrue,
            reason: 'cran $i');
      }
    });

    test('un cran persisté hors bornes est ramené, jamais levé (AD-10)', () {
      expect(ZChatCycleState(step: 42, stepCount: 6).step, 0);
      expect(ZChatCycleState(step: -1, stepCount: 6).step, 5);
      expect(ZChatCycleState(step: 3, stepCount: 0).stepCount, 1);
      expect(ZChatCycleState(step: 3, stepCount: 0).step, 0);
    });

    test('`advance` fait avancer sans connaître la nature, et BOUCLE', () {
      ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          ZChatToolEntry(key: 'think', state: ZChatCycleState(stepCount: 3)),
        ],
      );
      final List<int> steps = <int>[];
      for (int i = 0; i < 4; i++) {
        c = c.advance('think').getOrElse(() => c);
        steps.add((c.entry('think')!.state as ZChatCycleState).step);
      }
      expect(steps, <int>[1, 2, 0, 1]);
    });

    test('`advance` sur une nature sans cran suivant est REFUSÉ (AD-5)', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          ZChatToolEntry(
            key: 'corpus',
            state: ZChatCatalogState(itemKeys: const <String>['a']),
          ),
        ],
      );
      expect(
        c.advance('corpus').fold((ZFailure f) => f, (_) => null),
        isA<ZUnsupportedOperationFailure>(),
      );
      expect(
        c.advance('absent').fold((ZFailure f) => f, (_) => null),
        isA<ZNotFoundFailure>(),
      );
    });
  });

  group('TOOL-2 — une entrée désactivée est PRÉSENTE et porte sa raison', () {
    ZChatToolCatalog build() => ZChatToolCatalog(
          entries: <ZChatToolEntry>[
            _toggle('summary', value: true),
            _toggle(
              'web',
              value: true,
              disabledWhen: <ZChatToolRule>[
                ZChatToolRule(
                  condition: ZChatToolCondition(
                      activeKeys: const <String>['summary']),
                  reasonToken: 'host.reason.summaryCutsWeb',
                ),
              ],
            ),
          ],
        );

    test('elle est rendue, non actionnable, et sa raison est NOMMÉE', () {
      final ZChatToolResolution r = build().resolve();
      // L'ordre compte : on affirme la PRÉSENCE avant de lire l'entrée, sans
      // quoi un masquage rougirait par exception au lieu de rougir par
      // assertion — et la garde ne dirait plus ce qu'elle mesure.
      expect(r.hidden.containsKey('web'), isFalse,
          reason: 'désactivée ne veut pas dire masquée');
      expect(r.entries.map((ZChatToolResolvedEntry e) => e.entry.key),
          contains('web'));
      final ZChatToolResolvedEntry web =
          r.entries.firstWhere((ZChatToolResolvedEntry e) => e.entry.key == 'web');
      expect(web.isEnabled, isFalse);
      expect(web.disabledReasonToken, 'host.reason.summaryCutsWeb');
    });

    test('une entrée désactivée ne COMPTE pas comme active', () {
      final ZChatToolResolution r = build().resolve();
      expect(r.activeKeys, <String>['summary']);
      expect(r.activeCount, 1);
    });

    test('une entrée désactivée n\'est pas réglable par un autre chemin', () {
      final Either<ZFailure, ZChatToolCatalog> res = build()
          .setState('web', const ZChatToggleState());
      expect(res.fold((ZFailure f) => f, (_) => null), isA<ZDomainFailure>());
    });

    test('la condition redevient fausse ⇒ l\'entrée redevient actionnable', () {
      final ZChatToolCatalog off = build()
          .setState('summary', const ZChatToggleState())
          .getOrElse(() => build());
      final ZChatToolResolvedEntry web = off
          .resolve()
          .entries
          .firstWhere((ZChatToolResolvedEntry e) => e.entry.key == 'web');
      expect(web.isEnabled, isTrue);
    });

    test('une condition VIDE n\'est jamais satisfaite (fail-safe)', () {
      expect(ZChatToolCondition().isSatisfiedBy((_) => true), isFalse);
    });

    test('une clé INCONNUE ne satisfait ni le versant actif ni l\'inactif', () {
      final ZChatToolCondition active =
          ZChatToolCondition(activeKeys: const <String>['ghost']);
      final ZChatToolCondition inactive =
          ZChatToolCondition(inactiveKeys: const <String>['ghost']);
      expect(active.isSatisfiedBy((_) => null), isFalse);
      expect(inactive.isSatisfiedBy((_) => null), isFalse);
    });
  });

  group('TOOL-3 — la révélation conditionnelle masque l\'enfant', () {
    ZChatToolCatalog build({required bool parentOn}) => ZChatToolCatalog(
          entries: <ZChatToolEntry>[
            _toggle('think', value: parentOn),
            ZChatToolEntry(
              key: 'think.level',
              state: ZChatScaleState(min: 1, max: 5, value: 3),
              revealedBy: 'think',
            ),
          ],
        );

    test('parent inactif ⇒ enfant absent, et la raison est NOMMÉE', () {
      final ZChatToolResolution r = build(parentOn: false).resolve();
      expect(r.entries.map((ZChatToolResolvedEntry e) => e.entry.key),
          <String>['think']);
      expect(r.hidden['think.level'], ZChatToolHiddenReason.parentInactive);
    });

    test('parent actif ⇒ enfant révélé', () {
      final ZChatToolResolution r = build(parentOn: true).resolve();
      expect(r.entries.map((ZChatToolResolvedEntry e) => e.entry.key),
          <String>['think', 'think.level']);
      expect(r.hidden.containsKey('think.level'), isFalse);
    });

    test('un enfant NON révélé ne compte pas, même actif', () {
      expect(build(parentOn: false).resolve().activeKeys, <String>[]);
      expect(build(parentOn: true).resolve().activeKeys,
          <String>['think', 'think.level']);
    });

    test('parent introuvable ou chaîne qui boucle ⇒ non révélé, jamais levé',
        () {
      final ZChatToolCatalog orphan = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          ZChatToolEntry(
              key: 'a', state: const ZChatToggleState(), revealedBy: 'nope'),
        ],
      );
      expect(orphan.resolve().hidden['a'], ZChatToolHiddenReason.unknownParent);

      final ZChatToolCatalog loop = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          ZChatToolEntry(
              key: 'a',
              state: const ZChatToggleState(value: true),
              revealedBy: 'b'),
          ZChatToolEntry(
              key: 'b',
              state: const ZChatToggleState(value: true),
              revealedBy: 'a'),
        ],
      );
      expect(loop.resolve().hidden['a'], ZChatToolHiddenReason.unknownParent);
      expect(loop.resolve().hidden['b'], ZChatToolHiddenReason.unknownParent);
    });
  });

  group('TOOL-4 — `activeCount` compte ce qu\'il doit, et RIEN d\'autre', () {
    test('une action ponctuelle n\'est JAMAIS active', () {
      const ZChatCommandState cmd = ZChatCommandState();
      expect(cmd.isActive, isFalse);
      expect(cmd.stateToken, kZChatToolTokenIdle);
    });

    test('un catalogue sans sélection vaut « tous » et n\'est pas actif', () {
      final ZChatCatalogState all =
          ZChatCatalogState(itemKeys: const <String>['a', 'b']);
      expect(all.isActive, isFalse);
      expect(all.stateToken, kZChatToolTokenAll);
      expect(all.select(const <String>['a']).isActive, isTrue);
    });

    test('une entrée déclarée non comptable ne compte pas, même active', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', value: true),
          _toggle('b', value: true, counts: false),
        ],
      );
      expect(c.resolve().activeKeys, <String>['a']);
      expect(c.activeCount, 1);
    });

    test('le compte est IDENTIQUE sur la bande et sur la feuille', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', value: true, prominence: ZChatToolProminence.sheet),
          _toggle('b', prominence: ZChatToolProminence.band),
        ],
      );
      expect(c.resolve(surface: ZChatToolSurface.band).activeCount,
          c.resolve(surface: ZChatToolSurface.sheet).activeCount);
      expect(c.resolve(surface: ZChatToolSurface.band).activeCount, 1);
    });

    test('la recherche ne modifie PAS le compte (elle filtre le rendu)', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', value: true, label: 'Recherche web'),
          _toggle('b', value: true, label: 'Résumé'),
        ],
      );
      final ZChatToolResolution r = c.resolve(query: 'web');
      expect(r.entries.length, 1);
      expect(r.activeCount, 2);
      expect(r.hidden['b'], ZChatToolHiddenReason.filteredOut);
    });
  });

  group('TOOL-5 — un état, DEUX surfaces, UNE déclaration', () {
    test('`auto` n\'entre dans la bande QUE lorsqu\'il est actif', () {
      ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[_toggle('a')],
      );
      expect(c.resolve(surface: ZChatToolSurface.band).entries, isEmpty);
      expect(c.resolve(surface: ZChatToolSurface.band).hidden['a'],
          ZChatToolHiddenReason.notOnSurface);
      c = c.setState('a', const ZChatToggleState(value: true))
          .getOrElse(() => c);
      expect(
          c.resolve(surface: ZChatToolSurface.band).entries.single.entry.key,
          'a');
    });

    test('`band` y est toujours, `sheet` n\'y est jamais', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('always', prominence: ZChatToolProminence.band),
          _toggle('never',
              value: true, prominence: ZChatToolProminence.sheet),
        ],
      );
      expect(
          c
              .resolve(surface: ZChatToolSurface.band)
              .entries
              .map((ZChatToolResolvedEntry e) => e.entry.key),
          <String>['always']);
      expect(
          c
              .resolve(surface: ZChatToolSurface.sheet)
              .entries
              .map((ZChatToolResolvedEntry e) => e.entry.key),
          <String>['always', 'never']);
    });

    test('la feuille rend TOUT ce qui est révélé', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', prominence: ZChatToolProminence.sheet),
          _toggle('b', prominence: ZChatToolProminence.band),
          _toggle('c'),
        ],
      );
      expect(c.resolve().entries.length, 3);
    });
  });

  group('TOOL-6 — exclusion mutuelle : un SEUL site d\'application', () {
    test('activer coupe les exclus ; désactiver ne les rallume pas', () {
      ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('summary', deactivates: const <String>['web']),
          _toggle('web', value: true),
        ],
      );
      c = c
          .setState('summary', const ZChatToggleState(value: true))
          .getOrElse(() => c);
      expect(c.entry('web')!.isActive, isFalse);
      c = c.setState('summary', const ZChatToggleState()).getOrElse(() => c);
      expect(c.entry('web')!.isActive, isFalse,
          reason: 'l\'exclusion ne restaure rien : elle éteint');
    });

    test('poser un état INACTIF n\'applique aucune exclusion', () {
      ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('summary', deactivates: const <String>['web']),
          _toggle('web', value: true),
        ],
      );
      c = c.setState('summary', const ZChatToggleState()).getOrElse(() => c);
      expect(c.entry('web')!.isActive, isTrue);
    });

    test('changer la NATURE d\'un outil est refusé (AD-5)', () {
      final ZChatToolCatalog c =
          ZChatToolCatalog(entries: <ZChatToolEntry>[_toggle('a')]);
      expect(
        c
            .setState('a', ZChatCycleState(stepCount: 3))
            .fold((ZFailure f) => f, (_) => null),
        isA<ZDomainFailure>(),
      );
      expect(
        c
            .setState('ghost', const ZChatToggleState())
            .fold((ZFailure f) => f, (_) => null),
        isA<ZNotFoundFailure>(),
      );
    });
  });

  group('TOOL-7 — l\'en-tête « actifs » : la promesse que le badge fait', () {
    ZChatToolCatalog build() => ZChatToolCatalog(
          entries: <ZChatToolEntry>[
            _toggle('a', value: true),
            ZChatToolEntry(
                key: 'b', state: ZChatCycleState(step: 4, stepCount: 6)),
            ZChatToolEntry(
              key: 'c',
              state: ZChatCatalogState(
                  itemKeys: const <String>['x', 'y'],
                  selectedKeys: const <String>['x']),
            ),
          ],
        );

    test('la liste des actifs nomme exactement ce que le badge compte', () {
      final ZChatToolCatalog c = build();
      expect(c.resolve().activeKeys, <String>['a', 'b', 'c']);
      expect(c.activeCount, 3);
      expect(c.active.map((ZChatToolEntry e) => e.key), <String>['a', 'b', 'c']);
    });

    test('la remise à zéro rend un catalogue SANS aucun actif', () {
      final ZChatToolCatalog reset = build().reset();
      expect(reset.resolve().activeKeys, isEmpty);
      expect(reset.activeCount, 0);
      expect(reset.active, isEmpty);
      // La nature est préservée : seule la position retombe.
      expect(reset.entry('b')!.state, isA<ZChatCycleState>());
      expect((reset.entry('b')!.state as ZChatCycleState).stepCount, 6);
      expect(reset.entry('c')!.state, isA<ZChatCatalogState>());
      expect((reset.entry('c')!.state as ZChatCatalogState).itemKeys,
          <String>['x', 'y']);
    });

    test('la remise à zéro ne retire aucune entrée du catalogue', () {
      expect(build().reset().entries.length, build().entries.length);
    });
  });

  group('TOOL-8 — le sous-titre décrit l\'ÉTAT, et le socle ne le NOMME pas',
      () {
    test('le jeton d\'état est déterministe par nature', () {
      expect(const ZChatToggleState(value: true).stateToken, kZChatToolTokenOn);
      expect(const ZChatToggleState().stateToken, kZChatToolTokenOff);
      expect(ZChatCycleState(step: 3, stepCount: 6).stateToken, 'step.3');
      expect(
          ZChatChoiceState(
                  optionKeys: const <String>['a', 'b'], selectedKey: 'b')
              .stateToken,
          'b');
      expect(ZChatChoiceState(optionKeys: const <String>['a']).stateToken,
          kZChatToolTokenNone);
      expect(
          ZChatScaleState(
                  min: 1,
                  max: 5,
                  value: 4.1,
                  marks: const <double>[1, 3, 5])
              .stateToken,
          'mark.2');
      expect(ZChatScaleState(min: 1, max: 5, value: 4).stateToken,
          kZChatToolTokenValue);
    });

    test('sans texte d\'hôte, le socle ne rend AUCUN sous-titre', () {
      final ZChatToolEntry bare =
          ZChatToolEntry(key: 'a', state: const ZChatToggleState(value: true));
      expect(bare.describeState(), isNull);
    });

    test('le texte d\'hôte est rendu tel quel, jeton par jeton', () {
      final ZChatToolEntry e = ZChatToolEntry(
        key: 'think',
        state: ZChatCycleState(step: 3, stepCount: 6),
        stateLabels: const <String, String>{
          'step.0': 'Désactivé',
          'step.3': 'Niveau : Équilibré',
        },
      );
      expect(e.describeState(), 'Niveau : Équilibré');
      expect(e.reset().describeState(), 'Désactivé');
      expect(
          e.withState(ZChatCycleState(step: 5, stepCount: 6)).describeState(),
          isNull);
    });

    test('une option retenue hors catalogue est ÉCARTÉE, pas conservée', () {
      final ZChatChoiceState s = ZChatChoiceState(
          optionKeys: const <String>['a'], selectedKey: 'zzz');
      expect(s.selectedKey, isNull);
      expect(s.isActive, isFalse);
    });

    test('une échelle à bornes inversées est remise à l\'endroit, écrêtée', () {
      final ZChatScaleState s = ZChatScaleState(min: 5, max: 1, value: 99);
      expect(s.min, 1);
      expect(s.max, 5);
      expect(s.value, 5);
    });
  });

  group('TOOL-9 — recherche et sections', () {
    test('une requête vide accepte tout ; la casse est ignorée', () {
      final ZChatToolEntry e = ZChatToolEntry(
        key: 'a',
        state: const ZChatToggleState(),
        label: 'Recherche Web',
        searchTerms: const <String>['internet'],
      );
      expect(e.matches(''), isTrue);
      expect(e.matches('  '), isTrue);
      expect(e.matches('WEB'), isTrue);
      expect(e.matches('inter'), isTrue);
      expect(e.matches('corpus'), isFalse);
    });

    test('la recherche est recommandée au-delà du seuil de sections', () {
      ZChatToolCatalog withSections(int n) => ZChatToolCatalog(
            sections: <ZChatToolSection>[
              for (int i = 0; i < n; i++) ZChatToolSection(key: 's$i'),
            ],
          );
      expect(withSections(kZChatToolSearchSectionThreshold - 1)
          .searchRecommended, isFalse);
      expect(
          withSections(kZChatToolSearchSectionThreshold).searchRecommended,
          isTrue);
    });

    test('les sections sont ordonnées, les vides ne sont pas rendues', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        sections: const <ZChatToolSection>[
          ZChatToolSection(key: 'late', order: 9),
          ZChatToolSection(key: 'early', order: 1),
          ZChatToolSection(key: 'empty', order: 5),
        ],
        entries: <ZChatToolEntry>[
          _toggle('a', section: 'late'),
          _toggle('b', section: 'early'),
          _toggle('orphan'),
        ],
      );
      final ZChatToolResolution r = c.resolve();
      expect(r.sections.map((ZChatToolResolvedSection s) => s.section.key),
          <String>['early', 'late', kZChatToolSectionUnassigned]);
      expect(r.entries.map((ZChatToolResolvedEntry e) => e.entry.key),
          <String>['b', 'a', 'orphan']);
    });

    test('une entrée déclarée est TOUJOURS soit visible, soit expliquée', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', prominence: ZChatToolProminence.sheet),
          _toggle('b', prominence: ZChatToolProminence.band),
          ZChatToolEntry(
              key: 'c', state: const ZChatToggleState(), revealedBy: 'a'),
        ],
      );
      for (final ZChatToolSurface s in ZChatToolSurface.values) {
        final ZChatToolResolution r = c.resolve(surface: s);
        final Set<String> accounted = <String>{
          ...r.entries.map((ZChatToolResolvedEntry e) => e.entry.key),
          ...r.hidden.keys,
        };
        expect(accounted, c.entries.map((ZChatToolEntry e) => e.key).toSet(),
            reason: 'surface $s');
      }
    });

    test('les clés dupliquées sont écartées : la première déclaration gagne',
        () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          _toggle('a', value: true),
          _toggle('a'),
        ],
      );
      expect(c.entries.length, 1);
      expect(c.entry('a')!.isActive, isTrue);
    });
  });

  group('TOOL-10 — (dé)sérialisation défensive (AD-10) et extension (AD-4)',
      () {
    test('aller-retour complet d\'un catalogue', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        sections: const <ZChatToolSection>[
          ZChatToolSection(key: 's', label: 'Génération', order: 2),
        ],
        entries: <ZChatToolEntry>[
          _toggle('a', value: true, section: 's', label: 'Web'),
          ZChatToolEntry(
            key: 'b',
            state: ZChatCycleState(step: 2, stepCount: 6),
            revealedBy: 'a',
            prominence: ZChatToolProminence.band,
            deactivates: const <String>['a'],
            searchTerms: const <String>['reflexion'],
            stateLabels: const <String, String>{'step.2': 'Léger'},
            countsTowardActive: false,
            order: 3,
            extra: const <String, dynamic>{'host': 1},
            disabledWhen: <ZChatToolRule>[
              ZChatToolRule(
                condition:
                    ZChatToolCondition(inactiveKeys: const <String>['a']),
                reasonToken: 'host.reason.needsA',
              ),
            ],
          ),
          ZChatToolEntry(
            key: 'c',
            state: ZChatScaleState(
                min: 1, max: 5, value: 3, marks: const <double>[1, 3, 5]),
          ),
          ZChatToolEntry(
            key: 'd',
            state: ZChatCatalogState(
              itemKeys: const <String>['x', 'y'],
              selectedKeys: const <String>['x'],
              unavailableKeys: const <String>['y'],
              unavailableReasonToken: 'host.reason.notIndexed',
            ),
          ),
          ZChatToolEntry(key: 'e', state: const ZChatCommandState()),
        ],
      );
      final ZChatToolCatalog back =
          ZChatToolCatalog.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
      expect(back.entries.length, 5);
      expect(back.entry('b')!.disabledWhen.single.reasonToken,
          'host.reason.needsA');
      expect(back.entry('d')!.state, isA<ZChatCatalogState>());
    });

    test('un payload corrompu ne coûte JAMAIS le parent', () {
      expect(ZChatToolCatalog.fromJson('nope').entries, isEmpty);
      expect(ZChatToolCatalog.fromJson(null).sections, isEmpty);
      final ZChatToolCatalog c = ZChatToolCatalog.fromJson(<String, dynamic>{
        'sections': <Object?>['bad', <String, dynamic>{'key': 'ok'}],
        'entries': <Object?>[
          42,
          <String, dynamic>{'state': <String, dynamic>{'kind': 'toggle'}},
          <String, dynamic>{'key': 'noState'},
          <String, dynamic>{
            'key': 'good',
            'state': <String, dynamic>{'kind': 'toggle', 'value': true},
            'prominence': 'bogus',
            'disabled_when': <Object?>[
              'bad',
              <String, dynamic>{'condition': <String, dynamic>{}},
            ],
          },
        ],
      });
      expect(c.sections.single.key, 'ok');
      expect(c.entries.map((ZChatToolEntry e) => e.key), <String>['good']);
      expect(c.entry('good')!.prominence, ZChatToolProminence.auto);
      expect(c.entry('good')!.disabledWhen, isEmpty,
          reason: 'une règle sans raison lisible est écartée, pas devinée');
    });

    test('une NATURE inconnue est préservée verbatim, jamais perdue (AD-4)',
        () {
      final ZChatToolState? s = ZChatToolState.fromJson(<String, dynamic>{
        'kind': 'hostRoulette',
        'active': true,
        'state_token': 'spin.7',
        'data': <String, dynamic>{'seed': 3},
      });
      expect(s, isA<ZChatCustomToolState>());
      expect(s!.kind, 'hostRoulette');
      expect(s.isActive, isTrue);
      expect(s.stateToken, 'spin.7');
      expect((s as ZChatCustomToolState).data['seed'], 3);
      expect(s.cleared.isActive, isFalse);
      expect(s.cleared.kind, 'hostRoulette');
    });

    test('une nature d\'hôte compte comme n\'importe quelle autre', () {
      final ZChatToolCatalog c = ZChatToolCatalog(
        entries: <ZChatToolEntry>[
          ZChatToolEntry(
            key: 'r',
            state: const ZChatCustomToolState(kind: 'hostRoulette', active: true),
          ),
        ],
      );
      expect(c.activeCount, 1);
      expect(c.reset().activeCount, 0);
    });
  });
}
