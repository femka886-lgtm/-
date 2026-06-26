import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => StatsController()..loadProgress(),
      child: const LifeGamificationApp(),
    ),
  );
}

class LifeGamificationApp extends StatelessWidget {
  const LifeGamificationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Life Gamification',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
        dividerColor: const Color(0xFFE6EAF0),
      ),
      home: const MainNavigationScreen(),
    );
  }
}

enum HabitIconType {
  water,
  sport,
  book,
}

enum ProofType {
  note,
  timer,
}

enum HabitStatus {
  idle,
  inProgress,
  rewardReady,
  completed,
}

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.xpReward,
    required this.restMinutesReward,
    required this.iconType,
    required this.proofType,
    this.targetSeconds = 0,
    this.status = HabitStatus.idle,
    this.isCompletedToday = false,
    this.proofNote,
    this.proofSubmittedAt,
  });

  final String id;
  final String title;
  final int xpReward;
  final int restMinutesReward;
  final HabitIconType iconType;
  final ProofType proofType;
  final int targetSeconds;
  final HabitStatus status;
  final bool isCompletedToday;
  final String? proofNote;
  final DateTime? proofSubmittedAt;

  Habit copyWith({
    String? id,
    String? title,
    int? xpReward,
    int? restMinutesReward,
    HabitIconType? iconType,
    ProofType? proofType,
    int? targetSeconds,
    HabitStatus? status,
    bool? isCompletedToday,
    String? proofNote,
    DateTime? proofSubmittedAt,
    bool clearProofNote = false,
    bool clearProofSubmittedAt = false,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      xpReward: xpReward ?? this.xpReward,
      restMinutesReward: restMinutesReward ?? this.restMinutesReward,
      iconType: iconType ?? this.iconType,
      proofType: proofType ?? this.proofType,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      status: status ?? this.status,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      proofNote: clearProofNote ? null : proofNote ?? this.proofNote,
      proofSubmittedAt: clearProofSubmittedAt
          ? null
          : proofSubmittedAt ?? this.proofSubmittedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'status': status.name,
      'isCompletedToday': isCompletedToday,
      'proofNote': proofNote,
      'proofSubmittedAt': proofSubmittedAt?.toIso8601String(),
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      xpReward: (map['xpReward'] as num?)?.toInt() ?? 0,
      restMinutesReward: ((map['restMinutesReward'] ?? map['goldReward'] ?? 0)
              as num?)
          ?.toInt() ??
          0,
      iconType: HabitIconType.values.firstWhere(
        (value) => value.name == map['iconType'],
        orElse: () => HabitIconType.book,
      ),
      proofType: ProofType.values.firstWhere(
        (value) => value.name == map['proofType'],
        orElse: () => ProofType.note,
      ),
      targetSeconds: (map['targetSeconds'] as num?)?.toInt() ?? 0,
      status: HabitStatus.values.firstWhere(
        (value) => value.name == map['status'],
        orElse: () => HabitStatus.idle,
      ),
      isCompletedToday: map['isCompletedToday'] as bool? ?? false,
      proofNote: map['proofNote'] as String?,
      proofSubmittedAt: map['proofSubmittedAt'] == null
          ? null
          : DateTime.tryParse(map['proofSubmittedAt'] as String),
    );
  }
}

class ShopItem {
  const ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
  });

  final String id;
  final String title;
  final String description;
  final int price;
}

class GameLog {
  const GameLog({
    required this.timestamp,
    required this.message,
  });

  final DateTime timestamp;
  final String message;

  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'message': message,
    };
  }

  factory GameLog.fromMap(Map<String, dynamic> map) {
    return GameLog(
      timestamp: DateTime.parse(map['timestamp'] as String),
      message: map['message'] as String,
    );
  }
}

class HabitCompleteResult {
  const HabitCompleteResult({
    required this.wasCompleted,
    required this.xpGained,
    required this.restMinutesGained,
    required this.levelsGained,
    required this.newLevel,
    required this.currentStreak,
  });

