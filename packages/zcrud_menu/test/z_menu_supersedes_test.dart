/// 🔴 Garde **ANTI-DOUBLON APPAUVRI** (leçon CR-LEX-78) — version CHAT-4b.
///
/// ## Ce qui a changé, et pourquoi cette garde a dû être RETENDUE
///
/// En CHAT-4, `zcrud_study` n'était pas modifiable : cette garde comparait donc
/// DEUX menus coexistants, capacité par capacité, avec un contrôle positif sur
/// le fichier de l'existant. Sa dartdoc prévoyait explicitement le jour où la
/// façade serait livrée : « Si le fichier a été déplacé ou supprimé (façade
/// livrée ?), METTRE À JOUR cette garde, ne pas la laisser verte à vide. »
///
/// CHAT-4b a livré cette façade. `ZItemActionsMenu` ne construit plus AUCUN
/// `PopupMenuButton` : il délègue à [ZActionMenu]. La moitié « contrôle positif
/// chez l'existant » de la table est donc devenue FAUSSE par construction — et
/// la moitié « supériorité stricte » aussi, puisque la façade expose désormais
/// `permitted`, `disabledReason`, `ZMenuEntryTile`… C'était le SUCCÈS attendu,
/// pas une régression.
///
/// 🔴 La garde n'est pas AFFAIBLIE pour autant — elle est REPOINTÉE sur trois
/// affirmations qui, elles, peuvent encore casser :
///
/// 1. **PRÉSERVATION** — les 15 capacités de l'ancien `ZItemActionsMenu` ont
///    toujours un pendant DANS `zcrud_menu`. C'est la moitié qui portait
///    réellement le risque « doublon appauvri » : retirer `excludeSemantics`
///    de `ZMenuEntryTile` ou le filtrage amont de `ZActionMenu` rougit ici.
/// 2. **ABSORPTION** — la façade est un CONSOMMATEUR : grep NÉGATIF prouvant
///    qu'aucun `PopupMenu*` n'y subsiste, plus la preuve POSITIVE qu'elle
///    délègue. C'est ce qui interdit la réapparition du second menu.
/// 3. **ACCESSIBILITÉ** — les capacités supérieures de `zcrud_menu` sont
///    ATTEIGNABLES depuis la façade. Une capacité livrée mais inatteignable
///    par l'hôte historique ne vaut rien (c'est le reproche de CR-LEX-78 sous
///    une autre forme).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'menu_test_support.dart';

/// Une capacité et le motif qui la prouve dans `zcrud_menu/lib/`.
class _Capacite {
  const _Capacite(this.nom, this.chezNous, {this.fichier});

  /// Ce que la capacité fait.
  final String nom;

  /// Motif prouvant la capacité dans `zcrud_menu/lib/`.
  final String chezNous;

  /// 🔴 Fichier où le motif DOIT se trouver (findings F3/F4 de la revue de fin
  /// d'epic CHAT).
  ///
  /// Sans cet ancrage, la table est évaluée sur la CONCATÉNATION de tout
  /// `lib/` : un motif partagé par deux fichiers rend la capacité de l'un
  /// satisfaite par l'autre. Mesuré : `z_menu_trigger.dart` **entièrement
  /// vidé** ⇒ 1 seul rouge sur 34, et « glyphe de déclencheur injecté » restait
  /// VERT (couvert par le `final IconData? icon;` de l'ENTRÉE) ; plancher de
  /// `ZMenuEntryTile` mis à 0 ⇒ « cible ≥ 48 dp explicite » restait VERT
  /// (couvert par le `ConstrainedBox` du DÉCLENCHEUR).
  final String? fichier;
}

/// Une capacité et le motif qui la prouve dans le fichier de la FAÇADE.
class _CapaciteFacade {
  const _CapaciteFacade(this.nom, this.chezLaFacade);

  /// Ce que la capacité fait.
  final String nom;

  /// Motif prouvant la capacité dans le fichier de `ZItemActionsMenu`.
  final String chezLaFacade;
}

const String _fichierFacade =
    'packages/zcrud_study/lib/src/presentation/z_item_actions_menu.dart';

