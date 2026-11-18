import 'package:flutter/material.dart';

class CarSessionCard extends StatelessWidget {
  final Map<String, dynamic> car;
  final VoidCallback? onAdminExit;

  const CarSessionCard({
    super.key,
    required this.car,
    this.onAdminExit,
  });

  static const Color blue = Color(0xFF1565C0);
  static const Color darkBlue = Color(0xFF0D47A1);
  static const Color red = Color(0xFFD32F2F);
  static const Color lightBlue = Color(0xFFEAF3FF);
  static const Color lightRed = Color(0xFFFFEBEE);
  static const Color borderColor = Color(0xFFDDEBFF);

  String formatDateTime(dynamic value) {
    if (value == null) return '-';

    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return '-';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  String customerDisplayName(dynamic value) {
    final name = (value ?? '').toString().trim();
    return name.isEmpty ? 'ללא שם' : name;
  }

  String statusHeb(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'parking':
        return 'חונה';
      case 'exited':
        return 'יצא';
      case 'paid':
        return 'שילם';
      default:
        return value?.toString() ?? '-';
    }
  }

  String paymentHeb(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'paid':
        return 'שולם';
      case 'waiting_payment':
        return 'ממתין לתשלום';
      case 'unpaid':
        return 'לא שולם';
      default:
        return value?.toString() ?? '-';
    }
  }

  String vehicleTypeHeb(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'disabled':
        return 'נכה';
      case 'subscriber':
        return 'מנוי';
      default:
        return 'רגיל';
    }
  }

  String exitByHeb(dynamic value) {
    switch ((value ?? '').toString()) {
      case 'user_app':
        return 'אפליקציית משתמש';
      case 'admin':
        return 'מנהל';
      case 'parking':
        return 'חניון';
      case 'system_simulator':
        return 'סימולטור';
      default:
        return '-';
    }
  }

  @override
  Widget build(BuildContext context) {
    final canAdminExit =
        car['status'] == 'parking' && car['expected_exit_by'] == 'admin';

    final price = double.tryParse((car['total_price'] ?? 0).toString()) ?? 0;
    final isParking = car['status'] == 'parking';
    final isPaid = car['payment_status'] == 'paid';

    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: borderColor),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isParking ? lightBlue : lightRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.directions_car,
            color: isParking ? blue : red,
          ),
        ),
        title: Text(
          '${car['plate'] ?? ''} | ${customerDisplayName(car['customer_name'])}',
          style: const TextStyle(
            color: darkBlue,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
            '${car['parking_name'] ?? ''}\n'
            'כניסה: ${formatDateTime(car['entry_time'])} | יציאה: ${formatDateTime(car['exit_time'])}\n'
            'סוג: ${vehicleTypeHeb(car['vehicle_type'])} | סטטוס: ${statusHeb(car['status'])} | תשלום: ${paymentHeb(car['payment_status'])}\n'
            'יציאה דרך: ${exitByHeb(car['ended_by'] ?? car['expected_exit_by'])} | סכום: ₪${price.toStringAsFixed(2)}',
            style: const TextStyle(
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        isThreeLine: true,
        trailing: canAdminExit
            ? ElevatedButton(
                onPressed: onAdminExit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'הוצא',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isPaid ? lightBlue : lightRed,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isPaid ? borderColor : red),
                ),
                child: Text(
                  isPaid ? 'שולם' : 'לא שולם',
                  style: TextStyle(
                    color: isPaid ? blue : red,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
      ),
    );
  }
}