  final bool wasCompleted;
  final int xpGained;
  final int restMinutesGained;
  final int levelsGained;
  final int newLevel;
  final int currentStreak;
}

class RewardClaimResult {
  const RewardClaimResult({
    required this.success,
    required this.xpGained,
    required this.restMinutesGained,
    required this.levelsGained,
    required this.newLevel,
  });

  final bool success;
  final int xpGained;
  final int restMinutesGained;
  final int levelsGained;
  final int newLevel;
}

class StatsController extends ChangeNotifier {
  StatsController();

  static const int maxXp = 100;
  static const int maxLogs = 100;

  static const String levelKey = 'level';
  static const String xpKey = 'xp';
  static const String restMinutesKey = 'rest_minutes';
  static const String legacyGoldKey = 'gold';
  static const String streakKey = 'streak';
  static const String lastOpenedDateKey = 'last_opened_date';
  static const String lastRewardDateKey = 'last_rewarded_date';
  static const String legacyLastCompletedDateKey = 'last_completed_date';
  static const String habitsStateKey = 'habits_state';
  static const String inventoryItemIdsKey = 'inventory_item_ids';
  static const String gameLogsKey = 'game_logs';
  static const String activeTimerHabitIdKey = 'active_timer_habit_id';
  static const String timerEndAtKey = 'timer_end_at';

  SharedPreferences? _prefs;
  Timer? _timer;

  int _level = 1;
  int _xp = 0;
  int _restMinutes = 0;
  int _streak = 0;
  bool _isLoading = true;
  DateTime? _lastOpenedDate;
  DateTime? _lastRewardDate;
  List<Habit> _habits = [];
  List<ShopItem> _shopItems = [];
  List<String> _inventoryItemIds = [];
  List<GameLog> _logs = [];
  String? _activeTimerHabitId;
  DateTime? _timerEndAt;

  int get level => _level;
  int get xp => _xp;
  int get restMinutes => _restMinutes;
  int get streak => _streak;
  bool get isLoading => _isLoading;
  double get progress => _xp / maxXp;
  List<Habit> get habits => List.unmodifiable(_habits);
  List<ShopItem> get shopItems => List.unmodifiable(_shopItems);
  List<String> get inventoryItemIds => List.unmodifiable(_inventoryItemIds);
  int get inventoryCount => _inventoryItemIds.length;
  List<GameLog> get logs => List.unmodifiable(_logs);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<Habit> _createDefaultHabits() {
    return const [
      Habit(
        id: 'water',
        title: 'Выпить стакан воды',
        xpReward: 10,
        restMinutesReward: 5,
        iconType: HabitIconType.water,
        proofType: ProofType.note,
      ),
      Habit(
        id: 'sport',
        title: 'Сделать 10 минут зарядки',
        xpReward: 30,
        restMinutesReward: 15,
        iconType: HabitIconType.sport,
        proofType: ProofType.timer,
        targetSeconds: 600,
      ),
      Habit(
        id: 'book',
        title: 'Почитать 15 минут',
        xpReward: 25,
        restMinutesReward: 10,
        iconType: HabitIconType.book,
        proofType: ProofType.timer,
        targetSeconds: 900,
      ),
    ];
  }

