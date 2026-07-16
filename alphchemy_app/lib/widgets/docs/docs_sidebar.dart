import "package:alphchemy_app/blocs/docs/docs_bloc.dart";
import "package:alphchemy_app/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:forui/forui.dart";

class DocsSidebar extends StatelessWidget {
  const DocsSidebar({super.key});
  
  @override
  Widget build(BuildContext context) {
    final loaded = context.read<DocsBloc>().state as DocsLoaded;

    return ListView(
      children: [
        ...[for (final entry in loaded.index.groups.entries)
          ...[
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: LargeText(entry.key)
            ),
            ...[for (final docId in entry.value)
              DocButton(
                docId: docId,
                selected: docId == loaded.activeId
              )
            ]
          ]],
          const SizedBox(height: 10.0)
        ]
    );
  }
}

class DocButton extends StatelessWidget {
  final String docId;
  final bool selected;

  const DocButton({
    super.key,
    required this.docId,
    required this.selected
  });

  @override
  Widget build(BuildContext context) {
    final variant = selected ? FButtonVariant.primary : FButtonVariant.ghost;
    final label = selected ? InvertedText(docId) : NormalText(docId);

    return FButton(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      variant: variant,
      onPress: () {
        final event = SelectDoc(id: docId);
        context.read<DocsBloc>().add(event);
      },
      child: label
    );
  }
}
