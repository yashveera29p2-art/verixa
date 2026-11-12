import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:verixa/features/auth/data/auth_errors.dart';
import 'package:verixa/features/auth/data/otp_api.dart';

void main() {
  OtpApi api(int status, Map<String, dynamic> body, {List<String>? calls}) =>
      OtpApi(
        baseUrl: 'https://api.test',
        client: MockClient((req) async {
          calls?.add('${req.url.path} ${req.body}');
          return http.Response(jsonEncode(body), status);
        }),
      );

  test('start sends the number and returns the session', () async {
    final calls = <String>[];
    final session =
        await api(200, {'session': 'abc'}, calls: calls).start('+919876543210');
    expect(session, 'abc');
    expect(calls.single, '/v1/auth/otp/start {"phone":"+919876543210"}');
  });

  test('verify returns the Firebase token', () async {
    final token = await api(200, {'firebaseToken': 'tok'})
        .verify(session: 'abc', code: '123456');
    expect(token, 'tok');
  });

  test('server messages reach the user as-is', () async {
    final call = api(429, {'detail': 'Please wait 20 seconds.'}).start('+919876543210');
    await expectLater(
      call,
      throwsA(isA<OtpApiException>()
          .having((e) => friendlyAuthError(e), 'message', 'Please wait 20 seconds.')),
    );
  });
}
