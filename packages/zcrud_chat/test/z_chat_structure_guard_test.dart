/// Gardes **STRUCTURELLES** de CHAT-2, lues sur les SOURCES.
///
/// Les gardes de comportement (`z_chat_action_flow_test.dart`,
/// `z_chat_token_lifecycle_test.dart`, `z_chat_sm1_test.dart`) vérifient le
/// chemin qui passe par le contrôleur. Elles sont **aveugles** à celui qui le
/// contourne — et c'est précisément ainsi qu'IFFD a produit une « surface B ».
/// Ce fichier est le grep NÉGATIF outillé, exécuté par une machine.
///
/// 🔴 Il complète **G-U1** du kernel
/// (`zcrud_chat_kernel/test/z_chat_action_contract_guard_test.dart`), qui
/// balaie **tous** les `packages/*/lib` et couvre donc `zcrud_chat` sans
/// modification : si le contrôleur invoquait un membre de `ZChatActionExecutor`
/// au lieu de passer par le répartiteur, G-U1 rougirait **en nommant ce
/// fichier**. Vérifié en rejouant sa suite après la création du package.
@TestOn('vm')
library;

import 'package:flutter_test/flutter_test.dart';

import 'support/z_chat_sources.dart';

/// Le fichier du contrôleur.
const String _controller = 'lib/src/presentation/z_chat_controller.dart';

/// Corps de la classe `ZChatController` (lignes dé-commentées).
List<String> _classBody() {
  final List<String> lines = stripped(libFile(_controller));
  final int start = lines.indexWhere(
    (String l) => RegExp(r'^class\s+ZChatController\b').hasMatch(l),
  );
  expect(start, greaterThanOrEqualTo(0),
      reason: '🔴 `ZChatController` introuvable — la garde serait VACUELLE');
  final List<String> body = <String>[];
  for (int i = start + 1; i < lines.length; i++) {
    if (RegExp(r'^\}').hasMatch(lines[i])) break;
    body.add(lines[i]);
  }
  expect(body.length, greaterThan(50),
      reason: '🔴 corps de classe quasi vide (${body.length} lignes) : le '
          'découpeur est cassé, toutes les gardes ci-dessous seraient VACUELLES');
  return body;
}

