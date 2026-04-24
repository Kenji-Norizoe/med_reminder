import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medicine.dart';
import '../services/database_helper.dart';
import '../utils/time_utils.dart';
import 'medicine_form_screen.dart';

class EndingSoonScreen extends StatefulWidget {
  const EndingSoonScreen({super.key});

  @override
  State<EndingSoonScreen> createState() => _EndingSoonScreenState();
}

class _EndingSoonScreenState extends State<EndingSoonScreen> {
  List<Medicine> _medicines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  Future<void> _loadMedicines() async {
    setState(() => _isLoading = true);
    final medicines =
        await DatabaseHelper.instance.getEndingSoonMedicines();
    setState(() {
      _medicines = medicines;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('もうすぐ終わる薬'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 上部の案内メッセージ
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  color: Colors.orange.shade50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.orange.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '薬がなくなる前に、病院や薬局への連絡をご確認ください。',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 一覧
                Expanded(
                  child: _medicines.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          onRefresh: _loadMedicines,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _medicines.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _buildCard(_medicines[index]);
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildCard(Medicine medicine) {
    final remaining = remainingDays(medicine.endDate!);

    // 残り日数に応じて色を変える
    Color cardColor;
    Color labelColor;
    String urgencyLabel;

    if (remaining <= 0) {
      cardColor = Colors.red.shade50;
      labelColor = Colors.red.shade700;
      urgencyLabel = '今日が最終日';
    } else if (remaining == 1) {
      cardColor = Colors.orange.shade50;
      labelColor = Colors.orange.shade800;
      urgencyLabel = '明日で終わります';
    } else {
      cardColor = Colors.amber.shade50;
      labelColor = Colors.amber.shade800;
      urgencyLabel = 'あと $remaining 日';
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
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: labelColor.withOpacity(0.4), width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 残り日数バッジ
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: labelColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    remaining <= 0 ? '0' : '$remaining',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  Text(
                    '日',
                    style: TextStyle(
                      fontSize: 13,
                      color: labelColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // 薬名・詳細
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.displayName,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    urgencyLabel,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '終了予定日：${_formatDate(medicine.endDate!)}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // タイミング
                  Wrap(
                    spacing: 6,
                    children: medicine.timings.map((t) {
                      return Text(
                        Timing.label(t),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

            const Icon(Icons.chevron_right, color: Colors.black26),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 72,
              color: Colors.green.shade300,
            ),
            const SizedBox(height: 20),
            const Text(
              'もうすぐ終わる薬はありません',
              style: TextStyle(
                fontSize: 18,
                color: Colors.black45,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              '終了日が3日以内の薬があると\nここに表示されます',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black38,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // "yyyy-MM-dd" → "yyyy年M月d日"
  String _formatDate(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('yyyy年M月d日').format(dt);
    } catch (_) {
      return dateStr;
    }
  }
}