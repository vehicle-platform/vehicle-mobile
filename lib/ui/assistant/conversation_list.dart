import 'package:flutter/material.dart';

import 'package:vehicle_mobile/l10n/l10n.dart';
import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/ui/theme/app_theme.dart';

/// Conversation list, search, new chat, rename and delete (D-128, D-130).
/// Rendered as a left column inside the assistant pane at >= 900 px and inside
/// a modal sheet on narrower screens.
class ConversationListPane extends StatefulWidget {
  const ConversationListPane({
    super.key,
    required this.conversations,
    required this.activeId,
    required this.loading,
    required this.onSelect,
    required this.onNewChat,
    required this.onRename,
    required this.onDelete,
    required this.onSearch,
    required this.onRetry,
    this.searchHits,
    this.searching = false,
    this.loadFailed = false,
    this.searchFailed = false,
  });

  final List<ConversationSummary> conversations;
  final String? activeId;
  final bool loading;
  final ValueChanged<String> onSelect;
  final VoidCallback onNewChat;
  final void Function(ConversationSummary conversation, String newTitle)
      onRename;
  final ValueChanged<ConversationSummary> onDelete;
  final ValueChanged<String> onSearch;
  final List<ConversationSearchHit>? searchHits;
  final bool searching;

  /// The list could not be loaded (transient): show an error and [onRetry].
  final bool loadFailed;

  /// The last search failed: show an error, not "no matching messages".
  final bool searchFailed;
  final VoidCallback onRetry;

  @override
  State<ConversationListPane> createState() => _ConversationListPaneState();
}

class _ConversationListPaneState extends State<ConversationListPane> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _promptRename(ConversationSummary conv) async {
    final next = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: conv.title),
    );
    if (!mounted) return;
    if (next != null && next.isNotEmpty && next != conv.title) {
      widget.onRename(conv, next);
    }
  }

  Future<void> _confirmDelete(ConversationSummary conv) async {
    final l = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.assistantDeleteChatTitle),
        content: Text(l.assistantDeleteChatBody(conv.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.settingsCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.settingsDelete),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      widget.onDelete(conv);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final theme = Theme.of(context);
    final hits = widget.searchHits;
    return Material(
      color: t.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.md, Spacing.md, Spacing.md, Spacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    upperFor(context, l.assistantChatsTitle),
                    style: theme.textTheme.labelSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  key: const ValueKey('new-chat-button'),
                  onPressed: widget.onNewChat,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(l.assistantNewChat),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                Spacing.md, 0, Spacing.md, Spacing.sm),
            child: TextField(
              key: const ValueKey('conversation-search-field'),
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: widget.onSearch,
              onSubmitted: widget.onSearch,
              decoration: InputDecoration(
                isDense: true,
                hintText: l.assistantSearchChats,
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.assistantClose,
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          widget.onSearch('');
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
          Divider(height: 1, thickness: 1, color: t.hairline),
          Expanded(
            child: widget.loading || widget.searching
                ? const Center(child: CircularProgressIndicator())
                : widget.searchFailed
                    ? _errorState(context, l.assistantSearchFailed,
                        () => widget.onSearch(_searchController.text))
                    : hits != null
                        ? _searchList(context, hits)
                        : widget.loadFailed && widget.conversations.isEmpty
                            ? _errorState(context, l.assistantChatsLoadFailed,
                                widget.onRetry)
                            : _conversationList(context),
          ),
        ],
      ),
    );
  }

  Widget _errorState(BuildContext context, String text, VoidCallback retry) {
    final l = context.l10n;
    final t = context.vehicle;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              text,
              key: const ValueKey('conversation-error-text'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: t.textSecondary),
            ),
            const SizedBox(height: Spacing.sm),
            TextButton(
              key: const ValueKey('conversation-retry-button'),
              onPressed: retry,
              child: Text(l.assistantChatsRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _searchList(BuildContext context, List<ConversationSearchHit> hits) {
    final l = context.l10n;
    final t = context.vehicle;
    final theme = Theme.of(context);
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(
            l.assistantNoSearchHits,
            style: theme.textTheme.bodySmall!.copyWith(color: t.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: hits.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 1, color: t.hairline),
      itemBuilder: (context, i) {
        final hit = hits[i];
        return ListTile(
          key: ValueKey('search-hit-${hit.conversationId}-$i'),
          title: Text(hit.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall),
          subtitle: Text(hit.snippet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall!
                  .copyWith(color: t.textSecondary)),
          onTap: () => widget.onSelect(hit.conversationId),
        );
      },
    );
  }

  Widget _conversationList(BuildContext context) {
    final l = context.l10n;
    final t = context.vehicle;
    final theme = Theme.of(context);
    if (widget.conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.lg),
          child: Text(
            l.assistantNoChats,
            style: theme.textTheme.bodySmall!.copyWith(color: t.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: widget.conversations.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, thickness: 1, color: t.hairline),
      itemBuilder: (context, i) {
        final conv = widget.conversations[i];
        final selected = conv.id == widget.activeId;
        return Container(
          decoration: BoxDecoration(
            border: selected
                ? Border(left: BorderSide(color: t.accent, width: 3))
                : null,
          ),
          child: ListTile(
            key: ValueKey('conv-row-${conv.id}'),
            tileColor: selected ? t.surfaceRaised : null,
            title: Text(
              conv.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall!.copyWith(
                color: selected ? t.textPrimary : t.textSecondary,
              ),
            ),
            onTap: () => widget.onSelect(conv.id),
            trailing: PopupMenuButton<String>(
              key: ValueKey('conv-menu-${conv.id}'),
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (action) {
                if (action == 'rename') {
                  _promptRename(conv);
                } else if (action == 'delete') {
                  _confirmDelete(conv);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                    value: 'rename', child: Text(l.assistantRenameChat)),
                PopupMenuItem(
                    value: 'delete', child: Text(l.assistantDeleteChat)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.assistantRenameChat),
      content: TextField(
        key: const ValueKey('rename-chat-field'),
        controller: _ctrl,
        autofocus: true,
        maxLength: 80,
        decoration: InputDecoration(hintText: l.assistantRenameHint),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.settingsCancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _ctrl.text.trim()),
          child: Text(l.settingsSave),
        ),
      ],
    );
  }
}
