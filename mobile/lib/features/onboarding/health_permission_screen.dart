/// Health Connect permission screen (Phase 1: optional, can be declined).
///
/// The parent flow's bottom bar owns navigation. This screen only handles the
/// platform permission request.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_strings.dart';
import '../../repositories/health_repository.dart';
import '../../services/health_connect_service.dart';
import '../../widgets/selection_card.dart';
import '../../app.dart';
import 'onboarding_controller.dart';

class HealthPermissionScreen extends StatefulWidget {
  const HealthPermissionScreen({super.key});

  @override
  State<HealthPermissionScreen> createState() => _HealthPermissionScreenState();
}

class _HealthPermissionScreenState extends State<HealthPermissionScreen> {
  bool _loading = true;
  bool _supported = false;
  bool _requesting = false;
  bool _granted = false;
  bool _linking = false;
  String? _error;
  String? _linkError;

  final _service = HealthConnectService.instance;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final avail = await _service.setup();
    setState(() {
      _supported = avail == HealthConnectAvailability.supported;
      _loading = false;
    });
  }

  Future<void> _request() async {
    setState(() {
      _requesting = true;
      _error = null;
    });
    try {
      final types = [
        HealthDataType.STEPS,
        HealthDataType.SLEEP_ASLEEP,
        HealthDataType.ACTIVITY_INTENSITY,
      ];
      final granted = await _service.requestPermissions(types);
      if (!mounted) return;
      setState(() {
        _granted = granted;
        if (!granted) {
          _error = AppStrings.permissionDenied;
        } else {
          context.read<OnboardingController>().setHealthSelection([
                const HealthDataTypeWrapper(type: HealthDataType.STEPS, title: 'Steps', description: 'Your daily step count', granted: true),
                const HealthDataTypeWrapper(type: HealthDataType.SLEEP_ASLEEP, title: 'Sleep', description: 'Sleep duration', granted: true),
                const HealthDataTypeWrapper(type: HealthDataType.ACTIVITY_INTENSITY, title: 'Activity', description: 'Active minutes', granted: true),
              ]);
        }
      });
      if (granted) await _link();
    } catch (_) {
      if (mounted) setState(() => _error = AppStrings.somethingWentWrong);
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  /// Record the connection on the backend so dashboard syncs are enabled.
  /// Best-effort: if it fails while offline, the user can retry below.
  Future<void> _link() async {
    setState(() {
      _linking = true;
      _linkError = null;
    });
    try {
      await HealthRepository(AppServices.instance.api).connect(
        steps: true,
        sleep: true,
        activity: true,
      );
    } catch (_) {
      if (mounted) setState(() => _linkError = AppStrings.noInternet);
    } finally {
      if (mounted) setState(() => _linking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.phone_android_rounded, size: 40, color: scheme.primary),
          ),
          const SizedBox(height: 22),
          const Text(
            AppStrings.healthPermissionTitle,
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text(
            AppStrings.healthPermissionBody,
            style: TextStyle(fontSize: 15, height: 1.45, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          if (_supported && !_granted) ...[
            const Text('Data we can read automatically:', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            const SelectionCard(label: 'Steps', icon: Icons.directions_walk_rounded, selected: true, onTap: null),
            const SizedBox(height: 8),
            const SelectionCard(label: 'Sleep', icon: Icons.nightlight_round, selected: true, onTap: null),
            const SizedBox(height: 8),
            const SelectionCard(label: 'Activity', icon: Icons.directions_run_rounded, selected: true, onTap: null),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: scheme.error, fontSize: 14)),
              ),
            ],
            _primaryAction(_requesting ? 'Requesting access\u2026' : 'Allow health data access', _requesting ? null : _request),
          ],
          if (_granted) ...[
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 48, color: scheme.primary),
                  const SizedBox(height: 10),
                  Text('Health data access granted', style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSecondaryContainer)),
                  const SizedBox(height: 6),
                  Text(
                    'Steps, sleep and activity will appear here automatically. You can revoke this at any time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: scheme.onSecondaryContainer, height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  if (_linking)
                    const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (_linkError != null)
                    Column(
                      children: [
                        Text(
                          _linkError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: scheme.error),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: _link,
                          child: const Text('Retry linking'),
                        ),
                      ],
                    )
                  else
                    Text(
                      'Linked to your dashboard',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.primary),
                    ),
                ],
              ),
            ),
          ],
          if (!_supported) ...[
            if (_service.availability == HealthConnectAvailability.notInstalled)
              Text(
                'Health Connect is not installed on this device. You can still track manually and add Health Connect later from the profile.',
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              )
            else
              Text(
                AppStrings.healthConnectUnavailable,
                style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
              ),
          ],
          if (!_granted) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.read<OnboardingController>().setHealthSelection([]),
                child: const Text(AppStrings.continueWithManual),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _primaryAction(String label, VoidCallback? onPressed) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.health_and_safety_rounded),
        label: Text(label),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}