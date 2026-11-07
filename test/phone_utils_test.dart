import 'package:flutter_test/flutter_test.dart';
import 'package:verixa/core/utils/phone_utils.dart';
import 'package:verixa/features/auth/domain/user_profile.dart';

void main() {
  group('PhoneUtils', () {
    test('builds E.164 numbers', () {
      expect(PhoneUtils.toE164('+91', '99999 99999'), '+919999999999');
      expect(PhoneUtils.toE164('91', '98765-43210'), '+919876543210');
    });

    test('validates Indian mobile numbers', () {
      expect(PhoneUtils.validate('+91', '9999999999'), isNull);
      expect(PhoneUtils.validate('+91', '999999999'), isNotNull); // 9 digits
      expect(PhoneUtils.validate('+91', '5999999999'), isNotNull); // starts 5
      expect(PhoneUtils.validate('+91', ''), isNotNull);
    });

    test('accepts other countries with a plausible length', () {
      expect(PhoneUtils.validate('+1', '6505551234'), isNull);
      expect(PhoneUtils.validate('+1', '123'), isNotNull);
    });

    test('formats Indian numbers for display', () {
      expect(PhoneUtils.pretty('+919999999999'), '+91 99999 99999');
      expect(PhoneUtils.pretty('+16505551234'), '+16505551234');
    });
  });

  group('UserStatus', () {
    test('round-trips its Firestore id', () {
      for (final s in UserStatus.values) {
        expect(UserStatus.fromId(s.id), s);
      }
      expect(UserStatus.fromId('unknown'), isNull);
    });

    test('only working professionals are asked for a company', () {
      expect(UserStatus.workingProfessional.asksForCompany, isTrue);
      expect(UserStatus.student.asksForCompany, isFalse);
      expect(UserStatus.fresher.asksForCompany, isFalse);
    });
  });
}
