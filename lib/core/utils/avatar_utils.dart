/// Derives a single uppercase initial for avatar fallbacks from a display name.
///
/// The name is trimmed first so a whitespace-only name can never render a
/// blank circle, and '?' is returned when there is no usable name. Used
/// wherever the app shows a circular avatar without a photo (Dashboard header,
/// Settings, Profile) so every fallback behaves identically.
String avatarInitial(String? displayName) {
  final name = displayName?.trim() ?? '';
  if (name.isEmpty) return '?';
  return name[0].toUpperCase();
}
