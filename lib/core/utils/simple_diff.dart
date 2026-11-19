/// Line-by-line diff used by the project editor preview.
String simpleLineDiff(String before, String after) {
  if (before == after) return '';
  final beforeLines = before.split('\n');
  final afterLines = after.split('\n');
  final out = StringBuffer();
  final max = beforeLines.length > afterLines.length
      ? beforeLines.length
      : afterLines.length;
  for (var i = 0; i < max; i++) {
    final a = i < beforeLines.length ? beforeLines[i] : null;
    final b = i < afterLines.length ? afterLines[i] : null;
    if (a == b) continue;
    if (a != null) out.writeln('- ${i + 1}: $a');
    if (b != null) out.writeln('+ ${i + 1}: $b');
  }
  final text = out.toString();
  return text.length > 8000
      ? '${text.substring(0, 8000)}\n...[diff truncado]'
      : text;
}
