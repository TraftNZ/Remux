import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../models/connection.dart';
import '../models/identity.dart';
import '../models/snippet.dart';

class StorageService {
  static const _secureStorage = FlutterSecureStorage();

  Future<String> get _storagePath async {
    final dir = await getApplicationSupportDirectory();
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir.path;
  }

  // Connections

  Future<List<Connection>> loadConnections() async {
    final path = await _storagePath;
    final file = File('$path/connections.json');
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as List;
    return json.map((e) => Connection.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveConnections(List<Connection> connections) async {
    final path = await _storagePath;
    final file = File('$path/connections.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        connections.map((c) => c.toJson()).toList(),
      ),
    );
  }

  // Identities (metadata in JSON, secrets in secure storage)

  Future<List<Identity>> loadIdentities() async {
    final path = await _storagePath;
    final file = File('$path/identities.json');
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as List;
    final identities = <Identity>[];
    for (final item in json) {
      final base = Identity.fromJson(item as Map<String, dynamic>);
      final password = await _secureStorage.read(key: 'identity_${base.id}_password');
      final privateKey = await _secureStorage.read(key: 'identity_${base.id}_privateKey');
      final passphrase = await _secureStorage.read(key: 'identity_${base.id}_passphrase');
      identities.add(base.copyWith(
        password: password,
        privateKey: privateKey,
        passphrase: passphrase,
      ));
    }
    return identities;
  }

  Future<void> saveIdentities(List<Identity> identities) async {
    final path = await _storagePath;
    final file = File('$path/identities.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        identities.map((i) => i.toJson()).toList(),
      ),
    );
    for (final identity in identities) {
      if (identity.password != null) {
        await _secureStorage.write(
          key: 'identity_${identity.id}_password',
          value: identity.password,
        );
      }
      if (identity.privateKey != null) {
        await _secureStorage.write(
          key: 'identity_${identity.id}_privateKey',
          value: identity.privateKey,
        );
      }
      if (identity.passphrase != null) {
        await _secureStorage.write(
          key: 'identity_${identity.id}_passphrase',
          value: identity.passphrase,
        );
      }
    }
  }

  Future<void> deleteIdentitySecrets(String identityId) async {
    await _secureStorage.delete(key: 'identity_${identityId}_password');
    await _secureStorage.delete(key: 'identity_${identityId}_privateKey');
    await _secureStorage.delete(key: 'identity_${identityId}_passphrase');
  }

  // Snippets

  Future<List<Snippet>> loadSnippets() async {
    final path = await _storagePath;
    final file = File('$path/snippets.json');
    if (!await file.exists()) return [];
    final json = jsonDecode(await file.readAsString()) as List;
    return json.map((e) => Snippet.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveSnippets(List<Snippet> snippets) async {
    final path = await _storagePath;
    final file = File('$path/snippets.json');
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(
        snippets.map((s) => s.toJson()).toList(),
      ),
    );
  }
}
