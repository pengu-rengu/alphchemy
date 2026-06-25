import "dart:convert";

import "package:alphchemy/blocs/agents/agent_bloc.dart";
import "package:alphchemy/model/agents/agent_system.dart";
import "package:alphchemy/model/agents/submission.dart";
//import "package:alphchemy/model/experiment/experiment.dart";
import "package:alphchemy/model/notebook/notebook.dart";
//import "package:alphchemy/widgets/experiment_tree.dart";
import "package:alphchemy/widgets/misc_widgets.dart";
import "package:alphchemy/widgets/notebook/notebook_view.dart";
import "package:flutter/material.dart";
import "package:flutter_bloc/flutter_bloc.dart";

class SubmissionsSection extends StatelessWidget {
  const SubmissionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AgentBloc, AgentState>(
      builder: (context, state) {
        return state is! AgentLoaded ? const SizedBox.shrink() : Column(
          children: [
            SubmissionsHeader(count: state.agentSys.submissions.length),
            const Divider(height: 1),
            Expanded(child: SubmissionsList(agentSys: state.agentSys))
          ]
        );
      }
    );
  }
}

class SubmissionsHeader extends StatelessWidget {
  final int count;

  const SubmissionsHeader({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(
        children: [
          const Expanded(child: LargeText("Submissions")),
          NormalText(count.toString())
        ]
      )
    );
  }
}

class SubmissionsList extends StatelessWidget {
  final AgentSystem agentSys;

  const SubmissionsList({super.key, required this.agentSys});

  @override
  Widget build(BuildContext context) {
    final submissions = agentSys.submissions;

    return submissions.isEmpty ? const CenterText("No submissions yet") : ListView.builder(
      itemCount: submissions.length,
      itemBuilder: (context, index) => SubmissionTile(
        submission: submissions[index],
        index: index
      )
    );
  }
}

class SubmissionTile extends StatelessWidget {
  final Submission submission;
  final int index;

  const SubmissionTile({super.key, required this.submission, required this.index});

  @override
  Widget build(BuildContext context) {
    final icon = submission is ExperimentSubmission ? Icons.science : Icons.menu_book;

    return ListTile(
      leading: NormalIcon(icon),
      title: NormalText(submission.title),
      onTap: () async {
        final bloc = context.read<AgentBloc>();
        await showDialog<void>(
          context: context,
          builder: (innerContext) => SubmissionDialog(
            submission: submission,
            index: index,
            bloc: bloc
          )
        );
      }
    );
  }
}

class SubmissionDialog extends StatelessWidget {
  final Submission submission;
  final int index;
  final AgentBloc bloc;

  const SubmissionDialog({super.key, required this.submission, required this.index, required this.bloc});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return AlertDialog(
      title: LargeText(submission.title),
      content: SizedBox(
        width: size.width * 0.8,
        height: size.height,
        child: SubmissionContent(submission: submission)
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const InvertedText("Close")
        ),
        FilledButton(
          onPressed: () {
            final event = DiscardSubmission(index: index);
            bloc.add(event);
            Navigator.pop(context);
          },
          child: const InvertedText("Discard")
        ),
        if (submission is ExperimentSubmission)
          FilledButton.icon(
            onPressed: () {
              final event = QueueSubmissionExperiment(index: index);
              bloc.add(event);
              Navigator.pop(context);
            },
            icon: const InvertedIcon(Icons.add),
            label: const InvertedText("Queue Experiment")
          ),
        if (submission is NotebookSubmission)
          FilledButton.icon(
            onPressed: () {
              final event = AddSubmissionNotebook(index: index);
              bloc.add(event);
              Navigator.pop(context);
            },
            icon: const InvertedIcon(Icons.menu_book),
            label: const InvertedText("Add Notebook")
          )

      ]
    );
  }
}

class SubmissionContent extends StatelessWidget {
  final Submission submission;

  const SubmissionContent({super.key, required this.submission});

  @override
  Widget build(BuildContext context) {

    if (submission is ExperimentSubmission) {
      /*
      final experiment = Experiment.fromJson((submission as ExperimentSubmission).experimentJson);
      final tree = buildExperimentTree(experiment);
      return ExperimentTree(tree: tree, readOnly: true);
      */
      const encoder = JsonEncoder.withIndent("  ");
      final experimentJson = (submission as ExperimentSubmission).experimentJson;
      final text = encoder.convert(experimentJson);
      return SingleChildScrollView(
        padding: const EdgeInsets.all(10.0),
        child: NormalText(text)
      );
    }

    final notebook = Notebook.fromJson({...(submission as NotebookSubmission).notebookJson, "id": 0, "status": "idle"});
    return NotebookView(notebook: notebook, readOnly: true);
  }
}
