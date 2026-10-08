import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/task_status.dart';
import '../../widgets/message_banner.dart';
import '../../widgets/primary_button.dart';
import 'task_badges.dart';
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
                  _Title(
                    taskName: widget.taskName,
                    onClose: state.isBusy
                        ? null
                        : () => Navigator.of(context).pop(),
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
                    style: const TextStyle(color: AppColors.ink, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Note (optional)',
                      hintText: 'Posted as a comment after the status is saved',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: AppColors.fieldFill,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.fieldBorder,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13),
                        borderSide: const BorderSide(
                          color: AppColors.fieldBorder,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // After a failed comment only the comment can be retried.
                  if (state.commentFailedBefore) ...[
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

class _Title extends StatelessWidget {
  const _Title({required this.taskName, required this.onClose});

  final String taskName;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: const Text(
                  'Change status',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Move "$taskName" to a new stage',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Close',
          onPressed: onClose,
          icon: const Icon(Icons.close, color: AppColors.muted),
        ),
      ],
    );
  }
}

/// One radio row per API status: coloured dot, label, short description.
class _StatusOptions extends StatelessWidget {
  const _StatusOptions({required this.state, required this.onSelected});

  final UpdateStatusState state;
  final ValueChanged<TaskStatus> onSelected;

  static String _description(TaskStatus status) => switch (status) {
    TaskStatus.toDo => 'Ready to be started',
    TaskStatus.inProgress => 'Actively being worked on',
    TaskStatus.onHold => 'Paused for now',
    TaskStatus.review => 'Ready for feedback',
    TaskStatus.changesRequested => 'Needs another pass',
    TaskStatus.blocked => 'Cannot move forward',
    TaskStatus.done => 'Work is complete',
    TaskStatus.canceled => 'No longer needed',
  };

  @override
  Widget build(BuildContext context) {
    // Once the status is saved it can't be changed from this sheet.
    final enabled = state.phase == UpdateStatusPhase.editing;
    return Column(
      children: [
        for (final status in TaskStatus.values)
          _StatusRow(
            status: status,
            description: _description(status),
            selected: status == state.selected,
            current: status == state.current,
            onTap: enabled ? () => onSelected(status) : null,
          ),
      ],
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.status,
    required this.description,
    required this.selected,
    required this.current,
    required this.onTap,
  });

  final TaskStatus status;
  final String description;
  final bool selected;
  final bool current;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        inMutuallyExclusiveGroup: true,
        checked: selected,
        enabled: onTap != null,
        child: Opacity(
          opacity: onTap == null && !selected ? 0.5 : 1,
          child: Material(
            color: selected ? const Color(0xFFF5F4FF) : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: radius,
              side: BorderSide(
                color: selected ? const Color(0xFFCFCBFA) : Colors.transparent,
              ),
            ),
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: StatusBadge.statusColor(status),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                status.label,
                                style: const TextStyle(
                                  color: AppColors.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (current) const _CurrentTag(),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RadioDot(selected: selected),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentTag extends StatelessWidget {
  const _CurrentTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.line),
      ),
      child: const Text(
        'Current',
        style: TextStyle(
          color: AppColors.muted,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  const _RadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.brand : AppColors.fieldBorder,
          width: selected ? 2 : 1.5,
        ),
      ),
      child: selected
          ? Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.brand,
                shape: BoxShape.circle,
              ),
            )
          : null,
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
