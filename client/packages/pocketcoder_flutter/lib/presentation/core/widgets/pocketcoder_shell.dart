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

  /// Null defers to [showBack]: a screen reached via Back is a sub-screen
  /// of whichever pillar it lives under, so the pillar row would just be
  /// redundant chrome next to Back -- and pushes the footer past the
  /// 4-button budget (see docs/superpowers/specs footer-normalization
  /// notes). Pass this explicitly only for the rare screen that is both
  /// a back-target and wants the pillar row anyway.
  final bool? showNavigation;
  final bool configureBadge;
  final EdgeInsets? padding;
  final List<TerminalAction>? actions;

  const PocketCoderShell({
    super.key,
    required this.title,
    required this.activePillar,
    required this.body,
    this.showBack = false,
    this.backLabel,
    this.showNavigation,
    this.configureBadge = false,
    this.padding,
    this.actions,
  });

  bool get _effectiveShowNavigation => showNavigation ?? !showBack;

  @override
  Widget build(BuildContext context) {
    // Back is always the leftmost button -- it is the one constant escape
    // hatch, so it belongs in the one constant position.
    final footerActions = <TerminalAction>[
      if (showBack)
        TerminalAction(
          label: backLabel ?? context.l10n.actionBack,
          onTap: () => AppNavigation.back(context),
        ),
      ...?actions,
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
      if (_effectiveShowNavigation)
        ..._buildPillarActions(context, releaseState.shouldShowNotice),
    ];
    return TerminalScaffold(
      title: title,
      padding: padding,
      actions: footerActions.isNotEmpty ? footerActions : null,
      body: Column(
        children: [
          // This is the banner slot from the page-scaffold spec (see
          // docs/superpowers/specs/2026-08-23-page-scaffold.md §2, §3):
          // persistent, app-level, dismissible notices only. It is
          // deliberately NOT exposed as a per-screen constructor parameter
          // -- ReleaseStatusBanner is the only thing that has ever earned
          // this slot. A screen-local, transient notice (an error, a
          // status change, a one-off announcement) belongs in VimToast
          // (lib/presentation/core/widgets/vim_toast.dart), not here.
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
