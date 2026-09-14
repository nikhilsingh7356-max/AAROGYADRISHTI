/// Editable consent toggles for the five data categories tracked by the
/// backend. Each toggle POSTs to `POST /consent` so consent state is
/// persisted server-side.
library;

import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/constants/app_strings.dart';
import '../../core/network/api_exception.dart';
import '../../repositories/consent_repository.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _repo = ConsentRepository(AppServices.instance.api);
  Map<String, bool>? _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final status = await _repo.status();
      if (mounted) setState(() => _status = status);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your consent settings.');
    }
  }

  Future<void> _update(String dataType, bool value) async {
    setState(() => _saving = true);
    try {
      await _repo.record(dataType, value);
      final updated = await _repo.status();
      if (mounted) setState(() => _status = updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update consent: ${e.message}')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final status = _status;

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.privacySettings)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Text(
                AppStrings.privacySubtitle,
                style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: scheme.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (status != null) ...[
                _ConsentTile(
                  label: 'Steps',
                  value: status['steps'] ?? false,
                  onChanged: _saving ? null : (v) => _update('steps', v),
                ),
                _ConsentTile(
                  label: 'Sleep',
                  value: status['sleep'] ?? false,
                  onChanged: _saving ? null : (v) => _update('sleep', v),
                ),
                _ConsentTile(
                  label: 'Activity',
                  value: status['activity'] ?? false,
                  onChanged: _saving ? null : (v) => _update('activity', v),
                ),
                _ConsentTile(
                  label: 'Screen time',
                  value: status['screen_time'] ?? false,
                  onChanged: _saving ? null : (v) => _update('screen_time', v),
                ),
                _ConsentTile(
                  label: 'Demographic data',
                  value: status['demographic_optional'] ?? false,
                  onChanged: _saving
                      ? null
                      : (v) => _update('demographic_optional', v),
                  trailing: Tooltip(
                    message: 'Age range, occupation, etc.',
                    child: Icon(Icons.info_outline_rounded,
                        size: 18, color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  AppStrings.consentBody,
                  style: TextStyle(
                      fontSize: 12.5,
                      color: scheme.onSurfaceVariant,
                      height: 1.4),
                ),
              ),
            ],
          ),
          if (_saving)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.03),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.trailing,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      title: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            trailing!,
          ],
        ],
      ),
    );
  }
}