import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ParamField extends StatelessWidget {
  final String fieldKey;
  final ParamType paramType;
  final Widget child;

  const ParamField({
    super.key,
    required this.fieldKey,
    required this.paramType,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, editorState) {
        final compatible = editorState.paramsOfType(paramType);
        final nodeData = context.read<NodeDataBloc>().node.data;
        final currentRef = nodeData.paramRefs[fieldKey];
        final hasValidRef = compatible.any((param) => param.name == currentRef);
        final isLiteral = !hasValidRef;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: !isLiteral,
                child: Opacity(opacity: isLiteral ? 1.0 : 0.5, child: child),
              ),
            ),
            const SizedBox(width: 2),
            SizedBox(
              width: 80,
              child: ParamSelector(
                fieldKey: fieldKey,
                compatible: compatible,
                currentRef: currentRef,
                hasValidRef: hasValidRef,
              ),
            ),
          ],
        );
      },
    );
  }
}

class ParamSelector extends StatelessWidget {
  final String fieldKey;
  final List<Param> compatible;
  final String? currentRef;
  final bool hasValidRef;

  const ParamSelector({
    super.key,
    required this.fieldKey,
    required this.compatible,
    required this.currentRef,
    required this.hasValidRef,
  });

  @override
  Widget build(BuildContext context) {
    final dropdownValue = hasValidRef ? currentRef : null;
    return SizedBox(
      height: 24,
      child: DropdownButton<String?>(
        value: dropdownValue,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text("literal")),
          ...compatible.map((def) {
            return DropdownMenuItem<String?>(
              value: def.name,
              child: Text(def.name),
            );
          }),
        ],
        onChanged: (val) {
          final bloc = context.read<NodeDataBloc>();
          bloc.add(UpdateNodeParamRef(fieldKey: fieldKey, paramName: val));
        },
      ),
    );
  }
}
