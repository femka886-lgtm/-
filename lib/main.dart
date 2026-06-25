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

enum HabitIconType { water, sport, book }

class Habit {
  final String id;
  final String title;
  final int xpReward;
  final int restMinutesReward;
  final bool isCompletedToday;

  const Habit({
    required this.id,
    required this.title,
    required this.xpReward,
    required this.restMinutesReward,
    this.isCompletedToday = false,
  });

  Habit copyWith({bool? isCompletedToday}) {
    return Habit(
      id: id,
      title: title,
      xpReward: xpReward,
      restMinutesReward: restMinutesReward,
      isCompletedToday: isCompletedToday ?? this.isCompletedToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'xpReward': xpReward,
        'restMinutesReward': restMinutesReward,
        'isCompletedToday': isCompletedToday,
      };

  factory Habit.fromJson(Map<String, dynamic> json) => Habit(
        id: json['id'] as String,
        title: json['title'] as String,
        xpReward: json['xpReward'] as int,
        restMinutesReward: json['restMinutesReward'] as int,
        isCompletedToday: json['isCompletedToday'] as bool? ?? false,
      );
}

class ShopItem {
  final String id;
  final String title;
  final String description;
  final int price;
  final IconData icon;

  const ShopItem({
    required this.id,
    required this.title,
    required this.description,
    required this.price,
    required this.icon,
  });
}

class GameLog {
  final String message;
  final DateTime timestamp;

  const GameLog({required this.message, required this.timestamp});

