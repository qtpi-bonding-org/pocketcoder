import 'package:flutter/material.dart';
import 'onboarding_login_screen.dart';
import 'onboarding_prefill.dart';
import 'adapters/onboarding_adapter.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key, this.prefill});

  final OnboardingPrefill? prefill;

  @override
  Widget build(BuildContext context) => prefill == null
      ? const OnboardingAdapter()
      : OnboardingLoginScreen(prefill: prefill);
}