/// Les 15 capacités de l'ancien `ZItemActionsMenu`, et leur pendant ICI.
///
/// La colonne « chez l'existant » a disparu : l'existant, c'est désormais NOUS.
/// Ce que la table garde, c'est qu'aucune de ces 15 capacités ne peut être
/// perdue par une refonte de `zcrud_menu`.
const List<_Capacite> _capacites = <_Capacite>[
  _Capacite('action déclarée en donnée immuable', 'class ZMenuEntry'),
  _Capacite('libellé injecté', 'final String label;'),
  _Capacite('glyphe injecté', 'final IconData? icon;'),
  _Capacite('callback de sélection', 'final VoidCallback? onSelected;'),
  _Capacite(
    "règle d'absence AD-4",
    'onSelected != null || disabledReason != null',
  ),
  _Capacite('filtrage AMONT partagé', 'toList(growable: false)'),
  _Capacite(
    'glyphe de déclencheur injecté',
    'final IconData? icon;',
    fichier: 'z_menu_trigger.dart',
  ),
  _Capacite('label a11y du déclencheur', 'final String? tooltip;'),
  _Capacite('slot de présentation du contenu', 'typedef ZMenuContentBuilder'),
  _Capacite(
    'cible ≥ 48 dp explicite',
    'minHeight: kZMenuMinTapTarget',
    fichier: 'z_menu_entry_tile.dart',
  ),
  _Capacite('Semantics non dupliquées', 'excludeSemantics: true'),
  _Capacite(
    'entrée NUE pour le contenu injecté',
    'extends PopupMenuEntry<ZMenuEntry>',
  ),
  _Capacite('aucune valeur représentée', 'represents('),
  _Capacite('sortie par Navigator.pop', 'Navigator.of(context).pop('),
  _Capacite(
    'vocabulaire de nature partagé',
    'abstract final class ZMenuEntryIds',
  ),
];

/// Ce que la FAÇADE doit porter pour que les capacités supérieures de
/// `zcrud_menu` soient réellement ATTEIGNABLES par un hôte historique.
const List<_CapaciteFacade> _atteignables = <_CapaciteFacade>[
  _CapaciteFacade("droit séparé de l'effet", 'final bool permitted;'),
  _CapaciteFacade(
    'entrée désactivée AVEC motif',
    'final String? disabledReason;',
  ),
  _CapaciteFacade(
    'assert droit/effet exclusifs',
    'onSelected == null || disabledReason == null',
  ),
  _CapaciteFacade('identités partagées', 'ZMenuEntryIds.'),
  _CapaciteFacade('identité surchargeable par action', 'String get entryId'),
  _CapaciteFacade(
    'projection vers l\'entrée neutre',
    'ZMenuEntry toMenuEntry()',
  ),
  _CapaciteFacade('nature destructive dérivée', 'isDestructive:'),
  _CapaciteFacade('cellule a11y offerte au slot', 'ZMenuEntryTile'),
  _CapaciteFacade('renderer substituable', 'final ZMenuRenderer? renderer;'),
  _CapaciteFacade('déclencheur déclaré en données', 'ZMenuTrigger('),
];

/// Motifs dont la présence dans la façade signerait la RÉAPPARITION du doublon.
const List<String> _interdits = <String>[
  'PopupMenuButton',
  'PopupMenuItem',
  'PopupMenuEntry',
  'showMenu(',
];

