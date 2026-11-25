import 'package:shared_preferences/shared_preferences.dart';

/// Highest notification id already pulled from each host (D-123), so a pull
/// asks only for `since_id=<last seen>` and a notification is never shown or
/// announced twice. Kept in shared_preferences: an id is not a secret.
class NotificationStore {
  const NotificationStore();

  static String _key(String hostId) => 'notifications.$hostId.last_id';

  Future<int> lastSeenId(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_key(hostId)) ?? 0;
  }

  /// Raises the stored id; a lower value never overwrites a higher one.
  Future<void> saveLastSeenId(String hostId, int id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id > (prefs.getInt(_key(hostId)) ?? 0)) {
      await prefs.setInt(_key(hostId), id);
    }
  }

  Future<void> clear(String hostId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(hostId));
  }
}
