import "package:alphchemy/blocs/experiments/node_data_bloc.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/synced_text_field.dart";

mixin NodeField {
  String get field;
}

class NodeTextField extends StatelessWidget with NodeField {
  final String label;
  @override
  final String field;

  const NodeTextField({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeData>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = bloc.state.formatField(field);

        return Row(children: [
          SizedBox(width: 200, child: NormalText(label)),
          Expanded(child: SyncedTextField(
            text: value,
            onChanged: (val) {
              bloc.add(UpdateNodeField(field: field, text: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeDropdown<T> extends StatelessWidget with NodeField  {
  final String label;
  @override
  final String field;
  final List<T> options;
  final String Function(T) optionLabel;

  const NodeDropdown({super.key, required this.label, required this.field, required this.options, required this.optionLabel});

  T? optionFromText(String text) {
    for (final option in options) {
      final optionText = optionLabel(option);
      if (optionText == text) {
        return option;
      }
    }
    return null;
  }

  T? _selectedValue(NodeDataBloc bloc) {
    return _selectedValueFromNode(bloc.state);
  }

  T? _selectedValueFromNode(NodeData nodeData) {
    final currentText = nodeData.formatField(field);
    return optionFromText(currentText);
  }

  List<DropdownMenuEntry<T>> _entries() {
    final entries = <DropdownMenuEntry<T>>[];

    for (final option in options) {
      final label = optionLabel(option);
      final entry = DropdownMenuEntry<T>(
        value: option,
        label: label,
        labelWidget: NormalText(label)
      );
      entries.add(entry);
    }

    return entries;
  }

  InputDecorationThemeData _inputDecorationTheme(BuildContext context) {

    return Theme.of(context).dropdownMenuTheme.inputDecorationTheme!.copyWith(
      contentPadding: const EdgeInsets.all(2),
      suffixIconConstraints: const BoxConstraints()
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeData>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = _selectedValue(bloc);
        final currentText = bloc.state.formatField(field);
        final menuKey = "node_dropdown_${field}_$currentText";

        return Row(children: [
          SizedBox(width: 200, child: NormalText(label)),
          Expanded(child: DropdownMenu<T>(
            key: ValueKey<String>(menuKey),
            initialSelection: value,
            inputDecorationTheme: _inputDecorationTheme(context),
            expandedInsets: EdgeInsets.zero,
            dropdownMenuEntries: _entries(),
            onSelected: (val) {
              if (val == null) return;
              bloc.add(UpdateNodeFieldTyped(field: field, value: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeDateTimeField extends StatelessWidget with NodeField {
  final String label;
  @override
  final String field;

  const NodeDateTimeField({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeData>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final raw = bloc.state.formatField(field);
        final timestamp = double.tryParse(raw) ?? 0.0;

        return DateTimeFieldInput(
          label: label,
          labelOnLeft: true,
          timestamp: timestamp,
          onChanged: (value) {
            bloc.add(UpdateNodeFieldTyped(field: field, value: value));
          }
        );
      }
    );
  }
}

class NodeBoolDropdown extends StatelessWidget with NodeField {
  final String label;
  @override
  final String field;

  const NodeBoolDropdown({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return NodeDropdown<bool>(
      label: label,
      field: field,
      options: const [true, false],
      optionLabel: (option) => option.toString()
    );
  }
}

class NodeFields extends StatelessWidget {
  final NodeData nodeData;

  const NodeFields({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: (() {
        final fields = nodeData.fields;
        final widgets = <Widget>[const SizedBox(height: 5)];

        for (var i = 0; i < fields.length; i++) {
          if (i > 0) {
            const spacing = SizedBox(height: 2);
            widgets.add(spacing);
          }
          widgets.add(fields[i]);
        }

        return widgets;
      })()
    );
  }
}
