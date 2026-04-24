// 服薬記録のモデルクラス
class DoseLog {
  final int? id;
  final int medicineId;       // 薬ID
  final String date;          // 対象日 YYYY-MM-DD
  final String timing;        // タイミング種別
  final String scheduledTime; // 予定服薬時刻 HH:mm
  final String status;        // "taken" / "skipped" / "pending"
  final String? actionTime;   // 操作した時刻

  DoseLog({
    this.id,
    required this.medicineId,
    required this.date,
    required this.timing,
    required this.scheduledTime,
    required this.status,
    this.actionTime,
  });

  factory DoseLog.fromMap(Map<String, dynamic> map) {
    return DoseLog(
      id: map['id'] as int?,
      medicineId: map['medicine_id'] as int,
      date: map['date'] as String,
      timing: map['timing'] as String,
      scheduledTime: map['scheduled_time'] as String,
      status: map['status'] as String,
      actionTime: map['action_time'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'medicine_id': medicineId,
      'date': date,
      'timing': timing,
      'scheduled_time': scheduledTime,
      'status': status,
      'action_time': actionTime,
    };
  }
}

// status の定数
class DoseStatus {
  static const String taken = 'taken';
  static const String skipped = 'skipped';
  static const String pending = 'pending';
}