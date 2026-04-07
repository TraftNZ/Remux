import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/identity.dart';
import '../providers/identities_provider.dart';

class IdentityTile extends ConsumerWidget {
  final Identity identity;

  const IdentityTile({super.key, required this.identity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: Key(identity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Identity'),
            content: Text('Delete "${identity.name}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) {
        ref.read(identitiesProvider.notifier).delete(identity.id);
      },
      child: ListTile(
        leading: Icon(
          identity.authType == AuthType.key ? Icons.vpn_key : Icons.password,
        ),
        title: Text(identity.name),
        subtitle: Text(
          '${identity.username} (${identity.authType == AuthType.key ? 'SSH Key' : 'Password'})',
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () => context.push('/identity/edit/${identity.id}'),
        ),
      ),
    );
  }
}
