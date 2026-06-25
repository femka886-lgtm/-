import 'dart:convert';

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
          seedColor: const Color(0xFF5B8CFF),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F7FB),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
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

class Habit {
  const Habit({
    required this.id,
    required this.title,
    required this.xpReward,
    required this.restMinutesReward,
    required this.iconType,
    this.isCompletedToday = false,
  });

  final String id;
  final String title;
  final int xpReward;
  final int restMinutesReward;
  final bool isCompletedToday;
  final HabitIconType iconType;

  Habit copyWith({
    String? id,
    String? title,
    int? xpReward,
    int? restMinutesReward,
    bool? isCompletedToday,
    HabitIconType? iconType,
  }) {
    return Habit(
      id: id ?? this.id,
      title: title ?? this.title,
      xpReward: xpReward ?? this.xpReward,
      restMinutesReward: restMinutesReward ?? this.restMinutesReward,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
      iconType: iconType ?? this.iconType,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'xpReward': xpReward,
      'restMinutesReward': restMinutesReward,
      'isCompletedToday': isCompletedToday,
      'iconType': iconType.name,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as String,
      title: map['title'] as String,
      xpReward: (map['xpReward'] as num).toInt(),
      restMinutesReward:
          ((map['restMinutesReward'] ?? map['goldReward'] ?? 5) as num)
              .toInt(),
      isCompletedToday: map['isCompletedToday'] as bool? ?? false,
      iconType: HabitIconType.values.firstWhere(
        (value) => value.name == map['iconType'],
        orElse: () => HabitIconType.book,
      ),
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

class StatsController extends ChangeNotifier {
  StatsController();

  static const int maxXp = 100;
  static const int maxLogs = 100;

  static const String levelKey = 'level';
  static const String xpKey = 'xp';
  static const String restMinutesKey = 'rest_minutes';
  static const String legacyGoldKey = 'gold';
  static const String streakKey = 'streak';
  static const String completedHabitIdsKey = 'completed_habit_ids';
  static const String lastOpenedDateKey = 'last_opened_date';
  static const String lastCompletedDateKey = 'last_completed_date';
  static const String inventoryItemIdsKey = 'inventory_item_ids';
  static const String gameLogsKey = 'game_logs';

  SharedPreferences? _prefs;

  int _level = 1;
  int _xp = 0;
  int _restMinutes = 0;
  int _streak = 0;
  bool _isLoading = true;
  DateTime? _lastOpenedDate;
  DateTime? _lastCompletedDate;
  List<Habit> _habits = [];
  List<ShopItem> _shopItems = [];
  List<String> _inventoryItemIds = [];
  List<GameLog> _logs = [];

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

  List<Habit> _createDefaultHabits() {
    return [
      const Habit(
        id: 'water',
        title: 'Выпить стакан воды',
        xpReward: 15,
        restMinutesReward: 5,
        iconType: HabitIconType.water,
      ),
      const Habit(
        id: 'sport',
        title: 'Сделать 10 минут зарядки',
        xpReward: 30,
        restMinutesReward: 15,
        iconType: HabitIconType.sport,
      ),
      const Habit(
        id: 'book',
        title: 'Почитать 15 минут',
        xpReward: 20,
        restMinutesReward: 10,
        iconType: HabitIconType.book,
      ),
    ];
  }

  List<ShopItem> _createDefaultShopItems() {
    return const [
      ShopItem(
        id: 'series',
        title: 'Посмотреть серию сериала',
        description: 'Легальный эпизод любимого шоу без чувства вины.',
        price: 30,
      ),
      ShopItem(
        id: 'snack',
        title: 'Съесть вкусняшку',
        description: 'Небольшая награда в виде десерта или любимого снека.',
        price: 40,
      ),
      ShopItem(
        id: 'games',
        title: '1 час видеоигр',
        description: 'Полноценный игровой час, честно заработанный дисциплиной.',
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

  List<ShopItem> get inventory {
    return _inventoryItemIds
        .map(getShopItemById)
        .whereType<ShopItem>()
        .toList(growable: false);
  }

  void _addLog(String message) {
    final log = GameLog(
      timestamp: DateTime.now(),
      message: message,
    );

    _logs = [log, ..._logs];
    if (_logs.length > maxLogs) {
      _logs = _logs.take(maxLogs).toList(growable: false);
    }
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
    _inventoryItemIds = (prefs.getStringList(inventoryItemIdsKey) ?? [])
        .where((id) => getShopItemById(id) != null)
        .toList(growable: false);
    _logs = _decodeLogs(prefs.getStringList(gameLogsKey) ?? []);
    _lastOpenedDate = _parseDate(prefs.getString(lastOpenedDateKey));
    _lastCompletedDate = _parseDate(prefs.getString(lastCompletedDateKey));

    final bool isNewDay =
        _lastOpenedDate == null || !_isSameDay(_lastOpenedDate!, today);

    if (_lastCompletedDate == null) {
      _streak = 0;
    } else {
      final daysSinceLastCompletion =
          today.difference(_lastCompletedDate!).inDays;
      if (daysSinceLastCompletion > 1) {
        _streak = 0;
      }
    }

    if (isNewDay) {
      _habits = _createDefaultHabits();
    } else {
      final completedHabitIds = prefs.getStringList(completedHabitIdsKey) ?? [];
      _habits = _createDefaultHabits().map((habit) {
        return habit.copyWith(
          isCompletedToday: completedHabitIds.contains(habit.id),
        );
      }).toList(growable: false);
    }

    _lastOpenedDate = today;
    await _saveAll();

    _isLoading = false;
    notifyListeners();
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

    if (_lastCompletedDate != null) {
      await prefs.setString(
        lastCompletedDateKey,
        _formatDate(_lastCompletedDate!),
      );
    } else {
      await prefs.remove(lastCompletedDateKey);
    }
  }

  Future<void> _saveHabits() async {
    final prefs = await _getPrefs();
    final completedHabitIds = _habits
        .where((habit) => habit.isCompletedToday)
        .map((habit) => habit.id)
        .toList(growable: false);

    await prefs.setStringList(completedHabitIdsKey, completedHabitIds);
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

  Future<HabitCompleteResult> completeHabit(String habitId) async {
    final habitIndex = _habits.indexWhere((habit) => habit.id == habitId);

    if (habitIndex == -1) {
      return HabitCompleteResult(
        wasCompleted: true,
        xpGained: 0,
        restMinutesGained: 0,
        levelsGained: 0,
        newLevel: _level,
        currentStreak: _streak,
      );
    }

    final habit = _habits[habitIndex];
    if (habit.isCompletedToday) {
      return HabitCompleteResult(
        wasCompleted: true,
        xpGained: 0,
        restMinutesGained: 0,
        levelsGained: 0,
        newLevel: _level,
        currentStreak: _streak,
      );
    }

    final today = _today();
    final bool isFirstCompletedHabitToday =
        _lastCompletedDate == null || !_isSameDay(_lastCompletedDate!, today);

    if (isFirstCompletedHabitToday) {
      if (_lastCompletedDate == null) {
        _streak = 1;
      } else {
        final daysSinceLastCompletion =
            today.difference(_lastCompletedDate!).inDays;
        if (daysSinceLastCompletion == 1) {
          _streak += 1;
        } else {
          _streak = 1;
        }
      }
    }

    _lastCompletedDate = today;
    _lastOpenedDate = today;
    _habits[habitIndex] = habit.copyWith(isCompletedToday: true);

    _xp += habit.xpReward;
    _restMinutes += habit.restMinutesReward;

    int levelsGained = 0;
    while (_xp >= maxXp) {
      _xp -= maxXp;
      _level++;
      levelsGained++;
    }

    _addLog(
      'Выполнено: ${habit.title}. Получено +${habit.restMinutesReward} мин. отдыха',
    );

    notifyListeners();
    await _saveAll();

    return HabitCompleteResult(
      wasCompleted: false,
      xpGained: habit.xpReward,
      restMinutesGained: habit.restMinutesReward,
      levelsGained: levelsGained,
      newLevel: _level,
      currentStreak: _streak,
    );
  }

  Future<bool> buyItem(String itemId) async {
    final item = getShopItemById(itemId);
    if (item == null) return false;
    if (_restMinutes < item.price) return false;

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
    _habits = _createDefaultHabits();
    _shopItems = _createDefaultShopItems();
    _inventoryItemIds = [];
    _logs = [];
    _lastOpenedDate = _today();
    _lastCompletedDate = null;

    notifyListeners();
    await _saveAll();
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
            icon: Icon(Icons.person_rounded),
            label: 'Персонаж',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_rounded),
            label: 'Магазин',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_rounded),
            label: 'Инвентарь',
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _handleHabitTap(BuildContext context, String habitId) async {
    final controller = context.read<StatsController>();
    final result = await controller.completeHabit(habitId);

    if (!context.mounted || result.wasCompleted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (result.levelsGained > 0) {
      await _showLevelUpDialog(context, result.newLevel);
    }

    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Квест выполнен: +${result.xpGained} XP и +${result.restMinutesGained} мин. отдыха',
        ),
      ),
    );
  }

  Future<void> _confirmResetProgress(BuildContext context) async {
    final controller = context.read<StatsController>();

    final bool? shouldReset = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Сбросить прогресс?'),
          content: const Text(
            'Уровень, опыт, минуты отдыха, серия, инвентарь, история и все выполненные сегодня привычки будут сброшены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
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
        const SnackBar(
          content: Text('Прогресс, инвентарь и история сброшены.'),
        ),
      );
  }

  Future<void> _showLevelUpDialog(BuildContext context, int newLevel) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF7B61FF),
                  Color(0xFFFF7A59),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 24,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 52,
                ),
                const SizedBox(height: 12),
                const Text(
                  'LEVEL UP!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ты поднялся на новый уровень',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: 120,
                  height: 120,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$newLevel',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF5B3FD6),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'В бой!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          : Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFF8FAFF),
                    Color(0xFFF2F7F5),
                  ],
                ),
              ),
              child: SafeArea(
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
                        'Полезные привычки',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E2430),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Закрывай ежедневные квесты и зарабатывай минуты заслуженного отдыха.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.separated(
                          itemCount: controller.habits.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 14),
                          itemBuilder: (context, index) {
                            final habit = controller.habits[index];
                            return HabitCard(
                              habit: habit,
                              onTap: habit.isCompletedToday
                                  ? null
                                  : () => _handleHabitTap(context, habit.id),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
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
                ? 'Куплено: ${item.title} (-${item.price} мин. отдыха)'
                : 'Недостаточно минут отдыха для покупки.',
          ),
        ),
      );
  }

  Widget _buildHeaderCard(StatsController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFC44D),
            Color(0xFFFF8A3D),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22FF9A3C),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.storefront_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Магазин наград',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Трать заработанные минуты отдыха только на то, что реально хочется заслужить.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeaderChip(
                icon: Icons.schedule_rounded,
                label: '${controller.restMinutes} мин. отдыха',
              ),
              _HeaderChip(
                icon: Icons.inventory_2_rounded,
                label: '${controller.inventoryCount} в инвентаре',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShopCard(
    BuildContext context,
    StatsController controller,
    ShopItem item,
  ) {
    final canBuy = controller.restMinutes >= item.price;
    final purchaseCount = controller.getPurchaseCountFor(item.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5D6),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.card_giftcard_rounded,
                    color: Color(0xFFE0A800),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Куплено: $purchaseCount шт.',
                    style: const TextStyle(
                      color: Color(0xFF5B8CFF),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E2430),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.description,
              style: const TextStyle(
                fontSize: 14,
                height: 1.4,
                color: Color(0xFF6B7280),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5D6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.schedule_rounded,
                        color: Color(0xFFE0A800),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${item.price} мин.',
                        style: const TextStyle(
                          color: Color(0xFFE0A800),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: canBuy ? () => _buyItem(context, item) : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: canBuy
                          ? const Color(0xFF5B8CFF)
                          : const Color(0xFFD7DCE5),
                      disabledBackgroundColor: const Color(0xFFD7DCE5),
                      disabledForegroundColor: const Color(0xFF8B93A5),
                    ),
                    child: Text(canBuy ? 'Купить' : 'Не хватает минут'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Магазин наград'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFBF2),
              Color(0xFFF7F9FD),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(controller),
                const SizedBox(height: 20),
                const Text(
                  'Награды',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2430),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Каждая покупка — это отдых, который ты сначала заслужил дисциплиной.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final crossAxisCount = constraints.maxWidth > 700 ? 3 : 2;

                      return GridView.builder(
                        itemCount: controller.shopItems.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          return _buildShopCard(
                            context,
                            controller,
                            controller.shopItems[index],
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
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

  Widget _buildHeaderCard(StatsController controller) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF41C7AF),
            Color(0xFF5B8CFF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2241C7AF),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                color: Colors.white,
                size: 28,
              ),
              SizedBox(width: 10),
              Text(
                'Инвентарь наград',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Здесь лежат купленные награды и история твоего прогресса.',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeaderChip(
                icon: Icons.inventory_rounded,
                label: '${controller.inventoryCount} предметов',
              ),
              _HeaderChip(
                icon: Icons.schedule_rounded,
                label: '${controller.restMinutes} мин. отдыха',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyInventoryState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF1FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(
              Icons.backpack_outlined,
              color: Color(0xFF5B8CFF),
              size: 36,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Инвентарь пока пуст',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E2430),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Покупай награды в магазине, и они появятся здесь.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, ShopItem item, int count) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7EE),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFF21A65B),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E2430),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF1FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'x$count',
                          style: const TextStyle(
                            color: Color(0xFF5B8CFF),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.description,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B7280),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () => _useItem(context, item),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Активировать'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF41C7AF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard(GameLog log, bool isFirst, bool isLast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: isFirst
                    ? const Color(0xFF5B8CFF)
                    : const Color(0xFF9BB4FF),
                shape: BoxShape.circle,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 68,
                color: const Color(0xFFDCE5FF),
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E2430),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _formatLogTime(log.timestamp),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7B8699),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyLogState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: const Text(
        'История пока пуста. Выполняй привычки, покупай награды и здесь появится хроника действий.',
        style: TextStyle(
          fontSize: 14,
          color: Color(0xFF6B7280),
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();

    if (controller.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final ownedItems = controller.shopItems
        .where((item) => controller.getPurchaseCountFor(item.id) > 0)
        .toList(growable: false);

    final double itemsHeight = ownedItems.isEmpty
        ? 0
        : ownedItems.length == 1
            ? 150
            : ownedItems.length == 2
                ? 280
                : 320;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Инвентарь'),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5FFFC),
              Color(0xFFF7F9FD),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(controller),
                const SizedBox(height: 20),
                const Text(
                  'Твои награды',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2430),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Используй только то, что действительно заслужил.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                if (ownedItems.isEmpty)
                  _buildEmptyInventoryState()
                else
                  SizedBox(
                    height: itemsHeight,
                    child: ListView.separated(
                      itemCount: ownedItems.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final item = ownedItems[index];
                        final count = controller.getPurchaseCountFor(item.id);
                        return _buildInventoryCard(context, item, count);
                      },
                    ),
                  ),
                const SizedBox(height: 18),
                const Text(
                  'Хроника игрока',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1E2430),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Все важные действия записываются в твою историю.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: controller.logs.isEmpty
                      ? _buildEmptyLogState()
                      : ListView.builder(
                          itemCount: controller.logs.length,
                          itemBuilder: (context, index) {
                            final log = controller.logs[index];
                            return _buildLogCard(
                              log,
                              index == 0,
                              index == controller.logs.length - 1,
                            );
                          },
                        ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF5B8CFF),
            Color(0xFF7B61FF),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x225B8CFF),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.shield_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Текущий уровень',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Level $level',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeaderChip(
                icon: Icons.local_fire_department_rounded,
                label: '$streak серия',
              ),
              _HeaderChip(
                icon: Icons.schedule_rounded,
                label: '$restMinutes мин. отдыха',
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Опыт',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '$xp/$maxXp XP',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 350),
              builder: (context, value, _) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: Colors.white.withOpacity(0.22),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                );
              },
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
    required this.onTap,
  });

  final Habit habit;
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

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = habit.isCompletedToday;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: isCompleted ? 0.78 : 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x11000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: isCompleted ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFFE8F7EE)
                          : const Color(0xFFEAF1FF),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _iconForHabit(habit.iconType),
                      color: isCompleted
                          ? const Color(0xFF21A65B)
                          : const Color(0xFF5B8CFF),
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
                            color: Color(0xFF1E2430),
                          ),
                        ),
                        const SizedBox(height: 8),
                        isCompleted
                            ? const Text(
                                'Выполнено сегодня',
                                style: TextStyle(
                                  color: Color(0xFF21A65B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              )
                            : Wrap(
                                spacing: 10,
                                runSpacing: 8,
                                children: [
                                  _RewardChip(
                                    icon: Icons.bolt_rounded,
                                    iconColor: const Color(0xFF5B8CFF),
                                    backgroundColor: const Color(0xFFEAF1FF),
                                    label: '+${habit.xpReward} XP',
                                  ),
                                  _RewardChip(
                                    icon: Icons.schedule_rounded,
                                    iconColor: const Color(0xFF1AA67D),
                                    backgroundColor: const Color(0xFFE8F7EE),
                                    label: '+${habit.restMinutesReward} мин.',
                                  ),
                                ],
                              ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: isCompleted
                        ? Container(
                            key: const ValueKey('completed'),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F7EE),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF21A65B),
                            ),
                          )
                        : Container(
                            key: const ValueKey('available'),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F7FF),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF5B8CFF),
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: iconColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
