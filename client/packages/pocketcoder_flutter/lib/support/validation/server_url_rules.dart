enum ServerUrlIssue { missingScheme, invalid }

final _httpScheme = RegExp(r'^https?://', caseSensitive: false);
final _whitespace = RegExp(r'\s');

ServerUrlIssue? serverUrlIssue(String url) {
  if (!_httpScheme.hasMatch(url)) return ServerUrlIssue.missingScheme;
  if (url.contains(_whitespace)) return ServerUrlIssue.invalid;
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return ServerUrlIssue.invalid;
  return null;
}
