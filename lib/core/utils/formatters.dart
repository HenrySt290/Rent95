import 'package:intl/intl.dart';

class Formatters {
  const Formatters._();

  static String currency(num amount, {String symbol = '\$'}) {
    return NumberFormat.currency(symbol: symbol, decimalDigits: 2).format(amount);
  }

  static String compact(num value) => NumberFormat.compact().format(value);

  static String date(DateTime dt) => DateFormat.yMMMd().format(dt);
  static String dateTime(DateTime dt) => DateFormat.yMMMd().add_jm().format(dt);
  static String time(DateTime dt) => DateFormat.jm().format(dt);

  static String relative(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return date(dt);
  }
}
