import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neural_idle/app/locale_controller.dart';
import 'package:neural_idle/l10n/app_localizations.dart';
import 'package:neural_idle/theme/app_colors.dart';
import 'package:neural_idle/ui/dev/widget_preview.dart';
import 'package:neural_idle/ui/widgets/language_toggle.dart';

class SettingsSheet extends ConsumerWidget {
  const SettingsSheet({
    super.key,
    this.onResetProgress,
    this.exportSave,
    this.importSave,
    this.version,
  });

  final VoidCallback? onResetProgress;
  final String Function()? exportSave;
  final bool Function(String raw)? importSave;
  final String? version;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.settings,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                IconButton(
                  tooltip: l10n.close,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  l10n.language,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const LanguageToggle(),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.systemLanguage,
                style: Theme.of(context).textTheme.bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
              value: ref.watch(localeControllerProvider) == null,
              onChanged: (enabled) => ref
                  .read(localeControllerProvider.notifier)
                  .setLocale(enabled ? null : Localizations.localeOf(context)),
            ),
            if (exportSave != null) ...[
              const Divider(height: 32),
              _SettingsAction(
                icon: Icons.file_upload_outlined,
                label: l10n.exportSave,
                onTap: () => _export(context, exportSave!),
              ),
            ],
            if (importSave != null)
              _SettingsAction(
                icon: Icons.file_download_outlined,
                label: l10n.importSave,
                onTap: () => showDialog<void>(
                  context: context,
                  builder: (_) => _ImportSaveDialog(importSave: importSave!),
                ),
              ),
            if (onResetProgress != null)
              _SettingsAction(
                icon: Icons.delete_outline_rounded,
                label: l10n.resetProgress,
                color: AppColors.error,
                onTap: () => _reset(context, onResetProgress!),
              ),
            if (version != null) ...[
              const Divider(height: 32),
              Text(l10n.about, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              Text(l10n.versionLabel(version!)),
              const SizedBox(height: 8),
              Text(l10n.builtWithFlutter),
              const SizedBox(height: 12),
              SelectableText(
                _sourceUrl,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              _CopyAction(
                icon: Icons.code_rounded,
                label: l10n.sourceCode,
                text: _sourceUrl,
              ),
            ],
            if (kDebugMode) ...[
              const Divider(height: 32),
              _SettingsAction(
                icon: Icons.dashboard_customize_outlined,
                label: l10n.widgetPreview,
                onTap: () {
                  final navigator = Navigator.of(context);
                  navigator.pop();
                  navigator.push(
                    MaterialPageRoute<void>(
                      builder: (_) => const WidgetPreview(),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _sourceUrl = 'https://github.com/matiasstr/IDLE-game';

Future<void> showSettingsSheet(
  BuildContext context, {
  VoidCallback? onResetProgress,
  String Function()? exportSave,
  bool Function(String raw)? importSave,
  String? version,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => SettingsSheet(
    onResetProgress: onResetProgress,
    exportSave: exportSave,
    importSave: importSave,
    version: version,
  ),
);

class _SettingsAction extends StatelessWidget {
  const _SettingsAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    minVerticalPadding: 12,
    leading: Icon(icon, color: color ?? AppColors.textSecondary),
    title: Text(label, style: TextStyle(color: color)),
    onTap: onTap,
  );
}

Future<void> _reset(BuildContext context, VoidCallback onReset) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      scrollable: true,
      title: Text(l10n.resetProgress),
      content: Text(l10n.resetProgressConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(l10n.resetProgress),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) onReset();
}

/// Copies [text] to the clipboard. False if the platform refused.
Future<bool> _copyToClipboard(String text) async {
  try {
    await Clipboard.setData(ClipboardData(text: text));
    return true;
  } on Object {
    return false;
  }
}

/// How a copy went, shown where it was asked for: a SnackBar would appear
/// under this modal sheet, out of sight.
enum _CopyState { idle, copied, failed }

/// A settings row that copies [text] and reports the result in place.
class _CopyAction extends StatefulWidget {
  const _CopyAction({
    required this.icon,
    required this.label,
    required this.text,
  });
  final IconData icon;
  final String label;
  final String text;

  @override
  State<_CopyAction> createState() => _CopyActionState();
}

class _CopyActionState extends State<_CopyAction> {
  var _state = _CopyState.idle;

  Future<void> _copy() async {
    final copied = await _copyToClipboard(widget.text);
    if (mounted) {
      setState(() => _state = copied ? _CopyState.copied : _CopyState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 12,
      leading: Icon(widget.icon, color: AppColors.textSecondary),
      title: Text(widget.label),
      subtitle: switch (_state) {
        _CopyState.idle => null,
        _CopyState.copied => Text(
          l10n.copied,
          style: const TextStyle(color: AppColors.neonLime),
        ),
        _CopyState.failed => Text(
          l10n.copyFailed,
          style: const TextStyle(color: AppColors.error),
        ),
      },
      onTap: _copy,
    );
  }
}

void _export(BuildContext context, String Function() exportSave) {
  final l10n = AppLocalizations.of(context);
  String? raw;
  try {
    raw = exportSave();
  } on Object {
    raw = null;
  }
  final save = raw;
  showDialog<void>(
    context: context,
    builder: (_) => save == null
        ? AlertDialog(
            title: Text(l10n.exportSave),
            content: Text(l10n.exportFailed),
            actions: [
              Builder(
                builder: (dialogContext) => TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(l10n.close),
                ),
              ),
            ],
          )
        : _ExportDialog(save: save),
  );
}

/// The exported save, selectable, with a copy button that says how it went.
class _ExportDialog extends StatefulWidget {
  const _ExportDialog({required this.save});
  final String save;

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  var _state = _CopyState.idle;

  Future<void> _copy() async {
    final copied = await _copyToClipboard(widget.save);
    if (mounted) {
      setState(() => _state = copied ? _CopyState.copied : _CopyState.failed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.exportSave),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(widget.save),
          if (_state == _CopyState.failed) ...[
            const SizedBox(height: 12),
            Text(
              l10n.copyFailed,
              style: const TextStyle(color: AppColors.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.close),
        ),
        FilledButton.icon(
          onPressed: _copy,
          icon: Icon(
            _state == _CopyState.copied
                ? Icons.check_rounded
                : Icons.copy_rounded,
          ),
          label: Text(_state == _CopyState.copied ? l10n.copied : l10n.copy),
        ),
      ],
    );
  }
}

class _ImportSaveDialog extends StatefulWidget {
  const _ImportSaveDialog({required this.importSave});
  final bool Function(String raw) importSave;

  @override
  State<_ImportSaveDialog> createState() => _ImportSaveDialogState();
}

class _ImportSaveDialogState extends State<_ImportSaveDialog> {
  final _controller = TextEditingController();
  bool _invalid = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    var accepted = false;
    try {
      accepted = widget.importSave(_controller.text);
    } catch (_) {
      accepted = false;
    }
    if (!mounted) return;
    if (accepted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _invalid = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(l10n.importSave),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.importSaveBody),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 6,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.saveData,
                hintText: l10n.importSaveHint,
                errorText: _invalid ? l10n.importInvalid : null,
                errorMaxLines: 4,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_invalid) setState(() => _invalid = false);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.importSave)),
      ],
    );
  }
}
