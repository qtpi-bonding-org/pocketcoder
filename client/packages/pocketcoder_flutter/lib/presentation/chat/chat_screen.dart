import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pocketcoder_flutter/app/bootstrap.dart';
import 'package:pocketcoder_flutter/application/agent/chat_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/elicitation_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/permission_cubit.dart';
import 'package:pocketcoder_flutter/application/agent/session_controls_cubit.dart';
import 'package:pocketcoder_flutter/presentation/chat/adapters/chat_adapter.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key, this.chatId});

  final String? chatId;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<ChatCubit>(create: (_) => getIt<ChatCubit>()),
        BlocProvider<PermissionCubit>(create: (_) => getIt<PermissionCubit>()),
        BlocProvider<ElicitationCubit>(create: (_) => getIt<ElicitationCubit>()),
        BlocProvider<SessionControlsCubit>(
          create: (_) => getIt<SessionControlsCubit>(),
        ),
      ],
      child: ChatAdapter(chatId: chatId),
    );
  }
}
