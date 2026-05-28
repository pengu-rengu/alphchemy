import "package:alphchemy/main.dart";
import "package:alphchemy/widgets/synced_text_field.dart";
import "package:flutter/material.dart";

class PaddedCard extends StatelessWidget {
  final Widget child;

  const PaddedCard({
    super.key,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: child,
      )
    );
  }
}

class NormalText extends StatelessWidget {
  final String text;
  final int? maxLines;

  const NormalText(this.text, {super.key, this.maxLines});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.displayMedium, maxLines: maxLines);
  }
}

class BoldText extends StatelessWidget {
  final String text;

  const BoldText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}

class CenterText extends StatelessWidget {
  final String text;
  final bool expanded;

  const CenterText(this.text, {super.key, this.expanded = false});

  @override
  Widget build(BuildContext context) {
    final inner = Center(child: NormalText(text));
    return expanded ? Expanded(child: inner) : inner;
  }
}

class LargeText extends StatelessWidget {
  final String text;

  const LargeText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.displayLarge);
  }
}

class InvertedText extends StatelessWidget {
  final String text;

  const InvertedText(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.labelMedium);
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Expanded(child: Center(child: CircularProgressIndicator()));
  }
}

class NormalIcon extends StatelessWidget {
  final IconData icon;

  const NormalIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Theme.of(context).extension<AppColors>()!.fgColor1);
  }
}

class InvertedIcon extends StatelessWidget {
  final IconData icon;

  const InvertedIcon(this.icon, {super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: Theme.of(context).textTheme.labelMedium?.color);
  }
}

class CompactDropdown<T> extends StatelessWidget {
  final List<DropdownMenuEntry<T>> dropdownMenuEntries;
  final T? initialSelection;
  final ValueChanged<T?>? onSelected;
  final EdgeInsetsGeometry? expandedInsets;

  const CompactDropdown({super.key, required this.dropdownMenuEntries, this.initialSelection, this.onSelected, this.expandedInsets});

  @override
  Widget build(BuildContext context) {
    return DropdownMenu<T>(
      dropdownMenuEntries: dropdownMenuEntries,
      initialSelection: initialSelection,
      onSelected: onSelected,
      expandedInsets: expandedInsets,
      requestFocusOnTap: false,
      inputDecorationTheme: Theme.of(context).inputDecorationTheme.copyWith(
        //contentPadding: const EdgeInsets.symmetric(horizontal: 2.0),
        suffixIconConstraints: const BoxConstraints()
      )
    );
  }
}

class StyledTextField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextStyle? style;
  final InputDecoration? decoration;
  final bool autofocus;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const StyledTextField({super.key, this.controller, this.focusNode, this.style, this.decoration, this.autofocus = false, this.minLines, this.maxLines = 1, this.onChanged, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: style ?? Theme.of(context).textTheme.displayMedium,
      decoration: decoration ?? const InputDecoration(),
      autofocus: autofocus,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted
    );
  }
}

class TitleTextField extends StatelessWidget {
  final TextEditingController? controller;

  const TitleTextField({super.key, this.controller});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 500.0,
      child: StyledTextField(
        controller: controller,
        style: Theme.of(context).textTheme.displayLarge,
        decoration: const InputDecoration(
          isDense: false,
          isCollapsed: false
        )
      )
    );
  }
}

class Header extends StatelessWidget {
  final List<Widget> left;
  final List<Widget> right;
  final String? errorMessage;

  const Header({super.key, required this.left, required this.right, this.errorMessage});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: Row(children: [
            ...left,
            const Spacer(),
            ...right 
          ]),
        ),
        if (errorMessage != null)
          PaddedCard(child: Row(children: [
            const SizedBox(width: 10.0),
            const NormalIcon(Icons.error_outline),
            const SizedBox(width: 10.0),
            NormalText(errorMessage!)
          ])),
      ]
    );
  }
  
}

class StaleIndicator extends StatelessWidget {
  final bool stale;

  const StaleIndicator({super.key, required this.stale});

  @override
  Widget build(BuildContext context) {
    if (!stale) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10.0,
          height: 10.0,
          decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle)
        ),
        const SizedBox(width: 5.0),
        const NormalText("unsaved"),
        const SizedBox(width: 10.0)
      ]
    );
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

  @override
  void initState() {
    super.initState();
    _syncFromTimestamp();
  }

  @override
  void didUpdateWidget(DateTimeFieldInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timestamp != widget.timestamp) {
      _syncFromTimestamp();
    }
  }

  void _syncFromTimestamp() {
    if (widget.timestamp <= 0.0) {
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

    final hour24 = (hour12 % 12) + (_isPm ? 12 : 0);
    return DateTime.utc(year, month, day, hour24, minute);
  }

  void _emit() {
    final composed = _composeUtc();
    if (composed == null) return;
    final seconds = composed.millisecondsSinceEpoch / 1000.0;
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
    final inputs = Row(children: [
      _ComponentBox(label: "MM", width: 40, text: _month, onChanged: (val) => _onChanged("month", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "DD", width: 40, text: _day, onChanged: (val) => _onChanged("day", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "YYYY", width: 50, text: _year, onChanged: (val) => _onChanged("year", val)),
      const SizedBox(width: 10),
      _ComponentBox(label: "hh", width: 40, text: _hour, onChanged: (val) => _onChanged("hour", val)),
      const SizedBox(width: 5),
      _ComponentBox(label: "mm", width: 40, text: _minute, onChanged: (val) => _onChanged("minute", val)),
      const SizedBox(width: 10),
      SizedBox(width: 50.0, child: CompactDropdown<bool>(
        initialSelection: _isPm,
        onSelected: (value) {
          if (value == null) return;
          _setAmPm(value);
        },
        dropdownMenuEntries: const [
          DropdownMenuEntry(value: false, label: "AM"),
          DropdownMenuEntry(value: true, label: "PM")
        ]
      ))
    ]);

    if (widget.labelOnLeft) {
      return Row(children: [
        SizedBox(width: 150, child: NormalText(widget.label)),
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
