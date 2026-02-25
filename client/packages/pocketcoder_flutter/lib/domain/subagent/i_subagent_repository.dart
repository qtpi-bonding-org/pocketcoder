import 'subagent.dart';

abstract class ISubagentRepository {
  Stream<List<Subagent>> watchSubagents(String chatId);
  Future<void> terminateSubagent(String id);
}
