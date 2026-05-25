import "package:alphchemy/blocs/docs/docs_bloc.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class DocsSidebar extends StatelessWidget {
  const DocsSidebar({super.key});
  
  @override
  Widget build(BuildContext context) {
    final loaded = context.read<DocsBloc>().state as DocsLoaded;

    final items = <Widget>[];
    for (final entry in loaded.index.groups.entries) {
      items.add(Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: BoldText(entry.key)
      ));
      for (final docId in entry.value) {
        items.add(ListTile(
          title: NormalText(docId),
          selected: docId == loaded.activeId,
          onTap: () {
            final event = SelectDoc(id: docId);
            context.read<DocsBloc>().add(event);
          }
        ));
      }
    }
    return ListView(children: items);
  }
}
