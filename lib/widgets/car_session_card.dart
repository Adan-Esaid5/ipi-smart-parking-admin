
// import 'package:flutter/material.dart';

// // שם הרכיב: CarSessionCard
// // תפקיד הרכיב: להציג כרטיס עם פרטי רכב וביקור בחניון.
// // הכרטיס מציג מספר רכב, שם לקוח, סוג רכב, שעות כניסה ויציאה,
// // מצב החניה, מצב התשלום והסכום.
// // במקרים המתאימים, המנהל יכול להוציא את הרכב מהחניון.

// class CarSessionCard extends StatelessWidget {

//   // שומר את כל נתוני הרכב והביקור שמגיעים ממסך המנהל.
//   // לדוגמה: מספר רכב, שם חניון, סוג רכב ומצב תשלום.
//   final Map<String, dynamic> car;

//   // פעולה שמתבצעת כאשר המנהל לוחץ על הכפתור "הוצא".
//   // סימן השאלה אומר שהפעולה אינה חובה.
//   final VoidCallback? onAdminExit;

//   // הפונקציה שיוצרת את כרטיס הרכב.
//   // חובה להעביר את פרטי הרכב באמצעות car.
//   const CarSessionCard({
//     super.key,
//     required this.car,
//     this.onAdminExit,
//   });

//   // הצבעים הקבועים שמשמשים לעיצוב הכרטיס.
//   static const Color blue = Color(0xFF1565C0);
//   static const Color darkBlue = Color(0xFF0D47A1);
//   static const Color red = Color(0xFFD32F2F);
//   static const Color lightBlue = Color(0xFFEAF3FF);
//   static const Color lightRed = Color(0xFFFFEBEE);
//   static const Color borderColor = Color(0xFFDDEBFF);

//   // ממירה תאריך ושעה שמגיעים מהנתונים לפורמט ברור.
//   // לדוגמה: 23/11/2026 14:30.
//   // אם התאריך חסר או לא תקין, מחזירה מקף.
//   String formatDateTime(dynamic value) {
//     if (value == null) return '-';

//     // מנסה להמיר את הערך לתאריך ולשעה המקומית.
//     final date = DateTime.tryParse(value.toString())?.toLocal();
//     if (date == null) return '-';

//     // מחזירה יום, חודש, שנה, שעה ודקות.
//     // padLeft מוסיף אפס לפני מספר שיש בו ספרה אחת.
//     return '${date.day.toString().padLeft(2, '0')}/'
//         '${date.month.toString().padLeft(2, '0')}/'
//         '${date.year} '
//         '${date.hour.toString().padLeft(2, '0')}:'
//         '${date.minute.toString().padLeft(2, '0')}';
//   }

//   // מחזירה את שם הלקוח לצורך הצגה בכרטיס.
//   // trim מסיר רווחים מיותרים מתחילת השם ומסופו.
//   // אם אין שם, מציגה "ללא שם".
//   String customerDisplayName(dynamic value) {
//     final name = (value ?? '').toString().trim();
//     return name.isEmpty ? 'ללא שם' : name;
//   }

//   // מתרגמת את מצב הרכב מאנגלית לעברית.
//   // לדוגמה: parking פירושו שהרכב עדיין חונה.
//   String statusHeb(dynamic value) {
//     switch ((value ?? '').toString()) {
//       case 'parking':
//         return 'חונה';

//       case 'exited':
//         return 'יצא';

//       case 'paid':
//         return 'שילם';

//       // אם התקבל מצב אחר, מציגה את הערך המקורי.
//       default:
//         return value?.toString() ?? '-';
//     }
//   }

//   // מתרגמת את מצב התשלום מאנגלית לעברית.
//   // חשוב להבדיל בין רכב ששילם לבין רכב שפטור מתשלום.
//   String paymentHeb(dynamic value) {
//     switch ((value ?? '').toString()) {

//       // התשלום בוצע.
//       case 'paid':
//         return 'שולם';

//       // הרכב עדיין ממתין לתשלום.
//       case 'waiting_payment':
//         return 'ממתין לתשלום';

//       // התשלום לא בוצע.
//       case 'unpaid':
//         return 'לא שולם';

//       // לא נדרש תשלום עבור הביקור.
//       // לדוגמה, רכב נכה שקיבל פטור לפי הגדרת החניון.
//       case 'not_required':
//         return 'פטור מתשלום';

