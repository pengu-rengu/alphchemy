import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/experiment/node_data.dart";
import "package:alphchemy/widgets/widget_utils.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:alphchemy/widgets/editor/synced_text_field.dart";

class NodeTextField extends StatelessWidget {
  final String label;
  final String field;

  const NodeTextField({super.key, required this.label, required this.field});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = bloc.nodeData.formatField(field);

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

class NodeDropdown<T> extends StatelessWidget {
  final String label;
  final String field;
  final List<T> options;
  final String Function(T) optionLabel;

  const NodeDropdown({super.key, required this.label, required this.field, required this.options, required this.optionLabel});

  T? _selectedValue(NodeDataBloc bloc) {
    final currentText = bloc.nodeData.formatField(field);
    for (final option in options) {
      final optionText = optionLabel(option);
      if (optionText != currentText) continue;
      return option;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        final value = _selectedValue(bloc);

        return Row(children: [
          SizedBox(width: 200, child: NormalText(label)),
          Expanded(child: DropdownButton<T>( // change to DropdownMenu
            key: ValueKey<String>("node_dropdown_$field"),
            value: value,
            isExpanded: true,
            isDense: true,
            underline: const SizedBox(),
            items: options.map((option) {
              final label = optionLabel(option);
              return DropdownMenuItem<T>(
                value: option,
                child: NormalText(label)
              );
            }).toList(),
            onChanged: (val) {
              if (val == null) return;
              bloc.add(UpdateNodeFieldTyped(field: field, value: val));
            }
          ))
        ]);
      }
    );
  }
}

class NodeDateTimeField extends StatefulWidget {
  final String label;
  final String field;

  const NodeDateTimeField({super.key, required this.label, required this.field});

  @override
  State<NodeDateTimeField> createState() => _NodeDateTimeFieldState();
}

class _NodeDateTimeFieldState extends State<NodeDateTimeField> {
  String _month = "";
  String _day = "";
  String _year = "";
  String _hour = "";
  String _minute = "";
  bool _isPm = false;
  double? _lastEmittedSeconds;

  void _syncFromNode(NodeDataBloc bloc) {
    final iso = bloc.nodeData.formatField(widget.field);
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) {
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

    final utc = parsed.toUtc();
    final seconds = utc.millisecondsSinceEpoch / 1000.0;
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

  void _emit(NodeDataBloc bloc) {
    final composed = _composeUtc();
    if (composed == null) return;
    final seconds = composed.millisecondsSinceEpoch / 1000.0;
    _lastEmittedSeconds = seconds;
    bloc.add(UpdateNodeFieldTyped(field: widget.field, value: seconds));
  }

  void _onChanged(String which, String text, NodeDataBloc bloc) {
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
    _emit(bloc);
  }

  void _setAmPm(bool isPm, NodeDataBloc bloc) {
    setState(() {
      _isPm = isPm;
    });
    _emit(bloc);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NodeDataBloc, NodeDataState>(
      builder: (context, _) {
        final bloc = context.read<NodeDataBloc>();
        _syncFromNode(bloc);

        return Row(children: [
          SizedBox(width: 200, child: NormalText(widget.label)),
          Expanded(child: Row(children: [
            _ComponentBox(label: "MM", width: 50, text: _month, onChanged: (val) => _onChanged("month", val, bloc)),
            const SizedBox(width: 5),
            _ComponentBox(label: "DD", width: 50, text: _day, onChanged: (val) => _onChanged("day", val, bloc)),
            const SizedBox(width: 5),
            _ComponentBox(label: "YYYY", width: 100, text: _year, onChanged: (val) => _onChanged("year", val, bloc)),
            const SizedBox(width: 10),
            _ComponentBox(label: "hh", width: 50, text: _hour, onChanged: (val) => _onChanged("hour", val, bloc)),
            const SizedBox(width: 5),
            _ComponentBox(label: "mm", width: 50, text: _minute, onChanged: (val) => _onChanged("minute", val, bloc)),
            const SizedBox(width: 10),
            ChoiceChip(
              label: !_isPm ? const InvertedText("AM") : const NormalText("AM"),
              selected: !_isPm,
              onSelected: (_) => _setAmPm(false, bloc)
            ),
            const SizedBox(width: 4),
            ChoiceChip(
              label: _isPm ? const InvertedText("PM") : const NormalText("PM"),
              selected: _isPm,
              onSelected: (_) => _setAmPm(true, bloc)
            )
          ]))
        ]);
      }
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

class NodeBoolDropdown extends StatelessWidget {
  final String label;
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
  static const _fieldGap = SizedBox(height: 2);
  final NodeData nodeData;

  const NodeFields({super.key, required this.nodeData});

  @override
  Widget build(BuildContext context) {
    final fields = nodeData.fields;
    if (fields.isEmpty) return const SizedBox();

    final children = <Widget>[const SizedBox(height: 5)];

    for (var i = 0; i < fields.length; i++) {
      if (i > 0) children.add(_fieldGap);
      children.add(fields[i]);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children
    );
  }
}
