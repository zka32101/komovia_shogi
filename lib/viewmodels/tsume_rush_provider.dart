import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/tsume_rush_service.dart';

final tsumeRushServiceProvider = Provider<TsumeRushService>(
  (ref) => TsumeRushService(),
);

final tsumeRushStatsProvider = StreamProvider.family<TsumeRushStats, String>(
  (ref, uid) => ref.watch(tsumeRushServiceProvider).statsStream(uid),
);
