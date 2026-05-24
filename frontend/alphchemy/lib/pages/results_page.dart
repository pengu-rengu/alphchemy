import "package:alphchemy/blocs/experiments/pinescript_bloc.dart";
import "package:alphchemy/blocs/experiments/results_bloc.dart";
import "package:alphchemy/widgets/dialog_utils.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/results/results_area.dart";
import "package:alphchemy/widgets/results/results_dashboard.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter/services.dart";
import "package:supabase_flutter/supabase_flutter.dart";

class ResultsPage extends StatelessWidget {
  final String title;
  final int experimentId;

  const ResultsPage({super.key, required this.experimentId, required this.title});

  @override
  Widget build(BuildContext context) {
    final client = context.read<SupabaseClient>();

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (blocContext) {
            final bloc = ResultsBloc(client: client);
            final event = LoadResults(experimentId: experimentId);
            bloc.add(event);
            return bloc;
          }
        ),
        BlocProvider(
          create: (blocContext) => PinescriptBloc(client: client)
        )
      ],
      child: PinescriptListener(child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              ResultsHeader(title: title),
              const Divider(height: 1),
              const Expanded(child: ResultsArea())
            ]
          )
        )
      ))
    );
  }
}

class PinescriptListener extends StatelessWidget {
  final Widget child;

  const PinescriptListener({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocListener<PinescriptBloc, PinescriptState>(
      listener: (context, state) async {
        if (state is PinescriptCompleted) {
          await showDialog<void>(
            context: context,
            builder: (dialogContext) => PinescriptDialog(pinescript: state.pinescript)
          );
          if (context.mounted) {
            context.read<PinescriptBloc>().add(const ResetPinescript());
          }
          return;
        }

        if (state is PinescriptError) {
          await errorDialog(context: context, message: state.message);
          if (context.mounted) {
            context.read<PinescriptBloc>().add(const ResetPinescript());
          }
        }
      },
      child: child
    );
  }
}

class ResultsHeader extends StatelessWidget {
  final String title;

  const ResultsHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Header(
      left: [
        IconButton(
          icon: const NormalIcon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop()
        ),
        const SizedBox(width: 10.0),
        LargeText(title)
      ],
      right: [
        BlocBuilder<ResultsBloc, ResultsState>(
          builder: (context, state) {
            if (state is ResultsLoaded) {
              return Row(
                children: [
                  PinescriptButton(resultsState: state),
                  const SizedBox(width: 10.0),
                  ExperimentConfigButton(experiment: state.results.experiment)
                ]
              );
            }
            return const SizedBox();
          }
        )
      ]
    );
  }
}

class PinescriptButton extends StatelessWidget {
  final ResultsLoaded resultsState;

  const PinescriptButton({super.key, required this.resultsState});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PinescriptBloc, PinescriptState>(
      builder: (context, state) {
        final working = state is PinescriptWorking;
        final label = working ? "Converting..." : "Convert to PineScript";

        return FilledButton.icon(
          onPressed: working ? null : () {
            final event = ConvertPinescript(
              experimentId: resultsState.experimentId,
              foldIdx: resultsState.selectedFoldIdx
            );
            context.read<PinescriptBloc>().add(event);
          },
          icon: InvertedIcon(working ? Icons.hourglass_top : Icons.code),
          label: InvertedText(label)
        );
      }
    );
  }
}

class PinescriptDialog extends StatefulWidget {
  final String pinescript;

  const PinescriptDialog({super.key, required this.pinescript});

  @override
  State<PinescriptDialog> createState() => _PinescriptDialogState();
}

class _PinescriptDialogState extends State<PinescriptDialog> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: const LargeText("Pinescript code"),
      content: SizedBox(
        width: size.width * 0.8,
        height: size.height,
        child: Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            child: NormalText(widget.pinescript)
          )
        )
      ),
      actions: [
        FilledButton(
          onPressed: _copy,
          child: const InvertedText("Copy")
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const InvertedText("Close")
        )
      ]
    );
  }

  Future<void> _copy() async {
    final data = ClipboardData(text: widget.pinescript);
    await Clipboard.setData(data);
  }
}
