import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/opening_repertoire.dart';
import '../services/repertoire_service.dart';

final repertoireServiceProvider = Provider<RepertoireService>(
  (ref) => RepertoireService(),
);

final repertoiresStreamProvider =
    StreamProvider.family<List<OpeningRepertoire>, String>(
  (ref, uid) => ref.watch(repertoireServiceProvider).repertoiresStream(uid),
);
