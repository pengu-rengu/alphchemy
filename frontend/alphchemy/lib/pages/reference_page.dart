import "package:alphchemy/widgets/page_scaffold.dart";
import "package:flutter/material.dart";
import "package:alphchemy/blocs/docs/docs_bloc.dart";
import "package:alphchemy/widgets/docs/docs_reader.dart";
import "package:alphchemy/widgets/docs/docs_sidebar.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:http/http.dart" as http;

class ReferencePage extends StatelessWidget {
  const ReferencePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DocsBloc>(
      create: (_) {
        final bloc = DocsBloc(httpClient: context.read<http.Client>());
        bloc.add(const LoadDocs());
        return bloc;
      },
      child: const PageScaffold(
        selectedIdx: 4,
        child: DocsArea()
      )
    );
  }
}

class DocsArea extends StatelessWidget {
  const DocsArea({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DocsBloc, DocsState>(
      builder: (context, state) {
        // ignore: prefer_const_constructors
        return Column(
          // ignore: prefer_const_literals_to_create_immutables
          children: [
            const Header(left: [LargeText("Reference")], right: []),
            const Divider(height: 1.0),
            switch (state) {
              DocsInitial() => const Expanded(child: Center(child: CircularProgressIndicator())),
              DocsError() => const Expanded(child: Center(child: NormalText("Docs unavailable"))),
              // ignore: prefer_const_constructors
              DocsLoaded() => Expanded(child: Row(
                // ignore: prefer_const_literals_to_create_immutables
                children: [
                  // ignore: prefer_const_constructors
                  SizedBox(width: 250, child: DocsSidebar()),
                  const VerticalDivider(width: 0),
                  // ignore: prefer_const_constructors
                  Expanded(child: DocsBody())
                ]
              ))
            }
          ]
        );
      }
    );
  }
}