//       default:
//         return value?.toString() ?? '-';
//     }
//   }

//   // מחזירה את סוג הרכב בעברית לפי הנתונים שנשמרו בביקור.
//   // הפונקציה מבדילה בין נכה רגיל לנכה עם כיסא גלגלים.
//   String vehicleTypeHeb(Map<String, dynamic> vehicle) {

//     // קוראת את סוג הרכב הראשי.
//     // אם אין סוג רכב, משתמשת כברירת מחדל ב-regular.
//     // toLowerCase הופך אותיות באנגלית לקטנות.
//     // trim מסיר רווחים מיותרים.
//     final type = (vehicle['vehicle_type'] ?? 'regular')
//         .toString().toLowerCase().trim();

//     // מנסה לקרוא את תת-הסוג של תו הנכה.
//     // המידע יכול להישמר באחד משלושה שדות שונים.
//     // אם שדה אינו קיים, עוברים לשדה הבא.
//     final subtype = (vehicle['disabled_type'] ??
//             vehicle['disability_type'] ?? vehicle['permit_type'] ?? '')
//         .toString().toLowerCase().trim();

//     // בודקת אם הרכב שייך לנכה עם כיסא גלגלים.
//     // אפשר לזהות זאת ישירות לפי סוג הרכב,
//     // או לפי תת-הסוג אם סוג הרכב הוא disabled.
//     if (['disabled_wheelchair', 'wheelchair',
//           'disabled_wheelchair_vehicle'].contains(type) ||
//         (type == 'disabled' &&
//             ['wheelchair', 'disabled_wheelchair',
//               'wheelchair_accessible'].contains(subtype))) {
//       return 'נכה עם כיסא גלגלים';
//     }

//     // בודקת אם הרכב שייך לנכה רגיל.
//     if (type == 'disabled_regular' ||
//         (type == 'disabled' &&
//             ['regular', 'disabled_regular'].contains(subtype))) {
//       return 'נכה רגיל';
//     }

//     // ברשומות ישנות לפעמים נשמר רק disabled.
//     // במקרה הזה מציגה "נכה" בלי לנחש לאיזה סוג הוא שייך.
//     if (type == 'disabled') return 'נכה';

//     // בודקת אם הרכב שייך למנוי.
//     if (type == 'subscriber' || type == 'subscription') return 'מנוי';

//     // בודקת אם מדובר ברכב של סטודנט.
//     // אפשר לזהות סטודנט לפי סוג הרכב או לפי השדה is_student.
//     if (type == 'student' || vehicle['is_student'] == true ||
//         vehicle['is_student']?.toString().toLowerCase() == 'true') {
//       return 'סטודנט';
//     }

//     // אם הרכב אינו שייך לאף אחת מהקבוצות, מציגה "רגיל".
//     return 'רגיל';
//   }

//   // מתרגמת את הגורם שביצע את יציאת הרכב מהחניון.
//   // לדוגמה: מנהל, חניון, אפליקציה או סימולטור.
//   String exitByHeb(dynamic value) {
//     switch ((value ?? '').toString()) {
//       case 'user_app':
//         return 'אפליקציית משתמש';

//       case 'admin':
//         return 'מנהל';

//       case 'parking':
//         return 'חניון';

//       case 'system_simulator':
//         return 'סימולטור';

//       // אם לא ידוע מי ביצע את היציאה, מציגה מקף.
//       default:
//         return '-';
//     }
//   }

//   // הפונקציה הראשית שבונה ומציגה את כרטיס הרכב.
//   // Flutter מפעיל אותה כאשר צריך להציג או לעדכן את הכרטיס.
//   @override
//   Widget build(BuildContext context) {

//     // בודקת אם המנהל יכול להוציא את הרכב.
//     // שני התנאים חייבים להתקיים:
//     // 1. הרכב עדיין חונה.
//     // 2. היציאה שלו מוגדרת לביצוע על ידי המנהל.
//     final canAdminExit =
//         car['status'] == 'parking' && car['expected_exit_by'] == 'admin';

//     // קוראת את מחיר החניה וממירה אותו למספר עשרוני.
//     // אם אין מחיר תקין, משתמשת ב-0.
//     final price = double.tryParse((car['total_price'] ?? 0).toString()) ?? 0;

