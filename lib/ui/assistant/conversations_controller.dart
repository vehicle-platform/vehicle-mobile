import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:vehicle_mobile/models/conversation.dart';
import 'package:vehicle_mobile/services/conversations_client.dart';

/// Where to send a request: base URL and session token, or `null` when the
/// app has no host or no session.
typedef ConversationsTarget = Future<(String, String)?> Function();

/// What [ConversationsController.delete] did.
enum DeleteOutcome {
  /// The server refused or did not answer; nothing changed.
  failed,

  /// Deleted; another conversation (or none) was open.
  deleted,

  /// Deleted, and it was the open one: the transcript must be cleared.
  deletedActive,
}

/// State of the stored-conversation list (D-128): the list, search hits,
/// whether the host offers the feature, and the load/search/rename/delete/
/// select calls. The screen owns the transcript; this owns everything the
/// list and the sheet show.
class ConversationsController extends ChangeNotifier {
  ConversationsController({
    required ConversationsClient client,
    required ConversationsTarget target,
  })  : _client = client,
        _target = target;

  final ConversationsClient _client;
  final ConversationsTarget _target;

  List<ConversationSummary> _conversations = const [];
  bool _loading = false;
  bool _probed = false;
  bool _unsupported = false;
  bool _everLoaded = false;
  bool _loadFailed = false;
  List<ConversationSearchHit>? _searchHits;
  bool _searching = false;
  bool _searchFailed = false;
  int _searchSeq = 0;
  bool _disposed = false;

  /// The stored conversation the transcript continues, or `null` (new chat).
  /// The screen sets it and rebuilds itself; [delete] clears it.
  String? activeId;

  List<ConversationSummary> get conversations => _conversations;
  bool get loading => _loading;

  /// The last list load failed with a transient error (no answer, server
  /// error): the list is empty but the feature may be there, so show a retry.
  bool get loadFailed => _loadFailed;

  /// Search hits for the current query; `null` when no search is active.
  List<ConversationSearchHit>? get searchHits => _searchHits;
  bool get searching => _searching;

  /// The last search failed: show an error, never "no results".
  bool get searchFailed => _searchFailed;

  /// The list and its entry points are shown: the host did not say 403 or 404
  /// (an older server, or a token kind without conversations) and either a
  /// load worked once or the first one has not failed. While the first load
  /// keeps failing transiently the feature stays out of sight but is not given
  /// up: [retryIfNeeded] tries again (after the next answer, on every sheet
  /// open and from the retry button).
  bool get available =>
      _probed && !_unsupported && (_everLoaded || !_loadFailed);

  /// Reloads after an answer: always when the exchange created a stored
  /// conversation, otherwise only to retry a first load that failed. Nothing
  /// is asked of a host that said 403 or 404.
  Future<void> refreshAfterAnswer({required bool createdNew}) async {
    if (_unsupported) return;
    if (createdNew) {
      await load();
    } else {
      await retryIfNeeded();
    }
  }

  /// Loads again when no load has worked yet and the host may still offer the
  /// feature (the first load failed transiently or never ran).
  Future<void> retryIfNeeded() async {
    if (_everLoaded || _unsupported || _loading) return;
    await load();
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  /// Loads the first page. A 403 or 404 hides the feature for good; any other
  /// failure (including `unreachable`) keeps it visible and retryable.
  Future<void> load() async {
    final target = await _target();
    if (target == null || _disposed) return;
    _loading = true;
    _changed();
    final res = await _client.list(baseUrl: target.$1, token: target.$2);
    if (_disposed) return;
    _loading = false;
    _probed = true;
    if (res.isSuccess && res.value != null) {
      _conversations = res.value!.conversations;
      _unsupported = false;
      _loadFailed = false;
      _everLoaded = true;
    } else if (res.outcome == ConvOutcome.forbidden ||
        res.outcome == ConvOutcome.notFound) {
      _unsupported = true;
      _loadFailed = false;
    } else {
      _loadFailed = true;
    }
    _changed();
  }

  /// Fetches one stored conversation; the screen applies it.
  Future<ConvResult<ConversationDetail>?> open(String id) async {
    final target = await _target();
    if (target == null) return null;
    return _client.get(baseUrl: target.$1, token: target.$2, id: id);
  }

  /// Renames a conversation. Returns whether the server accepted it.
  Future<bool> rename(ConversationSummary conv, String title) async {
    final target = await _target();
    if (target == null || _disposed) return false;
    final res = await _client.rename(
        baseUrl: target.$1, token: target.$2, id: conv.id, title: title);
    if (_disposed || !res.isSuccess || res.value == null) return false;
    _conversations = [
      for (final item in _conversations)
        item.id == conv.id ? res.value! : item,
    ];
    _changed();
    return true;
  }

  /// Deletes a conversation; when it is the open one at the moment the server
  /// answers, [activeId] is cleared and the result tells the screen to clear
  /// the transcript.
  Future<DeleteOutcome> delete(ConversationSummary conv) async {
    final target = await _target();
    if (target == null || _disposed) return DeleteOutcome.failed;
    final res = await _client.deleteOne(
        baseUrl: target.$1, token: target.$2, id: conv.id);
    if (_disposed || !res.isSuccess) return DeleteOutcome.failed;
    _conversations =
        _conversations.where((c) => c.id != conv.id).toList(growable: false);
    final wasActive = activeId == conv.id;
    if (wasActive) activeId = null;
    _changed();
    return wasActive ? DeleteOutcome.deletedActive : DeleteOutcome.deleted;
  }

  /// Searches message text. An empty query leaves search mode. Only the
  /// newest request may change the state.
  Future<void> search(String raw) async {
    final q = raw.trim();
    final seq = ++_searchSeq;
    if (q.isEmpty) {
      clearSearch();
      return;
    }
    final target = await _target();
    if (target == null || _disposed || seq != _searchSeq) return;
    _searching = true;
    _searchFailed = false;
    _changed();
    final res = await _client.search(
        baseUrl: target.$1, token: target.$2, query: q);
    if (_disposed || seq != _searchSeq) return;
    _searching = false;
    if (res.isSuccess) {
      _searchHits = res.value ?? const [];
      _searchFailed = false;
    } else {
      _searchHits = null;
      _searchFailed = true;
    }
    _changed();
  }

  void clearSearch() {
    _searchSeq++;
    final changed = _searchHits != null || _searching || _searchFailed;
    _searchHits = null;
    _searching = false;
    _searchFailed = false;
    if (changed) _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
