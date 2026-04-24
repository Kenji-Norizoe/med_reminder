import 'package:flutter/material.dart';
import '../models/medicine.dart';
import '../models/dose_log.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../utils/time_utils.dart';
import 'medicine_list_screen.dart';
import 'medicine_form_screen.dart';
import 'settings_screen.dart';
import 'ending_soon_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Medicine> _todayMedicines = [];
  List<Medicine> _endingSoonMedicines = [];
  Map<String, DoseLog?> _doseLogMap = {};
  int _takenCount = 0;
  bool _isLoading = true;
  final String _today = todayString();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final todayMeds = await DatabaseHelper.instance.getTodayMedicines();
    final endingSoon = await DatabaseHelper.instance.getEndingSoonMedicines();
    final takenCount =
        await DatabaseHelper.instance.getTakenCountByDate(_today);

    final logs = await DatabaseHelper.instance.getDoseLogsByDate(_today);
    final logMap = <String, DoseLog?>{};
    for (final med in todayMeds) {
      for (final timing in med.timings) {
        final key = '${med.id}_$timing';
        try {
          logMap[key] = logs.firstWhere(
            (l) => l.medicineId == med.id && l.timing == timing,
          );
        } catch (_) {
          logMap[key] = null;
        }
      }
    }

    setState(() {
      _todayMedicines = todayMeds;
      _endingSoonMedicines = endingSoon;
      _doseLogMap = logMap;
      _takenCount = takenCount;
      _isLoading = false;
    });
  }

  Future<void> _markTaken(Medicine medicine, String timing) async {
    final lifeTimes = await LifeTimePrefs.load();
    final scheduledTime = calcNotifyTime(timing, lifeTimes);

    final log = DoseLog(
      medicineId: medicine.id!,
      date: _today,
      timing: timing,
      scheduledTime: scheduledTime,
      status: DoseStatus.taken,
      actionTime: dateTimeToTimeString(DateTime.now()),
    );
    await DatabaseHelper.instance.insertOrUpdateDoseLog(log);
    await _loadData();
  }

  Future<void> _markSkipped(Medicine medicine, String timing) async {
    final lifeTimes = await LifeTimePrefs.load();
    final scheduledTime = calcNotifyTime(timing, lifeTimes);

    final log = DoseLog(
      medicineId: medicine.id!,
      date: _today,
      timing: timing,
      scheduledTime: scheduledTime,
      status: DoseStatus.skipped,
      actionTime: dateTimeToTimeString(DateTime.now()),
    );
    await DatabaseHelper.instance.insertOrUpdateDoseLog(log);
    await _loadData();
  }

  Future<void> _showSnoozeDialog(Medicine medicine, String timing) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          'あとで通知する',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${medicine.displayName}（${Timing.label(timing)}）\nあと何分後に通知しますか？',
          style: const TextStyle(fontSize: 17),
        ),
actionsPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
actions: [
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () async {
        Navigator.of(ctx).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('30分後スヌーズは後で実装します'),
          ),
        );
      },
      child: const Text('30分後'),
    ),
  ),
  const SizedBox(height: 8),
  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: () async {
        Navigator.of(ctx).pop();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('60分後スヌーズは後で実装します'),
          ),
        );
      },
      child: const Text('60分後'),
    ),
  ),
  const SizedBox(height: 4),
  SizedBox(
    width: double.infinity,
    child: OutlinedButton(
      onPressed: () => Navigator.of(ctx).pop(),
      child: const Text('キャンセル'),
    ),
  ),
],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('服薬リマインダー'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '設定',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
              _loadData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_endingSoonMedicines.isNotEmpty)
                      _buildEndingSoonBanner(),
                    _buildTodaySummary(),
                    const SizedBox(height: 20),
                    const Text(
                      '今日の薬',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_todayMedicines.isEmpty)
                      _buildEmptyToday()
                    else
                      ..._buildTodayMedicineCards(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildEndingSoonBanner() {
    return GestureDetector(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const EndingSoonScreen()),
        );
        _loadData();
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.shade300, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'もうすぐなくなる薬が${_endingSoonMedicines.length}件あります',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.orange.shade700),
          ],
        ),
      ),
    );
  }

  Widget _buildTodaySummary() {
    int totalCount = 0;
    for (final med in _todayMedicines) {
      totalCount += med.timings.length;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2E7D9F),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('今日の薬', '$totalCount 件', Icons.medication),
          _buildSummaryDivider(),
          _buildSummaryItem('飲んだ', '$_takenCount 件', Icons.check_circle),
          _buildSummaryDivider(),
          _buildSummaryItem(
            '残り',
            '${totalCount - _takenCount} 件',
            Icons.pending,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Colors.white70),
        ),
      ],
    );
  }

  Widget _buildSummaryDivider() {
    return Container(
      height: 50,
      width: 1,
      color: Colors.white30,
    );
  }

  List<Widget> _buildTodayMedicineCards() {
    final widgets = <Widget>[];
    for (final med in _todayMedicines) {
      for (final timing in med.timings) {
        final key = '${med.id}_$timing';
        final log = _doseLogMap[key];
        widgets.add(_buildDoseCard(med, timing, log));
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Widget _buildDoseCard(Medicine medicine, String timing, DoseLog? log) {
    final isTaken = log?.status == DoseStatus.taken;
    final isSkipped = log?.status == DoseStatus.skipped;
    final isDone = isTaken || isSkipped;

    return Container(
      decoration: BoxDecoration(
        color: isDone ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTaken
              ? Colors.green.shade300
              : isSkipped
                  ? Colors.grey.shade300
                  : Colors.blue.shade200,
          width: 1.5,
        ),
        boxShadow: isDone
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.grey.shade300
                        : const Color(0xFF2E7D9F),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    Timing.label(timing),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDone ? Colors.grey.shade600 : Colors.white,
                    ),
                  ),
                ),
                const Spacer(),
                if (isTaken)
                  Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.green, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        '飲んだ',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else if (isSkipped)
                  Row(
                    children: [
                      Icon(Icons.skip_next,
                          color: Colors.grey.shade500, size: 20),
                      const SizedBox(width: 4),
                      Text(
                        'スキップ',
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              medicine.displayName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDone ? Colors.grey.shade500 : Colors.black87,
              ),
            ),
            if (medicine.memo != null && medicine.memo!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                medicine.memo!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            if (!isDone) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: ElevatedButton.icon(
                      onPressed: () => _markTaken(medicine, timing),
                      icon: const Icon(Icons.check, size: 20),
                      label: const Text('飲んだ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _showSnoozeDialog(medicine, timing),
                      icon: const Icon(Icons.alarm, size: 18),
                      label: const Text('あとで'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: OutlinedButton.icon(
                      onPressed: () => _markSkipped(medicine, timing),
                      icon: const Icon(Icons.skip_next, size: 18),
                      label: const Text('スキップ'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 50),
                        foregroundColor: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyToday() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.medication_outlined,
              size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            '今日飲む薬はありません',
            style: TextStyle(fontSize: 17, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '下の「薬を追加する」から登録してください',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MedicineFormScreen()),
            );
            _loadData();
          },
          icon: const Icon(Icons.add, size: 24),
          label: const Text('薬を追加する'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
            textStyle: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 12),ElevatedButton(
  onPressed: () async {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('通知テストボタンが押されました'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await NotificationService.instance.showTestNotification();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('通知処理を実行しました'),
          duration: Duration(seconds: 1),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('通知エラー: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  },
  child: const Text('通知テスト'),
),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MedicineListScreen()),
            );
            _loadData();
          },
          icon: const Icon(Icons.list, size: 24),
          label: const Text('登録中の薬一覧'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }
}