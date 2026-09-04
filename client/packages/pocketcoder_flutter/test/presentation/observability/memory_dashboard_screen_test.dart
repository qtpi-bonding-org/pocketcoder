import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocketcoder_flutter/application/memory/memory_cubit.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/domain/memory/i_memory_repository.dart';
import 'package:pocketcoder_flutter/l10n/app_localizations.dart';
import 'package:pocketcoder_flutter/presentation/observability/memory_dashboard_screen.dart';

class _FakeMemoryRepository implements IMemoryRepository {
  _FakeMemoryRepository({this.stats, this.error});

  final MemoryStats? stats;
  final Object? error;

  @override
  Future<MemoryStats> fetchStats() async {
    if (error != null) throw error!;
    return stats ?? const MemoryStats();
  }
}

Widget _app(MemoryCubit cubit) => MaterialApp(
      theme: AppTheme.darkTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider.value(
        value: cubit,
        child: const MemoryDashboardScreen(),
      ),
    );

void main() {
  testWidgets('renders counts and recent entries once loaded', (tester) async {
    final cubit = MemoryCubit(_FakeMemoryRepository(
      stats: const MemoryStats(
        observations: 3,
        interpretations: 1,
        links: 2,
        byAccount: [
          MemoryAccountSummary(
            accountId: 'acc-1',
            agentProfileId: 'profile-1',
            agentName: 'Goose',
            observations: 3,
            interpretations: 1,
          ),
        ],
        recentObservations: [
          MemoryObservation(
            id: 'obs-1',
            accountId: 'acc-1',
            author: 'Goose',
            body: 'The user prefers dark mode.',
            createdAt: '2026-08-30 00:00:00',
            updatedAt: '2026-08-30 00:00:00',
            retrievedAt: '2026-08-30 00:00:00',
          ),
        ],
        recentInterpretations: [],
      ),
    ));
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('3'), findsOneWidget);
    expect(find.text('Goose'), findsWidgets);
    expect(find.text('The user prefers dark mode.'), findsOneWidget);
    await cubit.close();
  });

  testWidgets('shows an unavailable message when the fetch fails',
      (tester) async {
    final cubit = MemoryCubit(
      _FakeMemoryRepository(error: Exception('proxy unreachable')),
    );
    await tester.pumpWidget(_app(cubit));
    await tester.pumpAndSettle();

    expect(find.text('MEMORY UNAVAILABLE'), findsOneWidget);
    await cubit.close();
  });
}
