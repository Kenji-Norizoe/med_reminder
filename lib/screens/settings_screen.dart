import 'package:flutter/material.dart';
import '../utils/time_utils.dart';
import '../services/database_helper.dart';
import 'home_screen.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  final bool isFirstSetup;

  const SettingsScreen({super.key, this.isFirstSetup = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 各時刻の初期値
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 30);
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 7, minute: 30);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 0);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 18, minute: 30);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 30);

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTimes();
  }

  // 保存済みの時刻を読み込む
  Future<void> _loadSavedTimes() async {
    final times = await LifeTimePrefs.load();
    setState(() {
      _wakeTime = _parseTime(times[PrefKeys.wakeTime]!);
      _breakfastTime = _parseTime(times[PrefKeys.breakfastTime]!);
      _lunchTime = _parseTime(times[PrefKeys.lunchTime]!);
      _dinnerTime = _parseTime(times[PrefKeys.dinnerTime]!);
      _sleepTime = _parseTime(times[PrefKeys.sleepTime]!);
    });
  }

  // "HH:mm" → TimeOfDay
  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 0,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  // TimeOfDay → "HH:mm"
  String _formatTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  // 時刻ピッカーを開いて選択結果を反映する
  Future<void> _pickTime(
    BuildContext context,
    TimeOfDay current,
    ValueChanged<TimeOfDay> onPicked,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        // 時刻ピッカーのフォントも大きめに
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            alwaysUse24HourFormat: true,
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

// 保存処理
Future<void> _save() async {
  print('_save called');

 await LifeTimePrefs.save(
  wakeTime: _formatTime(_wakeTime),
  breakfastTime: _formatTime(_breakfastTime),
  lunchTime: _formatTime(_lunchTime),
  dinnerTime: _formatTime(_dinnerTime),
  sleepTime: _formatTime(_sleepTime),
);

print('prefs saved');

final now = DateTime.now().add(const Duration(minutes: 3));

print('before scheduleDailyNotification');

try {
  await NotificationService.instance.scheduleDailyNotification(
    id: 999,
    title: 'テスト通知',
    body: '3分後に通知されます',
    hour: now.hour,
    minute: now.minute,
  );
  print('after scheduleDailyNotification');
} catch (e) {
  print('scheduleDailyNotification error: $e');
}

  final medicines = await DatabaseHelper.instance.getActiveMedicines();
  final lifeTimes = await LifeTimePrefs.load();

  for (final medicine in medicines) {
    if (medicine.endDate != null) {
    }
  }

  if (!mounted) return;
  setState(() => _isSaving = false);

  if (widget.isFirstSetup) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
      (route) => false,
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('設定を保存しました', style: TextStyle(fontSize: 16)),
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isFirstSetup ? '最初の設定' : '生活時刻の設定'),
        // 初回設定時は戻るボタンを非表示
        automaticallyImplyLeading: !widget.isFirstSetup,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isFirstSetup) ...[
              const Text(
                'あなたの生活時刻を教えてください。\n薬の通知時刻に使います。',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 24),
            ],

            // 各時刻の設定行
            _buildTimeRow(
              icon: Icons.wb_sunny_outlined,
              label: '起床時刻',
              time: _wakeTime,
              onTap: () => _pickTime(
                context,
                _wakeTime,
                (t) => setState(() => _wakeTime = t),
              ),
            ),
            _buildDivider(),
            _buildTimeRow(
              icon: Icons.free_breakfast_outlined,
              label: '朝食時刻',
              time: _breakfastTime,
              onTap: () => _pickTime(
                context,
                _breakfastTime,
                (t) => setState(() => _breakfastTime = t),
              ),
            ),
            _buildDivider(),
            _buildTimeRow(
              icon: Icons.lunch_dining_outlined,
              label: '昼食時刻',
              time: _lunchTime,
              onTap: () => _pickTime(
                context,
                _lunchTime,
                (t) => setState(() => _lunchTime = t),
              ),
            ),
            _buildDivider(),
            _buildTimeRow(
              icon: Icons.dinner_dining_outlined,
              label: '夕食時刻',
              time: _dinnerTime,
              onTap: () => _pickTime(
                context,
                _dinnerTime,
                (t) => setState(() => _dinnerTime = t),
              ),
            ),
            _buildDivider(),
            _buildTimeRow(
              icon: Icons.bedtime_outlined,
              label: '就寝時刻',
              time: _sleepTime,
              onTap: () => _pickTime(
                context,
                _sleepTime,
                (t) => setState(() => _sleepTime = t),
              ),
            ),

            const SizedBox(height: 16),

            // 通知時刻のプレビュー
            _buildNoticePreview(),

            const SizedBox(height: 32),

            // 保存ボタン
            ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(widget.isFirstSetup ? 'この時刻で始める' : '保存する'),
            ),

            const SizedBox(height: 16),

            // 注意書き
            const Text(
              '※ アンインストールするとデータはすべて消えます。',
              style: TextStyle(fontSize: 13, color: Colors.black45),
            ),
          ],
        ),
      ),
    );
  }

  // 時刻設定行のウィジェット
  Widget _buildTimeRow({
    required IconData icon,
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 28, color: const Color(0xFF2E7D9F)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              _formatTime(time),
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D9F),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, color: Colors.black12);
  }

  // 通知時刻のプレビュー表示
  Widget _buildNoticePreview() {
    final lifeTimes = {
      PrefKeys.wakeTime: _formatTime(_wakeTime),
      PrefKeys.breakfastTime: _formatTime(_breakfastTime),
      PrefKeys.lunchTime: _formatTime(_lunchTime),
      PrefKeys.dinnerTime: _formatTime(_dinnerTime),
      PrefKeys.sleepTime: _formatTime(_sleepTime),
    };

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '通知が来る時刻（目安）',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          ...Timing.all.map((timing) {
            final notifyTime = calcNotifyTime(timing, lifeTimes);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      Timing.label(timing),
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Text(
                    notifyTime,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D9F),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}