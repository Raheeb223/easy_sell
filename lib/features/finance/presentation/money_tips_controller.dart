import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../expiry/domain/expiry_dates.dart';

/// Which tips these are for: the day, the language and every number the tips
/// were worked out from. A new sale changes the numbers, so old advice is not
/// passed off as current -- the card offers to ask again instead.
String moneyTipsKey(DateTime today, String lang, Map<String, dynamic> facts) =>
    '${ymd(today)}|$lang|${jsonEncode(facts)}';

sealed class MoneyTipsState {
  const MoneyTipsState();
}

class TipsIdle extends MoneyTipsState {
  const TipsIdle();
}

class TipsLoading extends MoneyTipsState {
  const TipsLoading(this.key);

  final String key;
}

class TipsReady extends MoneyTipsState {
  const TipsReady(this.key, this.tips);

  final String key;
  final List<String> tips;
}

class TipsFailed extends MoneyTipsState {
  const TipsFailed(this.key);

  final String key;
}

const _kCache = 'money_tips_cache';

/// Tips are worked out on the phone when the seller taps (`moneyTips`, no
/// network). The last answer is kept, so reopening the app the same day with
/// the same numbers shows it again.
class MoneyTipsController extends Notifier<MoneyTipsState> {
  @override
  MoneyTipsState build() {
    _restore();
    return const TipsIdle();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final tips = [for (final t in m['tips'] as List) t as String];
      // A tap that already started wins over the saved copy.
      if (state is TipsIdle) state = TipsReady(m['key'] as String, tips);
    } catch (_) {
      // A broken cache only costs one extra tap.
    }
  }

  void ask({required String key, required List<String> tips}) {
    if (state case TipsReady(key: final k) when k == key) return;
    if (tips.isEmpty) {
      state = TipsFailed(key);
      return;
    }
    state = TipsReady(key, tips);
    _save(key, tips);
  }

  Future<void> _save(String key, List<String> tips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode({'key': key, 'tips': tips}));
    } catch (_) {}
  }
}

final moneyTipsProvider = NotifierProvider<MoneyTipsController, MoneyTipsState>(
  MoneyTipsController.new,
);
