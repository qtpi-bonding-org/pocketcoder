import 'package:freezed_annotation/freezed_annotation.dart';

part 'oauth_token.freezed.dart';
part 'oauth_token.g.dart';

@freezed
class OAuthToken with _$OAuthToken {
  const OAuthToken._();

  const factory OAuthToken({
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    required List<String> scopes,
  }) = _OAuthToken;

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  bool get needsRefresh =>
      DateTime.now().isAfter(expiresAt.subtract(const Duration(minutes: 5)));

  factory OAuthToken.fromJson(Map<String, dynamic> json) =>
      _$OAuthTokenFromJson(json);
}