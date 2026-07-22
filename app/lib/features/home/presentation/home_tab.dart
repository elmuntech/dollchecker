import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected bottom-navigation tab index for the home shell.
/// 0 = Scan, 1 = Dashboard, 2 = History.
final homeTabProvider = StateProvider<int>((ref) => 0);
