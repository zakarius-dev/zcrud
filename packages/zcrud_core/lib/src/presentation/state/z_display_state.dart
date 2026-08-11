/// `ZDisplayState` — **patron général** : un composant détient un état
/// d'AFFICHAGE, et l'hôte a un **second chemin** pour le déclencher.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// LE MOTIF, ET POURQUOI IL EST GÉNÉRAL
///
/// Un socle qui internalise un état d'affichage sans l'exposer **ferme la porte
/// au deuxième chemin de déclenchement**. L'hôte n'a alors que de mauvaises
/// options : dupliquer le composant, ou retirer sa commande — et s'il la garde,
/// il livre un **bouton mort**, *« plus coûteux qu'une commande absente, parce
/// qu'il promet »*.
///
/// Plusieurs familles d'état reviennent d'un hôte à l'autre : révélation d'une
/// carte (DEUX boutons : « Voir la réponse » en face avant, « Masquer la
/// réponse » posé par le PARENT sur la face arrière), carte courante d'un
/// carrousel piloté par des flèches externes, onglet actif (sommaire en tiroir,
/// barre d'outils, barre d'onglets parallèle), page courante d'un visionneur
/// commandée par un champ « aller à la page », déplié/replié commandé depuis
/// l'en-tête **et** le chevron.
///
/// Deux formes d'état suffisent à les couvrir toutes :
/// [ZToggleController] (booléen) et [ZIndexController] (entier).
///
/// ═══════════════════════════════════════════════════════════════════════════
/// LE CONTRAT (les cinq clauses, toutes gardées)
///
/// 1. **État interne par DÉFAUT.** Sans contrôleur, le composant se gouverne
///    seul et son comportement est **strictement inchangé** — c'est le bon
///    défaut pour la majorité des hôtes (AD-4 : extension par point d'entrée
///    optionnel, jamais par obligation).
/// 2. **Le contrôleur fourni devient LA SOURCE DE VÉRITÉ**, jamais un miroir
///    qu'on synchronise. [ZDisplayStateBinding] ne **copie** rien : quand un
///    contrôleur est présent, toute lecture et toute écriture le traversent.
///    Deux états ne peuvent donc pas diverger, parce qu'il n'y en a qu'un.
/// 3. **La notification sortante est CONSERVÉE.** Elle ne suffit pas (elle ne
///    fait que constater), mais elle reste nécessaire : l'hôte qui n'a pas
///    besoin de commander a toujours besoin de savoir.
/// 4. **La possession HORS `build` est IMPOSÉE** — cf. [ZDisplayStateOwnerMixin].
///    Sans cela, on industrialiserait le bug de l'hôte : trois de ses
///    contrôleurs sont instanciés **dans `build`**, donc écrasés au rebuild
///    suivant, donc silencieusement inertes.
/// 5. **Un contrôleur JAMAIS CONSOMMÉ est détectable** — cf.
///    [ZDisplayStateController.wasEverConsumed]. Sans cela on ne distingue plus
///    « bouton inerte » de « bouton non branché » : un widget peut
///    **déclarer** un contrôleur de retournement de carte sans jamais
///    l'utiliser dans son corps.
///
/// ═══════════════════════════════════════════════════════════════════════════
/// AD-2 / AD-15 : Flutter-native pur. `ChangeNotifier` + `ValueListenable`,
/// **aucun** gestionnaire d'état, **aucune** dépendance hors SDK ⇒ CORE OUT = 0.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Jeton de **POSSESSION** d'un état d'affichage piloté.
///
/// Un [ZDisplayStateController] ne peut pas être construit sans lui : c'est la
/// mécanique par laquelle la possession hors `build` est **imposée** plutôt que
/// recommandée. Le seul propriétaire fourni par le socle est
/// [ZDisplayStateOwnerMixin], appliqué à un `State` — donc un objet qui a une
/// **durée de vie**, contrairement à une variable locale de `build`.
abstract class ZDisplayStateOwner {
  /// Enregistre [controller] auprès de ce propriétaire.
  ///
  /// Implémentation réservée au socle : un hôte l'obtient en appliquant
  /// [ZDisplayStateOwnerMixin] à son `State`.
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller);
}

