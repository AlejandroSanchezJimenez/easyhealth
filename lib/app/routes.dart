import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_providers.dart';
import '../features/auth/presentation/login_page.dart';
import '../features/diseases/presentation/explore_page.dart';
import '../features/friends/presentation/friends_page.dart';
import '../features/friends/presentation/manage_friends_page.dart';
import '../features/profile/presentation/profile_page.dart';
import '../features/streak/presentation/home_page.dart';
import '../features/streak/presentation/progress_page.dart';
import '../features/teacher/presentation/diseases/disease_form_page.dart';
import '../features/teacher/presentation/diseases/teacher_diseases_page.dart';
import '../features/teacher/presentation/exercises/exercise_form_page.dart';
import '../features/teacher/presentation/exercises/teacher_exercises_page.dart';
import '../features/teacher/presentation/teacher_shell.dart';
import '../features/teacher/presentation/workouts/teacher_workouts_page.dart';
import '../features/teacher/presentation/workouts/workout_form_page.dart';
import '../shared/widgets/home_shell.dart';
import '../features/workouts/domain/daily_pick.dart';
import '../features/workouts/presentation/daily_player_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authStateProvider);
  return GoRouter(
    initialLocation: '/home',
    redirect: (context, state) {
      if (auth.isLoading) return null;
      final user = auth.valueOrNull;
      final loc = state.matchedLocation;
      if (user == null) return loc == '/login' ? null : '/login';
      if (loc == '/login') return '/home';
      if (loc.startsWith('/teacher') && !user.role.canManageContent)
        return '/home';
      if (loc == '/teacher') return '/teacher/diseases';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginPage()),
      GoRoute(
        path: '/play',
        redirect: (_, state) => state.extra is DailyPick ? null : '/home',
        builder: (_, state) => DailyPlayerPage(pick: state.extra as DailyPick),
      ),
      ShellRoute(
        builder: (_, __, child) => TeacherShell(child: child),
        routes: [
          GoRoute(
            path: '/teacher/diseases',
            builder: (_, __) => const TeacherDiseasesPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const DiseaseFormPage()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    DiseaseFormPage(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/teacher/exercises',
            builder: (_, __) => const TeacherExercisesPage(),
            routes: [
              GoRoute(
                  path: 'new', builder: (_, __) => const ExerciseFormPage()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    ExerciseFormPage(id: state.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: '/teacher/workouts',
            builder: (_, __) => const TeacherWorkoutsPage(),
            routes: [
              GoRoute(path: 'new', builder: (_, __) => const WorkoutFormPage()),
              GoRoute(
                path: ':id',
                builder: (_, state) =>
                    WorkoutFormPage(id: state.pathParameters['id']),
              ),
            ],
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => HomeShell(shell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/home', builder: (_, __) => const HomePage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/explore', builder: (_, __) => const ExplorePage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/progress', builder: (_, __) => const ProgressPage())
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/friends',
              builder: (_, __) => const FriendsPage(),
              routes: [
                GoRoute(
                    path: 'manage',
                    builder: (_, __) => const ManageFriendsPage()),
              ],
            )
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, __) => const ProfilePage())
          ]),
        ],
      ),
    ],
  );
});
