import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:xterm/xterm.dart';

import '../models/app_settings.dart';
import '../models/connection.dart';
import '../models/terminal_themes.dart';
import '../providers/connections_provider.dart';
import '../providers/identities_provider.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/snippets_provider.dart';
import '../widgets/session_sidebar.dart';
import '../widgets/terminal_toolbar.dart';
import '../widgets/session_tabs.dart';


/// Wraps a plain function as a [TerminalInputHandler].
class _FnInputHandler implements TerminalInputHandler {
  final String? Function(TerminalKeyboardEvent) fn;
  const _FnInputHandler(this.fn);

  @override
  String? call(TerminalKeyboardEvent event) => fn(event);
}

class TerminalScreen extends ConsumerStatefulWidget {
  const TerminalScreen({super.key});

  @override
  ConsumerState<TerminalScreen> createState() => _TerminalScreenState();
}

const double _wideBreakpoint = 720;

class _TerminalScreenState extends ConsumerState<TerminalScreen> {
  late final AppLifecycleListener _lifecycleListener;
  bool _sidebarVisible = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _terminalFocusNode = FocusNode();

  // Sticky modifier state shared between the toolbar and the hardware key handler.
  bool _ctrlModifier = false;
  bool _altModifier = false;

  /// Platform-aware CJK font fallback so Chinese/Japanese/Korean characters
  /// render using a font that's actually present on the device.
  static List<String> get _terminalFontFallback {
    const base = ['Menlo', 'Monaco', 'Consolas', 'Liberation Mono', 'Courier New'];
    const emoji = ['Noto Color Emoji', 'Noto Sans Symbols'];

    final List<String> cjk;
    if (Platform.isIOS || Platform.isMacOS) {
      cjk = ['PingFang SC', 'PingFang TC', 'Hiragino Sans GB', 'Hiragino Kaku Gothic ProN'];
    } else if (Platform.isAndroid) {
      cjk = ['Noto Sans CJK SC', 'Noto Sans CJK TC', 'Noto Sans CJK JP', 'DroidSansFallback'];
    } else if (Platform.isWindows) {
      cjk = ['Microsoft YaHei', 'SimHei', 'SimSun', 'NSimSun', 'MingLiU'];
    } else {
      // Linux and others
      cjk = [
        'Noto Sans Mono CJK SC', 'Noto Sans Mono CJK TC',
        'Noto Sans Mono CJK JP', 'Noto Sans Mono CJK KR',
        'WenQuanYi Zen Hei Mono', 'WenQuanYi Micro Hei Mono',
        'Source Han Mono SC', 'Sarasa Mono SC',
        'Noto Sans CJK SC',
      ];
    }

    return [...base, ...cjk, ...emoji, 'monospace', 'sans-serif'];
  }

