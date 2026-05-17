import "package:alphchemy/blocs/results_bloc.dart";
import "package:alphchemy/widgets/results/results_body.dart";
import "package:alphchemy/widgets/page_scaffold.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final int? initialExperimentId;

  const ResultsPage({
    super.key,
    this.initialExperimentId
  });

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return BlocProvider(
      create: (blocContext) {
        final bloc = ResultsBloc(client: client);
        final experimentId = initialExperimentId;
        if (experimentId != null) {
          final event = LoadResults(experimentId: experimentId);
          bloc.add(event);
        }
        return bloc;
      },
      child: PageScaffold(
        selectedIdx: 2,
        child: Column(
          children: [
            ResultsHeader(initialExperimentId: initialExperimentId),
            const Divider(height: 1),
            const Expanded(child: ResultsBody())
          ]
        )
      )
    );
  }
}

class ResultsHeader extends StatelessWidget {
  final int? initialExperimentId;

  const ResultsHeader({
    super.key,
    this.initialExperimentId
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
      child: Row(
        children: [
          const LargeText("Results"),
          const Spacer(),
          ResultsExperimentIdField(initialExperimentId: initialExperimentId)
        ]
      )
    );
  }
}

class ResultsExperimentIdField extends StatefulWidget {
  final int? initialExperimentId;

  const ResultsExperimentIdField({
    super.key,
    this.initialExperimentId
  });

  @override
  State<ResultsExperimentIdField> createState() => _ResultsExperimentIdFieldState();
}

class _ResultsExperimentIdFieldState extends State<ResultsExperimentIdField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    final experimentId = widget.initialExperimentId;
    if (experimentId != null) {
      _controller.text = experimentId.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240.0,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: TextInputType.number,
              style: Theme.of(context).textTheme.displayMedium,
              onSubmitted: (submittedValue) => _openResults(context, submittedValue)
            )
          ),
          const SizedBox(width: 8.0),
          FilledButton.icon(
            onPressed: () => _openCurrentResults(context),
            icon: const InvertedIcon(Icons.open_in_new),
            label: const InvertedText("Open")
          )
        ]
      )
    );
  }

  void _openCurrentResults(BuildContext context) {
    final text = _controller.text;
    _openResults(context, text);
  }

  void _openResults(BuildContext context, String text) {
    final trimmed = text.trim();
    final experimentId = int.tryParse(trimmed);

    if (experimentId == null) {
      _showInputError(context);
      return;
    }
    if (experimentId < 1) {
      _showInputError(context);
      return;
    }

    final event = LoadResults(experimentId: experimentId);
    final bloc = context.read<ResultsBloc>();
    bloc.add(event);
  }

  void _showInputError(BuildContext context) {
    const event = ShowResultsError(message: "Enter a valid experiment id");
    final bloc = context.read<ResultsBloc>();
    bloc.add(event);
  }
}
