// Référence d'API zcrud : lance `dart doc` sur chaque paquet de `packages/**`
// et assemble la sortie sous `website/static/api/<pkg>/` (servie en `/api`
// par le site Docusaurus). Produit aussi `website/static/api/index.html` :
// un index autonome, en français, sans dépendance externe, thème
// clair/sombre via `prefers-color-scheme`, groupant les paquets par
// capacité (même découpage que `docs/site/paquets/index.md`).
//
// Usage :
//   dart run scripts/doc/build_api_docs.dart
//
// Comportement :
//   - `dart doc` tourne pour CHAQUE paquet, dans son propre dossier (cwd),
//     avec sortie directe sous `website/static/api/<pkg>` (pas de copie).
//   - Un échec sur un paquet est CONSIGNÉ et n'interrompt PAS la boucle
//     (best-effort — un paquet en échec reste listé dans l'index, non
//     cliquable, avec la mention « documentation indisponible »).
//   - Un paquet dépasse 6 minutes ⇒ tué et compté en échec (garde-fou contre
//     un `dart doc` qui resterait accroché).
//   - RC final : 0 si AU MOINS un paquet a réussi, 1 sinon (aucun succès).
//
// `website/static/api/**` est gitignoré (régénéré avant chaque publication,
// cf. CLAUDE.md) — cet index est donc reconstruit à chaque exécution à partir
// des résultats RÉELS de la boucle courante, jamais d'une liste figée.
import 'dart:io';

void _info(String message) => stdout.writeln(message);

/// Racine du dépôt, demandée directement à git (fiable quel que soit le cwd
/// d'invocation — `melos run doc:api` comme un lancement manuel).
Directory _repoRoot() {
  final result = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (result.exitCode != 0) {
    stderr.writeln(
      '[doc:api] ÉCHEC — impossible de localiser la racine du dépôt git : '
      '${(result.stderr as String).trim()}',
    );
    exit(2);
  }
  return Directory((result.stdout as String).trim());
}

class _PackageResult {
  final String name;
  final bool ok;
  final Duration duration;
  final int? warnings;
  final String? error;

  const _PackageResult({
    required this.name,
    required this.ok,
    required this.duration,
    this.warnings,
    this.error,
  });
}

/// Dernière(s) ligne(s) non vide(s) d'une sortie process — utilisées pour
/// résumer un échec sans noyer la console dans un log complet de `dart doc`.
String _lastNonEmptyLines(String text, int count) {
  final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  if (lines.isEmpty) return '(sortie vide)';
  final tail = lines.length > count ? lines.sublist(lines.length - count) : lines;
  return tail.join(' | ');
}

final RegExp _summaryRe = RegExp(r'Found (\d+) warnings? and (\d+) errors?');

Future<_PackageResult> _buildPackageDoc(Directory pkgDir, Directory apiDir, String name) async {
  final outputDir = Directory('${apiDir.path}/$name');
  final stopwatch = Stopwatch()..start();
  final stdoutBuf = StringBuffer();
  final stderrBuf = StringBuffer();
  Process process;
  try {
    process = await Process.start(
      'dart',
      ['doc', '.', '--output', outputDir.path],
      workingDirectory: pkgDir.path,
    );
  } catch (e) {
    stopwatch.stop();
    return _PackageResult(name: name, ok: false, duration: stopwatch.elapsed, error: 'lancement impossible : $e');
  }

  final stdoutDone = process.stdout.transform(const SystemEncoding().decoder).listen(stdoutBuf.write).asFuture<void>();
  final stderrDone = process.stderr.transform(const SystemEncoding().decoder).listen(stderrBuf.write).asFuture<void>();

  int exitCode;
  var timedOut = false;
  try {
    exitCode = await process.exitCode.timeout(
      const Duration(minutes: 6),
      onTimeout: () {
        timedOut = true;
        process.kill(ProcessSignal.sigkill);
        return -1;
      },
    );
  } finally {
    await Future.wait([stdoutDone, stderrDone]);
  }
  stopwatch.stop();

  final combined = '${stdoutBuf.toString()}${stderrBuf.toString()}';

  if (!timedOut && exitCode == 0 && File('${outputDir.path}/index.html').existsSync()) {
    final match = _summaryRe.firstMatch(combined);
    final warnings = match != null ? int.tryParse(match.group(1)!) : null;
    return _PackageResult(name: name, ok: true, duration: stopwatch.elapsed, warnings: warnings);
  }

  final error = timedOut
      ? 'dépassement du délai (6 min) — processus tué'
      : 'RC=$exitCode — ${_lastNonEmptyLines(combined, 3)}';
  return _PackageResult(name: name, ok: false, duration: stopwatch.elapsed, error: error);
}

