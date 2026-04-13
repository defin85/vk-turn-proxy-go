import 'package:flutter/material.dart';
import 'package:flutter_shell_core/control_plane_models.dart';

class ProviderSettingsForm extends StatefulWidget {
  const ProviderSettingsForm({
    super.key,
    required this.descriptor,
    required this.values,
    required this.enabled,
    required this.onChanged,
  });

  final ProviderDescriptor descriptor;
  final Map<String, dynamic> values;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  State<ProviderSettingsForm> createState() => _ProviderSettingsFormState();
}

class _ProviderSettingsFormState extends State<ProviderSettingsForm> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};

  @override
  void didUpdateWidget(covariant ProviderSettingsForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.descriptor != widget.descriptor ||
        oldWidget.values != widget.values) {
      _syncControllers();
    }
  }

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.descriptor.providerSettingsFields
          .map((ProviderSettingsField field) => _field(field))
          .toList(growable: false),
    );
  }

  Widget _field(ProviderSettingsField field) {
    final property = field.property;
    final label = property.title.isEmpty ? field.key : property.title;

    switch (property.control) {
      case ProviderSettingControl.select:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<dynamic>(
            key: ValueKey<String>(
              'provider-setting-select-${field.key}-${widget.values[field.key]}',
            ),
            initialValue: widget.values[field.key],
            decoration: InputDecoration(
              labelText: label,
              helperText: property.description.isEmpty
                  ? null
                  : property.description,
            ),
            items: property.enumValues
                .map(
                  (dynamic value) => DropdownMenuItem<dynamic>(
                    value: value,
                    child: Text('$value'),
                  ),
                )
                .toList(growable: false),
            onChanged: widget.enabled
                ? (dynamic value) => _updateSetting(field.key, value)
                : null,
          ),
        );
      case ProviderSettingControl.checkbox:
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: widget.values[field.key] as bool? ?? false,
          onChanged: widget.enabled
              ? (bool value) => _updateSetting(field.key, value)
              : null,
          title: Text(label),
          subtitle: property.description.isEmpty
              ? null
              : Text(property.description),
        );
      case ProviderSettingControl.text:
      case ProviderSettingControl.textarea:
      case ProviderSettingControl.password:
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: _controller(field.key),
            enabled: widget.enabled,
            maxLines: property.control == ProviderSettingControl.textarea
                ? 3
                : 1,
            obscureText: property.control == ProviderSettingControl.password,
            keyboardType: switch (property.type) {
              ProviderSettingType.integer => TextInputType.number,
              ProviderSettingType.number =>
                const TextInputType.numberWithOptions(decimal: true),
              _ => TextInputType.text,
            },
            decoration: InputDecoration(
              labelText: label,
              helperText: property.description.isEmpty
                  ? null
                  : property.description,
            ),
            onChanged: (String value) {
              final trimmed = value.trim();
              if (trimmed.isEmpty) {
                _removeSetting(field.key);
                return;
              }
              final nextValue = switch (property.type) {
                ProviderSettingType.integer => int.tryParse(trimmed) ?? trimmed,
                ProviderSettingType.number =>
                  double.tryParse(trimmed) ?? trimmed,
                ProviderSettingType.boolean => trimmed.toLowerCase() == 'true',
                _ => value,
              };
              _updateSetting(field.key, nextValue);
            },
          ),
        );
      case null:
        return const SizedBox.shrink();
    }
  }

  void _updateSetting(String key, dynamic value) {
    final next = Map<String, dynamic>.from(widget.values);
    if (value == null) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    widget.onChanged(next);
  }

  void _removeSetting(String key) {
    final next = Map<String, dynamic>.from(widget.values);
    if (next.remove(key) != null) {
      widget.onChanged(next);
    }
  }

  TextEditingController _controller(String key) {
    return _controllers.putIfAbsent(key, TextEditingController.new);
  }

  void _syncControllers() {
    final activeKeys = widget.descriptor.providerSettingsFields
        .where((ProviderSettingsField field) {
          return field.property.control == ProviderSettingControl.text ||
              field.property.control == ProviderSettingControl.textarea ||
              field.property.control == ProviderSettingControl.password;
        })
        .map((ProviderSettingsField field) => field.key)
        .toSet();

    final removable = _controllers.keys
        .where((String key) => !activeKeys.contains(key))
        .toList(growable: false);
    for (final key in removable) {
      _controllers.remove(key)?.dispose();
    }

    for (final key in activeKeys) {
      final controller = _controller(key);
      final value = widget.values[key];
      final text = value == null ? '' : '$value';
      if (controller.text == text) {
        continue;
      }
      controller.value = controller.value.copyWith(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
        composing: TextRange.empty,
      );
    }
  }
}
