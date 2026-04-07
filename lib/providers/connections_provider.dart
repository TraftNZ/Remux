import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/connection.dart';
import '../services/storage_service.dart';

const _uuid = Uuid();

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final connectionsProvider =
    AsyncNotifierProvider<ConnectionsNotifier, List<Connection>>(
  ConnectionsNotifier.new,
);

class ConnectionsNotifier extends AsyncNotifier<List<Connection>> {
  StorageService get _storage => ref.read(storageServiceProvider);

  @override
  Future<List<Connection>> build() async {
    return _storage.loadConnections();
  }

  Future<void> add(Connection connection) async {
    final current = await future;
    final updated = [...current, connection.copyWith(id: _uuid.v4())];
    await _storage.saveConnections(updated);
    state = AsyncData(updated);
  }

  Future<void> updateConnection(Connection connection) async {
    final current = await future;
    final updated = current.map((c) {
      return c.id == connection.id ? connection : c;
    }).toList();
    await _storage.saveConnections(updated);
    state = AsyncData(updated);
  }

  Future<void> delete(String id) async {
    final current = await future;
    final updated = current.where((c) => c.id != id).toList();
    await _storage.saveConnections(updated);
    state = AsyncData(updated);
  }
}
