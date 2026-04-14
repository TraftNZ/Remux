/// Normalizes soft-keyboard / IME Enter into a single carriage return.
///
/// Hardware-keyboard Enter flows through `xterm`'s `defaultInputHandler` and
/// always arrives as `"\r"`. Soft keyboards (iOS/Android IMEs) deliver Enter
/// via `terminal.textInput`, which forwards it to `terminal.onOutput` as
/// `"\n"` — or on some IMEs as `"\r\n"`. Shells accept either in cooked mode,
/// but TUIs (tmux, vim, Claude Code, etc.) interpret `\r` and `\n` as
/// distinct characters and only treat `\r` as Enter, which is why
/// soft-keyboard Enter appears to "sometimes" work.
///
/// Collapsing `\r\n` first prevents Android IMEs that emit CRLF from being
/// rewritten to `\r\r` (a double submit) by the second pass.
String normalizeSoftEnter(String data) =>
    data.replaceAll('\r\n', '\r').replaceAll('\n', '\r');
