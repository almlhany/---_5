// ========================================================
// تطبيق ساعة التنبيه الذكية بلغة Flutter (Material 3)
// Al-Tanbeeh Flutter Smart Alarm Clock
// حزمة التطبيق: com.almlhany.smartalarm
// ========================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:async';
import 'dart:convert';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
      ],
      child: const AlTanbeehApp(),
    ),
  );
}

// --------------------------------------------------------
// 1. التطبيق الرئيسي (Material 3 + الوضع المظلم + العربية)
// --------------------------------------------------------
class AlTanbeehApp extends StatelessWidget {
  const AlTanbeehApp({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AlarmProvider>(context);

    return MaterialApp(
      title: 'ساعة التنبيه الذكية',
      debugShowCheckedModeBanner: false,
      themeMode: provider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      // الوضع الفاتح
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      // الوضع المظلم الليلي المريح للعين
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF0B0F19), // كحلي داكن OLED
        cardTheme: CardTheme(
          color: const Color(0xFF131B2E),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
      home: const Directionality(
        textDirection: TextDirection.rtl, // واجهة عربية أصيلة
        child: MainNavigationScreen(),
      ),
    );
  }
}

// --------------------------------------------------------
// 2. نموذج بيانات المنبه (Alarm Model)
// --------------------------------------------------------
class AlarmModel {
  final String id;
  TimeOfDay time;
  String label;
  bool isEnabled;
  List<int> repeatDays; // 0=الأحد, 1=الاثنين, 2=الثلاثاء, 3=الأربعاء, 4=الخميس, 5=الجمعة, 6=السبت
  String soundName;
  bool gradualVolume;
  bool autoSnooze;
  int snoozeMinutes;
  int maxSnoozeCount;
  String wakeChallenge; // 'none', 'math', 'tap'

  AlarmModel({
    required this.id,
    required this.time,
    this.label = 'منبه جديد',
    this.isEnabled = true,
    required this.repeatDays,
    this.soundName = 'gentle_dawn',
    this.gradualVolume = true,
    this.autoSnooze = true,
    this.snoozeMinutes = 10,
    this.maxSnoozeCount = 3,
    this.wakeChallenge = 'none',
  });

  String get formattedTime {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'ص' : 'م';
    return '$hour:$minute $period';
  }

  String get repeatSummary {
    if (repeatDays.length == 7) return 'تكرار يومياً';
    if (repeatDays.isEmpty) return 'مرة واحدة فقط';
    if (repeatDays.length == 5 && !repeatDays.contains(5) && !repeatDays.contains(6)) {
      return 'أيام العمل (الأحد - الخميس)';
    }
    const days = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
    return repeatDays.map((d) => days[d]).join(' · ');
  }
}

// --------------------------------------------------------
// 3. مزود الحالة (Alarm Provider)
// --------------------------------------------------------
class AlarmProvider extends ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  final AudioPlayer _audioPlayer = AudioPlayer();
  final List<AlarmModel> _alarms = [
    AlarmModel(
      id: '1',
      time: const TimeOfDay(hour: 5, minute: 0),
      label: 'صلاة الفجر وبداية البركة',
      isEnabled: true,
      repeatDays: [0, 1, 2, 3, 4, 5, 6],
      soundName: 'شروق هادئ',
      gradualVolume: true,
      autoSnooze: true,
      snoozeMinutes: 10,
    ),
    AlarmModel(
      id: '2',
      time: const TimeOfDay(hour: 7, minute: 30),
      label: 'الاستعداد للعمل والجامعة',
      isEnabled: true,
      repeatDays: [0, 1, 2, 3, 4],
      soundName: 'نبضات حيوية',
      gradualVolume: true,
      autoSnooze: true,
      snoozeMinutes: 5,
    ),
    AlarmModel(
      id: '3',
      time: const TimeOfDay(hour: 17, minute: 45),
      label: 'التمارين الرياضية والصحة',
      isEnabled: false,
      repeatDays: [0, 2, 4],
      soundName: 'ماريمبا الصباح',
      gradualVolume: false,
      autoSnooze: false,
    ),
  ];

  List<AlarmModel> get alarms => _alarms;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleAlarm(String id) {
    final index = _alarms.indexWhere((a) => a.id == id);
    if (index != -1) {
      _alarms[index].isEnabled = !_alarms[index].isEnabled;
      notifyListeners();
    }
  }

  void addAlarm(AlarmModel alarm) {
    _alarms.add(alarm);
    _alarms.sort((a, b) => (a.time.hour * 60 + a.time.minute).compareTo(b.time.hour * 60 + b.time.minute));
    notifyListeners();
  }

  void updateAlarm(AlarmModel alarm) {
    final index = _alarms.indexWhere((a) => a.id == alarm.id);
    if (index != -1) {
      _alarms[index] = alarm;
      notifyListeners();
    }
  }

  void deleteAlarm(String id) {
    _alarms.removeWhere((a) => a.id == id);
    notifyListeners();
  }

  void playRingtone() async {
    // تشغيل نغمة المنبه مع التكرار
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.play(AssetSource('sounds/alarm.mp3'));
    } catch (_) {}
  }

  void stopRingtone() async {
    await _audioPlayer.stop();
  }
}

