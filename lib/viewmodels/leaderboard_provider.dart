import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:komovia_core/komovia_core.dart';

import '../services/leaderboard_service.dart';

final leaderboardServiceProvider = Provider<LeaderboardService>(
  (ref) => LeaderboardService(),
);

final topLeaderboardEntriesProvider = StreamProvider<List<LeaderboardEntry>>(
  (ref) => ref.watch(leaderboardServiceProvider).topEntriesStream(),
);
