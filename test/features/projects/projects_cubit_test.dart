import 'package:beemview_tasks/core/network/api_exception.dart';
import 'package:beemview_tasks/data/models/project.dart';
import 'package:beemview_tasks/data/repositories/project_repository.dart';
import 'package:beemview_tasks/features/projects/projects_cubit.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockProjectRepository extends Mock implements ProjectRepository {}

List<Project> _projects(int from, int count) => [
  for (var i = from; i < from + count; i++) Project(id: i, name: 'P$i'),
];

ProjectPage _page(int from, int count, {required int total}) =>
    ProjectPage(items: _projects(from, count), total: total, offset: from - 1);

const _offline = ApiException(ApiErrorType.network, 'Offline');

void main() {
  late MockProjectRepository repository;

  setUp(() => repository = MockProjectRepository());

  void stubPage(int offset, Future<ProjectPage> Function() answer) =>
      when(() => repository.fetchProjects(limit: 2, offset: offset))
          .thenAnswer((_) => answer());

  ProjectsCubit build() => ProjectsCubit(repository, pageSize: 2);

  group('load', () {
    blocTest<ProjectsCubit, ProjectsState>(
      'emits loading then the first page',
      setUp: () => stubPage(0, () async => _page(1, 2, total: 5)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProjectsState(status: ProjectsStatus.loading),
        ProjectsState(
          status: ProjectsStatus.success,
          projects: _projects(1, 2),
          total: 5,
          hasMore: true,
        ),
      ],
    );

    blocTest<ProjectsCubit, ProjectsState>(
      'an empty result is success with no more pages',
      setUp: () => stubPage(
        0,
        () async => const ProjectPage(items: [], total: 0, offset: 0),
      ),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProjectsState(status: ProjectsStatus.loading),
        const ProjectsState(status: ProjectsStatus.success),
      ],
    );

    blocTest<ProjectsCubit, ProjectsState>(
      'emits failure with the API message',
      setUp: () => stubPage(0, () => throw _offline),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [
        const ProjectsState(status: ProjectsStatus.loading),
        const ProjectsState(status: ProjectsStatus.failure, error: 'Offline'),
      ],
    );
  });

  group('loadMore', () {
    blocTest<ProjectsCubit, ProjectsState>(
      'appends pages using the next offset until total is reached',
      setUp: () {
        stubPage(0, () async => _page(1, 2, total: 5));
        stubPage(2, () async => _page(3, 2, total: 5));
        stubPage(4, () async => _page(5, 1, total: 5));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
        await cubit.loadMore();
        await cubit.loadMore(); // Nothing left: ignored.
      },
      skip: 2,
      expect: () => [
        isA<ProjectsState>().having((s) => s.isLoadingMore, 'loading', true),
        isA<ProjectsState>()
            .having((s) => s.projects.length, 'count', 4)
            .having((s) => s.hasMore, 'hasMore', true),
        isA<ProjectsState>().having((s) => s.isLoadingMore, 'loading', true),
        isA<ProjectsState>()
            .having((s) => s.projects.length, 'count', 5)
            .having((s) => s.hasMore, 'hasMore', false),
      ],
      verify: (_) {
        verify(() => repository.fetchProjects(limit: 2, offset: 4)).called(1);
        verifyNever(() => repository.fetchProjects(limit: 2, offset: 6));
      },
    );

    blocTest<ProjectsCubit, ProjectsState>(
      'ignores a second tap while a page is loading',
      setUp: () {
        stubPage(0, () async => _page(1, 2, total: 5));
        stubPage(2, () async => _page(3, 2, total: 5));
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await Future.wait([cubit.loadMore(), cubit.loadMore()]);
      },
      verify: (_) =>
          verify(() => repository.fetchProjects(limit: 2, offset: 2)).called(1),
    );

    blocTest<ProjectsCubit, ProjectsState>(
      'stops when the server returns an empty page before total',
      setUp: () {
        stubPage(0, () async => _page(1, 2, total: 5));
        stubPage(
          2,
          () async => const ProjectPage(items: [], total: 5, offset: 2),
        );
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      verify: (cubit) {
        expect(cubit.state.hasMore, isFalse);
        expect(cubit.state.projects, hasLength(2));
      },
    );

    blocTest<ProjectsCubit, ProjectsState>(
      'a failed page keeps loaded projects and can be retried',
      setUp: () {
        stubPage(0, () async => _page(1, 2, total: 5));
        stubPage(2, () => throw _offline);
      },
      build: build,
      act: (cubit) async {
        await cubit.load();
        await cubit.loadMore();
      },
      verify: (cubit) {
        expect(cubit.state.status, ProjectsStatus.success);
        expect(cubit.state.projects, hasLength(2));
        expect(cubit.state.loadMoreError, 'Offline');
        expect(cubit.state.hasMore, isTrue);
      },
    );
  });

  blocTest<ProjectsCubit, ProjectsState>(
    'a failed refresh keeps the current list and reports the error',
    setUp: () {
      var calls = 0;
      stubPage(0, () async {
        if (calls++ == 0) return _page(1, 2, total: 2);
        throw _offline;
      });
    },
    build: build,
    act: (cubit) async {
      await cubit.load();
      await cubit.refresh();
    },
    verify: (cubit) {
      expect(cubit.state.projects, hasLength(2));
      expect(cubit.state.refreshError, 'Offline');
    },
  );
}
