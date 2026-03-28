import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/blocs/param_space_bloc.dart";
import "package:alphchemy/objects/node_object.dart";
import "package:alphchemy/objects/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ParamField extends StatelessWidget {
  final String fieldKey;
  final ParamType paramType;
  final NodeObject nodeData;
  final Widget child;

  const ParamField({
    super.key,
    required this.fieldKey,
    required this.paramType,
    required this.nodeData,
    required this.child
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ParamSpaceBloc, ParamSpaceState>(
      builder: (context, paramState) {
        final compatible = paramState.paramsOfType(paramType);
        final currentRef = nodeData.paramRefs[fieldKey];
        final isLiteral = currentRef == null;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: IgnorePointer(
                ignoring: !isLiteral,
                child: Opacity(
                  opacity: isLiteral ? 1.0 : 0.5,
                  child: child
                )
              )
            ),
            SizedBox(width: 2),
            SizedBox(
              width: 80,
              child: ParamSelector(
                fieldKey: fieldKey,
                nodeData: nodeData,
                compatible: compatible,
                currentRef: currentRef
              )
            )
          ]
        );
      }
    );
  }
}

class ParamSelector extends StatelessWidget {
  final String fieldKey;
  final NodeObject nodeData;
  final List<ParamDef> compatible;
  final String? currentRef;

  const ParamSelector({super.key, required this.fieldKey, required this.nodeData,required this.compatible, required this.currentRef});

  @override
  Widget build(BuildContext context) {
    final hasValidRef = compatible.any((def) => def.name == currentRef);
    final dropdownValue = hasValidRef ? currentRef : null;
    return SizedBox(
      height: 24,
      child: DropdownButton<String?>(
        value: dropdownValue,
        isExpanded: true,
        isDense: true,
        underline: SizedBox(),
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text("literal")
          ),
          ...compatible.map((def) {
            return DropdownMenuItem<String?>(
              value: def.name,
              child: Text(def.name)
            );
          })
        ],
        onChanged: (val) {
          if (val == null) {
            nodeData.paramRefs.remove(fieldKey);
          } else {
            nodeData.paramRefs[fieldKey] = val;
          }
          context.read<NodeDataBloc>().add(const NodeDataChanged());
        }
      )
    );
  }
}