//     // בודקת אם הרכב עדיין נמצא בחניון.
//     final isParking = car['status'] == 'parking';

//     // בודקת אם הרכב שילם בפועל.
//     final isPaid = car['payment_status'] == 'paid';

//     // בודקת אם הרכב קיבל פטור מתשלום.
//     // חשוב: פטור אינו נחשב לתשלום שבוצע.
//     final isExempt = car['payment_status'] == 'not_required';

//     // קוראת את סוג הרכב בעברית בעזרת הפונקציה שהגדרנו למעלה.
//     // כוללת זיהוי של נכה רגיל ונכה עם כיסא גלגלים.
//     final displayType = vehicleTypeHeb(car);

//     // יוצרת את הכרטיס שמכיל את פרטי הרכב.
//     return Card(

//       // רקע לבן, ללא צל.
//       color: Colors.white,
//       elevation: 0,

//       // עיצוב מסגרת הכרטיס עם פינות מעוגלות.
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//         side: const BorderSide(color: borderColor),
//       ),

//       // ListTile מחלק את הכרטיס לאייקון, כותרת,
//       // פרטי הרכב ואזור פעולה בצד.
//       child: ListTile(

//         // קובע את הרווחים הפנימיים בכרטיס.
//         contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),

//         // מציג אייקון רכב בצד הכרטיס.
//         leading: Container(
//           width: 46,
//           height: 46,
//           decoration: BoxDecoration(

//             // תכלת כשהרכב חונה, ואדום בהיר כשהוא כבר יצא.
//             color: isParking ? lightBlue : lightRed,
//             borderRadius: BorderRadius.circular(16),
//           ),

//           // אייקון של רכב, בצבע שמתאים למצב החניה.
//           child: Icon(
//             Icons.directions_car,
//             color: isParking ? blue : red,
//           ),
//         ),

//         // הכותרת הראשית של הכרטיס.
//         // מציגה מספר רכב ושם לקוח.
//         title: Text(
//           '${car['plate'] ?? ''} | ${customerDisplayName(car['customer_name'])}',
//           style: const TextStyle(
//             color: darkBlue,
//             fontWeight: FontWeight.w900,
//           ),
//         ),

//         // מציג את פרטי הביקור מתחת למספר הרכב.
//         subtitle: Padding(
//           padding: const EdgeInsets.only(top: 5),
//           child: Text(

//             // שם החניון שבו הרכב חנה.
//             '${car['parking_name'] ?? ''}\n'

//             // תאריך ושעת הכניסה והיציאה.
//             'כניסה: ${formatDateTime(car['entry_time'])} | יציאה: ${formatDateTime(car['exit_time'])}\n'

//             // סוג הרכב, מצב החניה ומצב התשלום.
//             'סוג: $displayType | סטטוס: ${statusHeb(car['status'])} | תשלום: ${paymentHeb(car['payment_status'])}\n'

//             // מי הוציא את הרכב וכמה עלתה החניה.
//             'יציאה דרך: ${exitByHeb(car['ended_by'] ?? car['expected_exit_by'])} | סכום: ₪${price.toStringAsFixed(2)}',

//             // עיצוב הטקסט שמציג את פרטי החניה.
//             style: const TextStyle(
//               height: 1.35,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//         ),

//         // מאפשר להציג כמה שורות מידע בכרטיס.
//         isThreeLine: true,

//         // בצד הכרטיס מוצג כפתור "הוצא" או מצב התשלום.
//         trailing: canAdminExit

//             // אם המנהל רשאי להוציא את הרכב, מציגים כפתור יציאה.
//             ? ElevatedButton(

//                 // מפעיל את הפעולה שנשלחה ממסך המנהל.
//                 onPressed: onAdminExit,

//                 // עיצוב הכפתור בצבע אדום.
//                 style: ElevatedButton.styleFrom(
//                   backgroundColor: red,
//                   foregroundColor: Colors.white,
//                   elevation: 0,
//                   shape: RoundedRectangleBorder(
//                     borderRadius: BorderRadius.circular(14),
//                   ),
//                 ),

//                 child: const Text(
//                   'הוצא',
//                   style: TextStyle(fontWeight: FontWeight.w900),
//                 ),
//               )

//             // אם אין כפתור יציאה, מציגים תג שמסביר את מצב התשלום.
//             : Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
//                 decoration: BoxDecoration(

