/// A spending category for classifying expenses.
class CategoryEntity {
  const CategoryEntity({
    required this.categoryId,
    required this.name,
    this.icon = 'category',
    this.color = 0xFF00897B,
  });

  final String categoryId;
  final String name;
  final String icon;
  final int color;

  /// Default categories seeded per house.
  /// Colors follow the requested palette: Rent=Blue, Utilities=Orange,
  /// Food=Green, Household=Purple, Maintenance=Amber, Internet=Cyan, Other=Grey.
  static const List<CategoryEntity> defaults = [
    CategoryEntity(categoryId: 'rent', name: 'Rent', icon: 'home', color: 0xFF2563EB),
    CategoryEntity(categoryId: 'utilities', name: 'Utilities', icon: 'bolt', color: 0xFFF97316),
    CategoryEntity(categoryId: 'food', name: 'Food', icon: 'restaurant', color: 0xFF16A34A),
    CategoryEntity(categoryId: 'household', name: 'Household', icon: 'inventory', color: 0xFF7C3AED),
    CategoryEntity(categoryId: 'maintenance', name: 'Maintenance', icon: 'build', color: 0xFFD97706),
    CategoryEntity(categoryId: 'internet', name: 'Internet', icon: 'wifi', color: 0xFF0891B2),
    CategoryEntity(categoryId: 'other', name: 'Other', icon: 'more_horiz', color: 0xFF64748B),
  ];
}
