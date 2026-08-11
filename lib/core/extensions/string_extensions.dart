/// Extension methods on [String] for common formatting and validation.
extension StringExtensions on String {
  /// Capitalizes the first letter of this string.
  String get capitalize {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Capitalizes the first letter of each word.
  String get titleCase {
    return split(' ').map((word) => word.capitalize).join(' ');
  }

  /// Returns `true` if this string is a valid email address.
  bool get isValidEmail {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(this);
  }

  /// Returns `true` if this string is a valid UUID.
  bool get isValidUuid {
    return RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    ).hasMatch(this);
  }

  /// Truncates the string to [maxLength] and appends '...' if longer.
  String truncate(int maxLength) {
    if (length <= maxLength) return this;
    return '${substring(0, maxLength)}...';
  }
}