// ---------------------------------------------------------------------------
// Index HTML — mêmes 9 catégories et mêmes rôles en une ligne que la fiche
// docs/site/paquets/index.md (source validée par la charte documentaire) ;
// ce script n'écrit AUCUN fichier sous docs/site/ (interdiction du périmètre).
// ---------------------------------------------------------------------------

class _CatEntry {
  final String pkg;
  final String role;
  const _CatEntry(this.pkg, this.role);
}

class _Category {
  final String title;
  final List<_CatEntry> entries;
  const _Category(this.title, this.entries);
}

const List<_Category> _categories = [
  _Category('Cœur', [
    _CatEntry(
      'zcrud_core',
      "Domaine pur et moteur d'édition Flutter-natif : ZFieldSpec, ports, thème, l10n, ZcrudScope.",
    ),
    _CatEntry('zcrud_annotations', 'Annotations @ZcrudModel/@ZcrudField/@ZcrudId, lues par le générateur.'),
    _CatEntry(
      'zcrud_generator',
      "Générateur build_runner : (dé)sérialisation, ZFieldSpec[] et enregistrement au registre.",
    ),
  ]),
  _Category('Bindings d\'état', [
    _CatEntry('zcrud_riverpod', 'Binding état/injection Riverpod (optionnel) — cible lex_douane/IFFD.'),
    _CatEntry('zcrud_get', 'Binding état/injection GetX + get_it (optionnel) — cible DODLP.'),
    _CatEntry('zcrud_provider', "Binding état/injection provider (optionnel)."),
  ]),
  _Category('Liste & données', [
    _CatEntry('zcrud_list', 'Backend de liste Syncfusion (SfDataGrid) derrière le port ZListRenderer du cœur.'),
    _CatEntry('zcrud_firestore', 'Adaptateurs Firestore/Hive offline-first derrière les ports neutres du cœur.'),
    _CatEntry(
      'zcrud_select',
      "Présentateur de sélection (page/dialogue/feuille) au-dessus d'un fork vendored d'awesome_select.",
    ),
  ]),
  _Category('Rich-text', [
    _CatEntry(
      'zcrud_markdown',
      'Édition/lecture Markdown riche (Quill) avec ZCodec pluggable et embeds LaTeX/tableaux.',
    ),
    _CatEntry(
      'zcrud_html',
      'Champ HTML riche via WebView à contrôleur isolé — exclusif de zcrud_markdown.',
    ),
  ]),
  _Category('Étude', [
    _CatEntry(
      'zcrud_study',
      "Orchestration de présentation des outils d'étude (sections paramétriques, layout sectionné).",
    ),
    _CatEntry(
      'zcrud_study_kernel',
      "Noyau bas niveau de l'étude : dossiers, hiérarchie à 2 niveaux, modes de révision, sélecteur de session.",
    ),
    _CatEntry(
      'zcrud_session',
      "Moteur de session (ZStudySessionEngine) : file SRS cyclique, écriture par seam reviewCard unique.",
    ),
    _CatEntry(
      'zcrud_flashcard',
      "Flashcards en répétition espacée : modèle, planificateur SuperMemo-2, dossiers/sessions, repository offline-first.",
    ),
    _CatEntry('zcrud_exam', 'Domaine des examens datés (rappels, calcul de proximité par horloge injectée).'),
    _CatEntry('zcrud_mindmap', 'Cartes mentales : arbre immuable, vue à disposition automatique, éditeur en plan.'),
    _CatEntry(
      'zcrud_note',
      "Domaine des notes intelligentes à contenu Delta typé, avec extension audio optionnelle.",
    ),
    _CatEntry(
      'zcrud_document',
      "Domaine des documents d'étude partageables et de leur état de lecture personnel.",
    ),
  ]),
  _Category('Chat', [
    _CatEntry('zcrud_chat', "Contrôleur de conversation Flutter-natif (tranches ValueListenable, flux reprenables)."),
    _CatEntry(
      'zcrud_chat_kernel',
      "Noyau neutre de conversation IA (messages, blocs de contenu, sources, quotas).",
    ),
    _CatEntry('zcrud_chat_markdown', 'Rendu Markdown/LaTeX du chat, derrière le seam ZChatRenderer.'),
    _CatEntry(
      'zcrud_chat_material',
      "Builders Material calqués sur la référence lex_douane pour le composeur et les réglages de chat.",
    ),
    _CatEntry(
      'zcrud_chat_study',
      "Pont chat → SRS : cartes générées depuis les conversations, pool d'étude dédupliqué.",
    ),
    _CatEntry(
      'zcrud_chat_syncfusion',
      "Coquille Syncfusion AI AssistView et normalisation de flux texte, derrière ZChatRenderer.",
    ),
  ]),
  _Category('Champs spécialisés', [
    _CatEntry('zcrud_geo', 'Champs géo (point/aire/cercle/tracé) avec adaptateur carte OpenStreetMap optionnel.'),
    _CatEntry(
      'zcrud_geo_location',
      "Résolveur de position courante (geolocator) pour zcrud_geo, sans fuite de type SDK.",
    ),
    _CatEntry('zcrud_intl', 'Champs téléphone/pays/adresse avec métadonnées embarquées hors-ligne.'),
    _CatEntry(
      'zcrud_media',
      "Champ média (dépôt/aperçu/vignette vidéo) au-dessus du port ZFilePicker du cœur.",
    ),
    _CatEntry('zcrud_field_extras', 'Champs spécialisés PIN / autocomplétion / tableau éditable / icône.'),
  ]),
  _Category('Export', [
    _CatEntry('zcrud_export', 'Export tabulaire Excel/PDF (Syncfusion) derrière une API neutre en octets.'),
    _CatEntry(
      'zcrud_export_pdf',
      "Export PDF (gabarits de flashcards et documents tabulaires), sans dépendance tableur.",
    ),
    _CatEntry(
      'zcrud_export_ui',
      "Destinations d'export plateforme : aperçu/impression/partage PDF et rastérisation LaTeX.",
    ),
  ]),
  _Category('UI & navigation', [
    _CatEntry(
      'zcrud_ui_kit',
      "Widgets d'état de contenu (vide/chargement/erreur) et boîte de dialogue de confirmation thémée.",
    ),
    _CatEntry('zcrud_responsive', 'Classes de largeur de fenêtre (Material 3) et valeurs par point de rupture.'),
    _CatEntry(
      'zcrud_menu',
      "Menus contextuels découplés derrière un seam neutre, avec repli Material sans dépendance tierce.",
    ),
    _CatEntry(
      'zcrud_navigation',
      "Politique de présentation d'édition (page/feuille/dialogue) dérivée du point de rupture.",
    ),
    _CatEntry('zcrud_dnd', "Glisser-déposer natif opt-in (dépôts fichiers OS, échange inter-applications)."),
    _CatEntry(
      'zcrud_reorder',
      "Backend de réordonnancement opt-in, avec repli zéro-dépendance si non installé.",
    ),
  ]),
];

