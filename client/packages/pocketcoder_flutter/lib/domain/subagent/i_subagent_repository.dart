import 'package:pocketcoder_flutter/domain/models/subagent.dart';

abstract class ISubagentRepository {
  Stream<List<Subagent>> watchSubagents(String chatId);
  Future<void> terminateSubagent(String id);
}
