import 'package:flutter/material.dart';

/// Maps a category id to a Material icon. Used consistently by the History
/// timeline, the Expenses list, and the detail pages so the whole app speaks
/// the same icon language.
IconData categoryIcon(String? categoryId) {
  switch (categoryId) {
    case 'food':
      return Icons.shopping_cart_outlined;
    case 'utilities':
      return Icons.bolt_outlined;
    case 'internet':
      return Icons.wifi_rounded;
    case 'cleaning':
      return Icons.cleaning_services_outlined;
    case 'maintenance':
      return Icons.build_outlined;
    case 'rent':
      return Icons.home_work_outlined;
    case 'shopping':
      return Icons.shopping_bag_outlined;
    case 'household':
      return Icons.home_outlined;
    default:
      return Icons.payments_outlined;
  }
}
