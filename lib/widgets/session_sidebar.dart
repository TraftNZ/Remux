import 'package:flutter/material.dart';

import '../models/terminal_session.dart';

/// Vertical left-side session panel — alternative to the horizontal SessionTabs.
class SessionSidebar extends StatelessWidget {
  final List<TerminalSession> sessions;
  final int activeIndex;
  final void Function(int index) onTap;
  final void Function(int index) onClose;
  final VoidCallback onHide;
  final VoidCallback onAddSession;
  final VoidCallback? onCollapse;

  const SessionSidebar({
    super.key,
    required this.sessions,
    required this.activeIndex,
    required this.onTap,
    required this.onClose,
    required this.onHide,
    required this.onAddSession,
    this.onCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: 160,
      color: colorScheme.surfaceContainerHighest,
      child: Column(
        children: [
          // Top row: collapse button (only when collapsible)
          if (onCollapse != null) ...[
            Align(
              alignment: Alignment.centerRight,
              child: _SidebarIconButton(
                icon: Icons.chevron_left,
                tooltip: 'Collapse sidebar',
                onPressed: onCollapse!,
              ),
            ),
            const Divider(height: 1),
          ],
          // Session list
          Expanded(
            child: ListView.builder(
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                final isActive = index == activeIndex;
                return _SessionSidebarItem(
                  session: session,
                  isActive: isActive,
                  onTap: () => onTap(index),
                  onClose: () => onClose(index),
                );
              },
            ),
          ),
          const Divider(height: 1),
          // Bottom row: dashboard + new session
          Row(
            children: [
              Expanded(
                child: _SidebarIconButton(
                  icon: Icons.home_outlined,
                  tooltip: 'Dashboard (keep sessions alive)',
                  onPressed: onHide,
                ),
              ),
              Expanded(
                child: _SidebarIconButton(
                  icon: Icons.add,
                  tooltip: 'New session',
                  onPressed: onAddSession,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SessionSidebarItem extends StatelessWidget {
  final TerminalSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _SessionSidebarItem({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: isActive ? colorScheme.surface : Colors.transparent,
        border: Border(
          left: BorderSide(
            color: isActive ? colorScheme.primary : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Icon(
                      session.isConnected ? Icons.circle : Icons.circle_outlined,
                      size: 8,
                      color: session.isConnected ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        session.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isActive ? FontWeight.bold : FontWeight.normal,
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            onPressed: onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}

class _SidebarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _SidebarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: IconButton(
        icon: Icon(icon, size: 20),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