  Map<String, dynamic> toJson() => {
        'message': message,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GameLog.fromJson(Map<String, dynamic> json) => GameLog(
        message: json['message'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class StatsController extends ChangeNotifier {
  int _level = 1;
  int _xp = 0;
  int _restMinutes = 0;
  List<Habit> _habits = [];
  final List<String> _inventory = [];
  final List<GameLog> _logs = [];

  int get level => _level;
  int get xp => _xp;
  int get restMinutes => _restMinutes;
  List<Habit> get habits => _habits;
  List<String> get inventory => _inventory;
  List<GameLog> get logs => _logs.reversed.toList();

  int get xpToNextLevel => _level * 100;

  final List<ShopItem> shopItems = const [
    ShopItem(
      id: 'series',
      title: 'Серия сериала',
      description: 'Позволяет посмотреть одну серию любимого шоу без чувства вины.',
      price: 30,
      icon: Icons.tv,
    ),
    ShopItem(
      id: 'snack',
      title: 'Вкусняшка',
      description: 'Читмил! Купи себе что-то сладкое или вредное.',
      price: 45,
      icon: Icons.cookie,
    ),
    ShopItem(
      id: 'gaming',
      title: 'Час видеоигр',
      description: 'Один час чистой игровой сессии на ПК или консоли.',
      price: 60,
      icon: Icons.sports_esports,
    ),
  ];

  StatsController() {
    _initDefaultHabits();
  }

  void _initDefaultHabits() {
    _habits = const [
      Habit(id: '1', title: 'Выпить стакан воды', xpReward: 10, restMinutesReward: 5),
      Habit(id: '2', title: 'Сделать зарядку', xpReward: 25, restMinutesReward: 15),
      Habit(id: '3', title: 'Почитать книгу 20 мин', xpReward: 40, restMinutesReward: 25),
    ];
  }

  void toggleHabit(String id) {
    final index = _habits.indexWhere((h) => h.id == id);
    if (index == -index - 1) return;

    final habit = _habits[index];
    final newVal = !habit.isCompletedToday;
    _habits[index] = habit.copyWith(isCompletedToday: newVal);

    if (newVal) {
      _addXp(habit.xpReward);
      _restMinutes += habit.restMinutesReward;
      _addLog('Выполнена привычка: "${habit.title}" (+${habit.restMinutesReward} мин. отдыха)');
    } else {
      _xp = (_xp - habit.xpReward).clamp(0, double.infinity).toInt();
      _restMinutes = (_restMinutes - habit.restMinutesReward).clamp(0, double.infinity).toInt();
      _addLog('Отменено выполнение: "${habit.title}"');
    }

    _saveProgress();
    notifyListeners();
  }

  void _addXp(int amount) {
    _xp += amount;
    while (_xp >= xpToNextLevel) {
      _xp -= xpToNextLevel;
      _level++;
      _addLog('🎉 УРОВЕНЬ ПОВЫШЕН! Вы достигли $_level уровня!');
    }
  }

  Future<bool> buyItem(String id) async {
    final item = shopItems.firstWhere((i) => i.id == id);
    if (_restMinutes < item.price) return false;

    _restMinutes -= item.price;
    _inventory.add(item.id);
    _addLog('🛒 Куплено в магазине: ${item.title} (-${item.price} мин.)');
    
    await _saveProgress();
    notifyListeners();
    return true;
  }

  void useItem(String itemId) {
    if (_inventory.contains(itemId)) {
      _inventory.remove(itemId);
      final item = shopItems.firstWhere((i) => i.id == itemId);
      _addLog('🚀 Использовано: ${item.title}. Время отдыха пошло!');
      _saveProgress();
      notifyListeners();
    }
  }

  void resetProgress() {
    _level = 1;
    _xp = 0;
    _restMinutes = 0;
    _inventory.clear();
    _initDefaultHabits();
    _logs.clear();
    _addLog('🔄 Прогресс полностью сброшен.');
    _saveProgress();
    notifyListeners();
  }

  void _addLog(String msg) {
    _logs.add(GameLog(message: msg, timestamp: DateTime.now()));
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('level', _level);
    await prefs.setInt('xp', _xp);
    await prefs.setInt('restMinutes', _restMinutes);
    await prefs.setStringList('inventory', _inventory);

    final habitsJson = _habits.map((h) => h.toJson()).toList();
    await prefs.setString('habits', jsonEncode(habitsJson));

    final logsJson = _logs.map((l) => l.toJson()).toList();
    await prefs.setString('logs', jsonEncode(logsJson));
  }

  Future<void> loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _level = prefs.getInt('level') ?? 1;
    _xp = prefs.getInt('xp') ?? 0;
    _restMinutes = prefs.getInt('restMinutes') ?? 0;
    
    final savedInv = prefs.getStringList('inventory');
    if (savedInv != null) {
      _inventory.clear();
      _inventory.addAll(savedInv);
    }

    final habitsStr = prefs.getString('habits');
    if (habitsStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(habitsStr);
        _habits = decoded.map((item) => Habit.fromJson(item as Map<String, dynamic>)).toList();
      } catch (_) {
        _initDefaultHabits();
      }
    }

    final logsStr = prefs.getString('logs');
    if (logsStr != null) {
      try {
        final List<dynamic> decoded = jsonDecode(logsStr);
        _logs.clear();
        _logs.addAll(decoded.map((item) => GameLog.fromJson(item as Map<String, dynamic>)));
      } catch (_) {}
    }
    notifyListeners();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});
  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onTap(int index) {
    _pageController.animateToPage(
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
        onPageChanged: _onPageChanged,
        children: const [
          HomeScreen(),
          ShopScreen(),
          InventoryScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTap,
        selectedItemColor: const Color(0xFF5B8CFF),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Герой'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_bag), label: 'Магазин'),
          BottomNavigationBarItem(icon: Icon(Icons.backpack), label: 'Инвентарь'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мой Герой', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Сбросить прогресс?'),
                  content: const Text('Это удалит ваш уровень, минуты отдыха и инвентарь.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
                    TextButton(
                      onPressed: () {
                        context.read<StatsController>().resetProgress();
                        Navigator.pop(context);
                      },
                      child: const Text('Сбросить', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProfileCard(controller),
          const SizedBox(height: 24),
          const Text('Ежедневные Привычки', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...controller.habits.map((habit) => _buildHabitCard(context, controller, habit)),
        ],
      ),
    );
  }

  Widget _buildProfileCard(StatsController controller) {
    final progress = controller.xp / controller.xpToNextLevel;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(color: Color(0xFFE8EFFF), shape: BoxShape.circle),
                child: const Icon(Icons.shield, color: Color(0xFF5B8CFF), size: 32),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Уровень ${controller.level}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${controller.xp} / ${controller.xpToNextLevel} XP', style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: Colors.grey[200], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5B8CFF))),
          ),
          const Divider(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(Icons.hourglass_top, '${controller.restMinutes} мин', 'Отдых'),
              _buildStatItem(Icons.done_all, '${controller.habits.where((h) => h.isCompletedToday).length}', 'Сделано'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF5B8CFF)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildHabitCard(BuildContext context, StatsController controller, Habit habit) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 0,
      color: habit.isCompletedToday ? const Color(0xFFE8EFFF) : Colors.white,
      child: ListTile(
        leading: Icon(
          habit.isCompletedToday ? Icons.check_circle : Icons.radio_button_unchecked,
          color: const Color(0xFF5B8CFF),
        ),
        title: Text(habit.title, style: TextStyle(decoration: habit.isCompletedToday ? TextDecoration.lineThrough : null, fontWeight: FontWeight.w600)),
        subtitle: Text('+${habit.xpReward} XP  |  +${habit.restMinutesReward} мин'),
        onTap: () => controller.toggleHabit(habit.id),
      ),
    );
  }
}

class ShopScreen extends StatelessWidget {
  const ShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();
    return Scaffold(
      appBar: AppBar(title: const Text('Магазин Наград', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFFFAEB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFEAA7))),
            child: Row(
              children: [
                const Icon(Icons.hourglass_bottom, color: Color(0xFFE67E22)),
                const SizedBox(width: 12),
                Text('Доступно для трат: ${controller.restMinutes} минут', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFFD35400))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ...controller.shopItems.map((item) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFFFFFAEB), child: Icon(item.icon, color: const Color(0xFFE67E22))),
                    title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${item.description}\nЦена: ${item.price} мин.'),
                    isThreeLine: true,
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5B8CFF), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      onPressed: controller.restMinutes >= item.price
                          ? () async {
                              final success = await controller.buyItem(item.id);
                              if (success && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Куплено: ${item.title}')));
                              }
                            }
                          : null,
                      child: const Text('Купить'),
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<StatsController>();
    
    final Map<String, int> counts = {};
    for (var id in controller.inventory) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    final uniqueIds = counts.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Инвентарь и Логи', style: TextStyle(fontWeight: FontWeight.bold))),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ваши Награды', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (uniqueIds.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('Инвентарь пуст. Купите что-нибудь в магазине!')))
            else
              SizedBox(
                height: 110,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: uniqueIds.length,
                  itemBuilder: (context, index) {
                    final id = uniqueIds[index];
                    final count = counts[id]!;
                    final item = controller.shopItems.firstWhere((i) => i.id == id);
                    return Card(
                      margin: const EdgeInsets.only(right: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Badge(
                              label: Text('$count'),
                              child: Icon(item.icon, color: const Color(0xFF5B8CFF), size: 28),
                            ),
                            const SizedBox(height: 4),
                            Text(item.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: 26,
                              child: TextButton(
                                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                                onPressed: () => controller.useItem(id),
                                child: const Text('Юзнуть', style: TextStyle(fontSize: 11)),
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 24),
            const Text('История событий', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: controller.logs.isEmpty
                  ? const Center(child: Text('История пуста.'))
                  : ListView.builder(
                      itemCount: controller.logs.length,
                      itemBuilder: (context, index) {
                        final log = controller.logs[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.history_toggle_off, size: 20, color: Colors.grey),
                          title: Text(log.message, style: const TextStyle(fontSize: 13)),
                          subtitle: Text('${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(fontSize: 11)),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
