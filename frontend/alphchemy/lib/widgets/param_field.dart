import "package:alphchemy/blocs/editor_bloc.dart";
import "package:alphchemy/blocs/node_data_bloc.dart";
import "package:alphchemy/model/generator/param_space.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class ParamField extends StatelessWidget {
  final String fieldKey;
  final ParamType paramType;
  final Widget Function(BuildContext context, NodeDataBloc bloc) childBuilder;

  const ParamField({
    super.key,
    required this.fieldKey,
    required this.paramType,
    required this.childBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<EditorBloc, EditorState>(
      builder: (context, state) {
        if (state is! EditorLoaded) return const SizedBox();
        final compatible = state.paramSpace.paramsOfType(paramType);

        return BlocBuilder<NodeDataBloc, NodeDataState>(
          builder: (context, nodeState) {
            final bloc = context.read<NodeDataBloc>();
            final data = bloc.node.data;
            final paramRef = data.paramRefs[fieldKey];
            final isLiteral = paramRef == null;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: IgnorePointer(
                    key: ValueKey<String>("literal_wrapper_$fieldKey"),
                    ignoring: !isLiteral,
                    child: Opacity(
                      opacity: isLiteral ? 1.0 : 0.5,
                      child: childBuilder(context, bloc),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                SizedBox(
                  width: 80,
                  child: ParamSelector(
                    field: fieldKey,
                    compatible: compatible,
                    paramRef: paramRef,
                  )
                )
              ]
            );
          },
        );
      }
    );
  }
}

class ParamSelector extends StatelessWidget {
  final String field;
  final Map<String, Param> compatible;
  final String? paramRef;

  const ParamSelector({
    super.key,
    required this.field,
    required this.compatible,
    required this.paramRef,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 24,
      child: DropdownButton<String?>(
        key: ValueKey<String>("param_selector_$field"),
        value: paramRef,
        isExpanded: true,
        isDense: true,
        underline: const SizedBox(),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text("literal")),
          ...compatible.entries.map((entry) {
            return DropdownMenuItem<String?>(
              value: entry.key,
              child: Text(entry.key),
            );
          }),
        ],
        onChanged: (value) {
          final bloc = context.read<NodeDataBloc>();
          bloc.add(UpdateNodeParamRef(fieldKey: field, paramName: value));
        },
      ),
    );
  }
}
