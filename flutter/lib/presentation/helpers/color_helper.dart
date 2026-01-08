import 'package:flutter/widgets.dart';

Color getColorFromHex(String color) {
  try {
    final hex = color.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return const Color(0xFF808080);
  }
}
