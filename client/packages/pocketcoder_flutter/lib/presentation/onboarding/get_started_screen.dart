import 'package:flutter/material.dart';
import 'self_host_login_screen.dart';
import 'onboarding_prefill.dart';
import 'adapters/onboarding_adapter.dart';

class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  Widget build(BuildContext context) => prefill == null
      ? const OnboardingAdapter()
      : SelfHostLoginScreen(prefill: prefill);
}
