import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/theme/app_theme.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_footer.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';

/// The three navigation pillars of PocketCoder.
enum NavPillar { chats, monitor, configure }

/// Reusable layout shell that wraps every screen.
///
/// Screens never touch [TerminalScaffold], [TerminalFooter], or nav logic
/// directly. Instead they declare their title, active pillar, and body content.
class PocketCoderShell extends StatelessWidget {
  final String? title;
  final NavPillar activePillar;
  final Widget body;
  final bool showBack;
  final String? backLabel;
  final bool showNavigation;
  final bool configureBadge;
  final EdgeInsets? padding;

  /// Extra actions that intentionally belong in the compact header row.
  final List<TerminalAction>? extraHeaderActions;

  const PocketCoderShell({
    super.key,
    required this.title,
    required this.activePillar,
    required this.body,
    this.showBack = false,
    this.backLabel,
    this.showNavigation = true,
    this.configureBadge = false,
    this.padding,
    this.extraHeaderActions,
  });

  @override
  Widget build(BuildContext context) {
    final footerActions = <TerminalAction>[
      if (showBack)
        TerminalAction(
          label: backLabel ?? context.l10n.actionBack,
          onTap: () => AppNavigation.back(context),
        ),
    ];

    final releaseScope = ReleaseStatusScope.maybeOf(context);
    return _buildScaffold(
      context,
      releaseScope?.state ?? const ReleaseStatusState(),
      footerActions,
      releaseScope?.onDismiss,
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    ReleaseStatusState releaseState,
    List<TerminalAction> originalFooterActions,
    VoidCallback? onDismiss,
  ) {
    final footerActions = <TerminalAction>[
      for (final action in originalFooterActions) action,
      if (showNavigation)
        ..._buildPillarActions(context, releaseState.shouldShowNotice),
    ];
    return TerminalScaffold(
      title: title,
      padding: padding,
      headerActions: extraHeaderActions,
      actions: footerActions.isNotEmpty ? footerActions : null,
      body: Column(
        children: [
          ReleaseStatusBanner(
            state: releaseState,
            onDismiss: onDismiss ?? () {},
          ),
          Expanded(child: body),
        ],
      ),
    );
  }

  List<TerminalAction> _buildPillarActions(
    BuildContext context,
    bool hasReleaseNotice,
  ) {
    return [
      TerminalAction(
        label: context.l10n.navChats,
        isActive: activePillar == NavPillar.chats,
        onTap: () {
          if (activePillar != NavPillar.chats) {
            context.go(AppRoutes.chats);
          }
        },
      ),
      TerminalAction(
        label: context.l10n.navMonitor,
        isActive: activePillar == NavPillar.monitor,
        onTap: () {
          if (activePillar != NavPillar.monitor) {
            context.go(AppRoutes.monitor);
          }
        },
      ),
      TerminalAction(
        label: context.l10n.navConfigure,
        isActive: activePillar == NavPillar.configure,
        hasBadge: configureBadge || hasReleaseNotice,
        onTap: () {
          if (activePillar != NavPillar.configure) {
            context.go(AppRoutes.configure);
          }
        },
      ),
    ];
  }
}