String _escape(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');

String _buildIndexHtml(List<_PackageResult> results) {
  final byName = {for (final r in results) r.name: r};
  final okCount = results.where((r) => r.ok).length;

  final buf = StringBuffer();
  buf.writeln('<!doctype html>');
  buf.writeln('<html lang="fr">');
  buf.writeln('<head>');
  buf.writeln('<meta charset="utf-8">');
  buf.writeln('<meta name="viewport" content="width=device-width, initial-scale=1">');
  buf.writeln('<title>Référence d\'API — zcrud</title>');
  buf.writeln(
    '<meta name="description" content="Index de la référence d\'API dartdoc des paquets zcrud, '
    'groupés par capacité.">',
  );
  buf.writeln('<style>');
  buf.writeln('''
:root {
  --bg: #ffffff;
  --bg-alt: #f4f5f7;
  --fg: #1a1c20;
  --fg-muted: #5a6270;
  --border: #dfe2e8;
  --accent: #2563eb;
  --ok-bg: #eaf7ee;
  --ok-fg: #1c7a3d;
  --ko-bg: #fbeaea;
  --ko-fg: #a3272c;
  --card-shadow: 0 1px 2px rgba(16, 24, 40, 0.06);
}
@media (prefers-color-scheme: dark) {
  :root {
    --bg: #14161a;
    --bg-alt: #1c1f25;
    --fg: #e7e9ee;
    --fg-muted: #9aa2b1;
    --border: #2b2f38;
    --accent: #6ea8ff;
    --ok-bg: #123321;
    --ok-fg: #6fd897;
    --ko-bg: #391c1d;
    --ko-fg: #f19b9e;
    --card-shadow: 0 1px 2px rgba(0, 0, 0, 0.4);
  }
}
* { box-sizing: border-box; }
body {
  margin: 0;
  background: var(--bg);
  color: var(--fg);
  font-family: -apple-system, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
  line-height: 1.5;
}
main { max-width: 960px; margin: 0 auto; padding: 2.5rem 1.25rem 4rem; }
header h1 { font-size: 1.75rem; margin: 0 0 0.4rem; }
header p.lede { color: var(--fg-muted); margin: 0 0 1.5rem; }
.summary {
  display: flex; gap: 0.75rem; flex-wrap: wrap; margin-bottom: 2rem;
}
.pill {
  border-radius: 999px; padding: 0.3rem 0.8rem; font-size: 0.85rem;
  border: 1px solid var(--border); background: var(--bg-alt); color: var(--fg-muted);
}
.pill strong { color: var(--fg); }
section.category { margin-bottom: 2rem; }
section.category h2 {
  font-size: 1.05rem; text-transform: uppercase; letter-spacing: 0.04em;
  color: var(--fg-muted); border-bottom: 1px solid var(--border); padding-bottom: 0.4rem;
  margin-bottom: 0.75rem;
}
ul.pkg-list { list-style: none; margin: 0; padding: 0; display: grid; gap: 0.6rem; }
li.pkg-card {
  border: 1px solid var(--border); border-radius: 10px; padding: 0.85rem 1rem;
  background: var(--bg-alt); box-shadow: var(--card-shadow);
}
li.pkg-card .row { display: flex; align-items: baseline; justify-content: space-between; gap: 0.75rem; flex-wrap: wrap; }
li.pkg-card a.pkg-name { font-weight: 600; text-decoration: none; color: var(--accent); font-size: 1rem; }
li.pkg-card a.pkg-name:hover { text-decoration: underline; }
li.pkg-card span.pkg-name.disabled { font-weight: 600; color: var(--fg-muted); font-size: 1rem; }
li.pkg-card p.role { margin: 0.35rem 0 0; color: var(--fg-muted); font-size: 0.92rem; }
.badge {
  font-size: 0.72rem; padding: 0.15rem 0.55rem; border-radius: 999px; white-space: nowrap;
}
.badge.ok { background: var(--ok-bg); color: var(--ok-fg); }
.badge.ko { background: var(--ko-bg); color: var(--ko-fg); }
footer { margin-top: 3rem; color: var(--fg-muted); font-size: 0.85rem; }
footer a { color: var(--accent); }
''');
  buf.writeln('</style>');
  buf.writeln('</head>');
  buf.writeln('<body>');
  buf.writeln('<main>');
  buf.writeln('<header>');
  buf.writeln("<h1>Référence d'API — zcrud</h1>");
  buf.writeln(
    '<p class="lede">Documentation générée par <code>dart doc</code> pour chaque paquet du monorepo, '
    'groupée par capacité — même découpage que le catalogue des paquets du '
    '<a href="../">site zcrud</a>.</p>',
  );
  buf.writeln('</header>');
  buf.writeln('<div class="summary">');
  buf.writeln('<span class="pill"><strong>${results.length}</strong> paquets</span>');
  buf.writeln('<span class="pill"><strong>$okCount</strong> documentés</span>');
  if (results.length - okCount > 0) {
    buf.writeln('<span class="pill"><strong>${results.length - okCount}</strong> indisponibles</span>');
  }
  buf.writeln('</div>');

  for (final category in _categories) {
    buf.writeln('<section class="category">');
    buf.writeln('<h2>${_escape(category.title)}</h2>');
    buf.writeln('<ul class="pkg-list">');
    for (final entry in category.entries) {
      final result = byName[entry.pkg];
      final ok = result?.ok ?? false;
      buf.writeln('<li class="pkg-card">');
      buf.writeln('<div class="row">');
      if (ok) {
        buf.writeln('<a class="pkg-name" href="./${entry.pkg}/index.html">${_escape(entry.pkg)}</a>');
        buf.writeln('<span class="badge ok">documenté</span>');
      } else {
        buf.writeln('<span class="pkg-name disabled">${_escape(entry.pkg)}</span>');
        buf.writeln('<span class="badge ko">indisponible</span>');
      }
      buf.writeln('</div>');
      buf.writeln('<p class="role">${_escape(entry.role)}</p>');
      buf.writeln('</li>');
    }
    buf.writeln('</ul>');
    buf.writeln('</section>');
  }

  buf.writeln('<footer>');
  buf.writeln(
    '<p>Généré par <code>melos run doc:api</code> (<code>scripts/doc/build_api_docs.dart</code>) — '
    'régénéré avant chaque publication, non versionné.</p>',
  );
  buf.writeln('</footer>');
  buf.writeln('</main>');
  buf.writeln('</body>');
  buf.writeln('</html>');
  return buf.toString();
}

Future<void> main(List<String> args) async {
  final repoRoot = _repoRoot();
  final packagesDir = Directory('${repoRoot.path}/packages');
  final apiDir = Directory('${repoRoot.path}/website/static/api');
  apiDir.createSync(recursive: true);

  final packageDirs = packagesDir
      .listSync()
      .whereType<Directory>()
      .where((d) => File('${d.path}/pubspec.yaml').existsSync())
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (packageDirs.isEmpty) {
    stderr.writeln('[doc:api] ÉCHEC — aucun paquet trouvé sous ${packagesDir.path}.');
    exit(2);
  }

  _info('[doc:api] génération de la référence d\'API pour ${packageDirs.length} paquets\n');

  final results = <_PackageResult>[];
  final totalStopwatch = Stopwatch()..start();

  for (var i = 0; i < packageDirs.length; i++) {
    final dir = packageDirs[i];
    final name = dir.path.split(Platform.pathSeparator).last;
    final progress = '[${i + 1}/${packageDirs.length}]';
    stdout.write('$progress $name... ');
    final result = await _buildPackageDoc(dir, apiDir, name);
    results.add(result);
    if (result.ok) {
      final warn = result.warnings != null ? ', ${result.warnings} avertissement(s)' : '';
      _info('OK (${result.duration.inSeconds}s$warn)');
    } else {
      _info('ÉCHEC (${result.duration.inSeconds}s) — ${result.error}');
    }
  }

  totalStopwatch.stop();

  final okCount = results.where((r) => r.ok).length;
  final failCount = results.length - okCount;

  _info('\n${'-' * 64}');
  _info(
    '[doc:api] Résumé : $okCount réussi(s) / $failCount échoué(s) sur ${results.length} paquets '
    '(${totalStopwatch.elapsed.inSeconds}s total).',
  );
  if (failCount > 0) {
    _info('[doc:api] Échecs : ${results.where((r) => !r.ok).map((r) => r.name).join(', ')}');
  }

  final indexFile = File('${apiDir.path}/index.html');
  indexFile.writeAsStringSync(_buildIndexHtml(results));
  _info('[doc:api] Index écrit : ${indexFile.path}');

  if (okCount == 0) {
    stderr.writeln('\n[doc:api] ÉCHEC — aucun paquet documenté avec succès.');
    exit(1);
  }
  exit(0);
}
