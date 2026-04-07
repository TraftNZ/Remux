import 'package:flutter/material.dart';

import '../models/terminal_session.dart';

class SessionTabs extends StatelessWidget {
  final List<TerminalSession> sessions;
  final int activeIndex;
  final void Function(int index) onTap;
  final void Function(int index) onClose;
  final VoidCallback onHide;
  final VoidCallback onAddSession;

  const SessionTabs({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.onTap,
    required this.onClose,
    required this.onHide,
    required this.onAddSession,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      height: 40,
      child: Row(
        children: [
          // Hide to dashboard
          IconButton(
            icon: const Icon(Icons.home_outlined, size: 20),
            tooltip: 'Dashboard (keep sessions alive)',
            onPressed: onHide,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
          const VerticalDivider(width: 1, indent: 6, endIndent: 6),
          // Session tabs
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = index == activeIndex;
                return InkWell(
                  onTap: () => onTap(index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: isActive
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      color: isActive
                          ? Theme.of(context).colorScheme.surface
                          : Colors.transparent,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          session.isConnected
                              ? Icons.circle
                              : Icons.circle_outlined,
                          size: 8,
                          color:
                              session.isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          session.displayName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => onClose(index),
                          child: const Icon(Icons.close, size: 16),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(width: 1, indent: 6, endIndent: 6),
          // New session
          IconButton(
            icon: const Icon(Icons.add, size: 20),
            tooltip: 'New session',
            onPressed: onAddSession,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          ),
        ],
      ),
    );
  }
}
