import 'package:flutter/material.dart';

class ParkingCard extends StatelessWidget {
  final Map<String, dynamic> parking;

  const ParkingCard({
    super.key,
    required this.parking,
  });

  static const green = Color(0xFF188038);
  static const cardBg = Color(0xFFF3F8F1);

  int get available {
    return int.tryParse((parking['available_spots'] ?? 0).toString()) ?? 0;
  }

  int get total {
    return int.tryParse((parking['total_spots'] ?? 0).toString()) ?? 0;
  }

  String get name {
    return (parking['name_en'] ?? parking['name'] ?? 'Parking').toString();
  }

  @override
  Widget build(BuildContext context) {
    final occupied = total - available;
    final percent = total == 0 ? 0.0 : occupied / total;

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text('פנויים: $available | סה״כ: $total'),
            Text('תפוסים: $occupied'),
            Text('מחיר לדקה: ₪${parking['price_per_minute'] ?? 0}'),
            Text('תקרה יומית: ₪${parking['daily_max'] ?? 0}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percent.clamp(0, 1),
              backgroundColor: cardBg,
              color: percent > 0.8 ? Colors.red : green,
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
      ),
    );
  }
}