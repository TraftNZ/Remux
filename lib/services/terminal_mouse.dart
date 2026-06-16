import 'package:xterm/xterm.dart';

/// SGR mouse-wheel escape sequences (mouse protocol 1006), encoded at cell
/// (1,1). These are what a real terminal sends for a scroll wheel when the
/// remote application has enabled mouse reporting. tmux with `mouse on`
/// forwards them to whatever app is in the pane (e.g. Claude Code scrolls its
/// own view); a bare shell ignores them.
///
/// Button 64 = wheel up, button 65 = wheel down. The trailing `M` marks a
/// button press (wheel events have no release). Used by the toolbar scroll
/// buttons, which inject these directly regardless of mouse mode.
const String mouseWheelUp = '\x1b[<64;1;1M';
const String mouseWheelDown = '\x1b[<65;1;1M';

// X10 mouse encoding constants (used by the non-SGR report modes).
const int _x10PrintableBase = 32;
const int _x10MaxCoordinate = 223;
const String _x10OverflowByte = '\x00';

/// xterm 4.0.0 assigns its scroll-wheel buttons the SGR ids 68..71
/// (`64 + 4`..`64 + 7`) instead of the standard 64..67. Full-screen mouse
/// apps such as Claude Code and tmux read 68/69 as *Shift*+wheel and ignore
/// them, so wheel scrolling silently does nothing. This is the size of that
/// error: subtract it to recover the correct wheel code.
const int _xtermWheelIdError = 4;

/// Drop-in replacement for xterm's [defaultMouseHandler] that corrects the
/// off-by-four scroll-wheel button ids. Non-wheel events (clicks, motion,
/// drag) are delegated unchanged.
///
/// Install with `terminal.mouseHandler = const WheelFixMouseHandler();` so the
/// terminal's existing wheel→escape pipeline produces valid sequences and the
/// physical mouse wheel scrolls the remote application.
class WheelFixMouseHandler implements TerminalMouseHandler {
  const WheelFixMouseHandler();

  @override
  String? call(TerminalMouseEvent event) {
    if (!event.button.isWheel) {
      return defaultMouseHandler(event);
    }
    // The application must have asked for scroll reporting; otherwise the
    // escape bytes would land in a non-mouse app (less, man, plain vim) as
    // garbage input.
    if (!event.state.mouseMode.reportScroll) return null;
    // Wheel events are press-only; xterm never reports a release for them.
    if (event.buttonState == TerminalMouseButtonState.up) return null;

    final code = event.button.id - _xtermWheelIdError;
    final x = event.position.x + 1;
    final y = event.position.y + 1;
    return _encode(code, x, y, event.state.mouseReportMode);
  }

  String _encode(int code, int x, int y, MouseReportMode mode) {
    switch (mode) {
      case MouseReportMode.sgr:
        return '\x1b[<$code;$x;${y}M';
      case MouseReportMode.urxvt:
        return '\x1b[${_x10PrintableBase + code};$x;${y}M';
      case MouseReportMode.normal:
      case MouseReportMode.utf:
        final cb = String.fromCharCode(_x10PrintableBase + code);
        final cx = x > _x10MaxCoordinate
            ? _x10OverflowByte
            : String.fromCharCode(_x10PrintableBase + x);
        final cy = y > _x10MaxCoordinate
            ? _x10OverflowByte
            : String.fromCharCode(_x10PrintableBase + y);
        return '\x1b[M$cb$cx$cy';
    }
  }
}
