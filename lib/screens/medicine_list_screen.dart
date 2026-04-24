import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../utils/time_utils.dart';
import 'medicine_form_screen.dart';

class MedicineListScreen extends StatefulWidget {
  const MedicineListScreen({super.key});

  @override
  State<MedicineListScreen> createState() => _MedicineListScreenState();
}

class _MedicineListScreenState extends State<MedicineListScreen> {
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    final medicines = await DatabaseHelper.instance.getActiveMedicines();
    setState(() {
      _medicines = medicines;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('登録中の薬一覧'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _medicines.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadMedicines,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _medicines.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      return _buildMedicineCard(_medicines[index]);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const MedicineFormScreen(),
            ),
          );
          _loadMedicines();
        },
        icon: const Icon(Icons.add),
        label: const Text(
          '薬を追加',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF2E7D9F),
        foregroundColor: Colors.white,
      ),
    );
  }

  // 薬カード
  Widget _buildMedicineCard(Medicine medicine) {
    final today = todayString();
    final isActive = medicine.endDate == null ||
        medicine.endDate!.compareTo(today) >= 0;

    // 残り日数の計算
    String remainingLabel = '';
    if (medicine.endDate != null) {
      final remaining = remainingDays(medicine.endDate!);
      if (remaining < 0) {
        remainingLabel = '終了済み';
      } else if (remaining == 0) {
        remainingLabel = '今日で終わり';
      } else {
        remainingLabel = 'あと $remaining 日';
      }
    } else {
      remainingLabel = '無期限';
    }

    // 終了日のラベル色
    Color remainingColor = Colors.black54;
    if (medicine.endDate != null) {
      final remaining = remainingDays(medicine.endDate!);
      if (remaining <= 0) {
        remainingColor = Colors.grey;
      } else if (remaining <= 3) {
        remainingColor = Colors.orange.shade700;
      } else {
        remainingColor = Colors.green.shade700;
      }
    }

    return InkWell(
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MedicineFormScreen(medicine: medicine),
          ),
        );
        _loadMedicines();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? Colors.blue.shade100 : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 左側：薬アイコン
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF2E7D9F).withOpacity(0.12)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.medication,
                size: 30,
                color: isActive
                    ? const Color(0xFF2E7D9F)
                    : Colors.grey.shade400,
              ),
            ),
            const SizedBox(width: 14),

            // 中央：薬名・タイミング・開始日
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.displayName,
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: isActive ? Colors.black87 : Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // タイミングのチップ列
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: medicine.timings.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF2E7D9F).withOpacity(0.1)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          Timing.label(t),
                          style: TextStyle(
                            fontSize: 13,
                            color: isActive
                                ? const Color(0xFF2E7D9F)
                                : Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 4),
                  // 開始日
                  Text(
                    '開始：${_formatDateDisplay(medicine.startDate)}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 右側：残り日数
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  remainingLabel,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: remainingColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.chevron_right,
                  color: Colors.black26,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 薬が1件もない場合の表示
  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.medication_outlined,
              size: 72,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              '登録されている薬がありません',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              '右下の「＋薬を追加」から\n登録してください',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // "yyyy-MM-dd" → "yyyy年M月d日" 表示
  String _formatDateDisplay(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy年M月d日').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}