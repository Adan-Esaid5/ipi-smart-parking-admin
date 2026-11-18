import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> getParkingLots() async {
    final res = await supabase
        .from('parking_lots')
        .select()
        .order('id', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getParkingSessions() async {
    final res = await supabase
        .from('parking_sessions')
        .select()
        .order('entry_time', ascending: false)
        .limit(700);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> getContactMessages() async {
  final response = await supabase
      .from('contact_messages')
      .select()
      .order('created_at', ascending: false);

  return List<Map<String, dynamic>>.from(response);
}

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final res = await supabase
        .from('admin_notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(20);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> adminExitCar(Map<String, dynamic> car) async {
    final parkingLotId = car['parking_lot_id'];

    final parking = await supabase
        .from('parking_lots')
        .select()
        .eq('id', parkingLotId)
        .maybeSingle();

    final available =
        int.tryParse((parking?['available_spots'] ?? 0).toString()) ?? 0;

    final now = DateTime.now().toUtc();

    await supabase.from('parking_sessions').update({
      'exit_time': now.toIso8601String(),
      'status': 'exited',
      'payment_status': 'waiting_payment',
      'payment_method': 'admin',
      'ended_by': 'admin',
    }).eq('id', car['id']);

    if (parking != null) {
      await supabase.from('parking_lots').update({
        'available_spots': available + 1,
      }).eq('id', parkingLotId);
    }
  }

  Future<void> updateParkingRates({
    required Map<String, dynamic> parking,
    required double pricePerMinute,
    required double dailyMax,
    required int graceMinutes,
  }) async {
    final parkingId = parking['id'];
    final parkingName =
        (parking['name_en'] ?? parking['name'] ?? 'Parking').toString();

    await supabase.from('parking_lots').update({
      'price_per_minute': pricePerMinute,
      'daily_max': dailyMax,
      'GRACE_MINUTES': graceMinutes,
      'grace_minutes': graceMinutes,
    }).eq('id', parkingId);

    await supabase.from('admin_notifications').insert({
      'title': 'עדכון תעריף חניון',
      'message':
          'עודכן תעריף בחניון $parkingName: מחיר לדקה ₪$pricePerMinute, תקרה יומית ₪$dailyMax, זמן חסד $graceMinutes דקות.',
      'parking_lot_id': parkingId,
      'parking_name': parkingName,
    });
  }
}