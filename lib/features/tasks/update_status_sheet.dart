import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task_status.dart';
import '../../widgets/message_banner.dart';
import '../../widgets/primary_button.dart';
import 'update_status_cubit.dart';

/// Bottom sheet to pick a new status and an optional note. Expects an
/// [UpdateStatusCubit] above it; closes itself once everything is saved.
class UpdateStatusSheet extends StatefulWidget {
  const UpdateStatusSheet({super.key, required this.taskName});

  final String taskName;

  @override
  State<UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<UpdateStatusSheet> {
  /// Kept for the whole sheet, so a failed comment never loses the note.
  final _note = TextEditingController();

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<UpdateStatusCubit>();
    return BlocConsumer<UpdateStatusCubit, UpdateStatusState>(
      listenWhen: (previous, current) =>
          current.phase == UpdateStatusPhase.done &&
          previous.phase != UpdateStatusPhase.done,
      listener: (context, state) => Navigator.of(context).pop(),
      builder: (context, state) {
        final retryingComment = state.commentFailedBefore;
        return PopScope(
          // Don't let a swipe or back press drop a request in flight.
          canPop: !state.isBusy,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                20 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Change status',
                    style: TextStyle(
                      color: AppColors.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.taskName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  if (state.error != null) ...[
                    _ErrorBanner(state: state),
                    const SizedBox(height: 16),
                  ],
                  _StatusOptions(state: state, onSelected: cubit.select),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _note,
                    enabled: !state.isBusy,
                    minLines: 2,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Posted as a comment after the status is saved',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // After a failed comment only the comment can be retried.
                  if (retryingComment) ...[
                    PrimaryButton(
                      label: 'Retry comment',
                      loading: state.phase == UpdateStatusPhase.postingComment,
                      onPressed: () => cubit.retryComment(_note.text),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: state.isBusy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Close without posting the note'),
                    ),
                  ] else
                    PrimaryButton(
                      label: 'Save status',
                      // Covers both requests: status, then the note.
                      loading: state.isBusy,
                      onPressed: state.canSave
                          ? () => cubit.submit(_note.text)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One choice chip per API status; the task's current status is marked.
class _StatusOptions extends StatelessWidget {
  const _StatusOptions({required this.state, required this.onSelected});

  final UpdateStatusState state;
  final ValueChanged<TaskStatus> onSelected;

  @override
  Widget build(BuildContext context) {
    // Once the status is saved it can't be changed from this sheet.
    final enabled = state.phase == UpdateStatusPhase.editing;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final status in TaskStatus.values)
          ChoiceChip(
            label: Text(
              status == state.current
                  ? '${status.label} (current)'
                  : status.label,
            ),
            selected: status == state.selected,
            showCheckmark: false,
            onSelected: enabled ? (_) => onSelected(status) : null,
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.state});

  final UpdateStatusState state;

  @override
  Widget build(BuildContext context) {
    if (!state.statusSaved) {
      return MessageBanner(title: 'Status not saved', message: state.error!);
    }
    final maybe = state.commentMayHavePosted
        ? '\nThe note may have been posted anyway. Check the latest comment '
              'before retrying.'
        : '';
    return MessageBanner(
      title: 'Status saved, but the note was not posted',
      message: '${state.error!}$maybe',
    );
  }
}
