import 'package:flutter_test/flutter_test.dart';
import 'package:rental_ledger/core/widgets/breakpoints.dart';

void main() {
  group('AppBreakpoints.ofSize', () {
    test('classifies compact below 600px', () {
      expect(AppBreakpoints.ofSize(0), AppBreakpoint.compact);
      expect(AppBreakpoints.ofSize(320), AppBreakpoint.compact);
      expect(AppBreakpoints.ofSize(599), AppBreakpoint.compact);
    });

    test('classifies medium from 600px to 839px', () {
      expect(AppBreakpoints.ofSize(600), AppBreakpoint.medium);
      expect(AppBreakpoints.ofSize(768), AppBreakpoint.medium);
      expect(AppBreakpoints.ofSize(839), AppBreakpoint.medium);
    });

    test('classifies expanded from 840px to 1199px', () {
      expect(AppBreakpoints.ofSize(840), AppBreakpoint.expanded);
      expect(AppBreakpoints.ofSize(1024), AppBreakpoint.expanded);
      expect(AppBreakpoints.ofSize(1199), AppBreakpoint.expanded);
    });

    test('classifies extraLarge at and above 1200px', () {
      expect(AppBreakpoints.ofSize(1200), AppBreakpoint.extraLarge);
      expect(AppBreakpoints.ofSize(1440), AppBreakpoint.extraLarge);
      expect(AppBreakpoints.ofSize(1920), AppBreakpoint.extraLarge);
    });
  });

  group('AppBreakpoint helpers', () {
    test('isTabletOrWider is true at medium and above', () {
      expect(AppBreakpoint.compact.isTabletOrWider, isFalse);
      expect(AppBreakpoint.medium.isTabletOrWider, isTrue);
      expect(AppBreakpoint.expanded.isTabletOrWider, isTrue);
      expect(AppBreakpoint.extraLarge.isTabletOrWider, isTrue);
    });

    test('isDesktopOrWider is true at expanded and above', () {
      expect(AppBreakpoint.compact.isDesktopOrWider, isFalse);
      expect(AppBreakpoint.medium.isDesktopOrWider, isFalse);
      expect(AppBreakpoint.expanded.isDesktopOrWider, isTrue);
      expect(AppBreakpoint.extraLarge.isDesktopOrWider, isTrue);
    });

    test('isLargeDesktop is true only at extraLarge', () {
      expect(AppBreakpoint.compact.isLargeDesktop, isFalse);
      expect(AppBreakpoint.medium.isLargeDesktop, isFalse);
      expect(AppBreakpoint.expanded.isLargeDesktop, isFalse);
      expect(AppBreakpoint.extraLarge.isLargeDesktop, isTrue);
    });
  });
}