/// Noms des membres **publics** déclarés au premier niveau de la classe.
Set<String> _publicMembers(List<String> body) {
  // Un membre = une ligne indentée de 2 espaces exactement. Trois formes :
  // getter (`… get nom =>`), méthode/constructeur (`… nom(` ou `… nom<`),
  // champ (`… nom;` ou `… nom =`).
  //
  // 🔴 DÉFAUT DE GARDE TROUVÉ PAR R3 (et corrigé ici) : la forme empruntée à
  // G-U2 terminait par `[(<]`, pour attraper une méthode générique. Sur un
  // CHAMP typé générique (`final ValueNotifier<bool> _canSend = …`), le `<` du
  // TYPE se faisait passer pour l'ouverture de la méthode et la garde capturait
  // `ValueNotifier` comme un « membre public ». Deux conséquences opposées, les
  // deux fausses : le nom d'un type dans l'ensemble attendu (faux positif
  // permanent), et surtout un vrai membre public MASQUÉ derrière la mauvaise
  // capture — l'égalité d'ensemble aurait pu être satisfaite par un contrôleur
  // portant un raccourci de verbe. Le catalogue de ce dépôt ne compte AUCUNE
  // méthode générique de premier niveau : `\(` est exact.
  final RegExp getter = RegExp(r'^\s{2}[\w<>?,\s.]*\bget\s+(\w+)\b');
  final RegExp field = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*\s(\w+)\s*[;=]');
  final RegExp method = RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(');
  final Set<String> names = <String>{};
  for (final String l in body) {
    if (!RegExp(r'^\s{2}\S').hasMatch(l)) continue;
    final RegExpMatch? m =
        getter.firstMatch(l) ?? field.firstMatch(l) ?? method.firstMatch(l);
    if (m == null) continue;
    final String name = m.group(1)!;
    if (name.startsWith('_')) continue;
    if (name == 'ZChatController') continue; // le constructeur
    if (name == 'override') continue;
    names.add(name);
  }
  return names;
}

/// Le SEUL `setState` admis dans `lib/` : l'écriture d'une valeur immuable du
/// domaine (`ZChatToolCatalog.setState`), homonyme du `setState` de Flutter et
/// sans aucun rapport avec lui. Le motif exige le receveur nominal.
final RegExp _kDomainSetState = RegExp(r'\b_?catalog\.setState\s*\(');

void main() {
  group('🔴 G-CH1 — la surface publique du contrôleur, en ÉGALITÉ d\'ENSEMBLE',
      () {
    test('EXACTEMENT les membres attendus — aucun raccourci par verbe', () {
      final Set<String> publics = _publicMembers(_classBody());
      expect(
        publics,
        <String>{
          // Lecture — les tranches réactives.
          'composer',
          'attachmentIds',
          'canSend',
          'messages',
          'activeRequests',
          'lastFailure',
          'liveAnnouncement',
          'streamText',
          'progress',
          'currentDraft',
          'conversationId',
          'maxResumeAttempts',
          // Écriture — trois gestes, pas un de plus.
          'setAttachments',
          'attach',
          'send',
          // 🔴 EXTENSION ARBITRÉE (owner, 2026-08-07 — chantier composer-lex,
          // lot K2). Le mode ÉDITION et le BROUILLON À COMPTEUR de lex
          // (`chat_input_controller.dart:31-48, :357-392`) entrent comme
          // membres du contrôleur — et PAS ailleurs, précisément à cause de
          // G10-P2 : le seul écrivain légitime de la saisie hors capture est ce
          // contrôleur. Aucun de ces membres n'EXÉCUTE un verbe de
          // conversation : ce sont deux tranches de lecture et trois gestes de
          // saisie — la soumission d'une édition reste `runAction`
          // (`ZChatEditAction`), l'unique point d'entrée. La garde a rougi le
          // 2026-08-07 en montrant exactement ces cinq noms, puis a été étendue
          // ICI, délibérément.
          'editing',
          'draftSeeds',
          'startEditing',
          'cancelEditing',
          'seedDraft',
          // 🔴 EXTENSION ARBITRÉE (lot E, 2026-08-22) : CINQ requêtes PURES
          // sur le fil — jamais un verbe. `messageById`/`replyToOf`/`contentOf`
          // remplacent les quatre balayages linéaires qu'IFFD écrit à la main
          // dans l'écran ; `previewEditImpact` est le calcul d'impact d'une
          // édition que lex fait dans `chat_screen.dart:900-960` (mauvais
          // placement : c'est un calcul pur du contrôleur) ; `isInterrupted`
          // est la marque de la garantie d'annulation (partiel conservé ET
          // marqué). Aucune n'écrit, aucune ne notifie, aucune ne lève.
          // L'édition rejouée et la régénération natives, elles, passent
          // TOUJOURS par `runAction` — pas de `editAndResend()` ni de
          // `regenerate()` public : la garde a rougi en montrant exactement
          // ces cinq noms de lecture, puis a été étendue ICI.
          'messageById',
          'replyToOf',
          'contentOf',
          'previewEditImpact',
          'isInterrupted',
          // 🔴 EXTENSION ARBITRÉE (lot L6) : l'AGRÉGAT de propositions et le
          // BROUILLON PERSISTANT. `suggestions` est une tranche de lecture —
          // la même donnée que `progress(requestId).suggestions`, agrégée par
          // conversation parce qu'un composer n'a pas de `requestId` en main.
          // `draftRestored` et `persistsDraft` sont deux lectures d'état ;
          // `saveDraft`/`restoreDraft`/`dismissRestoredDraft` sont trois
          // gestes de SAISIE, jamais des verbes de conversation : ils
          // délèguent à `ZChatDraftStore` et passent, pour écrire dans le
          // champ, par l'écrivain unique `_setComposer` — exactement la
          // raison qui a fait entrer `seedDraft` ici en K2. La soumission
          // reste `send`/`runAction`. La garde a rougi en montrant
          // exactement ces six noms, puis a été étendue ICI, délibérément.
          'suggestions',
          'draftRestored',
          'persistsDraft',
          'saveDraft',
          'restoreDraft',
          'dismissRestoredDraft',
          // 🔴 L'UNIQUE point d'entrée des verbes.
          'runAction',
          'dispose',
        },
        reason: '🔴 ÉGALITÉ D\'ENSEMBLE, pas « contient » (leçon G-U2 de '
            'CHAT-0b). Chaque membre public ajouté qui EXÉCUTE un verbe — '
            '`deleteMessage()`, `stop()`, `regenerateAnswer()`, un callback de '
            'confort — est UN SITE D\'APPEL DE PLUS, donc une divergence '
            'possible entre deux surfaces d\'UI. C\'est EXACTEMENT ce qu\'IFFD '
            'a produit : deux barres d\'actions parallèles dans un fichier de '
            '5153 lignes, dont l\'une confirme la suppression (`:2134`) et '
            'l\'autre non (`:3886`).',
      );
    });

    test('🔬 contre-preuve R3 — l\'extracteur VOIT un raccourci de verbe et ne '
        'prend PAS un type générique pour un membre', () {
      const List<String> witness = <String>[
        '  final ValueNotifier<bool> _canSend = ValueNotifier<bool>(false);',
        '  final Map<String, ZChatRequestToken> _tokens = '
            '<String, ZChatRequestToken>{};',
        '  ValueListenable<List<String>> get attachmentIds => _attachmentIds;',
        '  Future<ZResult<ZChatActionOutcome>> runAction(ZChatAction a) async {',
        // 🔴 LE cas que la garde existe pour attraper.
        '  Future<void> deleteMessage(String id) async {',
      ];
      expect(
        _publicMembers(witness),
        <String>{'attachmentIds', 'runAction', 'deleteMessage'},
        reason: '🔴 si `ValueNotifier`/`Map` reviennent dans l\'ensemble, le '
            'défaut R3 est de retour ; si `deleteMessage` en disparaît, la '
            'garde ne voit plus la « surface B » qu\'elle existe pour '
            'interdire.',
      );
    });
  });

  group('🔴 G-CH2 — un seul site d\'appel du répartiteur', () {
    test('`prepare` et `execute` sont invoqués UNE fois chacun, dans le seul '
        'fichier du contrôleur', () {
      final Map<String, List<String>> lib = strippedLib();
      final Map<String, int> prepares = <String, int>{};
      final Map<String, int> executes = <String, int>{};
      final Map<String, int> constructions = <String, int>{};
      for (final MapEntry<String, List<String>> e in lib.entries) {
        for (final String l in e.value) {
          if (RegExp(r'\.prepare\s*\(').hasMatch(l)) {
            prepares[e.key] = (prepares[e.key] ?? 0) + 1;
          }
          if (RegExp(r'\.execute\s*\(').hasMatch(l)) {
            executes[e.key] = (executes[e.key] ?? 0) + 1;
          }
          if (RegExp(r'ZChatActionDispatcher\s*\(').hasMatch(l)) {
            constructions[e.key] = (constructions[e.key] ?? 0) + 1;
          }
        }
      }

      expect(prepares.values.fold<int>(0, (int a, int b) => a + b), 1,
          reason: '🔴 DEUX chemins de planification : sites $prepares');
      expect(executes.values.fold<int>(0, (int a, int b) => a + b), 1,
          reason: '🔴 DEUX chemins d\'exécution — la « surface B » d\'IFFD, '
              'réintroduite dans le socle : sites $executes');
      expect(constructions.values.fold<int>(0, (int a, int b) => a + b), 1,
          reason: '🔴 un SECOND répartiteur rendrait G-U1 satisfaite et '
              'l\'invariant faux : sites $constructions');
      for (final String path in <String>[
        ...prepares.keys,
        ...executes.keys,
        ...constructions.keys,
      ]) {
        expect(path.replaceAll(r'\', '/'), endsWith(_controller),
            reason: '🔴 le répartiteur est joint depuis un AUTRE fichier');
      }
    });

    test('🔬 contre-preuve — le motif SAIT rougir sur une source témoin', () {
      final RegExp use = RegExp(r'\.execute\s*\(');
      expect(use.hasMatch('await _dispatcher.execute(ticket);'), isTrue);
      expect(use.hasMatch('final x = executeLater;'), isFalse,
          reason: 'sans l\'ancre `.`, la garde crierait au loup — et une garde '
              'qui crie au loup finit désactivée');
    });
  });

  group('🔴 G-CH3 — AUCUN jeton d\'INSTANCE (le défaut IFFD exact)', () {
    /// Détecte un champ dont le type déclaré **est** `ZChatRequestToken`
    /// (éventuellement nullable) — la forme
    /// `CancelToken cancel = CancelToken();` d'IFFD.
    ///
    /// 🔴 Volontairement PAS restreint à `final|late|static|var` : un champ
    /// mutable s'écrit `ZChatRequestToken? _current;` — sans aucun mot-clé.
    /// C'est le défaut de garde qu'une INJECTION R3 du lot CHAT-0b a démontré.
    /// Une table `Map<String, ZChatRequestToken>` est au contraire la forme
    /// CORRECTE (l'annulation s'adresse à une identité) et ne doit pas rougir.
    bool bareTokenField(String line) => RegExp(
      r'^\s{2}(?:final\s+|late\s+|static\s+|var\s+)*ZChatRequestToken\??\s+\w+\s*[;=]',
    ).hasMatch(line);

    test('aucun champ de type `ZChatRequestToken` dans `lib/`', () {
      final List<String> offenders = <String>[];
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          if (bareTokenField(e.value[i])) {
            offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: '🔴 JETON D\'INSTANCE — la forme exacte du défaut IFFD '
            '(`iffd_ai_repository_impl.dart:29`, `:375-377` : '
            '`CancelToken cancel = CancelToken();` en champ d\'un dépôt '
            'SINGLETON). Annuler y coupe « la courante », c\'est-à-dire la '
            'DERNIÈRE lancée. Le jeton doit être indexé PAR `requestId`.\n'
            '${offenders.join('\n')}',
      );
    });

    test('…et la table indexée PAR identité, elle, existe bien', () {
      final String src = stripped(libFile(_controller)).join('\n');
      expect(
        RegExp(r'Map<String,\s*ZChatRequestToken>\s+_tokens').hasMatch(src),
        isTrue,
        reason: '🔴 GARDE VACUELLE : plus aucune table de jetons — la garde '
            'ci-dessus passerait sur un contrôleur qui n\'annule plus rien',
      );
    });

    test('🔬 contre-preuve — le motif distingue le CHAMP de la TABLE', () {
      expect(bareTokenField('  ZChatRequestToken? _current;'), isTrue,
          reason: '🔴 la variante SANS mot-clé est la plus discrète : une garde '
              'qui ne chercherait que `final|late|static|var` la raterait');
      expect(bareTokenField('  final ZChatRequestToken _token = t;'), isTrue);
      expect(
        bareTokenField(
          '  final Map<String, ZChatRequestToken> _tokens = '
          '<String, ZChatRequestToken>{};',
        ),
        isFalse,
        reason: '🔴 la table PAR IDENTITÉ est la forme CORRECTE : la dénoncer '
            'rendrait la garde inutilisable',
      );
    });
  });

  group('🔴 G-CH4 — un SEUL écrivain de la saisie de l\'utilisateur', () {
    /// Une **écriture** de la saisie (jamais une lecture).
    bool composerWrite(String line) => RegExp(
      r'composer\.(text\s*=[^=]|value\s*=[^=]|clear\s*\(|selection\s*=[^=])',
    ).hasMatch(line);

    test('`composer.text = …` / `.clear()` n\'apparaît que dans `_setComposer`',
        () {
      final List<String> body = _classBody();
      final List<String> sites = <String>[];
      String current = '';
      for (final String l in body) {
        final RegExpMatch? decl = RegExp(
          r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s(\w+)\s*\(',
        ).firstMatch(l);
        if (decl != null) current = decl.group(1)!;
        if (composerWrite(l)) sites.add('$current → ${l.trim()}');
      }
      expect(sites, isNotEmpty,
          reason: '🔴 GARDE VACUELLE : plus AUCUNE écriture de la saisie — le '
              'contrôleur ne viderait plus le champ à l\'envoi');
      expect(
        sites.map((String s) => s.split(' → ').first).toSet(),
        <String>{'_setComposer'},
        reason: '🔴 PLUSIEURS chemins écrivent dans le champ de saisie. C\'est '
            'ainsi qu\'IFFD en est arrivé à `:3618-3672`, où la poubelle de '
            '« Réflexion en cours » arrête la génération PUIS supprime la '
            'question tapée. Sites : $sites',
      );
    });

    test('le chemin d\'ANNULATION n\'appelle pas l\'écrivain de la saisie', () {
      final List<String> body = _classBody();
      // Bloc de `runAction` : depuis sa déclaration jusqu'à la déclaration du
      // membre suivant.
      final int start = body.indexWhere(
        (String l) => RegExp(r'^\s{2}\S.*\srunAction\s*\(').hasMatch(l),
      );
      expect(start, greaterThanOrEqualTo(0), reason: '`runAction` introuvable');
      int end = body.length;
      for (int i = start + 1; i < body.length; i++) {
        if (RegExp(r'^\s{2}[A-Za-z_][\w<>?,\s.]*?\s\w+\s*\(').hasMatch(body[i])) {
          end = i;
          break;
        }
      }
      final String scope = body.sublist(start, end).join('\n');
      expect(scope.contains('ZChatCancelAction'), isTrue,
          reason: '🔴 GARDE VACUELLE : le bloc découpé ne contient pas le '
              'chemin d\'annulation');
      expect(
        scope.contains('_setComposer'),
        isFalse,
        reason: '🔴 le point d\'entrée des verbes écrit dans la saisie : le '
            'défaut IFFD « annuler = supprimer la question tapée » redevient '
            'exprimable',
      );
    });

    test('🔬 contre-preuve — le motif voit les écritures, pas les lectures', () {
      expect(composerWrite('    composer.text = draft.text;'), isTrue);
      expect(composerWrite('    composer.clear();'), isTrue);
      expect(composerWrite('    if (composer.text != draft.text) {'), isFalse,
          reason: '🔴 une comparaison N\'EST PAS une écriture — sans le '
              '`[^=]`, la garde se dénoncerait elle-même');
      expect(composerWrite('    final String t = composer.text;'), isFalse);
    });
  });

  // 🔴 G-CH5 — ÉVOLUTION CHAT-3, et pourquoi ce n'est PAS un relâchement.
  //
  // La forme CHAT-2 disait : « AUCUN widget déclaré dans ce package », au motif
  // que « le RENDU appartient au lot C3 ». CHAT-3 EST le lot C3 : le motif de la
  // garde est éteint, et la garder telle quelle aurait interdit la story
  // elle-même. La question n'est donc pas de la lever mais de savoir ce qu'elle
  // protégeait RÉELLEMENT — et cela, elle le dit dans son propre message : « les
  // couleurs, les libellés et les `setState` que ce package existe pour tenir à
  // distance ».
  //
  // Les trois sont donc RÉ-ASSERTÉS, plus finement qu'avant :
  // * couleurs codées en dur → `z_chat_purity_test.dart` (inchangé, il balaie
  //   TOUT `lib/`, rendu compris) ;
  // * libellés en dur → `z_chat_render_guard_test.dart` (nouveau, et il n'y
  //   avait AUCUNE garde de ce type auparavant : G-CH5 n'interdisait pas les
  //   chaînes, elle interdisait les widgets) ;
  // * `setState` → ci-dessous, et RESSERRÉ : CHAT-2 ne pouvait pas voir un
  //   `setState` puisqu'il n'y avait pas de `State`. La garde en interdit
  //   désormais l'usage dans TOUT le package, y compris le rendu.
  //
  // Reste inchangé : le fichier du CONTRÔLEUR ne déclare toujours aucun widget.
  group('🔴 G-CH5 — le CONTRÔLEUR ne rend aucun pixel, et NUL ne `setState`',
      () {
    const String controllerPath = 'lib/src/presentation/z_chat_controller.dart';
    final RegExp widgetDecl = RegExp(
      r'\b(extends|implements|with)\s+(Stateless|Stateful)Widget\b|'
      r'\bextends\s+State<|\bWidget\s+build\s*\(',
    );

    test('aucun widget déclaré dans le fichier du contrôleur', () {
      final Map<String, List<String>> lib = strippedLib();
      final List<String> controllerFiles = <String>[
        for (final String p in lib.keys)
          if (p.replaceAll(r'\', '/').endsWith(controllerPath)) p,
      ];
      expect(controllerFiles, hasLength(1),
          reason: '🔴 GARDE VACUELLE : `$controllerPath` introuvable');
      final List<String> lines = lib[controllerFiles.single]!;
      final List<String> offenders = <String>[
        for (int i = 0; i < lines.length; i++)
          if (widgetDecl.hasMatch(lines[i])) '${i + 1}: ${lines[i].trim()}',
      ];
      expect(
        offenders,
        isEmpty,
        reason: '🔴 le contrôleur porte l\'ÉTAT, pas les pixels. Un widget '
            'déclaré dans ce fichier ferait cohabiter la machine à jetons et '
            'un `build()` — le chemin le plus court vers le `setState` global '
            'que ce package existe pour tenir à distance. Le rendu vit sous '
            '`presentation/render|view/`.\n${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — le motif VOIT une déclaration de widget', () {
      // Sans ceci, une regex cassée rendrait le test ci-dessus vacuellement
      // vert quel que soit le contenu du contrôleur.
      for (final String witness in <String>[
        'class Foo extends StatelessWidget {',
        'class _S extends State<Foo> {',
        '  Widget build(BuildContext context) {',
      ]) {
        expect(widgetDecl.hasMatch(witness), isTrue,
            reason: '🔴 le motif est aveugle à `$witness`');
      }
      expect(widgetDecl.hasMatch('  final ZChatDraft draft = currentDraft;'),
          isFalse);
    });

    test('AUCUN `setState` nulle part — rendu compris (AD-2)', () {
      final List<String> offenders = <String>[];
      final List<String> domainWrites = <String>[];
      int scanned = 0;
      for (final MapEntry<String, List<String>> e in strippedLib().entries) {
        for (int i = 0; i < e.value.length; i++) {
          scanned++;
          if (!RegExp(r'\bsetState\s*\(').hasMatch(e.value[i])) continue;
          // 🔴 HOMONYMIE, pas relâchement. `ZChatToolCatalog.setState` est
          // l'écriture d'une VALEUR immuable du domaine (elle rend un nouveau
          // catalogue) : elle ne reconstruit aucun sous-arbre. Seul l'appel
          // QUALIFIÉ par le catalogue est admis ; `setState(` nu et
          // `this.setState(` restent interdits (contre-preuve ci-dessous).
          if (_kDomainSetState.hasMatch(e.value[i])) {
            domainWrites.add('${e.key}:${i + 1}');
            continue;
          }
          offenders.add('${e.key}:${i + 1}: ${e.value[i].trim()}');
        }
      }
      // L'exemption ne doit pas devenir PENDANTE : si plus personne n'écrit le
      // catalogue d'outils, elle se retire.
      expect(domainWrites, isNotEmpty,
          reason: '🔴 exemption PENDANTE : aucune écriture de catalogue vue');
      for (final String site in domainWrites) {
        expect(site, contains('presentation/tools/'),
            reason: '🔴 l\'exemption d\'homonymie ne vaut que pour '
                'l\'écriture du catalogue d\'outils : $site');
      }
      expect(scanned, greaterThan(200),
          reason: '🔴 GARDE VACUELLE : seulement $scanned lignes scannées');
      expect(
        offenders,
        isEmpty,
        reason: '🔴 AD-2, objectif produit n°1 : la réactivité passe par des '
            'tranches `ValueListenable`. Un `setState` reconstruit tout le '
            'sous-arbre du `State` — sur une tuile de conversation, cela '
            'signifie re-rendre TOUS ses blocs à chaque bascule de dépli.\n'
            '${offenders.join('\n')}',
      );
    });

    test('🔬 contre-preuve — l\'exemption d\'HOMONYMIE reste étroite', () {
      // Ce que l'exemption laisse passer…
      expect(_kDomainSetState.hasMatch('    _catalog.setState(key, next);'),
          isTrue);
      // …et tout ce qu'elle NE laisse PAS passer : un `setState` de widget,
      // sous chacune de ses formes.
      for (final String witness in <String>[
        '    setState(() {});',
        '    this.setState(() {});',
        '    widget.setState(() {});',
        '    _controller.setState(() {});',
      ]) {
        expect(_kDomainSetState.hasMatch(witness), isFalse,
            reason: '🔴 l\'exemption attrape `$witness` : ce n\'est plus une '
                'homonymie, c\'est une porte');
        expect(RegExp(r'\bsetState\s*\(').hasMatch(witness), isTrue);
      }
    });

    test('🔬 contre-preuve — le motif `setState` voit son témoin', () {
      expect(RegExp(r'\bsetState\s*\(').hasMatch('    setState(() {});'),
          isTrue);
      expect(RegExp(r'\bsetState\s*\(').hasMatch('  // pas de setState ici'),
          isFalse,
          reason: '🔴 sans le `\\(`, une simple mention en prose accuserait');
    });
  });
}