  List<ShopItem> _createDefaultShopItems() {
    return const [
      ShopItem(
        id: 'series',
        title: 'Серия сериала',
        description: 'Один эпизод любимого сериала без чувства вины.',
        price: 30,
      ),
      ShopItem(
        id: 'snack',
        title: 'Вкусняшка',
        description: 'Маленькая награда: десерт, кофе или любимый снек.',
        price: 40,
      ),
      ShopItem(
        id: 'games',
        title: '1 час видеоигр',
        description: 'Честно заработанный игровой час для отдыха.',
        price: 60,
      ),
    ];
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime.utc(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;

    final parts = value.split('-');
    if (parts.length != 3) return null;

    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final day = int.tryParse(parts[2]);

    if (year == null || month == null || day == null) return null;

    return DateTime.utc(year, month, day);
  }

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  ShopItem? getShopItemById(String itemId) {
    try {
      return _shopItems.firstWhere((item) => item.id == itemId);
    } catch (_) {
      return null;
    }
  }

  int getPurchaseCountFor(String itemId) {
    return _inventoryItemIds.where((id) => id == itemId).length;
  }

  int remainingSecondsForHabit(String habitId) {
    if (_activeTimerHabitId != habitId || _timerEndAt == null) return 0;
    return math.max(0, _timerEndAt!.difference(DateTime.now()).inSeconds);
  }

  Future<void> loadProgress() async {
    _isLoading = true;
    notifyListeners();

    final prefs = await _getPrefs();
    final today = _today();

    _shopItems = _createDefaultShopItems();
    _level = prefs.getInt(levelKey) ?? 1;
    _xp = prefs.getInt(xpKey) ?? 0;
    _restMinutes =
        prefs.getInt(restMinutesKey) ?? prefs.getInt(legacyGoldKey) ?? 0;
    _streak = prefs.getInt(streakKey) ?? 0;
    _logs = _decodeLogs(prefs.getStringList(gameLogsKey) ?? []);
    _inventoryItemIds = (prefs.getStringList(inventoryItemIdsKey) ?? [])
        .where((id) => getShopItemById(id) != null)
        .toList(growable: false);
    _lastOpenedDate = _parseDate(prefs.getString(lastOpenedDateKey));
    _lastRewardDate = _parseDate(prefs.getString(lastRewardDateKey)) ??
        _parseDate(prefs.getString(legacyLastCompletedDateKey));

    final isNewDay =
        _lastOpenedDate == null || !_isSameDay(_lastOpenedDate!, today);

    if (_lastRewardDate == null) {
      _streak = 0;
    } else if (today.difference(_lastRewardDate!).inDays > 1) {
      _streak = 0;
    }

    if (isNewDay) {
      _habits = _createDefaultHabits();
      _activeTimerHabitId = null;
      _timerEndAt = null;
      _timer?.cancel();
    } else {
      _habits = _loadHabitsFromPrefs(prefs);
      _activeTimerHabitId = prefs.getString(activeTimerHabitIdKey);
      final timerEndRaw = prefs.getString(timerEndAtKey);
      _timerEndAt = timerEndRaw == null ? null : DateTime.tryParse(timerEndRaw);
      _restoreTimerState();
    }

    _lastOpenedDate = today;
    await _saveAll();

    _isLoading = false;
    notifyListeners();
  }

  List<Habit> _loadHabitsFromPrefs(SharedPreferences prefs) {
    final defaults = _createDefaultHabits();
    final raw = prefs.getStringList(habitsStateKey) ?? [];
    if (raw.isEmpty) return defaults;

    final loadedById = <String, Habit>{};
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        final habit = Habit.fromMap(map);
        loadedById[habit.id] = habit;
      } catch (_) {
        // ignore broken entries
      }
    }

