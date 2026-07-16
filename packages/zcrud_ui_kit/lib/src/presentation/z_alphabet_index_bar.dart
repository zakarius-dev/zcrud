/// Index alphabétique vertical A→Z **cliquable** (AD-32, AD-13).
///
/// `ZAlphabetIndexBar` neutralise l'index dupliqué des applications (lex
/// `alphabet_index_bar.dart`, `ConsumerWidget`/`WidgetRef` **morts**) en un
/// `StatelessWidget` **pur** `const` :
/// * **aucun** gestionnaire d'état (ni `flutter_riverpod`/`get`/`provider`) ni
///   routeur — le widget **émet** la lettre choisie via [ZAlphabetIndexBar.onLetter]
///   ; c'est l'appelant qui scrolle sa liste (aucun `ScrollController` interne) ;
/// * jeu de lettres **injectable** ([kZDefaultAlphabet] par défaut, A→Z) pour
///   d'autres alphabets/segments (NFR-U5) ;
/// * distinction actif/inerte/courant **multi-canal** : la couleur (dérivée du
///   `ColorScheme`, jamais de hex) n'est **jamais le seul canal** — l'état a11y
///   `enabled`/`selected` et l'inactivité du geste (`onTap: null`) sont des canaux
///   non-couleur (AD-13/NFR-U4) ;
/// * cibles tactiles **≥ 48 dp**, `Semantics` explicites, mise en page
///   **directionnelle** (RTL-safe).
library;

import 'package:flutter/material.dart';

/// Cible tactile minimale (Material / AD-13) par lettre.
const double _kMinTouchTarget = 48;

/// Alphabet latin **A→Z** par défaut (26 lettres, `String.fromCharCode(65 + i)`).
///
/// Défaut **neutre** (pas une chaîne métier) et injectable via
/// [ZAlphabetIndexBar.letters] pour supporter d'autres alphabets ou des segments
/// arbitraires (NFR-U5).
final List<String> kZDefaultAlphabet = List<String>.unmodifiable(
  List<String>.generate(26, (i) => String.fromCharCode(65 + i)),
);

/// Index alphabétique vertical cliquable qui **notifie** la lettre choisie.
///
/// Le widget ne possède **aucun** état de liste : au tap (ou au scrub vertical
/// si [enableScrub]) il invoque [onLetter] avec la lettre courante. Le
/// défilement de la liste indexée est la responsabilité de l'appelant.
class ZAlphabetIndexBar extends StatelessWidget {
  /// Construit un index. [onLetter] est requis ; [letters] vaut
  /// [kZDefaultAlphabet] (A→Z) par défaut.
  const ZAlphabetIndexBar({
    required this.onLetter,
    this.activeLetters,
    this.currentLetter,
    this.letters,
    this.enableScrub = true,
    super.key,
  });

  /// Notifie la lettre sélectionnée (au tap et, si [enableScrub], au scrub).
  final ValueChanged<String> onLetter;

  /// Ensemble des lettres **cliquables**. `null` ⇒ **toutes** actives (défaut
  /// permissif sûr, AD-10) ; sinon une lettre est active ssi présente ici.
  final Set<String>? activeLetters;

  /// Lettre **courante** mise en évidence par un canal non-couleur additionnel
  /// (`FontWeight.bold` + pastille `primaryContainer`) + `Semantics(selected:)`.
  /// Hors de [letters] ⇒ ignorée (aucune mise en évidence, pas de throw).
  final String? currentLetter;

  /// Jeu de lettres à afficher (défaut [kZDefaultAlphabet], A→Z). Vide ⇒
  /// `SizedBox.shrink()` (défaut sûr AD-10).
  final List<String>? letters;

  /// Active le **scrub vertical** (glisser le long de l'index émet la lettre
  /// survolée, dé-dupliquée au changement). Prédicat strictement binaire
  /// non extensible — **seule** exception `bool` tolérée (NFR-U7).
  final bool enableScrub;

  /// Lettres effectivement rendues (repli sur [kZDefaultAlphabet]).
  List<String> get _effectiveLetters => letters ?? kZDefaultAlphabet;

  bool _isActive(String letter) =>
      activeLetters == null || activeLetters!.contains(letter);

