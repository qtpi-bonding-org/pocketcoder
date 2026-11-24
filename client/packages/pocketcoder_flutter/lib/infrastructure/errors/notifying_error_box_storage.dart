import 'dart:async';

import 'package:flutter_error_privserver/flutter_error_privserver.dart';

class NotifyingErrorBoxStorage implements ErrorBoxStorage {
  NotifyingErrorBoxStorage(this._delegate);

  final ErrorBoxStorage _delegate;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  Stream<void> get changes => _changes.stream;

  @override
  Future<void> saveError(ErrorEntry error) async {
    await _delegate.saveError(error);
    _changes.add(null);
  }

  @override
  Future<void> markAsSent(String id) async {
    await _delegate.markAsSent(id);
    _changes.add(null);
  }

  @override
  Future<void> deleteError(String id) async {
    await _delegate.deleteError(id);
    _changes.add(null);
  }

  @override
  Future<List<ErrorBoxEntry>> getUnsentErrors() => _delegate.getUnsentErrors();

  @override
  Future<ErrorBoxEntry?> getErrorById(String id) => _delegate.getErrorById(id);

  @override
  Future<int> getUnsentCount() => _delegate.getUnsentCount();
}
