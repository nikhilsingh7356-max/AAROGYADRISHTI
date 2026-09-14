/// Root gate: decides where an authenticated user lands next.
///
/// - unauthenticated  -> WelcomeScreen
/// - authenticated but onboarding incomplete -> OnboardingFlow
/// - authenticated & onboarded -> AppScaffold
///
/// Onboarding state is fetched from the server profile (authoritative) and
/// mirrored to a per-user local cache used only as an offline fallback. The
/// gate listens to auth transitions so it re-resolves after a login lands
/// back on this route (and clears its view state on logout).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_constants.dart';
import '../core/constants/app_strings.dart';
import '../core/network/api_exception.dart';
import '../core/storage/storage_service.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_scaffold.dart';
import '../app.dart';
import 'auth/welcome_screen.dart';
import 'onboarding/onboarding_flow.dart';

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _checking = false;
  bool _onboarded = false;
  String? _error;
  AuthProvider? _watchedAuth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _attachListener());
  }

  void _attachListener() {
    if (!mounted) return;
    final auth = context.read<AuthProvider>();
    if (identical(_watchedAuth, auth)) return;
    _watchedAuth?.removeListener(_onAuthChanged);
    _watchedAuth = auth;
    auth.addListener(_onAuthChanged);
    if (auth.isAuthenticated) {
      _resolve();
    }
  }

  void _onAuthChanged() {
    final auth = _watchedAuth;
    if (auth == null) return;
    if (auth.isAuthenticated) {
      _resolve();
    } else {
      // Reset the view state on sign-out so it never leaks into the next
      // session on this device.
      setState(() {
        _onboarded = false;
        _error = null;
      });
    }
  }

  @override
  void dispose() {
    _watchedAuth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> _resolve() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isAuthenticated) return;

    setState(() {
      _checking = true;
      _error = null;
    });

    try {
      final profile = await AppServices.instance.profileRepository.get();
      if (!mounted) return;
      setState(() => _onboarded = profile.isOnboarded);
      await StorageService.instance.setBool(_cacheKey(auth.user?.id), profile.isOnboarded);
    } catch (e) {
      if (!mounted) return;
      if (e is NetworkException || e is ServerException) {
        // Offline / API unavailable: fall back to this user's cache only.
        final cached = await StorageService.instance.getBool(_cacheKey(auth.user?.id));
        if (mounted) setState(() => _onboarded = cached ?? false);
      } else if (e is UnauthorizedException) {
        // The session can no longer be authenticated - route to sign-in.
        await auth.logout();
      } else {
        setState(() => _error = AppStrings.somethingWentWrong);
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  String _cacheKey(int? userId) => userId == null
      ? AppConstants.keyOnboardingCompleted
      : '${AppConstants.keyOnboardingCompleted}_$userId';

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.status == AuthStatus.unknown) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!auth.isAuthenticated) {
      return const WelcomeScreen();
    }
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off, size: 40),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _resolve, child: const Text('Try again')),
              ],
            ),
          ),
        ),
      );
    }

    return _onboarded ? const AppScaffold() : OnboardingFlow(onComplete: () {
      setState(() => _onboarded = true);
    });
  }
}