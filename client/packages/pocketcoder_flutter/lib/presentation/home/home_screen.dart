import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_cubit.dart';
import 'package:pocketcoder_flutter/application/chat/chat_list_state.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_loading_indicator.dart';
import '../../app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => getIt<ChatListCubit>()..loadChats(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatListCubit, ChatListState>(
      builder: (context, state) {
        return TerminalScaffold(
          title: 'POCKETCODER HOME',
          actions: [
            TerminalAction(
              label: 'SETTINGS',
              onTap: () => AppNavigation.toSettings(context),
            ),
            TerminalAction(
              label: 'LOGOUT',
              onTap: () => context
                  .goNamed(RouteNames.boot), // Or auth route depending on flow
            ),
          ],
          body: _buildBody(context, state),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, ChatListState state) {
    final colors = context.colorScheme;
    final textTheme = context.textTheme;

    if (state.isLoading) {
      return const Center(
          child: TerminalLoadingIndicator(label: 'LOADING CHATS'));
    }

    if (state.hasError) {
      return Center(
        child: Text(
          'ERROR: ${state.error}',
          style: textTheme.bodyMedium?.copyWith(color: colors.error),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.all(AppSizes.space),
          child: ElevatedButton(
            onPressed: () => _handleNewChat(context),
            child: const Text('NEW CHAT'),
          ),
        ),
        Expanded(
          child: state.chats.isEmpty
              ? Center(
                  child: Text(
                    'No active chats found.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: state.chats.length,
                  itemBuilder: (context, index) {
                    final chat = state.chats[index];
                    return ListTile(
                      title: Text(
                        chat.title.toUpperCase(),
                        style: textTheme.bodyMedium,
                      ),
                      subtitle: Text(
                        'ID: ${chat.id}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.5),
                        ),
                      ),
                      onTap: () => AppNavigation.toChat(context, chat.id),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _handleNewChat(BuildContext context) {
    AppNavigation.toNewChat(context);
  }
}