  @override
  void initState() {
    super.initState();

    _lifecycleListener = AppLifecycleListener(onResume: _onAppResumed);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final s in ref.read(sessionProvider).sessions) {
        s.markTerminalReady();
        _attachInputHandler(s.terminal);
      }
    });
  }

  @override
  void dispose() {
    _terminalFocusNode.dispose();
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Sets a custom [TerminalInputHandler] on [terminal] that merges the
  /// sticky toolbar modifier with whatever modifier the event already carries.
  ///
  /// This intercepts **both** paths that xterm uses to deliver key input:
  ///   • Hardware keyboard path: _handleKeyEvent → keyInput(key, ctrl: true)
  ///   • IME/soft-keyboard path: _onInsert → keyInput(key)  ← ctrl lost here
  ///
  /// By sitting inside [inputHandler] we see every key before xterm converts
  /// it, so we can inject the sticky Ctrl/Alt before defaultInputHandler runs.
  void _attachInputHandler(Terminal terminal) {
    terminal.inputHandler = _FnInputHandler((event) {
      final ctrl = event.ctrl || _ctrlModifier;
      final alt = !ctrl && (event.alt || _altModifier);

      final modified = event.copyWith(ctrl: ctrl, alt: alt);
      final result = defaultInputHandler(modified);

      // Clear the sticky modifier only when a key was actually consumed.
      if (result != null && (_ctrlModifier || _altModifier)) {
        Future.microtask(() {
          if (mounted) {
            setState(() {
              _ctrlModifier = false;
              _altModifier = false;
            });
          }
        });
      }

      return result;
    });
  }

  void _onAppResumed() {
    final sessions = ref.read(sessionProvider).sessions;
    for (final s in sessions) {
      if (!s.isConnected && !s.isReconnecting) {
        ref.read(sessionProvider.notifier).reconnectNow(s);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-pop when all sessions are closed.
    // Mark newly added sessions ready after their first layout.
    ref.listen(sessionProvider, (prev, next) {
      if (next.sessions.isEmpty && mounted) {
        Navigator.of(context).pop();
        return;
      }
      if (next.sessions.length > (prev?.sessions.length ?? 0)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final s = next.sessions.last;
          s.markTerminalReady();
          _attachInputHandler(s.terminal);
        });
      }
    });

    final sessionState = ref.watch(sessionProvider);
    final activeSession = sessionState.activeSession;

    if (activeSession == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Terminal')),
        body: const Center(child: Text('No active sessions')),
      );
    }

    final settings = ref.watch(settingsProvider).valueOrNull;
    final tabPosition = settings?.tabPosition ?? TabPosition.top;
    final terminalTheme = settings?.terminalColorScheme.theme
        ?? TerminalColorScheme.vscodeDefault.theme;
    final fontSize = settings?.terminalFontSize ?? terminalFontSizeDefault;

    final sessionControls = (
      onTap: (int i) => ref.read(sessionProvider.notifier).setActiveIndex(i),
      onClose: (int i) => ref.read(sessionProvider.notifier).disconnect(i),
      onHide: () => Navigator.of(context).pop(),
      onAddSession: () => _showConnectionPicker(context),
    );

    final terminalStack = Stack(
      children: [
        TerminalView(
          activeSession.terminal,
          focusNode: _terminalFocusNode,
          autofocus: true,
          deleteDetection: true,
          theme: terminalTheme,
          textStyle: TerminalStyle(
            fontSize: fontSize,
            fontFamily: 'monospace',
            fontFamilyFallback: _terminalFontFallback,
          ),
        ),
        if (activeSession.isReconnecting)
          _ReconnectingOverlay(attempts: activeSession.reconnectAttempts),
      ],
    );

    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;
    final useDrawer = tabPosition == TabPosition.left && !isWide;

    final sidebar = SessionSidebar(
      sessions: sessionState.sessions,
      activeIndex: sessionState.activeIndex,
      onTap: (i) {
        _scaffoldKey.currentState?.closeDrawer();
        sessionControls.onTap(i);
      },
      onClose: sessionControls.onClose,
      onHide: useDrawer
          ? () {
              _scaffoldKey.currentState?.closeDrawer();
              Navigator.of(context).pop();
            }
          : sessionControls.onHide,
      onAddSession: useDrawer
          ? () {
              _scaffoldKey.currentState?.closeDrawer();
              sessionControls.onAddSession();
            }
          : sessionControls.onAddSession,
      onCollapse: (isWide && _sidebarVisible)
          ? () => setState(() => _sidebarVisible = false)
          : null,
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyW, control: true): () =>
            ref.read(sessionProvider.notifier).disconnect(sessionState.activeIndex),
        SingleActivator(LogicalKeyboardKey.tab, control: true): () {
          final n = sessionState.sessions.length;
          if (n > 1) {
            ref.read(sessionProvider.notifier)
                .setActiveIndex((sessionState.activeIndex + 1) % n);
          }
        },
        const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true): () =>
            _showConnectionPicker(context),
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.black,
        drawer: useDrawer ? Drawer(child: sidebar) : null,
        body: SafeArea(
          child: Builder(
            builder: (ctx) => _buildLayout(
              ctx,
              isWide: isWide,
              useDrawer: useDrawer,
              openDrawer: () => Scaffold.of(ctx).openDrawer(),
              sidebar: sidebar,
              tabPosition: tabPosition,
              terminalStack: terminalStack,
              sessionState: sessionState,
              sessionControls: sessionControls,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLayout(
    BuildContext context, {
    required bool isWide,
    required bool useDrawer,
    required VoidCallback openDrawer,
    required Widget sidebar,
    required TabPosition tabPosition,
    required Widget terminalStack,
    required dynamic sessionState,
    required dynamic sessionControls,
  }) {
    final VoidCallback? sidebarCallback = useDrawer
        ? openDrawer
        : (!_sidebarVisible ? () => setState(() => _sidebarVisible = true) : null);

    final toolbar = TerminalToolbar(
      ctrlActive: _ctrlModifier,
      altActive: _altModifier,
      onCtrlToggle: () => setState(() {
        _ctrlModifier = !_ctrlModifier;
        if (_ctrlModifier) _altModifier = false;
      }),
      onAltToggle: () => setState(() {
        _altModifier = !_altModifier;
        if (_altModifier) _ctrlModifier = false;
      }),
      onKey: (key) {
        sessionState.activeSession!.terminal.textInput(key);
        // Restore focus to terminal after any toolbar tap so the hardware
        // key handler and xterm both keep receiving keyboard events.
        _terminalFocusNode.requestFocus();
      },
      onSnippets: () => _showSnippetDrawer(context),
      vertical: isWide,
      onSidebar: sidebarCallback,
    );

    if (tabPosition == TabPosition.left) {
      final Widget leftPanel = (!useDrawer && _sidebarVisible) ? sidebar : const SizedBox.shrink();

      return Column(
        children: [
          Expanded(
            child: Row(
              children: [
                leftPanel,
                Expanded(child: terminalStack),
                if (isWide) toolbar,
              ],
            ),
          ),
          if (!isWide) toolbar,
        ],
      );
    }

    // Top tabs layout
    return Column(
      children: [
        SessionTabs(
          sessions: sessionState.sessions,
          activeIndex: sessionState.activeIndex,
          onTap: sessionControls.onTap,
          onClose: sessionControls.onClose,
          onHide: sessionControls.onHide,
          onAddSession: sessionControls.onAddSession,
        ),
        Expanded(
          child: isWide
              ? Row(children: [Expanded(child: terminalStack), toolbar])
              : terminalStack,
        ),
        if (!isWide) toolbar,
      ],
    );
  }

  void _showConnectionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ConnectionPickerSheet(),
    );
  }

  void _showSnippetDrawer(BuildContext context) {
    final snippets = ref.read(snippetsProvider);
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return snippets.when(
          loading: () => const SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => SizedBox(
            height: 200,
            child: Center(child: Text('Error: $e')),
          ),
          data: (list) {
            if (list.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(child: Text('No snippets')),
              );
            }
            return ListView(
              shrinkWrap: true,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Run Snippet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ...list.map((s) => ListTile(
                      leading: const Icon(Icons.play_arrow),
                      title: Text(s.name),
                      subtitle: Text(
                        s.command,
                        style: const TextStyle(fontFamily: 'monospace'),
                      ),
                      onTap: () {
                        ref
                            .read(sessionProvider.notifier)
                            .sendSnippet(s.command);
                        Navigator.pop(context);
                      },
                    )),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Overlays ─────────────────────────────────────────────────────────────────

class _ReconnectingOverlay extends StatelessWidget {
  final int attempts;

  const _ReconnectingOverlay({required this.attempts});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Reconnecting… (attempt ${attempts + 1})',
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Connection picker sheet ───────────────────────────────────────────────────

class _ConnectionPickerSheet extends ConsumerStatefulWidget {
  const _ConnectionPickerSheet();

  @override
  ConsumerState<_ConnectionPickerSheet> createState() =>
      _ConnectionPickerSheetState();
}

class _ConnectionPickerSheetState
    extends ConsumerState<_ConnectionPickerSheet> {
  String? _connectingId;

  @override
  Widget build(BuildContext context) {
    final connections = ref.watch(connectionsProvider).valueOrNull ?? [];
    final identities = ref.watch(identitiesProvider).valueOrNull ?? [];

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Open New Session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (!Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.computer),
              title: const Text('Local Shell'),
              onTap: () {
                ref.read(sessionProvider.notifier).connectLocal();
                Navigator.of(context).pop();
              },
            ),
          if (connections.isNotEmpty) const Divider(height: 1),
          if (connections.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No saved connections'),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: connections.length,
                itemBuilder: (context, index) {
                  final conn = connections[index];
                  final isConnecting = _connectingId == conn.id;
                  return ListTile(
                    leading: isConnecting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.dns_outlined),
                    title: Text(conn.name),
                    subtitle: Text('${conn.host}:${conn.port}'),
                    enabled: _connectingId == null,
                    onTap: () => _connect(conn, identities),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Future<void> _connect(
    Connection connection,
    List<dynamic> identities,
  ) async {
    final identity = identities
        .where((i) => i.id == connection.identityId)
        .firstOrNull;

    if (identity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('No identity assigned to this connection')),
      );
      return;
    }

    setState(() => _connectingId = connection.id);
    try {
      await ref.read(sessionProvider.notifier).connect(
            connection: connection,
            identity: identity,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connection failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _connectingId = null);
    }
  }
}
