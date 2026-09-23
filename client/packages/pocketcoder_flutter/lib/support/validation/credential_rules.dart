import 'package:pocketcoder_flutter/support/validation/email_format.dart';

const kPocketBasePasswordMinLength = 8;
const kPocketBasePasswordMaxLength = 71;

final _lineBreakOrTab = RegExp('[\n\r\t]');

bool hasSurroundingWhitespace(String value) => value != value.trim();

bool containsLineBreakOrTab(String value) => value.contains(_lineBreakOrTab);

int passwordRuneLength(String value) => value.runes.length;

enum EmailIssue { surroundingWhitespace, invalidFormat }

EmailIssue? emailIssue(String email) {
  if (hasSurroundingWhitespace(email)) return EmailIssue.surroundingWhitespace;
  if (!isValidEmailFormat(email)) return EmailIssue.invalidFormat;
  return null;
}

enum PasswordIssue { surroundingWhitespace, tooShort, tooLong }

PasswordIssue? newPasswordIssue(String password) {
  if (hasSurroundingWhitespace(password)) {
    return PasswordIssue.surroundingWhitespace;
  }
  final length = passwordRuneLength(password);
  if (length < kPocketBasePasswordMinLength) return PasswordIssue.tooShort;
  if (length > kPocketBasePasswordMaxLength) return PasswordIssue.tooLong;
  return null;
}

// Login accepts any password verbatim, so these only warn, never block.
bool loginPasswordLooksPasted(String password) =>
    hasSurroundingWhitespace(password) || containsLineBreakOrTab(password);
