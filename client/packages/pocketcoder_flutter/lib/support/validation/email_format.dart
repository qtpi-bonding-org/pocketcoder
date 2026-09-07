// Mirrors PocketBase's own EmailField rule (govalidator.IsEmail): a domain
// needs at least one dot, so "user@localhost" is rejected here too.
final _emailFormat = RegExp(
  r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+"
  r'@[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?'
  r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?)+$',
);

bool isValidEmailFormat(String value) => _emailFormat.hasMatch(value);
