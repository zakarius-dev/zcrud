/// Barrel d'API publique de `zcrud_chat_markdown`.
///
/// Backend de **rendu riche Markdown/LaTeX** du port `ZChatRenderer`
/// (`zcrud_chat`), adossé à `zcrud_markdown` — CR-IFFD-73. C'est au chat ce que
/// `zcrud_list` est à `ZListRenderer` : la ligne « rendu riche » de la table
/// d'implémentations du port avait un contrat et **aucun paquet**.
///
/// OPT-IN (AD-57) : un consommateur de `zcrud_chat` qui ne monte pas ce paquet
/// ne tire **rien** de nouveau — ni Quill, ni `flutter_math_fork` — et son
/// rendu reste strictement celui d'avant.
///
/// ISOLATION (AD-1/AD-57) : ce barrel n'exporte AUCUN symbole `flutter_quill`,
/// et le paquet ne déclare AUCUNE arête `flutter_quill` directe. Quill est
/// atteint uniquement à travers l'API neutre de `zcrud_markdown`.
///
/// API publique = ce barrel ; implémentation sous `lib/src/`.
library;

export 'src/presentation/z_chat_markdown_renderer.dart'
    show
        ZChatMarkdownRenderer,
        ZChatMarkdownStreamingMode,
        kZChatMarkdownDefaultRoles;
