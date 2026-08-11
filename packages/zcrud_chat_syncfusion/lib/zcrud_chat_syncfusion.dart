/// Barrel d'API publique de `zcrud_chat_syncfusion`.
///
/// Ce paquet est la frontière du chat avec Syncfusion : tout ce qu'une
/// intégration à ce backend d'affichage impose s'arrête ici, et le socle
/// (`zcrud_chat`, `zcrud_chat_kernel`, `zcrud_core`) n'en porte rien.
///
/// ## Deux volets, une seule raison d'être
///
/// **1. La coquille Syncfusion — un backend du port, jamais une vue
/// parallèle.** `ZSfAssistShellRenderer` implémente `ZChatShellRenderer` :
/// il rend le cadre (`SfAIAssistView`) et rappelle la fabrique de tuiles du
/// socle, plutôt que de réimplémenter une vue de conversation concurrente
/// qui perdrait la région live, le dépli inline et `ZChatMessageTile`.
/// `syncfusion_flutter_chat` est une arête de ce seul paquet du monorepo —
/// aucun autre satellite ne la déclare.
///
/// **2. La normalisation d'un fil textuel encodé selon la convention
/// IFFD.** `ZIffdLexer` découpe le flux brut en segments (texte décodé,
/// balises), `ZIffdStreamNormalizer` classe ces segments en canaux et
/// produit les événements typés du kernel, `ZIffdTextStreamPort` expose le
/// tout comme un `ZChatStreamPort`. Une erreur écrite en clair par le
/// serveur, dans le même canal que la réponse, devient un
/// `Left(ZChatProviderFailure)` — jamais un message de conversation
/// (invariant AD-5).
///
/// Aucun client HTTP, aucun SDK IA (invariants AD-11, AD-12), aucun
/// gestionnaire d'état (invariants AD-2, AD-15). Arêtes sortantes seules,
/// graphe acyclique (invariant AD-1).
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/data/z_iffd_lexer.dart';
export 'src/data/z_iffd_stream_normalizer.dart';
export 'src/data/z_iffd_stream_port.dart';
export 'src/data/z_iffd_wire.dart';
export 'src/presentation/z_sf_assist_labels.dart';
export 'src/presentation/z_sf_assist_shell_renderer.dart';
