import 'package:cubit_ui_flow/cubit_ui_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/scheduler/scheduler_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/models/schedule_owner.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/bios_action_strip.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/detail_row.dart';
import 'package:pocketcoder_flutter/presentation/scheduler/widgets/scheduler_view.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.lightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );

void main() {
  testWidgets(
    'renders a schedule as a DetailRow with a 4-action BiosActionStrip',
    (tester) async {
      await tester.pumpWidget(
        _app(
          SchedulerView(
            state: SchedulerState(
              status: UiFlowStatus.success,
              schedules: [
                ScheduleOwner(
                  id: 'sc1',
                  user: 'user123',
                  displayName: 'nightly backup',
                  cron: '0 2 * * *',
                  paused: false,
                ),
              ],
            ),
            onPause: (_) {},
            onUnpause: (_) {},
            onRunNow: (_) {},
            onDelete: (_) {},
            onRename: ({required id, required displayName}) async {},
            onUpdateCron: ({required id, required cron}) async {},
            onCreate: ({
              required displayName,
              required cron,
              required prompt,
            }) async {},
          ),
        ),
      );

      expect(find.byType(DetailRow), findsWidgets);
      final strip = tester.widget<BiosActionStrip>(
        find.byType(BiosActionStrip),
      );
      expect(strip.actions, hasLength(4));
    },
  );
}