//                   // אם שולם או התקבל פטור, הרקע תכלת.
//                   // אחרת הרקע אדום בהיר.
//                   color: (isPaid || isExempt) ? lightBlue : lightRed,

//                   borderRadius: BorderRadius.circular(14),

//                   // המסגרת כחולה בהירה לתשלום או לפטור,
//                   // ואדומה כאשר לא שולם.
//                   border: Border.all(
//                     color: (isPaid || isExempt) ? borderColor : red,
//                   ),
//                 ),

//                 // בוחר את הטקסט שיוצג בתג.
//                 child: Text(

//                   // שולם בפועל -> "שולם".
//                   // התקבל פטור -> "פטור".
//                   // אחרת -> "לא שולם".
//                   isPaid ? 'שולם' : (isExempt ? 'פטור' : 'לא שולם'),

//                   style: TextStyle(

//                     // כחול כאשר שולם או יש פטור,
//                     // ואדום כאשר אין תשלום.
//                     color: (isPaid || isExempt) ? blue : red,

//                     fontWeight: FontWeight.w900,
//                     fontSize: 12,
//                   ),
//                 ),
//               ),
//       ),
//     );
//   }
// }



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

  // מספר רכב אחיד בכל המערכות: 7 ספרות 12-345-67, 8 ספרות 123-45-678.
  // העיצוב בלבד; במסד הנתונים מזהים את הרכב לפי הספרות.
  String displayPlate(dynamic value) {
    final text = (value ?? '').toString().trim();
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 7) {
      return '${digits.substring(0, 2)}-${digits.substring(2, 5)}-${digits.substring(5)}';
    }
    if (digits.length == 8) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 5)}-${digits.substring(5)}';
    }
    return text;
  }

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
      case 'not_required':
        return 'פטור מתשלום';
      default:
        return value?.toString() ?? '-';
    }
  }

  // מחזיר את סוג הרכב לפי הנתונים של הביקור.
  // רשומות ישנות עם disabled בלי פירוט לא משויכות בטעות לאחד משני הסוגים.
  String vehicleTypeHeb(Map<String, dynamic> vehicle) {
    final type = (vehicle['vehicle_type'] ?? 'regular')
        .toString().toLowerCase().trim();
    final subtype = (vehicle['disabled_type'] ??
            vehicle['disability_type'] ?? vehicle['permit_type'] ?? '')
        .toString().toLowerCase().trim();

    if (['disabled_wheelchair', 'wheelchair',
          'disabled_wheelchair_vehicle'].contains(type) ||
        (type == 'disabled' &&
            ['wheelchair', 'disabled_wheelchair',
              'wheelchair_accessible'].contains(subtype))) {
      return 'נכה עם כיסא גלגלים';
    }
    if (type == 'disabled_regular' ||
        (type == 'disabled' &&
            ['regular', 'disabled_regular'].contains(subtype))) {
      return 'נכה רגיל';
    }
    if (type == 'disabled') return 'נכה'; // נתון ישן: בלי לשייך בטעות לאחד משני הסוגים.
    if (type == 'subscriber' || type == 'subscription') return 'מנוי';
    if (type == 'student' || vehicle['is_student'] == true ||
        vehicle['is_student']?.toString().toLowerCase() == 'true') {
      return 'סטודנט';
    }
    return 'רגיל';
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
    // פטור הוא לא תשלום שבוצע, ולכן מציגים אותו באופן נפרד.
    final isExempt = car['payment_status'] == 'not_required';
    // קורא את סוג הרכב המדויק, כולל שני סוגי תו הנכה.
    final displayType = vehicleTypeHeb(car);

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
          '${displayPlate(car['plate'])} | ${customerDisplayName(car['customer_name'])}',
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
            'סוג: $displayType | סטטוס: ${statusHeb(car['status'])} | תשלום: ${paymentHeb(car['payment_status'])}\n'
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
                  color: (isPaid || isExempt) ? lightBlue : lightRed,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (isPaid || isExempt) ? borderColor : red),
                ),
                child: Text(
                  isPaid ? 'שולם' : (isExempt ? 'פטור' : 'לא שולם'),
                  style: TextStyle(
                    color: (isPaid || isExempt) ? blue : red,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ),
      ),
    );
  }
}