void main() {
  final facade = File('${repoRoot().path}/$_fichierFacade');
  final parFichier = libCode('zcrud_menu');
  final nous = parFichier.values.join('\n');

  /// Source du fichier NOMMÉ, ou `null` s'il n'existe plus.
  String? fichier(String nom) {
    for (final e in parFichier.entries) {
      if (e.key.endsWith('/$nom')) return e.value;
    }
    return null;
  }

  test('contrôle positif : le fichier de la façade est lisible', () {
    expect(
      facade.existsSync(),
      isTrue,
      reason:
          'ZItemActionsMenu introuvable ($_fichierFacade) — cette garde ne '
          'garde plus rien. Si le fichier a été déplacé, METTRE À JOUR le '
          'chemin, ne pas laisser la garde verte à vide.',
    );
    expect(nous, isNotEmpty, reason: 'contrôle positif : lib/ de zcrud_menu');
  });

  final source = facade.existsSync()
      ? stripComments(facade.readAsStringSync())
      : '';

  group('1. PRÉSERVATION — les 15 capacités historiques vivent ici', () {
    for (final c in _capacites) {
      test(c.nom, () {
        // 🔴 Quand la capacité est ANCRÉE, elle est cherchée dans SON fichier
        // et nulle part ailleurs — sinon un homonyme d'un autre fichier la
        // satisfait (F3/F4).
        final ancre = c.fichier;
        String? portee = nous;
        if (ancre != null) {
          portee = fichier(ancre);
          expect(
            portee,
            isNotNull,
            reason:
                'CAPACITÉ PERDUE : le fichier « $ancre » n\'existe plus '
                'dans zcrud_menu/lib — la capacité « ${c.nom} » n\'a plus de '
                'porteur. Si le fichier a été RENOMMÉ, mettre à jour l\'ancre ; '
                'ne pas retirer l\'ancre (ce serait rendre la garde satisfiable '
                'par n\'importe quel autre fichier).',
          );
        }
        expect(
          (portee ?? '').contains(c.chezNous),
          isTrue,
          reason:
              'CAPACITÉ PERDUE : « ${c.nom} » n\'a plus de pendant dans '
              '${c.fichier ?? "zcrud_menu"} (motif attendu : '
              '« ${c.chezNous} »). Depuis CHAT-4b '
              'ce package est la SEULE source : la perdre ici, c\'est la perdre '
              'partout — exactement le doublon appauvri que CR-LEX-78 interdit.',
        );
      });
    }
  });

  group('2. ABSORPTION — la façade est un CONSOMMATEUR, pas un second menu', () {
    test('contrôle positif : la façade contient bien du code', () {
      expect(source, isNotEmpty);
      expect(
        source.contains('class ZItemActionsMenu'),
        isTrue,
        reason:
            'sonde : sans ce motif, les greps négatifs ci-dessous '
            'seraient verts sur un fichier vide ou renommé',
      );
    });

    test('elle IMPORTE la couture', () {
      expect(
        source.contains("import 'package:zcrud_menu/zcrud_menu.dart';"),
        isTrue,
        reason: 'la façade doit consommer zcrud_menu, pas le paraphraser',
      );
    });

    test('elle DÉLÈGUE à ZActionMenu', () {
      expect(
        source.contains('return ZActionMenu('),
        isTrue,
        reason:
            'le rendu doit passer par le point d\'entrée unique de la '
            'couture — sinon la délégation n\'est que décorative',
      );
    });

    for (final motif in _interdits) {
      test('grep NÉGATIF : aucun « $motif » construit en dur', () {
        expect(
          source.contains(motif),
          isFalse,
          reason:
              '🔴 « $motif » est REVENU dans $_fichierFacade. Le socle '
              'porterait de nouveau DEUX menus — le doublon que CHAT-4b a '
              'supprimé. Le déclencheur et la surface appartiennent au '
              'ZMenuRenderer, jamais à la façade.',
        );
      });
    }

    test('elle ne RE-FILTRE pas la règle d\'absence (site unique)', () {
      // `zVisibleMenuEntries` (ZActionMenu) est le site UNIQUE du filtrage AD-4.
      // Le refaire dans la façade recréerait la seconde source à corriger deux
      // fois — et les deux pourraient diverger sans que rien ne rougisse.
      expect(
        source.contains('.where('),
        isFalse,
        reason:
            '🔴 la façade re-filtre ses actions : le filtrage AD-4 a un '
            'site UNIQUE (zVisibleMenuEntries, dans ZActionMenu).',
      );
    });
  });

  group('3. ACCESSIBILITÉ — les capacités supérieures sont ATTEIGNABLES', () {
    for (final c in _atteignables) {
      test(c.nom, () {
        expect(
          source.contains(c.chezLaFacade),
          isTrue,
          reason:
              '🔴 « ${c.nom} » n\'est pas atteignable depuis '
              'ZItemActionsMenu (motif attendu : « ${c.chezLaFacade} »). Une '
              'capacité livrée dans zcrud_menu mais inatteignable par l\'hôte '
              'historique (IFFD, lex) ne vaut rien : il continuera de la '
              'compenser à la main.',
        );
      });
    }
  });

  test('la surface publique ne nomme NI chat NI message', () {
    // Directive owner : ce package sert un item de liste, une carte, une barre
    // d'app et un message — la même couture. Un type nommé « message » le
    // rendrait trop étroit.
    final barrel = File(
      '${repoRoot().path}/packages/zcrud_menu/lib/zcrud_menu.dart',
    ).readAsStringSync();
    expect(barrel.contains('export'), isTrue, reason: 'contrôle positif');
    final fautes = <String>[];
    for (final m in RegExp(
      r'\b(class|typedef|enum)\s+(Z\w+)',
    ).allMatches(stripComments(nous))) {
      final nom = m.group(2)!.toLowerCase();
      if (nom.contains('chat') || nom.contains('message')) fautes.add(nom);
    }
    expect(fautes, isEmpty, reason: 'types trop étroits : $fautes');
  });
}
