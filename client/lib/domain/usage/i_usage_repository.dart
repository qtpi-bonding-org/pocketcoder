import 'package:pocketbase/pocketbase.dart';

import 'usage.dart';

abstract class IUsageRepository {
  Future<List<Usage>> getUsages({String? messageId, int page = 1, int perPage = 30});
  Future<UsageStats> getUsageStats();
  Future<Usage> trackUsage(Usage usage);
  Stream<List<RecordModel>> watchUsages();
}