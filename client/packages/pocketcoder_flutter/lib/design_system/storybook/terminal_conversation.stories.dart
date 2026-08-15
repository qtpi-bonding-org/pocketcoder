import 'package:flutter/material.dart';
import 'package:widgetbook_annotation/widgetbook_annotation.dart' as wb;
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_conversation.dart';

Widget _app(Widget child) => MaterialApp(
      theme: AppTheme.darkTheme,
      home: Scaffold(
        body: Padding(
          padding: EdgeInsets.all(AppSizes.space * 2),
          child: child,
        ),
      ),
    );

@wb.UseCase(name: 'prepared Poco turn', type: TerminalConversationTurn)
Widget terminalPocoTurn(BuildContext context) => _app(
      const TerminalConversationTurn(
        speaker: TerminalConversationSpeaker.poco,
        message:
            'I found the deployment configuration. What would you like to inspect?',
      ),
    );

@wb.UseCase(name: 'prepared user turn', type: TerminalConversationTurn)
Widget terminalUserTurn(BuildContext context) => _app(
      const TerminalConversationTurn(
        speaker: TerminalConversationSpeaker.user,
        message: 'Show me the deployment status.',
      ),
    );

@wb.UseCase(name: 'live message frame', type: TerminalConversationFrame)
Widget terminalLiveFrame(BuildContext context) => _app(
      const TerminalConversationFrame(
        speaker: TerminalConversationSpeaker.poco,
        roleLabel: 'POCO',
        child: Text('This frame is shared by live AG-UI rendering.'),
      ),
    );
