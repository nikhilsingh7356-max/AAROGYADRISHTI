/// Health Connect management screen.
///
/// Shows the real device availability state AND the backend connection state
/// side by side - permission on the phone is never presented as "connected"
/// until the backend confirms the link.
library;

import 'package:flutter/material.dart';
import 'package:health/health.dart';

import '../../app.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../models/health_data.dart';
import '../../repositories/consent_repository.dart';
import '../../repositories/health_repository.dart';
import '../../services/health_connect_service.dart';
import '../../widgets/app_card.dart';
import '../../widgets/badges.dart';

enum _DeviceState { checking, unsupported, notInstalled, denied, granted }

enum _BackendState { loading, disconnected, connected, error }

class HealthConnectScreen extends StatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  State<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<HealthConnectScreen> {
  final _service = HealthConnectService.instance;
  final _healthRepo = HealthRepository(AppServices.instance.api);
  final _consentRepo = ConsentRepository(AppServices.instance.api);

  _DeviceState _device = _DeviceState.checking;
  _BackendState _backend = _BackendState.loading;
  HealthConnectionState? _connection;
  String? _error;
  bool _busy = false;
  bool _syncing = false;
  String? _syncMessage;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _device = _DeviceState.checking;
      _backend = _BackendState.loading;
      _error = null;
      _syncMessage = null;
    });

    final avail = await _service.setup();
    if (!mounted) return;

    _DeviceState device;
    switch (avail) {
      case HealthConnectAvailability.supported:
        final granted = await _service
            .checkPermissions(HealthConnectService.categoryTitles.keys.toList());
        device = granted ? _DeviceState.granted : _DeviceState.denied;
        break;
      case HealthConnectAvailability.notInstalled:
        device = _DeviceState.notInstalled;
        break;
      case HealthConnectAvailability.unsupported:
      case HealthConnectAvailability.notGranted:
        device = _DeviceState.unsupported;
        break;
      case HealthConnectAvailability.error:
        device = _DeviceState.unsupported;
        break;
    }
    setState(() => _device = device);

    try {
      final status = await _healthRepo.getStatus();
      if (!mounted) return;
      setState(() {
        _connection = status;
        _backend =
            status.isConnected ? _BackendState.connected : _BackendState.disconnected;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _backend = _BackendState.error;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _backend = _BackendState.error;
          _error = 'Could not reach the server. Check your connection.';
        });
      }
    }
  }

  /// Device permission first, then backend link + consent records.
  Future<void> _connect() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final granted =
          await _service.requestPermissions(HealthConnectService.categoryTitles.keys.toList());
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _device = _DeviceState.denied;
          _error = 'Permission denied. Enable access from Android Settings if you change your mind.';
        });
        return;
      }
      setState(() => _device = _DeviceState.granted);

      await _healthRepo.connect(steps: true, sleep: true, activity: true);
      // Consent trail for each category (audit records, not UI state).
      for (final t in const ['steps', 'sleep', 'activity']) {
        await _consentRepo.record(t, true);
      }
      if (!mounted) return;
      await _sync(initial: true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sync({bool initial = false}) async {
    setState(() {
      _syncing = true;
      _syncMessage = null;
    });
    try {
      final day = DateTime.now();
      final data = await _service.readDay(day);
      await _healthRepo.sync(
        steps: data.steps,
        activeMinutes: data.activeMinutes,
        sleepMinutes: data.sleepMinutes,
        date: '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}',
      );
      if (!mounted) return;
      // Re-read the connection so last_synced_at is real, not assumed.
      final status = await _healthRepo.getStatus();
      if (!mounted) return;
      setState(() {
        _connection = status;
        _backend = _BackendState.connected;
        _syncMessage = initial ? 'Connected and first sync complete' : 'Sync complete';
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _syncMessage = e.message);
    } catch (_) {
      if (mounted) setState(() => _syncMessage = 'Sync failed. Please try again.');
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Health Connect?'),
        content: const Text(
          'The app will stop reading steps, sleep and activity from this device. '
          'Data already saved in your account stays where it is.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await _consentRepo.record('steps', false);
      await _consentRepo.record('sleep', false);
      await _consentRepo.record('activity', false);
      if (!mounted) return;
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Health Connect')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            _stateCard(scheme),
            const SizedBox(height: 16),
            _categoriesCard(scheme),
            const SizedBox(height: 16),
            if (_backend == _BackendState.connected) ...[
              _syncCard(scheme),
              const SizedBox(height: 16),
            ],
            if (_error != null) ...[
              AppCard(
                color: scheme.errorContainer,
                borderColor: Colors.transparent,
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Health data is read from your device only to fill in steps, sleep '
                      'and activity when you skip them in a check-in. It is stored in '
                      'your own account and never used to diagnose anything.',
                      style: TextStyle(
                          fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateCard(ColorScheme scheme) {
    final (icon, title, subtitle, badge) = switch ((_device, _backend)) {
      (_DeviceState.checking, _) => (
          Icons.hourglass_top_rounded,
          'Checking Health Connect\u2026',
          'Reading your device status',
          const StatusBadge(label: 'Checking', icon: Icons.hourglass_top_rounded),
        ),
      (_DeviceState.unsupported, _) => (
          Icons.mobile_off_rounded,
          'Not available on this device',
          'Health Connect needs Android with the Health Connect app installed. Manual check-ins work everywhere.',
          const StatusBadge(label: 'Unsupported', icon: Icons.block_rounded),
        ),
      (_DeviceState.notInstalled, _) => (
          Icons.download_rounded,
          'Health Connect not installed',
          'Install Health Connect from the Play Store, then come back and connect.',
          const StatusBadge(label: 'Not installed', icon: Icons.download_rounded),
        ),
      (_DeviceState.denied, _) => (
          Icons.lock_outline_rounded,
          'Permission not granted',
          'Allow Health Connect access to fill your check-ins automatically.',
          StatusBadge(
              label: 'Permission denied',
              color: scheme.tertiary,
              icon: Icons.lock_outline_rounded),
        ),
      (_DeviceState.granted, _BackendState.connected) => (
          Icons.verified_rounded,
          'Connected',
          'Device permission granted and linked to your account.',
          StatusBadge(
              label: 'Connected',
              color: scheme.primary,
              icon: Icons.verified_rounded),
        ),
      (_DeviceState.granted, _BackendState.loading) => (
          Icons.link_rounded,
          'Finishing up\u2026',
          'Confirming the connection with your account',
          const StatusBadge(label: 'Checking', icon: Icons.hourglass_top_rounded),
        ),
      (_DeviceState.granted, _) => (
          Icons.link_off_rounded,
          'Not linked yet',
          'Permission is granted on this device, but your account is not linked yet.',
          StatusBadge(
              label: 'Not linked',
              color: scheme.tertiary,
              icon: Icons.link_off_rounded),
        ),
    };

    final canConnect = _device == _DeviceState.granted || _device == _DeviceState.denied;
    final connected = _backend == _BackendState.connected;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 26, color: scheme.primary),
              ),
              const Spacer(),
              badge,
            ],
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(fontSize: 13.5, height: 1.45, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : connected
                          ? _sync
                          : (canConnect ? _connect : null),
                  icon: _busy || _syncing
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(connected ? Icons.sync_rounded : Icons.link_rounded, size: 18),
                  label: Text(connected ? 'Sync now' : 'Connect'),
                ),
              ),
              if (connected) ...[
                const SizedBox(width: 10),
                IconButton.outlined(
                  tooltip: 'Disconnect',
                  onPressed: _busy ? null : _disconnect,
                  icon: const Icon(Icons.link_off_rounded, size: 20),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _categoriesCard(ColorScheme scheme) {
    Widget row(String label, bool enabled) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Icon(
                enabled ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: enabled ? scheme.primary : scheme.outline,
              ),
              const SizedBox(width: 10),
              Text(label, style: const TextStyle(fontSize: 14)),
              const Spacer(),
              Text(
                enabled ? 'On' : 'Off',
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: enabled ? scheme.primary : scheme.onSurfaceVariant),
              ),
            ],
          ),
        );

    final c = _connection;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data categories', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_backend == _BackendState.loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            )
          else ...[
            row('Steps', c?.stepsEnabled ?? false),
            row('Sleep', c?.sleepEnabled ?? false),
            row('Activity', c?.activityEnabled ?? false),
            if (c?.lastSyncedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Last synced ${AppDateUtils.shortDay(c!.lastSyncedAt!.toLocal())}'
                  ' \u00b7 ${AppDateUtils.timeLabel(c.lastSyncedAt!.toLocal())}',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _syncCard(ColorScheme scheme) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_sync_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 10),
              const Expanded(child: Text('Sync', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Today\'s steps, sleep minutes and active minutes are copied into your daily log '
            'for fields you didn\'t enter yourself.',
            style: TextStyle(fontSize: 13, height: 1.5, color: scheme.onSurfaceVariant),
          ),
          if (_syncMessage != null) ...[
            const SizedBox(height: 10),
            Text(
              _syncMessage!,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _syncing ? scheme.onSurfaceVariant : scheme.primary),
            ),
          ],
        ],
      ),
    );
  }
}
