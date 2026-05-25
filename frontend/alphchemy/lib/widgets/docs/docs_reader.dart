import "package:alphchemy/blocs/docs/docs_bloc.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";

class DocsBody extends StatelessWidget {
  const DocsBody({super.key});

  @override
  Widget build(BuildContext context) {
    final loaded = context.read<DocsBloc>().state as DocsLoaded;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
      child: MarkdownBody(data: loaded.body, selectable: true)
    );
  }
}

