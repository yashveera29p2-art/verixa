import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/app/routes.dart';
import 'package:verixa/core/utils/greeting.dart';
import 'package:verixa/features/companies/domain/company_category.dart';

DateTime at(int hour, [int minute = 0]) => DateTime(2026, 1, 1, hour, minute);

void main() {
  group('greetingFor (CLAUDE.md §4 boundaries)', () {
    test('morning is 04:00–11:59', () {
      expect(greetingFor(at(4)), 'Good morning');
      expect(greetingFor(at(11, 59)), 'Good morning');
    });

    test('afternoon is 12:00–16:59', () {
      expect(greetingFor(at(12)), 'Good afternoon');
      expect(greetingFor(at(16, 59)), 'Good afternoon');
    });

    test('evening is 17:00–03:59', () {
      expect(greetingFor(at(17)), 'Good evening');
      expect(greetingFor(at(23, 59)), 'Good evening');
      expect(greetingFor(at(0)), 'Good evening');
      expect(greetingFor(at(3, 59)), 'Good evening');
    });

    test('adds the first name when known', () {
      expect(greetingWithName(at(9), 'Asha'), 'Good morning, Asha');
      expect(greetingWithName(at(9), null), 'Good morning');
      expect(greetingWithName(at(9), '  '), 'Good morning');
    });
  });

  test('every company category has a route', () {
    for (final c in CompanyCategory.values) {
      expect(CompanyCategory.fromId(c.id), c);
      expect(AppRoutes.isProtected(AppRoutes.companiesFor(c.id)), isTrue);
    }
    expect(CompanyCategory.fromId('bank'), isNull);
  });

  test('auth routes are not protected, main routes are', () {
    expect(AppRoutes.isProtected(AppRoutes.welcome), isFalse);
    expect(AppRoutes.isProtected(AppRoutes.phone), isFalse);
    expect(AppRoutes.isProtected(AppRoutes.home), isTrue);
    expect(AppRoutes.isProtected(AppRoutes.profile), isTrue);
  });
}
