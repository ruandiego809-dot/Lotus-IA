import 'package:intl/intl.dart';

/// Human friendly day labels shared by the chat history and message list.
String formatDayLabel(DateTime value) {
  final now = DateTime.now();
  final day = DateTime(value.year, value.month, value.day);
  final today = DateTime(now.year, now.month, now.day);
  if (day == today) return 'Hoje';
  if (day == today.subtract(const Duration(days: 1))) return 'Ontem';
  return DateFormat('dd/MM/yyyy').format(value);
}

String formatShortDateTime(DateTime value) {
  final now = DateTime.now();
  final sameYear = now.year == value.year;
  return DateFormat(sameYear ? 'dd/MM • HH:mm' : 'dd/MM/yyyy • HH:mm')
      .format(value);
}

String formatRelative(DateTime value) {
  final diff = DateTime.now().difference(value);
  if (diff.inMinutes < 1) return 'agora';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 7) return '${diff.inDays} d';
  return DateFormat('dd/MM/yy').format(value);
}
