import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/pocketbase_inspector/pocketbase_inspector_cubit.dart';
import 'package:pocketcoder_flutter/design_system/primitives/ui_scaler.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/pocketbase_inspector/i_pocketbase_inspector_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/pocketbase_inspector/pocketbase_inspector_screen.dart';

class _FakePocketbaseInspectorRepository
    implements IPocketbaseInspectorRepository {
  _FakePocketbaseInspectorRepository({this.stats, this.error});

  final PocketbaseInspectorStats? stats;
  final Object? error;

  @override
  Future<PocketbaseInspectorStats> fetchStats() async {
    if (error != null) throw error!;
    return stats ?? const PocketbaseInspectorStats();
  }
}

Widget _app(PocketbaseInspectorCubit cubit) => MaterialApp(
      theme: AppTheme.darkTheme,
      builder: (context, child) {
        UiScaler.instance.init(context);
        return child ?? const SizedBox.shrink();
      },
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const PocketbaseInspectorScreen(),
      ),
    );

void main() {
  testWidgets('renders counts and recent chats once loaded', (tester) async {
    final cubit = PocketbaseInspectorCubit(_FakePocketbaseInspectorRepository(
      stats: const PocketbaseInspectorStats(
        users: 2,
        chats: 5,
        agentProfiles: 1,
        harnesses: 4,
        mcpServers: 0,
        skills: 0,
        recentChats: [
          PocketbaseChatSummary(
            id: 'chat-1',
            title: 'Fix the login bug',
            turn: 'assistant',
            createdAt: '2026-08-30 00:00:00',
            lastActive: '2026-08-30 01:00:00',
          ),
        ],
      ),
    ));
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('5'), findsOneWidget);
    expect(find.text('fix the login bug'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('shows an unavailable message when the fetch fails',
      (tester) async {
    final cubit = PocketbaseInspectorCubit(
      _FakePocketbaseInspectorRepository(error: Exception('proxy unreachable')),
    );
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('database unavailable'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('fits detail rows at the shell content width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(480, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final cubit = PocketbaseInspectorCubit(
      _FakePocketbaseInspectorRepository(),
    );

    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await cubit.close();
  });
}
