/// `ZIntlDateDisplayFormatter` — implémentation **`intl`** du port
/// [ZDateDisplayFormatter] de `zcrud_core`.
///
/// ## Le défaut fermé ici
///
/// Une valeur de date est stockée en ISO-8601 ; toutes les voies de LECTURE
/// du socle la rendent telle quelle tant qu'aucun port n'est injecté —
/// `2026-08-09T00:00:00.000` là où ce formateur affiche `dim. 9 août 2026`.
/// Le cœur pose le seam (invariant AD-1 lui interdit `intl`) ; **cette
/// classe est le seul endroit du graphe qui connaît `package:intl`**.
///
/// ## Aucun libellé n'est écrit ici
///
/// Les noms de mois et de jours, l'ordre des composantes et les séparateurs
/// viennent **des données de locale CLDR embarquées par `intl`**. Ce fichier ne
/// contient aucun nom de mois, aucun nom de jour, aucune casse localisée: que
/// des **squelettes de patron** (`EEE`, `d`, `MMM`, `y`, `Hm`), qui sont des
/// codes CLDR, pas du texte affichable.
///
/// ## Invariant AD-10 — décliner, jamais lever
///
/// Le contrat du port est explicite: `null` (ou chaîne vide) ⇒ **repli défini
/// du socle** (la chaîne brute). Cette impl ne laisse donc **aucune** rupture
/// s'échapper. Mesuré sur `intl` 0.20.2:
///
/// | Entrée | Ce que `intl` fait | Ce que cette impl rend |
/// |---|---|---|
/// | données de locale non initialisées | lève `LocaleDataException` (une **`Exception`**) | initialisées paresseusement ⇒ n'arrive plus; sinon `null` |
/// | étiquette inconnue (`zz`, `zz-ZZ`, `''`) | lève `ArgumentError` (une **`Error`**) | `null` |
/// | étiquette à tirets (`fr-FR`, `fr-Latn-FR`, `FR`) | canonicalise elle-même | rendu localisé |
/// | patron invalide | ne lève pas — rend une bouillie | rendu tel quel (hors de notre pouvoir) |
/// | patron vide | rend `''` | `null` (⇒ repli du socle) |
///
/// Le `catch` est un `catch (_)` **nu**: il rattrape `Object`, donc les
/// `Error` **et** les `Exception`. Rattraper la seule famille `Error` laisserait
/// remonter `LocaleDataException` — c'est-à-dire l'échec le plus NORMAL des
/// deux.
///
/// ## Coût, et pourquoi le cache est obligatoire
///
/// Le socle appelle [ZDateDisplayFormatter.format] **une fois par cellule et
/// par build**. Mesuré ici (20 000 itérations, `intl` 0.20.2):
/// construire+formater = **8,33 µs/appel**, formater seul = **0,32 µs/appel**,
/// soit un facteur **26×**. Les `DateFormat` sont donc mémoïsés par
/// (mode, patron, étiquette de locale) dans un cache de bibliothèque partagé
/// par toutes les instances — l'instance elle-même reste `const`.
///
/// ## Payload — pourquoi ce fichier N'EST PAS dans le barrel principal
///
/// L'initialisation des données de locale (`initializeDateFormatting`) rend
/// atteignable la table CLDR **complète** (`date_symbol_data_local`, plusieurs
/// centaines de Ko de données Dart pour ~700 locales). Un hôte qui ne veut que
/// les champs téléphone/pays de `zcrud_intl` n'a pas à la payer. Ce formateur
/// est donc servi par un **point d'entrée séparé**:
///
/// ```dart
/// import 'package:zcrud_intl/date_formatter.dart';
///
/// ZcrudScope(
///   dateDisplayFormatter: const ZIntlDateDisplayFormatter(),
///   child: …,
/// );
///
/// // Format court personnalisé (`dim. 9 août 2026`) :
/// const ZIntlDateDisplayFormatter(
///   datePattern: 'EEE d MMM y',
///   dateTimePattern: 'EEE d MMM y HH:mm',
/// );
/// ```
library;

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:zcrud_core/domain.dart';

/// Vrai dès que les données de locale ont été chargées (une seule fois).
bool _localeDataReady = false;

/// Cache de bibliothèque des `DateFormat`, partagé par toutes les instances
/// (l'instance publique reste `const`, donc sans champ mutable).
final Map<String, DateFormat> _formatters = <String, DateFormat>{};

/// Nombre de `DateFormat` réellement CONSTRUITS (mesure de morsure du cache).
int _creations = 0;

/// Plafond de sûreté: les clés sont bornées en pratique (modes × patrons ×
/// locales de l'app), mais un hôte qui fabriquerait des patrons dynamiques ne
/// doit pas faire fuir la mémoire.
const int _cacheCap = 64;

