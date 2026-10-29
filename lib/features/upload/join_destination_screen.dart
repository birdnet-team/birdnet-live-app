// =============================================================================
// Join Destination Screen — add an upload destination from a link
// =============================================================================
//
// One field takes whatever the contributor received: a join link, a Nextcloud
// share link, or a plain WebDAV address. Advanced fields for user name and
// password sit behind an expander for people who run their own server. The
// probe (webdav_probe.dart) must pass before Save is offered, and its
// warnings are shown above the Save button so the user accepts them
// knowingly. Returns the saved [UploadDestination] through `Navigator.pop`.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:birdnet_live/l10n/app_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../shared/utils/app_icons.dart';
import '../../shared/widgets/content_width_constraint.dart';
import 'join_link.dart';
import 'secret_store.dart';
import 'upload_destination.dart';
import 'upload_messages.dart';
import 'upload_providers.dart';
import 'webdav_probe.dart';

class JoinDestinationScreen extends ConsumerStatefulWidget {
  const JoinDestinationScreen({super.key, this.initialInput});

  /// Prefills the link field, for example from an app link.
  final String? initialInput;

  @override
  ConsumerState<JoinDestinationScreen> createState() =>
      _JoinDestinationScreenState();
}

class _JoinDestinationScreenState extends ConsumerState<JoinDestinationScreen> {
  late final TextEditingController _input = TextEditingController(
    text: widget.initialInput ?? '',
  );
  final _username = TextEditingController();
  final _secret = TextEditingController();
  final _name = TextEditingController();

  bool _showSecret = false;
  bool _probing = false;
  bool _saving = false;
  bool _invalidInput = false;
  JoinRequest? _request;
  ProbeResult? _result;
  bool _wifiOnly = true;
  String? _saveError;

  @override
  void dispose() {
    _input.dispose();
    _username.dispose();
    _secret.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) return;
    setState(() {
      _input.text = text;
      _resetResult();
    });
  }

  void _resetResult() {
    _request = null;
    _result = null;
    _invalidInput = false;
    _saveError = null;
  }

  Future<void> _probe() async {
    final request = JoinLinkParser.parse(
      _input.text,
      username: _username.text,
      secret: _secret.text,
    );
    if (request == null) {
      setState(() {
        _resetResult();
        _invalidInput = true;
      });
      return;
    }
    setState(() {
      _resetResult();
      _probing = true;
    });
    final deviceId = ref.read(uploadDeviceIdProvider);
    final info = await PackageInfo.fromPlatform();
    final result = await ref
        .read(webDavProbeProvider)
        .run(
          request,
          deviceId: deviceId,
          registration: joinRegistrationRecord(
            deviceId: deviceId,
            appVersion: info.version,
          ),
        );
    if (!mounted) return;
    setState(() {
      _probing = false;
      _request = request;
      _result = result;
      _wifiOnly = request.wifiOnly ?? true;
      if (result.ok) {
        _name.text = request.name ?? Uri.parse(result.resolvedUrl).host;
      }
    });
  }

  Future<void> _save() async {
    final request = _request;
    final result = _result;
    if (request == null || result == null || !result.ok) return;
    final name = _name.text.trim();
    if (name.isEmpty) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final l10n = AppLocalizations.of(context)!;
    UploadDestination destination;
    try {
      destination = await ref
          .read(uploadDestinationsProvider.notifier)
          .add(
            request: request,
            result: result,
            name: name,
            wifiOnly: _wifiOnly,
          );
    } on SecretStoreException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = l10n.uploadJoinSecretFailed;
      });
      return;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _saveError = l10n.uploadJoinSaveFailed('$e');
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(destination);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final result = _result;
    final canProbe = !_probing && !_saving && _input.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.uploadJoinTitle)),
      body: ContentWidthConstraint(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.uploadJoinLinkHelp, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              keyboardType: TextInputType.url,
              autocorrect: false,
              enableSuggestions: false,
              maxLines: 3,
              minLines: 1,
              onChanged: (_) => setState(_resetResult),
              decoration: InputDecoration(
                labelText: l10n.uploadJoinLinkLabel,
                hintText: l10n.uploadJoinLinkHint,
                border: const OutlineInputBorder(),
                errorText: _invalidInput ? l10n.uploadJoinInvalidInput : null,
                suffixIcon: IconButton(
                  icon: const Icon(AppIcons.contentPaste),
                  tooltip: l10n.uploadJoinPaste,
                  onPressed: _probing ? null : _paste,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ExpansionTile(
              title: Text(l10n.uploadJoinAdvanced),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                TextField(
                  controller: _username,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(_resetResult),
                  decoration: InputDecoration(
                    labelText: l10n.uploadJoinUsername,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _secret,
                  obscureText: !_showSecret,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(_resetResult),
                  decoration: InputDecoration(
                    labelText: l10n.uploadJoinPassword,
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showSecret
                            ? AppIcons.visibilityOff
                            : AppIcons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _showSecret = !_showSecret),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: canProbe ? _probe : null,
              icon: _probing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.cloudUpload),
              label: Text(
                _probing ? l10n.uploadJoinTesting : l10n.uploadJoinContinue,
              ),
            ),
            if (result != null) ...[
              const SizedBox(height: 24),
              _ProbeResultCard(result: result),
            ],
            if (result != null && result.ok) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.uploadJoinNameLabel,
                  border: const OutlineInputBorder(),
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.uploadDestinationWifiOnly),
                value: _wifiOnly,
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _wifiOnly = v),
              ),
              if (_saveError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _saveError!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ),
              FilledButton(
                onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
                child: Text(l10n.uploadJoinSave),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Outcome of the probe: one sentence per failure, one per warning.
class _ProbeResultCard extends StatelessWidget {
  const _ProbeResultCard({required this.result});

  final ProbeResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    if (!result.ok) {
      return Card(
        color: theme.colorScheme.errorContainer,
        child: ListTile(
          leading: Icon(
            AppIcons.errorOutline,
            color: theme.colorScheme.onErrorContainer,
          ),
          title: Text(
            probeFailureMessage(l10n, result),
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          subtitle: Text(
            result.resolvedUrl,
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: ListTile(
            leading: Icon(
              AppIcons.checkCircle,
              color: theme.colorScheme.primary,
            ),
            title: Text(l10n.uploadJoinSuccess),
            subtitle: Text(Uri.parse(result.resolvedUrl).host),
          ),
        ),
        for (final warning in result.warnings)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: ListTile(
              leading: Icon(
                AppIcons.warningAmberRounded,
                color: theme.colorScheme.onTertiaryContainer,
              ),
              title: Text(
                probeWarningMessage(l10n, warning),
                style: TextStyle(color: theme.colorScheme.onTertiaryContainer),
              ),
            ),
          ),
        if (result.flatLayout)
          Card(
            child: ListTile(
              leading: const Icon(AppIcons.infoOutline),
              title: Text(l10n.uploadDestinationFlatLayout),
            ),
          ),
      ],
    );
  }
}