// --------------------------------------------------------
// 4. الشاشة الرئيسية مع شريط التنقل السفلي (Material 3)
// --------------------------------------------------------
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    AlarmListScreen(),
    BedtimeCalculatorScreen(),
    TimerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AlarmProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.indigoAccent),
            SizedBox(width: 8),
            Text('ساعة التنبيه الذكية', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(provider.isDarkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'تغيير الوضع المظلم / الفاتح',
            onPressed: provider.toggleTheme,
          ),
        ],
      ),
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.alarm_outlined),
            selectedIcon: Icon(Icons.alarm, color: Colors.indigoAccent),
            label: 'المنبهات',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime, color: Colors.indigoAccent),
            label: 'ساعة النوم',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer, color: Colors.indigoAccent),
            label: 'المؤقت',
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddAlarmDialog(context),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('منبه جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _openAddAlarmDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardTheme.color,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => const Directionality(
        textDirection: TextDirection.rtl,
        child: AddAlarmBottomSheet(),
      ),
    );
  }
}

// --------------------------------------------------------
// 5. شاشة قائمة المنبهات (Alarm List Screen)
// --------------------------------------------------------
class AlarmListScreen extends StatelessWidget {
  const AlarmListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AlarmProvider>(context);

    if (provider.alarms.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_off, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('لا توجد منبهات مضافة بعد', style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: provider.alarms.length,
      itemBuilder: (context, index) {
        final alarm = provider.alarms[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.formattedTime,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: alarm.isEnabled
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${alarm.label} · ${alarm.repeatSummary}',
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                      if (alarm.autoSnooze)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'غفوة تلقائية كل ${alarm.snoozeMinutes} دقيقة',
                            style: const TextStyle(fontSize: 11, color: Colors.indigoAccent),
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.notifications_active_outlined),
                  tooltip: 'تجربة رنين المنبه',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlarmRingScreen(alarm: alarm),
                      ),
                    );
                  },
                ),
                Switch(
                  value: alarm.isEnabled,
                  activeColor: Colors.indigoAccent,
                  onChanged: (_) => provider.toggleAlarm(alarm.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------
// 6. شاشة الرنين والغفوة التلقائية (Alarm Ring Screen)
// --------------------------------------------------------
class AlarmRingScreen extends StatefulWidget {
  final AlarmModel alarm;
  const AlarmRingScreen({super.key, required this.alarm});

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen> {
  int _secondsLeft = 120; // دقيقتان للغفوة التلقائية
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    Provider.of<AlarmProvider>(context, listen: false).playRingtone();
    if (widget.alarm.autoSnooze) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_secondsLeft <= 1) {
          timer.cancel();
          _snooze();
        } else {
          setState(() => _secondsLeft--);
        }
      });
    }
  }

  void _snooze() {
    _timer?.cancel();
    Provider.of<AlarmProvider>(context, listen: false).stopRingtone();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تفعيل الغفوة لمدة ${widget.alarm.snoozeMinutes} دقائق')),
    );
  }

  void _dismiss() {
    _timer?.cancel();
    Provider.of<AlarmProvider>(context, listen: false).stopRingtone();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.alarm_on, size: 80, color: Colors.indigoAccent),
              const SizedBox(height: 20),
              Text(
                widget.alarm.formattedTime,
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                widget.alarm.label,
                style: const TextStyle(fontSize: 20, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              if (widget.alarm.autoSnooze)
                Text(
                  'غفوة تلقائية متبقية: ${_secondsLeft ~/ 60}:${(_secondsLeft % 60).toString().padLeft(2, '0')}',
                  style: const TextStyle(color: Colors.amber, fontSize: 13),
                ),
              const SizedBox(height: 48),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _snooze,
                      child: Text('غفوة (${widget.alarm.snoozeMinutes} د)'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _dismiss,
                      child: const Text('إيقاف المنبه'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------
// 7. نافذة إضافة وتعديل المنبه (Add Alarm Bottom Sheet)
// --------------------------------------------------------
class AddAlarmBottomSheet extends StatefulWidget {
  const AddAlarmBottomSheet({super.key});

  @override
  State<AddAlarmBottomSheet> createState() => _AddAlarmBottomSheetState();
}

class _AddAlarmBottomSheetState extends State<AddAlarmBottomSheet> {
  TimeOfDay _selectedTime = const TimeOfDay(hour: 7, minute: 0);
  final TextEditingController _labelController = TextEditingController(text: 'منبه الصباح');
  final List<int> _selectedDays = [0, 1, 2, 3, 4, 5, 6];
  bool _autoSnooze = true;
  int _snoozeMinutes = 10;
  bool _gradualVolume = true;

  final List<String> _dayNames = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إضافة منبه جديد', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const SizedBox(height: 12),
          // منتقي الوقت
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(context: context, initialTime: _selectedTime);
              if (picked != null) setState(() => _selectedTime = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFF0B0F19)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, letterSpacing: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _labelController,
            decoration: InputDecoration(
              labelText: 'تسمية المنبه',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('خاصية التكرار اليومي:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (idx) {
              final isSelected = _selectedDays.contains(idx);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _selectedDays.remove(idx);
                    } else {
                      _selectedDays.add(idx);
                    }
                  });
                },
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: isSelected ? Colors.indigoAccent : Colors.grey.shade800,
                  foregroundColor: Colors.white,
                  child: Text(_dayNames[idx]),
                ),
              );
            }),
          ),
          const SizedBox(h