/// Rend un `State` capable de **posséder** des états d'affichage pilotés.
///
/// ## Comment la possession hors `build` est IMPOSÉE (et non conseillée)
///
/// Le mixin pose une **borne temporelle** : il se déclare *installé* à la fin
/// de la première frame qui suit son `initState`. Tout ce qui est légitime —
/// initialiseur de champ, `initState`, `didChangeDependencies` — se produit
/// **avant** cette borne. Un contrôleur créé dans `build` en est
/// nécessairement **après** dès le **premier rebuild**, et l'enregistrement
/// lève alors une [FlutterError] nommant le contrôleur.
///
/// C'est le pendant exact de `SingleTickerProviderStateMixin`, qui refuse un
/// second ticker pour la même raison : une seconde création par le même `State`
/// est presque toujours une création dans `build`.
///
/// La borne est **temporelle**, pas syntaxique : une création tardive
/// légitime (paresseuse, sur action utilisateur, hors `build`) serait donc
/// refusée elle aussi. C'est assumé, et rattrapable **explicitement** en
/// surchargeant [zAllowsLateDisplayState] — jamais par accident.
///
/// ## Ce que le mixin fait AUSSI
///
/// - il **dispose** les contrôleurs possédés au `dispose` du `State` (la classe
///   de fuite disparaît, elle n'est pas seulement signalée) ;
/// - il **refuse au `dispose`** un contrôleur qui n'a **jamais été consommé**
///   par un composant (clause 5 du contrat).
mixin ZDisplayStateOwnerMixin<W extends StatefulWidget> on State<W>
    implements ZDisplayStateOwner {
  final List<ZDisplayStateController<Object?>> _zOwned =
      <ZDisplayStateController<Object?>>[];

  /// Vrai une fois la première frame du `State` écoulée : au-delà, un
  /// enregistrement signale une création dans `build`.
  bool _zInstalled = false;

  bool _zDisposed = false;

  /// Autorise une création **tardive** (hors `build`, après la première frame).
  ///
  /// Défaut `false` : la borne temporelle mord. À surcharger **explicitement**,
  /// avec un motif écrit — c'est le seul moyen de désarmer la clause 4, et il
  /// doit rester visible en revue.
  @protected
  bool get zAllowsLateDisplayState => false;

  /// Les contrôleurs possédés (lecture seule) — surface de garde structurelle.
  @visibleForTesting
  List<ZDisplayStateController<Object?>> get zOwnedDisplayStates =>
      List<ZDisplayStateController<Object?>>.unmodifiable(_zOwned);

  @override
  void initState() {
    super.initState();
    // La borne : tout ce qui est légitime (champ, initState,
    // didChangeDependencies) précède la fin de cette frame ; un `build`
    // ultérieur lui succède.
    WidgetsBinding.instance.addPostFrameCallback((_) => _zInstalled = true);
  }

  @override
  void zRegisterDisplayState(ZDisplayStateController<Object?> controller) {
    assert(
      !_zDisposed,
      'ZDisplayStateOwnerMixin : enregistrement après `dispose` de $this.',
    );
    if (_zInstalled && !zAllowsLateDisplayState) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
          'Un état d\'affichage a été créé APRÈS l\'installation de $this.',
        ),
        ErrorDescription(
          'Le contrôleur « ${controller.debugLabel} » a été enregistré après la '
          'première frame de ce State. C\'est la signature d\'une création '
          'dans `build` : l\'instance est alors remplacée à chaque rebuild, et '
          'la commande de l\'hôte devient silencieusement inerte.',
        ),
        ErrorHint(
          'Créez le contrôleur dans un CHAMP du State (ou dans `initState`), '
          'jamais dans `build`. Si la création tardive est intentionnelle, '
          'surchargez `zAllowsLateDisplayState` en motivant la dérogation.',
        ),
      ]);
    }
    _zOwned.add(controller);
  }

  @override
  void dispose() {
    _zDisposed = true;
    final List<ZDisplayStateController<Object?>> owned =
        List<ZDisplayStateController<Object?>>.of(_zOwned);
    _zOwned.clear();
    for (final ZDisplayStateController<Object?> controller in owned) {
      assert(
        controller.wasEverConsumed,
        'Le contrôleur « ${controller.debugLabel} » n\'a JAMAIS été consommé '
        'par un composant : il a été créé, possédé, puis jeté sans qu\'aucun '
        'widget ne s\'y branche. Une commande de l\'hôte câblée dessus serait '
        'un bouton mort. Passez-le au composant, ou supprimez-le.',
      );
      controller.dispose();
    }
    super.dispose();
  }
}