  @override
  Widget build(BuildContext context) {
    final items = _effectiveLetters;
    // Défaut sûr (AD-10) : jamais de throw, un jeu vide ne rend rien.
    if (items.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;

    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final letter in items)
          _ZAlphabetLetter(
            letter: letter,
            active: _isActive(letter),
            current: letter == currentLetter,
            colorScheme: colorScheme,
            onTap: _isActive(letter) ? () => onLetter(letter) : null,
          ),
      ],
    );

    if (!enableScrub) return column;

    // Zone de scrub accessible : glisser verticalement émet la lettre survolée,
    // dé-dupliquée au changement (l'index reste une cible continue ≥ 48 dp large).
    return _ZAlphabetScrubDetector(
      letters: items,
      isActive: _isActive,
      onLetter: onLetter,
      child: column,
    );
  }
}

/// Une lettre de l'index : cible ≥ 48 dp, multi-canal, `Semantics` explicites.
class _ZAlphabetLetter extends StatelessWidget {
  const _ZAlphabetLetter({
    required this.letter,
    required this.active,
    required this.current,
    required this.colorScheme,
    required this.onTap,
  });

  final String letter;
  final bool active;
  final bool current;
  final ColorScheme colorScheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Couleur DÉRIVÉE du ColorScheme (jamais de hex) :
    // - courante/active → primary ;
    // - inerte → onSurfaceVariant atténué (canal secondaire, jamais le seul).
    final Color color = active
        ? colorScheme.primary
        : colorScheme.onSurfaceVariant.withValues(alpha: 0.38);

    // Canal NON-couleur pour la lettre courante : graisse + pastille de fond.
    final TextStyle style = TextStyle(
      fontSize: 11,
      color: color,
      fontWeight: current ? FontWeight.bold : FontWeight.normal,
    );

    Widget label = Text(letter, style: style, textAlign: TextAlign.center);
    if (current) {
      label = DecoratedBox(
        decoration: ShapeDecoration(
          color: colorScheme.primaryContainer,
          shape: const CircleBorder(),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(2),
          child: label,
        ),
      );
    }

    return Semantics(
      button: true,
      enabled: active,
      selected: current,
      label: letter,
      // Le nœud parent porte toute la sémantique ; on masque le doublon du texte.
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          // Cible tactile ≥ 48 dp en LARGEUR (colonne de scrub accessible,
          // AD-13). La hauteur reste compacte : un index A→Z de 26 lettres à
          // 48 dp de haut dépasserait tout écran — la dimension tactile est la
          // largeur, la sélection verticale fine passe par le scrub.
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: _kMinTouchTarget),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 8,
                  vertical: 1,
                ),
                child: label,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Détecteur de scrub vertical : mappe la position `dy` sur la lettre survolée
/// et émet [onLetter] uniquement au **changement** de lettre (dé-dupliqué).
class _ZAlphabetScrubDetector extends StatefulWidget {
  const _ZAlphabetScrubDetector({
    required this.letters,
    required this.isActive,
    required this.onLetter,
    required this.child,
  });

  final List<String> letters;
  final bool Function(String) isActive;
  final ValueChanged<String> onLetter;
  final Widget child;

  @override
  State<_ZAlphabetScrubDetector> createState() =>
      _ZAlphabetScrubDetectorState();
}

class _ZAlphabetScrubDetectorState extends State<_ZAlphabetScrubDetector> {
  String? _lastEmitted;

  void _handle(Offset localPosition, Size size) {
    if (widget.letters.isEmpty || size.height <= 0) return;
    final fraction = (localPosition.dy / size.height).clamp(0.0, 0.999999);
    final index = (fraction * widget.letters.length).floor();
    final letter = widget.letters[index];
    if (letter == _lastEmitted) return;
    _lastEmitted = letter;
    if (widget.isActive(letter)) widget.onLetter(letter);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (details) {
        _lastEmitted = null;
        final size = context.size;
        if (size != null) _handle(details.localPosition, size);
      },
      onVerticalDragUpdate: (details) {
        final size = context.size;
        if (size != null) _handle(details.localPosition, size);
      },
      onVerticalDragEnd: (_) => _lastEmitted = null,
      child: widget.child,
    );
  }
}
