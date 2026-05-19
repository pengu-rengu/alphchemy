import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";

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
        final timestamp = _timestamp(bloc);

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

  double _timestamp(NodeDataBloc bloc) {
    final iso = bloc.state.formatField(field);
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return 0.0;

    final utc = parsed.toUtc();
    final millis = utc.millisecondsSinceEpoch;
    return millis / 1000.0;
  }
}

class DateTimeFieldInput extends StatefulWidget {
  final String label;
  final bool labelOnLeft;
  final double timestamp;
  final ValueChanged<double> onChanged;

  const DateTimeFieldInput({super.key, required this.label, required this.labelOnLeft, required this.timestamp, required this.onChanged});

  @override
  State<DateTimeFieldInput> createState() => _DateTimeFieldInputState();
}

class _DateTimeFieldInputState extends State<DateTimeFieldInput> {
  String _month = "";
  String _day = "";
  String _year = "";
  String _hour = "";
  String _minute = "";
  bool _isPm = false;
  double? _lastEmittedSeconds;

  void _syncFromTimestamp() {
    if (widget.timestamp <= 0.0) {
      if (_lastEmittedSeconds == 0.0) return;
      _lastEmittedSeconds = 0.0;
      _month = "";
      _day = "";
      _year = "";
      _hour = "";
      _minute = "";
      _isPm = false;
      return;
    }

    final millisDouble = widget.timestamp * 1000.0;
    final millis = millisDouble.round();
    final utc = DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
    final seconds = widget.timestamp;
    if (_lastEmittedSeconds == seconds) return;

    _lastEmittedSeconds = seconds;
    _month = utc.month.toString();
    _day = utc.day.toString();
    _year = utc.year.toString();
    final hour24 = utc.hour;
    _isPm = hour24 >= 12;
    final hour12Raw = hour24 % 12;
    final hour12 = hour12Raw == 0 ? 12 : hour12Raw;
    _hour = hour12.toString();
    _minute = utc.minute.toString().padLeft(2, "0");
  }

  DateTime? _composeUtc() {
    final month = int.tryParse(_month);
    final day = int.tryParse(_day);
    final year = int.tryParse(_year);
    final hour12 = int.tryParse(_hour);
    final minute = int.tryParse(_minute);
    if (month == null || day == null || year == null) return null;
    if (hour12 == null || minute == null) return null;

    final hourMod = hour12 % 12;
    final hourPmOffset = _isPm ? 12 : 0;
    final hour24 = hourMod + hourPmOffset;
    return DateTime.utc(year, month, day, hour24, minute);
  }

  void _emit() {
    final composed = _composeUtc();
    if (composed == null) return;
    final seconds = composed.millisecondsSinceEpoch / 1000.0;
    _lastEmittedSeconds = seconds;
    widget.onChanged(seconds);
  }

  void _onChanged(String which, String text) {
    setState(() {
      switch (which) {
        case "month":
          _month = text;
        case "day":
          _day = text;
        case "year":
          _year = text;
        case "hour":
          _hour = text;
        case "minute":
          _minute = text;
      }
    });
    _emit();
  }

  void _setAmPm(bool isPm) {
    setState(() {
      _isPm = isPm;
    });
    _emit();
  }

  @override
  Widget build(BuildContext context) {
    _syncFromTimestamp();

    final inputs = Row(children: [
      _ComponentBox(label: "MM", width: 50, text: _month, onChanged: (val) => _onChanged("month", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "DD", width: 50, text: _day, onChanged: (val) => _onChanged("day", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "YYYY", width: 100, text: _year, onChanged: (val) => _onChanged("year", val)),
      const SizedBox(width: 10),
      _ComponentBox(label: "hh", width: 50, text: _hour, onChanged: (val) => _onChanged("hour", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "mm", width: 50, text: _minute, onChanged: (val) => _onChanged("minute", val)),
      const SizedBox(width: 10),
      ChoiceChip(
        label: !_isPm ? const InvertedText("AM") : const NormalText("AM"),
        selected: !_isPm,
        onSelected: (_) => _setAmPm(false)
      ),
      const SizedBox(width: 4),
      ChoiceChip(
        label: _isPm ? const InvertedText("PM") : const NormalText("PM"),
        selected: _isPm,
        onSelected: (_) => _setAmPm(true)
      )
    ]);

    if (widget.labelOnLeft) {
      return Row(children: [
        SizedBox(width: 200, child: NormalText(widget.label)),
        Expanded(child: inputs)
      ]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NormalText(widget.label),
        const SizedBox(height: 4),
        inputs
      ]
    );
  }
}

class _ComponentBox extends StatelessWidget {
  final String label;
  final double width;
  final String text;
  final ValueChanged<String> onChanged;

  const _ComponentBox({required this.label, required this.width, required this.text, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: SyncedTextField(
        text: text,
        onChanged: onChanged,
        decoration: InputDecoration(hintText: label)
      )
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