/// Charge les données de locale si besoin.
///
/// `initializeDateFormatting` de `date_symbol_data_local` est **synchrone en
/// pratique** (elle installe les tables puis rend un `Future` déjà complété):
/// c'est ce qui permet de l'appeler depuis un `format` synchrone. Vérifié sur
/// `intl` 0.20.2.
void _ensureLocaleData() {
  if (_localeDataReady) return;
  initializeDateFormatting();
  _localeDataReady = true;
}

/// Sépare les composantes de la clé de cache: un caractère de CONTRÔLE, qui
/// ne peut apparaître ni dans un patron CLDR ni dans une étiquette BCP-47.
/// Écrit en **séquence d'échappement** — jamais un octet de contrôle BRUT dans
/// la source, qui rendrait le fichier « binaire » pour `grep` et pour les
/// gardes qui lisent le source.
const String _sep = '\u0001';

/// Marqueur d'ABSENCE d'étiquette — distinct de l'étiquette VIDE `''`, qui est
/// invalide pour `intl` et doit décliner au lieu de recevoir la locale par
/// défaut de l'instance absente.
const String _absent = '\u0002none';

String _cacheKey(ZDateMode mode, String? pattern, String? localeTag) =>
    '${mode.name}$_sep${pattern ?? _absent}$_sep${localeTag ?? _absent}';

/// Implémentation `intl` du port d'affichage des dates.
///
/// **`const`-constructible** (AD-2): l'hôte l'injecte en `const` dans
/// `ZcrudScope`, jamais reconstruite dans un `build`.
///
/// Voir le dartdoc de bibliothèque pour le contrat de repli, le coût mesuré et
/// la raison du point d'entrée séparé.
class ZIntlDateDisplayFormatter implements ZDateDisplayFormatter {
  /// Crée un formateur.
  ///
  /// [datePattern] / [dateTimePattern] sont des **patrons `intl`** explicites
  /// (codes CLDR, jamais du texte). `null` ⇒ patrons **localisés par défaut**
  /// (`yMMMMEEEEd`, plus `Hm` pour le mode date+heure).
  const ZIntlDateDisplayFormatter({
    this.datePattern,
    this.dateTimePattern,
  });

  /// Patron du mode [ZDateMode.date] (ex. `'EEE d MMM y'` pour un format court).
  final String? datePattern;

  /// Patron du mode [ZDateMode.dateTime] (ex. `'EEE d MMM y HH:mm'`).
  final String? dateTimePattern;

  @override
  String? format(
    DateTime value, {
    required ZDateMode mode,
    String? localeTag,
  }) {
    // Le socle ne route JAMAIS `time` vers le port (sa valeur canonique est
    // déjà `HH:mm`, non portable dans un `DateTime`). Défense en profondeur:
    // on DÉCLINE explicitement plutôt que d'inventer une heure à partir d'une
    // date reconstruite.
    if (mode == ZDateMode.time) return null;
    try {
      final pattern = mode == ZDateMode.date ? datePattern : dateTimePattern;
      final key = _cacheKey(mode, pattern, localeTag);
      var formatter = _formatters[key];
      if (formatter == null) {
        _ensureLocaleData();
        formatter = _build(mode, pattern, localeTag);
        _creations++;
        if (_formatters.length >= _cacheCap) _formatters.clear();
        _formatters[key] = formatter;
      }
      final out = formatter.format(value);
      // Chaîne vide ⇒ canal « je ne sais pas rendre » du port.
      return out.isEmpty ? null : out;
    } catch (_) {
      // `catch (_)` NU: rattrape `Error` (locale inconnue → `ArgumentError`)
      // ET `Exception` (données absentes → `LocaleDataException`). AD-10:
      // aucune rupture ne remonte dans un `build`.
      return null;
    }
  }

  DateFormat _build(ZDateMode mode, String? pattern, String? localeTag) {
    if (pattern != null) return DateFormat(pattern, localeTag);
    final base = DateFormat.yMMMMEEEEd(localeTag);
    return mode == ZDateMode.date ? base : base.add_Hm();
  }
}

/// Nombre de `DateFormat` réellement CONSTRUITS depuis le dernier
/// [zDebugResetIntlDateFormatterCache].
///
/// Réservé aux **gardes**: une garde de cache qui ne compare que les *sorties*
/// est vacante (deux formateurs distincts rendent la même chaîne). Ce compteur,
/// couplé à [zDebugIntlDateFormatterCacheEntries], mesure l'**instance**.
int get zDebugIntlDateFormatterCreations => _creations;

/// Les formateurs actuellement mémoïsés, en type **opaque** `Object`: aucun
/// type `intl` ne fuit dans une signature publique (AD-1). Une garde compare
/// les entrées avec `same(...)` / `identical(...)`.
List<Object> get zDebugIntlDateFormatterCacheEntries =>
    List<Object>.unmodifiable(_formatters.values);

/// Vide le cache et remet [zDebugIntlDateFormatterCreations] à zéro.
void zDebugResetIntlDateFormatterCache() {
  _formatters.clear();
  _creations = 0;
}