/// Contrôleur d'un état d'AFFICHAGE piloté depuis l'extérieur du composant.
///
/// C'est un `ValueListenable<T>` : **la** valeur, pas une copie de la valeur.
/// Quand il est fourni à un composant, il devient la **source de vérité**
/// unique — le composant ne garde aucun miroir (cf. [ZDisplayStateBinding]).
class ZDisplayStateController<T> extends ChangeNotifier
    implements ValueListenable<T> {
  /// Crée un contrôleur possédé par [owner], initialisé à [initialValue].
  ///
  /// [owner] est **requis** : c'est ce qui rend impossible la création
  /// anonyme dans un `build` (clause 4 du contrat).
  ZDisplayStateController({
    required ZDisplayStateOwner owner,
    required T initialValue,
    String? debugLabel,
  })  : _value = initialValue,
        debugLabel = debugLabel ?? 'ZDisplayStateController<$T>' {
    owner.zRegisterDisplayState(this);
  }

  /// Libellé de diagnostic — apparaît dans les messages d'erreur du patron.
  final String debugLabel;

  T _value;

  bool _disposed = false;

  final Set<Object> _consumers = <Object>{};

  bool _everConsumed = false;

  /// Valeur courante — **source de vérité** quand le contrôleur est fourni.
  @override
  T get value => _value;

  /// Commande l'état depuis l'hôte. Ne notifie que sur **changement**.
  set value(T next) {
    assert(!_disposed, 'ZDisplayStateController « $debugLabel » déjà disposé.');
    if (_value == next) return;
    _value = next;
    notifyListeners();
  }

  /// Nombre de composants actuellement branchés sur ce contrôleur.
  int get consumerCount => _consumers.length;

  /// Vrai si **au moins un** composant s'y est branché au cours de sa vie.
  ///
  /// C'est la propriété qui rend détectable un contrôleur *accepté mais jamais
  /// consommé* : elle reste `false` pour un contrôleur déclaré et jamais passé.
  bool get wasEverConsumed => _everConsumed;

  /// Vrai après [dispose] — le propriétaire évite ainsi la double libération.
  bool get isDisposed => _disposed;

  /// Branche [consumer] (appelé par [ZDisplayStateBinding], pas par l'hôte).
  void attachConsumer(Object consumer) {
    _consumers.add(consumer);
    _everConsumed = true;
  }

  /// Débranche [consumer].
  void detachConsumer(Object consumer) => _consumers.remove(consumer);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _consumers.clear();
    super.dispose();
  }
}

/// État d'affichage **booléen** : révélation, déplié/replié, ouvert/fermé…
///
/// Couvre les familles « révélation d'une carte » et « déplié/replié commandé
/// depuis l'en-tête ET le chevron ».
class ZToggleController extends ZDisplayStateController<bool> {
  /// Crée un contrôleur booléen possédé par [owner].
  ZToggleController({
    required super.owner,
    super.initialValue = false,
    super.debugLabel,
  });

  /// Bascule l'état.
  void toggle() => value = !value;

  /// Force l'état à `true`.
  void set() => value = true;

  /// Force l'état à `false`.
  void clear() => value = false;
}

/// État d'affichage **indexé** : onglet actif, carte courante, page courante.
///
/// Couvre les familles « carrousel piloté par des flèches externes », « onglet
/// actif » et « page courante commandée par un champ *aller à la page* ».
class ZIndexController extends ZDisplayStateController<int> {
  /// Crée un contrôleur d'index possédé par [owner].
  ZIndexController({
    required super.owner,
    super.initialValue = 0,
    super.debugLabel,
  });

  /// Avance d'un cran (borné par [max] s'il est fourni).
  void next({int? max}) {
    final int candidate = value + 1;
    if (max != null && candidate > max) return;
    value = candidate;
  }

  /// Recule d'un cran (jamais sous `0`).
  void previous() {
    if (value <= 0) return;
    value = value - 1;
  }
}

