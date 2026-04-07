import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../models/identity.dart';
import 'connections_provider.dart';

const _uuid = Uuid();

final identitiesProvider =
    AsyncNotifierProvider<IdentitiesNotifier, List<Identity>>(
  IdentitiesNotifier.new,
);

class IdentitiesNotifier extends AsyncNotifier<List<Identity>> {
  @override
  Future<List<Identity>> build() async {
    final storage = ref.read(storageServiceProvider);
    return storage.loadIdentities();
  }

  Future<void> add(Identity identity) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = [...current, identity.copyWith(id: _uuid.v4())];
    await storage.saveIdentities(updated);
    state = AsyncData(updated);
  }

  Future<void> updateIdentity(Identity identity) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = current.map((i) {
      return i.id == identity.id ? identity : i;
    }).toList();
    await storage.saveIdentities(updated);
    state = AsyncData(updated);
  }

  Future<void> delete(String id) async {
    final storage = ref.read(storageServiceProvider);
    final current = await future;
    final updated = current.where((i) => i.id != id).toList();
    await storage.saveIdentities(updated);
    await storage.deleteIdentitySecrets(id);
    state = AsyncData(updated);
  }
}
