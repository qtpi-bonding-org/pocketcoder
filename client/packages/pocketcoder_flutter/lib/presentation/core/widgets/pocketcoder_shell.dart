import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:pocketcoder_flutter/app_router.dart';
import 'package:pocketcoder_flutter/design_system/primitives/nav_pillar.dart';
import 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart';
import 'package:pocketcoder_flutter/domain/settings/i_local_settings_service.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/terminal_scaffold.dart';
import 'package:pocketcoder_flutter/application/release_status/release_status_cubit.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/release_status_banner.dart';
import 'package:pocketcoder_flutter/presentation/core/widgets/shell_footer_view.dart';
import 'package:pocketcoder_flutter/domain/server_control/i_server_control_service.dart';

// Re-export TerminalAction for convenience
export 'package:pocketcoder_flutter/design_system/primitives/shell_footer.dart'
    show TerminalAction;

void _navHaptic() {
  if (GetIt.instance<ILocalSettingsService>().hapticsEnabledSync) {
    HapticFeedback.selectionClick();
  }
}

PillarFooter buildPillarFooter(
  BuildContext context,
  NavPillar active, {
  bool configureBadge = false,
  List<TerminalAction> extraActions = const [],
}) {
  return PillarFooter(
    active: active,
    onSelect: (pillar) {
      if (pillar == active) return;
      _navHaptic();
      context.go(switch (pillar) {
        NavPillar.chat => AppRoutes.chats,
        NavPillar.config => AppRoutes.configure,
        NavPillar.status => AppRoutes.monitor,
        NavPillar.control => AppRoutes.serverControls,
      });
    },
    available: [
      NavPillar.chat,
      NavPillar.config,
      NavPillar.status,
      if (GetIt.instance.isRegistered<IServerControlService>())
        NavPillar.control,
    ],
    configureBadge: configureBadge,
    extraActions: extraActions,
  );
}

class PocketCoderShell extends StatelessWidget {
  // footer: present on most routes. null on branch points (multiple choices,
  // not a linear step).
  final ShellFooter? footer;
  final Widget body;
  final bool showBack;
  final String? backLabel;
  final String? backFallbackRoute;
  final EdgeInsets? padding;

  const PocketCoderShell({
    super.key,
    this.footer,
    required this.body,
    this.showBack = false,
    this.backLabel,
    this.backFallbackRoute,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final releaseScope = ReleaseStatusScope.maybeOf(context);
    final releaseState = releaseScope?.state ?? const ReleaseStatusState();
    // A screen reached via Back is a sub-screen of whichever pillar it
    // lives under, so the pillar row would just be redundant chrome next
    // to Back -- suppress it here rather than at each of the ~20 call
    // sites that rely on this.
    final currentFooter = footer;
    final effectiveFooter = showBack && currentFooter is PillarFooter
        ? PillarFooter(
            active: currentFooter.active,
            onSelect: currentFooter.onSelect,
            available: const [],
            extraActions: currentFooter.extraActions,
          )
        : footer;
    final footerActions = <TerminalAction>[
      if (showBack)
        TerminalAction(
          label: backLabel ?? 'back',
          onTap: () => backFallbackRoute == null
              ? AppNavigation.back(context)
              : AppNavigation.back(context, fallback: backFallbackRoute!),
        ),
      ...ShellFooterView.actionsFor(effectiveFooter,
          configureBadge: releaseState.shouldShowNotice),
    ];
    return TerminalScaffold(
      padding: padding,
      actions: footerActions,
      body: Column(children: [
        ReleaseStatusBanner(
            state: releaseState, onDismiss: releaseScope?.onDismiss ?? () {}),
        // Top-left, never centered: a screen's content shouldn't float in
        // the middle of a short viewport. Align only loosens the minimum
        // constraints it hands down, so a body that fills (Expanded,
        // ListView) is unaffected -- it still fills exactly as before.
        Expanded(child: Align(alignment: Alignment.topLeft, child: body)),
      ]),
    );
  }
}