/// Côté COMPOSANT du patron : résout « état interne » ou « contrôleur de
/// l'hôte » **sans jamais dupliquer l'état**.
///
/// Le composant s'en sert ainsi :
///
/// ```dart
/// late final ZDisplayStateBinding<bool> _reveal;
///
/// @override
/// void initState() {
///   super.initState();
///   _reveal = ZDisplayStateBinding<bool>(consumer: this, initialValue: false)
///     ..bind(widget.revealController)
///     ..listenable.addListener(_onRevealChanged);
/// }
///
/// @override
/// void didUpdateWidget(covariant Foo old) {
///   super.didUpdateWidget(old);
///   _reveal.bind(widget.revealController); // no-op si identique
/// }
///
/// @override
/// void dispose() {
///   _reveal.listenable.removeListener(_onRevealChanged);
///   _reveal.dispose();
///   super.dispose();
/// }
/// ```
///
/// [listenable] est **STABLE** au travers d'un changement de contrôleur :
/// c'est un relais d'ÉCOUTE, jamais un relais de VALEUR — il ne stocke aucune
/// valeur, il lit celle de la source courante. Sans cette stabilité, un
/// `ValueListenableBuilder` du composant devrait être reconstruit par un
/// `setState` à l'échelle du composant, ce qu'AD-2 interdit.
class ZDisplayStateBinding<T> {
  /// Crée la liaison pour [consumer], repliée sur un état interne valant
  /// [initialValue] tant qu'aucun contrôleur n'est fourni.
  ZDisplayStateBinding({required this.consumer, required T initialValue})
      : _internal = ValueNotifier<T>(initialValue) {
    _relay = _ZDisplayStateRelay<T>(() => _source.value);
    _source = _internal;
    _source.addListener(_relay.forward);
  }

  /// Le composant qui consomme l'état (sert au marquage de consommation).
  final Object consumer;

  final ValueNotifier<T> _internal;

  late final _ZDisplayStateRelay<T> _relay;

  late ValueListenable<T> _source;

  ZDisplayStateController<T>? _controller;

  /// Le contrôleur de l'hôte, s'il y en a un.
  ZDisplayStateController<T>? get controller => _controller;

  /// Vrai si l'hôte pilote l'état (⇒ le composant n'en est plus propriétaire).
  bool get isHostControlled => _controller != null;

  /// Écoute STABLE de l'état — à passer à un `ValueListenableBuilder`.
  ValueListenable<T> get listenable => _relay;

  /// Valeur courante, lue **à la source** (aucun miroir).
  T get value => _source.value;

  /// Écrit l'état — **à travers** le contrôleur quand il y en a un.
  set value(T next) {
    final ZDisplayStateController<T>? controller = _controller;
    if (controller != null) {
      controller.value = next;
      return;
    }
    _internal.value = next;
  }

  /// Branche (ou débranche) le contrôleur de l'hôte. Idempotent.
  ///
  /// À appeler en `initState` **et** en `didUpdateWidget` : un hôte a le droit
  /// de changer de contrôleur, et le composant ne doit pas rester branché sur
  /// l'ancien.
  void bind(ZDisplayStateController<T>? controller) {
    if (identical(controller, _controller)) return;
    final T previous = _source.value;
    _source.removeListener(_relay.forward);
    _controller?.detachConsumer(consumer);
    _controller = controller;
    if (controller != null) {
      controller.attachConsumer(consumer);
      _source = controller;
    } else {
      // Retour à l'état interne : il REPREND la dernière valeur rendue, sans
      // quoi un débranchement ferait sauter l'affichage à une valeur périmée.
      _internal.value = previous;
      _source = _internal;
    }
    _source.addListener(_relay.forward);
    if (_source.value != previous) _relay.forward();
  }

  /// Libère la liaison. **Ne dispose JAMAIS le contrôleur de l'hôte** : il ne
  /// nous appartient pas (son propriétaire est un `State` de l'hôte).
  void dispose() {
    _source.removeListener(_relay.forward);
    _controller?.detachConsumer(consumer);
    _controller = null;
    _relay.dispose();
    _internal.dispose();
  }
}

/// Relais d'écoute à valeur **calculée** — ne stocke rien, donc ne peut pas
/// diverger de la source.
class _ZDisplayStateRelay<T> extends ChangeNotifier
    implements ValueListenable<T> {
  _ZDisplayStateRelay(this._read);

  final T Function() _read;

  @override
  T get value => _read();

  /// Propage une notification de la source courante.
  void forward() => notifyListeners();
}