    return defaults.map((defaultHabit) {
      final loaded = loadedById[defaultHabit.id];
      if (loaded == null) return defaultHabit;
      return defaultHabit.copyWith(
        status: loaded.status,
        isCompletedToday: loaded.isCompletedToday,
        proofNote: loaded.proofNote,
        proofSubmittedAt: loaded.proofSubmittedAt,
      );
    }).toList(growable: false);
  }

  List<GameLog> _decodeLogs(List<String> rawLogs) {
    final result = <GameLog>[];

    for (final raw in rawLogs) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        result.add(GameLog.fromMap(map));
      } catch (_) {
        // ignore broken entries
      }
    }

    return result;
  }

  void _restoreTimerState() {
    _timer?.cancel();

    if (_activeTimerHabitId == null || _timerEndAt == null) return;

    final habitIndex = _habits.indexWhere((habit) => habit.id == _activeTimerHabitId);
    if (habitIndex == -1) {
      _clearTimerState();
      return;
    }

    final habit = _habits[habitIndex];
    if (habit.status != HabitStatus.inProgress) {
      _clearTimerState();
      return;
    }

    if (_timerEndAt!.isBefore(DateTime.now())) {
      _habits[habitIndex] = habit.copyWith(
        status: HabitStatus.rewardReady,
        proofSubmittedAt: DateTime.now(),
      );
      _clearTimerState();
      return;
    }

    _startTimerTicker();
  }

  void _startTimerTicker() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeTimerHabitId == null || _timerEndAt == null) {
        timer.cancel();
        return;
      }

      final remaining = _timerEndAt!.difference(DateTime.now()).inSeconds;
      if (remaining <= 0) {
        timer.cancel();
        _finishActiveTimer();
        return;
      }

      notifyListeners();
    });
  }

  Future<void> _finishActiveTimer() async {
    if (_activeTimerHabitId == null) return;

    final index = _habits.indexWhere((habit) => habit.id == _activeTimerHabitId);
    if (index == -1) {
      _clearTimerState();
      await _saveAll();
      return;
    }

    final habit = _habits[index];
    _habits[index] = habit.copyWith(
      status: HabitStatus.rewardReady,
      proofSubmittedAt: DateTime.now(),
    );

    _clearTimerState();
    notifyListeners();
    await _saveAll();
  }

  void _clearTimerState() {
    _timer?.cancel();
    _timer = null;
    _activeTimerHabitId = null;
    _timerEndAt = null;
  }

  Future<bool> startTimerProof(String habitId) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) return false;

    final habit = _habits[index];
    if (habit.isCompletedToday || habit.status != HabitStatus.idle) return false;
    if (habit.proofType != ProofType.timer || habit.targetSeconds <= 0) {
      return false;
    }

    if (_activeTimerHabitId != null) return false;

    _habits[index] = habit.copyWith(status: HabitStatus.inProgress);
    _activeTimerHabitId = habitId;
    _timerEndAt = DateTime.now().add(Duration(seconds: habit.targetSeconds));
    _startTimerTicker();

    notifyListeners();
    await _saveAll();
    return true;
  }

  Future<bool> submitNoteProof(String habitId, String note) async {
    final trimmed = note.trim();
    if (trimmed.isEmpty) return false;

    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) return false;

    final habit = _habits[index];
    if (habit.isCompletedToday || habit.status != HabitStatus.idle) return false;
    if (habit.proofType != ProofType.note) return false;

    _habits[index] = habit.copyWith(
      status: HabitStatus.rewardReady,
      proofNote: trimmed,
      proofSubmittedAt: DateTime.now(),
    );

    notifyListeners();
    await _saveAll();
    return true;
  }

  void _updateStreakForToday(DateTime today) {
    if (_lastRewardDate == null) {
      _streak = 1;
      _lastRewardDate = today;
      return;
    }

    final difference = today.difference(_lastRewardDate!).inDays;
    if (difference == 0) return;
    if (difference == 1) {
      _streak += 1;
    } else {
      _streak = 1;
    }
    _lastRewardDate = today;
  }

  Future<RewardClaimResult> claimReward(String habitId) async {
    final index = _habits.indexWhere((habit) => habit.id == habitId);
    if (index == -1) {
      return RewardClaimResult(
        success: false,
        xpGained: 0,
        restMinutesGained: 0,
        levelsGained: 0,
        newLevel: _level,
      );
    }

    final habit = _habits[index];
    if (habit.status != HabitStatus.rewardReady) {
      return RewardClaimResult(
        success: false,
        xpGained: 0,
        restMinutesGained: 0,
        levelsGained: 0,
        newLevel: _level,
      );
    }

    final today = _today();
    _updateStreakForToday(today);

    _xp += habit.xpReward;
    _restMinutes += habit.restMinutesReward;

    int levelsGained = 0;
    while (_xp >= maxXp) {
      _xp -= maxXp;
      _level++;
      levelsGained++;
    }

    _habits[index] = habit.copyWith(
      status: HabitStatus.completed,
      isCompletedToday: true,
    );

    _addLog(
      'Выполнено: ${habit.title}. Получено +${habit.restMinutesReward} мин. отдыха',
    );

    notifyListeners();
    await _saveAll();

    return RewardClaimResult(
      success: true,
      xpGained: habit.xpReward,
      restMinutesGained: habit.restMinutesReward,
      levelsGained: levelsGained,
      newLevel: _level,
    );
  }

  Future<bool> buyItem(String itemId) async {
    final item = getShopItemById(itemId);
    if (item == null || _restMinutes < item.price) return false;

    _restMinutes -= item.price;
    _inventoryItemIds = [..._inventoryItemIds, item.id];
    _addLog('Куплено: ${item.title}. Списано -${item.price} мин.');

    notifyListeners();
    await _saveAll();
    return true;
  }

  Future<bool> useItem(String itemId) async {
    final itemIndex = _inventoryItemIds.indexOf(itemId);
    if (itemIndex == -1) return false;

    final item = getShopItemById(itemId);
    if (item == null) return false;

    final updatedInventory = List<String>.from(_inventoryItemIds)
      ..removeAt(itemIndex);
    _inventoryItemIds = updatedInventory;
    _addLog('Активировано: ${item.title}');

    notifyListeners();
    await _saveInventory();
    await _saveLogs();
    return true;
  }

  Future<void> resetProgress() async {
    _level = 1;
    _xp = 0;
    _restMinutes = 0;
    _streak = 0;
    _shopItems = _createDefaultShopItems();
    _habits = _createDefaultHabits();
    _inventoryItemIds = [];
    _logs = [];
    _lastOpenedDate = _today();
    _lastRewardDate = null;
    _clearTimerState();

    notifyListeners();
    await _saveAll();
  }

  Future<void> _saveStatsAndMeta() async {
    final prefs = await _getPrefs();

    await prefs.setInt(levelKey, _level);
    await prefs.setInt(xpKey, _xp);
    await prefs.setInt(restMinutesKey, _restMinutes);
    await prefs.remove(legacyGoldKey);
    await prefs.setInt(streakKey, _streak);

    if (_lastOpenedDate != null) {
      await prefs.setString(lastOpenedDateKey, _formatDate(_lastOpenedDate!));
    }

    if (_lastRewardDate != null) {
      await prefs.setString(lastRewardDateKey, _formatDate(_lastRewardDate!));
    } else {
      await prefs.remove(lastRewardDateKey);
      await prefs.remove(legacyLastCompletedDateKey);
    }

    if (_activeTimerHabitId != null && _timerEndAt != null) {
      await prefs.setString(activeTimerHabitIdKey, _activeTimerHabitId!);
      await prefs.setString(timerEndAtKey, _timerEndAt!.toIso8601String());
    } else {
      await prefs.remove(activeTimerHabitIdKey);
      await prefs.remove(timerEndAtKey);
    }
  }

  Future<void> _saveHabits() async {
    final prefs = await _getPrefs();
    final encoded = _habits
        .map((habit) => jsonEncode(habit.toMap()))
        .toList(growable: false);
    await prefs.setStringList(habitsStateKey, encoded);
  }

  Future<void> _saveInventory() async {
    final prefs = await _getPrefs();
    await prefs.setStringList(inventoryItemIdsKey, _inventoryItemIds);
  }

  Future<void> _saveLogs() async {
    final prefs = await _getPrefs();
    final encoded = _logs
        .map((log) => jsonEncode(log.toMap()))
        .toList(growable: false);
    await prefs.setStringList(gameLogsKey, encoded);
  }

  Future<void> _saveAll() async {
    await _saveStatsAndMeta();
    await _saveHabits();
    await _saveInventory();
    await _saveLogs();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _onTabSelected(int index) async {
    setState(() {
      _selectedIndex = index;
    });

    await _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: const [
          HomeScreen(),
          ShopScreen(),
          InventoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onTabSelected,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline_rounded),
            activeIcon: Icon(Icons.person_rounded),
            label: 'Персонаж',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            activeIcon: Icon(Icons.shopping_bag_rounded),
            label: 'Магазин',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2_rounded),
            label: 'Инвентарь',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showNoteProofDialog(BuildContext context, Habit habit) async {
    final controller = context.read<StatsController>();
    final noteController = TextEditingController();

    final bool? submitted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(habit.title),
          content: TextField(
            controller: noteController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Коротко напиши, как выполнил привычку',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Подтвердить'),
            ),
          ],
        );
      },
    );

    if (submitted != true) {
      noteController.dispose();
      return;
    }

    final success = await controller.submitNoteProof(habit.id, noteController.text);
    noteController.dispose();

    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Подтверждение принято. Награда готова.'
                : 'Не удалось подтвердить привычку.',
          ),
        ),
      );
  }

  Future<void> _handleHabitAction(BuildContext context, Habit habit) async {
    final controller = context.read<StatsController>();

    switch (habit.status) {
      case HabitStatus.idle:
        if (habit.proofType == ProofType.note) {
          await _showNoteProofDialog(context, habit);
        } else {
          final started = await controller.startTimerProof(habit.id);
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  started
                      ? 'Таймер запущен: ${habit.title}'
                      : 'Сейчас нельзя запустить эту привычку.',
                ),
              ),
            );
        }
      case HabitStatus.inProgress:
        break;
      case HabitStatus.rewardReady:
        final result = await controller.claimReward(habit.id);
        if (!context.mounted || !result.success) return;

        if (result.levelsGained > 0) {
          await _showLevelUpDialog(context, result.newLevel);
        }

        if (!context.mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(
                'Награда получена: +${result.xpGained} XP и +${result.restMinutesGained} мин. отдыха',
              ),
            ),
          );
      case HabitStatus.completed:
        break;
    }
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final controller = context.read<StatsController>();

    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сбросить прогресс?'),
          content: const Text(
            'Уровень, опыт, минуты отдыха, серия, инвентарь, история и прогресс привычек будут сброшены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Сбросить'),
            ),
          ],
        );
      },
    );

    if (shouldReset != true) return;

    await controller.resetProgress();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(content: Text('Прогресс сброшен.')),
      );
  }

  Future<void> _showLevelUpDialog(BuildContext context, int newLevel) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('LEVEL UP!'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Text(
                'Level $newLevel',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Ты поднялся на новый уровень.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('В бой!'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Персонаж'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Сбросить прогресс',
            onPressed: controller.isLoading
                ? null
                : () => _confirmResetProgress(context),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: controller.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatsCard(
                      level: controller.level,
                      xp: controller.xp,
                      maxXp: StatsController.maxXp,
                      progress: controller.progress,
                      streak: controller.streak,
                      restMinutes: controller.restMinutes,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Привычки',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Сначала подтверди выполнение, потом отдельно забери награду.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView.separated(
                        itemCount: controller.habits.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final habit = controller.habits[index];
                          return HabitCard(
                            habit: habit,
                            remainingSeconds:
                                controller.remainingSecondsForHabit(habit.id),
                            onTap: habit.status == HabitStatus.inProgress ||
                                    habit.status == HabitStatus.completed
                                ? null
                                : () => _handleHabitAction(context, habit),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  Future<void> _buyItem(BuildContext context, ShopItem item) async {
    final controller = context.read<StatsController>();
    final success = await controller.buyItem(item.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Куплено: ${item.title} (-${item.price} мин.)'
                : 'Недостаточно минут отдыха.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин наград'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SummaryCard(
                title: 'Минуты отдыха',
                subtitle: 'Трать только то, что реально заработал.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(
                    icon: Icons.schedule_rounded,
                    label: '${controller.restMinutes} мин.',
                  ),
                  const SizedBox(width: 10),
                  _MiniMetric(
                    icon: Icons.inventory_2_rounded,
                    label: '${controller.inventoryCount} предметов',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Награды',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: controller.shopItems.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, index) {
                    final item = controller.shopItems[index];
                    final canBuy = controller.restMinutes >= item.price;
                    final purchaseCount = controller.getPurchaseCountFor(item.id);

                    return _ShopItemCard(
                      item: item,
                      purchaseCount: purchaseCount,
                      canBuy: canBuy,
                      onBuy: () => _buyItem(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  Future<void> _useItem(BuildContext context, ShopItem item) async {
    final controller = context.read<StatsController>();
    final success = await controller.useItem(item.id);
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Вы активировали награду: ${item.title}'
                : 'Этот предмет уже закончился.',
          ),
        ),
      );
  }

  String _formatLogTime(DateTime dateTime) {
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = dateTime.month.toString().padLeft(2, '0');
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$day.$month • $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final ownedItems = controller.shopItems
        .where((item) => controller.getPurchaseCountFor(item.id) > 0)
        .toList(growable: false);

    final itemsHeight = ownedItems.isEmpty
        ? 0.0
        : ownedItems.length == 1
            ? 144.0
            : ownedItems.length == 2
                ? 252.0
                : 320.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Инвентарь'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SummaryCard(
                title: 'Инвентарь и история',
                subtitle: 'Купленные награды и хронология действий.',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(
                    icon: Icons.inventory_2_rounded,
                    label: '${controller.inventoryCount} предметов',
                  ),
                  const SizedBox(width: 10),
                  _MiniMetric(
                    icon: Icons.schedule_rounded,
                    label: '${controller.restMinutes} мин.',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Купленные награды',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              if (ownedItems.isEmpty)
                const _EmptyCard(
                  icon: Icons.backpack_outlined,
                  title: 'Инвентарь пуст',
                  subtitle: 'Купи награду в магазине, и она появится здесь.',
                )
              else
                SizedBox(
                  height: itemsHeight,
                  child: ListView.separated(
                    itemCount: ownedItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = ownedItems[index];
                      return _InventoryItemTile(
                        item: item,
                        count: controller.getPurchaseCountFor(item.id),
                        onUse: () => _useItem(context, item),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              const Text(
                'История',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: controller.logs.isEmpty
                    ? const _EmptyCard(
                        icon: Icons.history_rounded,
                        title: 'История пуста',
                        subtitle: 'Выполняй привычки и используй награды — здесь появятся записи.',
                      )
                    : ListView.builder(
                        itemCount: controller.logs.length,
                        itemBuilder: (context, index) {
                          final log = controller.logs[index];
                          return _LogTile(
                            message: log.message,
                            timestamp: _formatLogTime(log.timestamp),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.level,
    required this.xp,
    required this.maxXp,
    required this.progress,
    required this.streak,
    required this.restMinutes,
  });

  final int level;
  final int xp;
  final int maxXp;
  final double progress;
  final int streak;
  final int restMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Персонаж',
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Level $level',
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _MetricBlock(
                  label: 'Серия',
                  value: '🔥 $streak',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricBlock(
                  label: 'Отдых',
                  value: '⏱ $restMinutes',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Опыт',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                ),
              ),
              Text(
                '$xp / $maxXp XP',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE9EEF5),
            ),
          ),
        ],
      ),
    );
  }
}

class HabitCard extends StatelessWidget {
  const HabitCard({
    super.key,
    required this.habit,
    required this.remainingSeconds,
    required this.onTap,
  });

  final Habit habit;
  final int remainingSeconds;
  final VoidCallback? onTap;

  IconData _iconForHabit(HabitIconType iconType) {
    switch (iconType) {
      case HabitIconType.water:
        return Icons.water_drop_rounded;
      case HabitIconType.sport:
        return Icons.fitness_center_rounded;
      case HabitIconType.book:
        return Icons.menu_book_rounded;
    }
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _statusText() {
    switch (habit.status) {
      case HabitStatus.idle:
        return habit.proofType == ProofType.note
            ? 'Подтверждение заметкой'
            : 'Таймер ${habit.targetSeconds ~/ 60} мин';
      case HabitStatus.inProgress:
        return 'Идёт таймер ${_formatDuration(remainingSeconds)}';
      case HabitStatus.rewardReady:
        return 'Доказательство принято';
      case HabitStatus.completed:
        return 'Выполнено сегодня';
    }
  }

  String _actionLabel() {
    switch (habit.status) {
      case HabitStatus.idle:
        return habit.proofType == ProofType.note ? 'Подтвердить' : 'Начать';
      case HabitStatus.inProgress:
        return _formatDuration(remainingSeconds);
      case HabitStatus.rewardReady:
        return 'Забрать';
      case HabitStatus.completed:
        return 'Готово';
    }
  }

  bool _isPrimaryAction() {
    return habit.status == HabitStatus.idle || habit.status == HabitStatus.rewardReady;
  }

  @override
  Widget build(BuildContext context) {
    final completed = habit.status == HabitStatus.completed;
    final muted = completed || habit.status == HabitStatus.inProgress;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: completed
                  ? const Color(0xFFE9F8EF)
                  : const Color(0xFFF2F5FA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              _iconForHabit(habit.iconType),
              color: completed
                  ? const Color(0xFF1D9E62)
                  : const Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  habit.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusText(),
                  style: TextStyle(
                    fontSize: 13,
                    color: completed
                        ? const Color(0xFF1D9E62)
                        : const Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SoftBadge(label: '+${habit.xpReward} XP'),
                    _SoftBadge(label: '+${habit.restMinutesReward} мин'),
                  ],
                ),
                if (habit.proofNote != null && habit.proofNote!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Заметка: ${habit.proofNote}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 100,
            child: FilledButton(
              onPressed: onTap,
              style: FilledButton.styleFrom(
                backgroundColor: _isPrimaryAction()
                    ? const Color(0xFF111827)
                    : const Color(0xFFE5E7EB),
                foregroundColor: _isPrimaryAction()
                    ? Colors.white
                    : const Color(0xFF6B7280),
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: Text(
                _actionLabel(),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricBlock extends StatelessWidget {
  const _MetricBlock({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftBadge extends StatelessWidget {
  const _SoftBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE6EAF0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: const Color(0xFF4F46E5)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShopItemCard extends StatelessWidget {
  const _ShopItemCard({
    required this.item,
    required this.purchaseCount,
    required this.canBuy,
    required this.onBuy,
  });

  final ShopItem item;
  final int purchaseCount;
  final bool canBuy;
  final VoidCallback onBuy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.card_giftcard_rounded,
                  color: Color(0xFF111827),
                ),
              ),
              const Spacer(),
              Text(
                'Куплено: $purchaseCount',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            item.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: const TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            '${item.price} мин. отдыха',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canBuy ? onBuy : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
              ),
              child: Text(canBuy ? 'Купить' : 'Не хватает'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryItemTile extends StatelessWidget {
  const _InventoryItemTile({
    required this.item,
    required this.count,
    required this.onUse,
  });

  final ShopItem item;
  final int count;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.card_giftcard_rounded,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'x$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: onUse,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(96, 38),
                ),
                child: const Text('Использовать'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({
    required this.message,
    required this.timestamp,
  });

  final String message;
  final String timestamp;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            timestamp,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: const Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}
