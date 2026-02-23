class ProposalException implements Exception {
  final String message;
  final Object? cause;

  ProposalException(this.message, {this.cause});

  @override
  String toString() => 'ProposalException: $message';
}