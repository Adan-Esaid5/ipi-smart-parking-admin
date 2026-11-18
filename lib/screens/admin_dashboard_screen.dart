/*
 * שם הדף: AdminDashboardScreen – מסך המנהל של IPI SMART PARKING
 * מה רואים כאן? נתוני רכבים, חניונים, תשלומים, הודעות וגרפים.
 * מאיפה מגיע המידע? מטבלאות Supabase, למשל parking_sessions ו-parking_lots.
 * מה אפשר לשנות בקוד? צבעים, טקסטים, זמני רענון, סינונים ועיצוב.
 * חשוב: שינוי סכומי תשלום, תנאי סינון או שמירה במסד הנתונים משנה התנהגות,
 * לכן לפני שינוי כזה כדאי לשמור עותק ולבדוק את התוצאה.
 * זהו קובץ המקור המקורי בתוספת הסברים; פעולות הקוד לא שונו.
 */


import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/admin_service.dart';
import '../widgets/car_session_card.dart';

/*
 * שם המסך: AdminDashboardScreen
 * תיאור: מסך ניהול מרכזי לחניונים, רכבים, הודעות, נתונים וגרפים.
 */

enum AdminPanel {
  dashboard,
  parkings,
  cars,
  messages,
  chart,
}

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  /// יוצר את מצב מסך הניהול.
  @override
  /// מה זה עושה? יוצר את החלק שמנהל את הנתונים והשינויים של הדף.
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  /// כחול רגיל: שינוי הקוד שבתוך Color משנה את צבע הכפתורים והסמלים.
  static const Color blue = Color(0xFF1565C0);
  /// כחול כהה: משמש לכותרות ולאזורים בולטים.
  static const Color darkBlue = Color(0xFF0D47A1);
  /// אדום: משמש להדגשה, אזהרה וכפתורי פעולה.
  static const Color red = Color(0xFFD32F2F);
  /// צבע הרקע של כל מסך המנהל.
  static const Color bg = Color(0xFFF6F9FE);
  /// צבע הרקע של הכרטיסים והמסגרות.
  static const Color cardBg = Color(0xFFFFFFFF);
  /// צבע כחול בהיר ברקעים של שדות וכרטיסים.
  static const Color lightBlue = Color(0xFFEAF3FF);
  /// צבע אדום בהיר לאזהרות ולהדגשות.
  static const Color lightRed = Color(0xFFFFEBEE);
  /// צבע הקווים מסביב לכרטיסים ושדות.
  static const Color borderColor = Color(0xFFDDEBFF);
  /// צבע הטקסט הרגיל.
  static const Color textDark = Color(0xFF111827);
  /// צבע טקסט משני, למשל תיאורים.
  static const Color textMuted = Color(0xFF6B7280);

  final adminService = AdminService();
  final supabase = Supabase.instance.client;
  final searchController = TextEditingController();
  final parkingSearchController = TextEditingController();
  final sideMenuScrollController = ScrollController();
  final chartSearchController = TextEditingController();

// זמן ריצה הגרף 
  /// שעון שמפעיל רענון של נתוני המנהל במרווח קבוע.
  Timer? refreshTimer;
  // בודק שינויים בתשלום של הרכבים המוצגים כל שלוש שניות.
  Timer? paymentRefreshTimer;
  Timer? messagesRefreshTimer;
  Timer? historyRefreshTimer;
  /// שעון שמחליף את החניון בגרף באופן אוטומטי.
  Timer? chartRotationTimer;
  /// מספר החניון שהגרף מציג כרגע ברצף.
  int dashboardChartIndex = 0;
  /// הטקסט שמוקלד בחיפוש החניון של הגרף.
  String chartSearchText = '';

  /// אומר אם הנתונים נטענים, כדי להציג סימן טעינה.
  bool loading = true;

  /// רשימת החניונים שהתקבלה מהמסד.
  List<Map<String, dynamic>> parkings = [];
  /// רשימת כניסות הרכבים שהתקבלה מהמסד.
  List<Map<String, dynamic>> sessions = [];
  /// רשימת הודעות הלקוחות.
  List<Map<String, dynamic>> contactMessages = [];

  /// מילות החיפוש שמקלידים באזור הרכבים.
  String searchText = '';
  /// מילות החיפוש שמקלידים באזור החניונים.
  String parkingSearchText = '';
  /// המצב שנבחר לסינון רכבים; all אומר הכול.
  String statusFilter = 'all';
  /// החניון שנבחר לסינון; all אומר כל החניונים.
  String parkingFilter = 'all';
  /// איך ממיינים חניונים: busy הוא עמוס קודם, free פנוי קודם.
  String parkingSort = 'busy';
  /// שם החניון שהגרף מציג.
  String selectedChartParkingName = '';

  /// תאריך שנבחר; כשהוא ריק מציגים ללא סינון יום.
  DateTime? selectedDate;
  /// החלק של מערכת המנהל שמוצג כרגע.
  AdminPanel selectedPanel = AdminPanel.dashboard;

  /// טוען את נתוני הניהול ומפעיל רענון אוטומטי.
  @override
  /// מה זה עושה? פועל כשפותחים את הדף: טוען מידע ומפעיל רענון וגרפים מתחלפים. אפשר לשנות כאן את זמני ההפעלה.
  void initState() {
    super.initState();

    loadData();
    // הודעות נטענות עצמאית, בלי להמתין להיסטוריית הרכבים.
    unawaited(_loadMessages());
    unawaited(_refreshFullHistory());

    // הגרף מחליף חניון כל 8 שניות. אפשר לשנות את המספר כדי לקבוע את קצב ההחלפה.
    chartRotationTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      final active = parkings.where((p) => p['is_active'] != false).toList();
      if (!mounted || selectedPanel != AdminPanel.dashboard || active.isEmpty) return;
      setState(() => dashboardChartIndex = (dashboardChartIndex + 1) % active.length);
    });

    refreshTimer = Timer.periodic(
      // רענון מלא שומר על נתוני הגרפים וכל ההיסטוריה.
      const Duration(seconds: 15),
      (_) => loadData(showLoading: false),
    );
    paymentRefreshTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshVisiblePayments(),
    );
    // הודעות נבדקות בנפרד כל 6 שניות.
    messagesRefreshTimer = Timer.periodic(
      const Duration(seconds: 6), (_) => unawaited(_loadMessages()),
    );
    // היסטוריה מלאה כבדה נטענת לעיתים רחוקות יותר.
    historyRefreshTimer = Timer.periodic(
      const Duration(minutes: 3), (_) => unawaited(_refreshFullHistory()),
    );
  }

  // Manual navigation through active parking-lot charts.
  /// מה זה עושה? מעביר את הגרף לחניון הקודם או הבא כשלוחצים על החצים.
  void _moveDashboardChart(int step) {
    final activeCount = parkings.where((p) => p['is_active'] != false).length;
    if (!mounted || activeCount == 0) return;
    setState(() {
      dashboardChartIndex = (dashboardChartIndex + step + activeCount) % activeCount;
    });
  }

  /// עוצר את הרענון האוטומטי ומשחרר משאבים.
  @override
  /// מה זה עושה? עוצר שעונים ומשחרר שדות טקסט כשעוזבים את הדף.
  void dispose() {
    refreshTimer?.cancel();
    paymentRefreshTimer?.cancel();
    messagesRefreshTimer?.cancel();
    historyRefreshTimer?.cancel();
    chartRotationTimer?.cancel();
    chartSearchController.dispose();
    searchController.dispose();
    parkingSearchController.dispose();
    sideMenuScrollController.dispose();
    super.dispose();
  }

  // מכיל את הגרסאות האחרונות שהתקבלו מה-DB, גם בזמן רענון מלא.
  final Map<String, Map<String, dynamic>> _freshSessionRows = {};
  bool _paymentRefreshInProgress = false;
  int _paymentRefreshRevision = 0;
  final Map<String, int> _rowRefreshRevision = {};

  // טוען לפי id את הרכבים שמוצגים בחיפוש ובכרטיסים האחרונים.
  // כך שינוי paid / waiting_payment מתעדכן בלי להמתין להורדת כל ההיסטוריה.
  Future<void> _refreshVisiblePayments() async {
    if (_paymentRefreshInProgress || !mounted || loading) return;
    final ids = <String>{};
    for (final row in filteredSessions.take(150)) {
      final id = (row['id'] ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    for (final row in sessions.take(35)) {
      final id = (row['id'] ?? '').toString();
      if (id.isNotEmpty) ids.add(id);
    }
    if (ids.isEmpty) return;
    _paymentRefreshInProgress = true;
    try {
      final updated = <String, Map<String, dynamic>>{};
      final allIds = ids.toList();
      for (var i = 0; i < allIds.length; i += 75) {
        final batch = allIds.skip(i).take(75).toList();
        final result = await supabase.from('parking_sessions')
            .select().inFilter('id', batch);
        for (final raw in result) {
          final row = Map<String, dynamic>.from(raw);
          updated[(row['id'] ?? '').toString()] = row;
        }
      }
      if (!mounted || updated.isEmpty) return;
      // מחליף את כל שדות הביקור, לא רק את תג התשלום.
      setState(() {
        _paymentRefreshRevision++;
        _freshSessionRows.addAll(updated);
        for (final id in updated.keys) {
          _rowRefreshRevision[id] = _paymentRefreshRevision;
        }
        sessions = sessions.map((row) {
          final fresh = updated[(row['id'] ?? '').toString()];
          return fresh == null ? row : {...row, ...fresh};
        }).toList();
        _occupiedByLotId = _buildOccupiedCounts(parkings, sessions);
      });
    } catch (error) {
      debugPrint('Admin payment refresh failed: $error');
    } finally {
      _paymentRefreshInProgress = false;
    }
  }

  // רענון מלא לא ידרוס תשלום שהתעדכן בזמן שהשאילתות עבדו.
  List<Map<String, dynamic>> _withFreshSessionRows(
      List<Map<String, dynamic>> rows, int startedAtRevision) {
    return rows.map((row) {
      final id = (row['id'] ?? '').toString();
      final recent = (_rowRefreshRevision[id] ?? 0) > startedAtRevision
          ? _freshSessionRows[id] : null;
      return recent == null ? row : {...row, ...recent};
    }).toList();
  }

  // Fast manual refresh: never block the whole dashboard while loading history.
  /// מונע לחיצה כפולה בזמן רענון מהיר.
  bool _quickRefreshInProgress = false;

  /// מה זה עושה? מרענן מהר חניונים ו-200 כניסות אחרונות. אפשר לשנות מגבלת זמן וכמות, אך זה משפיע על מהירות הטעינה.
  Future<void> _refreshQuickly() async {
    if (_quickRefreshInProgress) return;
    if (!mounted) return;
    final startedAtRevision = _paymentRefreshRevision;
    setState(() => _quickRefreshInProgress = true);

    try {
      // Only the recent records are needed for an immediate visual update.
      // Both requests run concurrently and share a five-second deadline.
      final results = await Future.wait<dynamic>([
        supabase.from('parking_lots').select().order('id'),
        supabase.from('parking_sessions').select()
            .order('entry_time', ascending: false)
            .order('id', ascending: false)
            // כאן קובעים כמה כניסות אחרונות ייטענו ברענון המהיר.
            .limit(200),
      // רענון מהיר מוגבל ל-5 שניות. אפשר לשנות את הזמן כאן.
      ]).timeout(const Duration(seconds: 5));

      if (!mounted) return;
      final freshLots = List<Map<String, dynamic>>.from(results[0] as List);
      final recent = List<Map<String, dynamic>>.from(results[1] as List);

      // Merge recent updates into the existing complete history, rather than
      // replacing all history with only 200 rows and corrupting statistics.
      final merged = <String, Map<String, dynamic>>{};
      for (final visit in sessions) {
        final id = (visit['id'] ?? '').toString();
        final key = id.isNotEmpty
            ? 'id:$id'
            : 'legacy:${visit['plate']}|${visit['parking_name']}|${visit['entry_time']}';
        merged[key] = visit;
      }
      for (final visit in recent) {
        final id = (visit['id'] ?? '').toString();
        final key = id.isNotEmpty
            ? 'id:$id'
            : 'legacy:${visit['plate']}|${visit['parking_name']}|${visit['entry_time']}';
        merged[key] = visit;
      }
      final mergedVisits = merged.values.toList()
        ..sort((a, b) => (b['entry_time'] ?? '').toString()
            .compareTo((a['entry_time'] ?? '').toString()));
      final names = freshLots.where((p) => p['is_active'] != false).map(parkingName).where((n) => n.isNotEmpty).toSet();
      setState(() {
        parkings = freshLots;
        sessions = _withFreshSessionRows(mergedVisits, startedAtRevision);
        _occupiedByLotId = _buildOccupiedCounts(freshLots, sessions);
        if (selectedChartParkingName.isEmpty || !names.contains(selectedChartParkingName)) {
          selectedChartParkingName = names.isNotEmpty ? names.first : '';
        }
        loading = false;
      });
    } on TimeoutException {
      // Five seconds is a UI deadline, not a guarantee of network completion.
      debugPrint('Quick admin refresh timed out after five seconds.');
    } catch (e) {
      debugPrint('Quick admin refresh failed: $e');
    } finally {
      if (mounted) setState(() => _quickRefreshInProgress = false);
    }

    // Full reconciliation continues separately: historical totals, occupancy,
    // messages and old sessions must not disappear from the dashboard.
    unawaited(loadData(showLoading: false));
  }

  // Loads the exact parking_sessions table used by IPI Car Simulator.
  // Explicit pagination avoids PostgREST's default 1,000-row limit.
  /// מונע טעינה מלאה נוספת לפני שהקודמת הסתיימה.
  bool _adminFetchInProgress = false;

  /// מה זה עושה? מביא את כל כניסות הרכבים בחתיכות של 500 רשומות; שינוי המספר ישפיע על קצב הטעינה.
  Future<List<Map<String, dynamic>>> _fetchAllParkingSessions() async {
    // כאן קובעים כמה רשומות מביאים בכל בקשה למסד הנתונים.
    const pageSize = 500;
    final result = <Map<String, dynamic>>[];
    var from = 0;

    while (true) {
      final page = await supabase
          .from('parking_sessions')
          .select()
          .order('entry_time', ascending: false)
          .order('id', ascending: false)
          .range(from, from + pageSize - 1);
      final rows = List<Map<String, dynamic>>.from(page);
      result.addAll(rows);
      if (rows.length < pageSize) break;
      from += pageSize;
    }
    return result;
  }

  // הודעות: בקשה עצמאית שאינה תלויה בטעינת הרכבים.
  bool _messagesInProgress = false;
  Future<void> _loadMessages() async {
    if (_messagesInProgress || !mounted) return;
    _messagesInProgress = true;
    try {
      final rows = await adminService.getContactMessages()
          .timeout(const Duration(seconds: 12));
      if (!mounted) return;
      setState(() => contactMessages = List<Map<String, dynamic>>.from(rows));
    } catch (error) {
      debugPrint('Admin messages refresh failed: $error');
    } finally {
      _messagesInProgress = false;
    }
  }

  // רק היסטוריית הרכבים נטענת ברקע; לא מעכבת הודעות או הצגת המסך.
  bool _historyInProgress = false;
  int _historyRequestEpoch = 0;
  Future<void> _refreshFullHistory() async {
    if (_historyInProgress || !mounted) return;
    _historyInProgress = true;
    final epoch = _historyRequestEpoch;
    final startedAtRevision = _paymentRefreshRevision;
    try {
      final data = await _fetchAllParkingSessions();
      if (!mounted || epoch != _historyRequestEpoch) return;
      // שלבי רענון התשלום שמגיעים בזמן בקשת ההיסטוריה נשמרים.
      setState(() {
        final merged = <String, Map<String, dynamic>>{};
        for (final row in data) {
          final id = (row['id'] ?? '').toString();
          if (id.isNotEmpty) merged[id] = row;
        }
        // אם התווספה כניסה מאז שהתחילה הורדת ההיסטוריה, לא מאבדים אותה.
        for (final row in sessions) {
          final id = (row['id'] ?? '').toString();
          if (id.isNotEmpty && !merged.containsKey(id)) merged[id] = row;
        }
        sessions = _withFreshSessionRows(merged.values.toList(), startedAtRevision)
          ..sort((a, b) => (b['entry_time'] ?? '').toString()
              .compareTo((a['entry_time'] ?? '').toString()));
        _occupiedByLotId = _buildOccupiedCounts(parkings, sessions);
      });
    } catch (error) {
      debugPrint('Admin historical sessions refresh failed: $error');
    } finally {
      _historyInProgress = false;
    }
  }

  /// טוען במהירות חניונים וביקורים אחרונים; הודעות והיסטוריה בנפרד.
  Future<void> loadData({bool showLoading = true}) async {
    if (_adminFetchInProgress || !mounted) return;
    _adminFetchInProgress = true;
    final startedAtRevision = _paymentRefreshRevision;
    if (showLoading && sessions.isEmpty && parkings.isEmpty) {
      setState(() => loading = true);
    }
    try {
      // שתי השאילתות מתבצעות במקביל; לא ממתינים להודעות.
      final results = await Future.wait<dynamic>([
        supabase.from('parking_lots').select().order('id'),
        supabase.from('parking_sessions').select()
            .order('entry_time', ascending: false)
            .order('id', ascending: false).limit(200),
      ]).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      final freshLots = List<Map<String, dynamic>>.from(results[0] as List);
      final recent = List<Map<String, dynamic>>.from(results[1] as List);
      final merged = <String, Map<String, dynamic>>{};
      for (final row in sessions) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) merged[id] = row;
      }
      for (final row in recent) {
        final id = (row['id'] ?? '').toString();
        if (id.isNotEmpty) merged[id] = row;
      }
      final names = freshLots.where((p) => p['is_active'] != false)
          .map(parkingName).where((n) => n.isNotEmpty).toSet();
      setState(() {
        parkings = freshLots;
        sessions = _withFreshSessionRows(merged.values.toList(), startedAtRevision)
          ..sort((a, b) => (b['entry_time'] ?? '').toString()
              .compareTo((a['entry_time'] ?? '').toString()));
        _occupiedByLotId = _buildOccupiedCounts(parkings, sessions);
        if (selectedChartParkingName.isEmpty || !names.contains(selectedChartParkingName)) {
          selectedChartParkingName = names.isEmpty ? '' : names.first;
        }
        loading = false;
      });
    } catch (error) {
      debugPrint('Admin fast data refresh failed: $error');
      if (mounted) setState(() => loading = false);
    } finally {
      _adminFetchInProgress = false;
    }
  }

  /// מציג הודעה למנהל בתחתית המסך.
  /// מה זה עושה? מציג הודעה קטנה בתחתית המסך; אפשר לשנות צבע ונוסח.
  void showMsg(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: error ? red : blue,
        content: Text(msg),
      ),
    );
  }

  /// מחזיר את שם החניון לתצוגה.
  /// מה זה עושה? מוצא שם חניון מתוך הנתונים; קודם באנגלית ואחר כך בשם חלופי.
  String parkingName(Map<String, dynamic> p) {
    return (p['name_en'] ?? p['name'] ?? p['display_name'] ?? 'Parking')
        .toString()
        .trim();
  }

  /// מציג סכומי כסף עם פסיק בין אלפים ושתי ספרות אחרי הנקודה.
  /// לדוגמה: 125430.5 יוצג בתור ₪125,430.50.
  String formatMoneyWithCommas(num amount) {
    final parts = amount.toStringAsFixed(2).split('.');
    final whole = parts.first;
    final negative = whole.startsWith('-');
    final digits = negative ? whole.substring(1) : whole;
    final grouped = digits.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '₪${negative ? '-' : ''}$grouped.${parts.last}';
  }

  /// קורא את מספר הרכב שנשמר עם פניית הלקוח בטבלת contact_messages.
  /// אם ההודעה הישנה לא כוללת מספר רכב, אין להמציא מספר של רכב אחר.
  String carNumberFromMessage(Map<String, dynamic> item) {
    for (final key in ['car_number', 'plate', 'vehicle_number', 'license_plate']) {
      final value = (item[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  /// מחזיר את שם הלקוח מתוך הודעה.
  /// מה זה עושה? מרכיב שם לקוח מהשם הפרטי והמשפחה שמופיעים בהודעה.
  String customerNameFromMessage(Map<String, dynamic> item) {
    final firstName = (item['first_name'] ?? '').toString().trim();
    final lastName = (item['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    if (fullName.isNotEmpty) return fullName;

    return (item['name'] ??
            item['full_name'] ??
            item['customer_name'] ??
            item['user_name'] ??
            'לקוח')
        .toString();
  }

  /// בודק האם שני תאריכים נמצאים באותו יום.
  /// מה זה עושה? בודק אם שני תאריכים מתייחסים לאותו יום מקומי.
  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    final local = a.toLocal();

    return local.year == b.year &&
        local.month == b.month &&
        local.day == b.day;
  }

  // Resolve searches by a lot's Hebrew/Arabic/English name, then match
  // parking sessions even if they store only the English parking name.
  /// מה זה עושה? מוצא חניון לפי שמות בכמה שפות כדי שהחיפוש יעבוד גם בעברית.
  Set<String> matchingLotNames(String query) {
    final q = query.toLowerCase().trim();
    if (q.isEmpty) return {};
    final names = <String>{};
    for (final p in parkings) {
      final aliases = [
        p['name_he'], p['name_en'], p['name_ar'], p['name'],
        p['display_name'], p['city'], p['address'], p['address_ar'],
      ].where((v) => v != null).map((v) => v.toString().toLowerCase());
      if (aliases.any((v) => v.contains(q))) {
        for (final key in ['name_he', 'name_en', 'name_ar', 'name', 'display_name']) {
          final value = (p[key] ?? '').toString().toLowerCase().trim();
          if (value.isNotEmpty) names.add(value);
        }
      }
    }
    
    // Legacy lots may only have English names in parking_sessions.
    if (q.contains('אתרים')) {
      names.addAll({'atarim parking', 'atarim', 'atarim tel aviv parking'});
    }
    return names;
  }

  /// מחזיר את החניות לאחר החלת הסינונים.
  /// מה זה עושה? מסנן כניסות רכב לפי החיפוש, מצב רכב, חניון ותאריך.
  List<Map<String, dynamic>> get filteredSessions {
    final aliases = matchingLotNames(searchText);
    return sessions.where((car) {
      final q = searchText.toLowerCase().trim();
      // הסרת מקפים, רווחים וסימנים מחיפוש מספר רכב.
      // כך 12345678 ימצא גם רכב שנשמר בתור 123-45-678.
      final searchDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
      final isPlateSearch = searchDigits.isNotEmpty &&
          q.replaceAll(RegExp(r'[0-9\s\-]'), '').isEmpty;
      final plate = (car['plate'] ?? '').toString().toLowerCase();
      final plateDigits = plate.replaceAll(RegExp(r'[^0-9]'), '');
      final customer = (car['customer_name'] ?? '').toString().toLowerCase();
      final parking = (car['parking_name'] ?? '').toString().toLowerCase();
      final status = (car['status'] ?? '').toString();
      final paymentStatus = (car['payment_status'] ?? '').toString();

      final matchesSearch = q.isEmpty ||
          plate.contains(q) ||
          (isPlateSearch && plateDigits.contains(searchDigits)) ||
          customer.contains(q) ||
          parking.contains(q) ||
          aliases.contains(parking) ||
          aliases.any((name) => parking.contains(name));

      final matchesStatus = statusFilter == 'all' ||
          status == statusFilter ||
          paymentStatus == statusFilter;

      final matchesParking =
          parkingFilter == 'all' || parking == parkingFilter.toLowerCase();

      final matchesDate = selectedDate == null ||
          isSameDay(
            DateTime.tryParse((car['entry_time'] ?? '').toString()),
            selectedDate,
          );

      return matchesSearch && matchesStatus && matchesParking && matchesDate;
    }).toList();
  }

  /// מחזיר את החניונים לפי סוג המיון שנבחר.
  /// מה זה עושה? מסדר את החניונים לפי האפשרות שנבחרה: עמוס, פנוי או רגיל.
  List<Map<String, dynamic>> get sortedParkings {
    final list = [...parkings];

    if (parkingSort == 'busy') {
      list.sort((a, b) => occupancyPercent(b).compareTo(occupancyPercent(a)));
    } else if (parkingSort == 'free') {
      list.sort((a, b) => occupancyPercent(a).compareTo(occupancyPercent(b)));
    }

    return list;
  }

  /// מחזיר את החניונים לאחר חיפוש וסינון.
  /// מה זה עושה? מראה רק חניונים שמתאימים לחיפוש בשם, בעיר או בכתובת.
  List<Map<String, dynamic>> get filteredParkings {
    final q = parkingSearchText.toLowerCase().trim();

    if (q.isEmpty) return sortedParkings;

    return sortedParkings.where((p) {
      final name = parkingName(p).toLowerCase();
      final nameEn = (p['name_en'] ?? '').toString().toLowerCase();
      final nameHe = (p['name_he'] ?? '').toString().toLowerCase();
      final nameAr = (p['name_ar'] ?? '').toString().toLowerCase();
      final displayName = (p['display_name'] ?? '').toString().toLowerCase();
      final city = (p['city'] ?? '').toString().toLowerCase();
      final address = (p['address'] ?? '').toString().toLowerCase();

      return name.contains(q) ||
          nameEn.contains(q) ||
          nameHe.contains(q) ||
          nameAr.contains(q) ||
          displayName.contains(q) ||
          city.contains(q) ||
          address.contains(q);
    }).toList();
  }


  /// מה זה עושה? סופר רשומות של רכבים שעדיין חונים.
  int get activeCars => sessions.where((s) => s['status'] == 'parking').length;

  /// מה זה עושה? סופר רשומות של רכבים שיצאו.
  int get exitedCars => sessions.where((s) => s['status'] == 'exited').length;

  /// מה זה עושה? סופר רשומות שסומנו כשולמו.
  int get paidCars =>
      sessions.where((s) => s['payment_status'] == 'paid').length;

  /// מה זה עושה? סופר רשומות שממתינות לתשלום.
  int get waitingPaymentCars =>
      sessions.where((s) => s['payment_status'] == 'waiting_payment').length;

  /// מחזיר את מספר הרכבים לפי התאריך שנבחר.
  /// מה זה עושה? סופר כניסות ביום שנבחר; ללא תאריך סופר את כל הרשומות שנטענו.
  int get dateCarsCount {
    if (selectedDate == null) {
      return sessions.length;
    }

    return sessions.where((s) {
      final entryDate = DateTime.tryParse((s['entry_time'] ?? '').toString());

      return isSameDay(entryDate, selectedDate);
    }).length;
  }

  /// מחזיר את סך ההכנסות מכל החניות ששולמו.
  /// מה זה עושה? מסכם מחירי כניסות שסומנו כשולמו, מכל הרשומות שנטענו.
  double get totalIncome {
    double sum = 0;

    for (final s in sessions) {
      if (s['payment_status'] == 'paid') {
        sum += double.tryParse((s['total_price'] ?? 0).toString()) ?? 0;
      }
    }

    return sum;
  }

  /// מחזיר את ההכנסה לפי הסינון הנוכחי.
  /// מה זה עושה? מסכם את הסכומים ששולמו רק ברשומות שמתאימות לסינון.
  double get filteredIncome {
    double sum = 0;

    for (final s in filteredSessions) {
      if (s['payment_status'] == 'paid') {
        sum += double.tryParse((s['total_price'] ?? 0).toString()) ?? 0;
      }
    }

    return sum;
  }

  // Active vehicle counts, rebuilt once after every successful Supabase refresh.
  // The simulator stores parking_lot_id for new sessions; older sessions
  // may only have parking_name, so we support both.
  /// שומר כמה רכבים חונים בכל חניון לפי המזהה שלו.
  Map<String, int> _occupiedByLotId = {};

  /// מה זה עושה? מחזיר את מזהה החניון בתור טקסט כדי לזהות אותו.
  String _lotKey(Map<String, dynamic> lot) =>
      (parkingId(lot) ?? '').toString();

  /// מה זה עושה? מאחד את צורת הכתיבה של שם החניון להשוואה.
  String _lotNameToken(dynamic value) =>
      (value ?? '').toString().trim().toLowerCase();

  /// מה זה עושה? מחשב כמה רכבים עדיין חונים בכל חניון לפי רשומות הפעילות.
  Map<String, int> _buildOccupiedCounts(
    List<Map<String, dynamic>> lots,
    List<Map<String, dynamic>> visits,
  ) {
    final counts = <String, int>{};
    final byName = <String, String>{};
    final validIds = <String>{};
    for (final lot in lots) {
      final id = _lotKey(lot);
      if (id.isEmpty) continue;
      validIds.add(id);
      counts[id] = 0;
      for (final column in ['name_en','name_he','name_ar','name','display_name']) {
        final alias = _lotNameToken(lot[column]);
        if (alias.isNotEmpty) byName[alias] = id;
      }
    }
    for (final visit in visits) {
      if (_lotNameToken(visit['status']) != 'parking') continue;
      final exit = visit['exit_time'];
      if (exit != null && exit.toString().trim().isNotEmpty) continue;
      final storedId = (visit['parking_lot_id'] ??
          visit['parking_id'] ?? visit['lot_id'])?.toString();
      // If there is an ID, do not accidentally attribute it to another lot
      // with a similar name.
      final id = storedId != null && storedId.isNotEmpty
          ? (validIds.contains(storedId) ? storedId : null)
          : byName[_lotNameToken(visit['parking_name'] ??
              visit['parking'] ?? visit['lot_name'])];
      if (id == null) continue;
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts;
  }

  /// מחזיר את מספר המקומות הפנויים בחניון.
  /// מה זה עושה? מחשב כמה מקומות נשארו פנויים בחניון.
  int availableSpots(Map<String, dynamic> p) =>
      (totalSpots(p) - occupiedSpots(p)).clamp(0, totalSpots(p)).toInt();

  /// מחזיר את מספר המקומות הכולל בחניון.
  /// מה זה עושה? מחזיר כמה מקומות חנייה יש בחניון בסך הכול.
  int totalSpots(Map<String, dynamic> p) {
    final total = int.tryParse((p['total_spots'] ?? 0).toString()) ?? 0;
    return total < 0 ? 0 : total;
  }

  /// מספר רכבים חונים בפועל לפי רשומות פעילות; לא לפי available_spots הישן.
  /// מה זה עושה? מחזיר כמה מקומות תפוסים כרגע לפי נתוני הרכבים.
  int occupiedSpots(Map<String, dynamic> p) {
    final total = totalSpots(p);
    return (_occupiedByLotId[_lotKey(p)] ?? 0).clamp(0, total).toInt();
  }
  /// מחשב את אחוז התפוסה של החניון.
  /// מה זה עושה? מחשב את אחוז התפוסה של החניון לגרף ההתקדמות.
  double occupancyPercent(Map<String, dynamic> p) {
    final total = totalSpots(p);
    if (total <= 0) return 0;
    final percent = occupiedSpots(p) / total;
    return percent.clamp(0, 1).toDouble();
  }

  /// מעצב תאריך לתצוגה.
  /// מה זה עושה? הופך תאריך לתצוגה פשוטה של יום/חודש/שנה.
  String formatDate(DateTime? date) {
    if (date == null) return 'בחר תאריך';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  /// מעצב תאריך ושעה לתצוגה.
  /// מה זה עושה? מציג תאריך ושעה בצורה קריאה לפי שעון המכשיר.
  String formatDateTime(dynamic value) {
    if (value == null) return '';

    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();

    final local = date.toLocal();

    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}  '
        '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  /// מחזיר נתוני כניסות לפי שעה עבור הגרף.
  /// מה זה עושה? סופר כניסות בכל אחת מ-24 שעות היום בשביל הגרף.
  List<int> hourlyData() {
    final data = List<int>.filled(24, 0);

    final activeName = selectedPanel == AdminPanel.dashboard
        ? (parkings.where((p) => p['is_active'] != false).isEmpty ? '' : parkingName(parkings.where((p) => p['is_active'] != false).toList()[dashboardChartIndex % parkings.where((p) => p['is_active'] != false).length]))
        : selectedChartParkingName;
    if (activeName.isEmpty) return data;

    final matchingParking = parkings.where((p) => parkingName(p) == activeName);
    final lotAliases = matchingParking.isEmpty
        ? <String>{activeName.toLowerCase()}
        : <String>{for (final key in ['name_en', 'name_he', 'name_ar', 'name', 'display_name'])
            if ((matchingParking.first[key] ?? '').toString().trim().isNotEmpty)
              matchingParking.first[key].toString().trim().toLowerCase()};
    for (final s in sessions) {
      final sessionParking = (s['parking_name'] ?? '').toString().trim();
      if (!lotAliases.contains(sessionParking.toLowerCase())) continue;

      final date = DateTime.tryParse((s['entry_time'] ?? '').toString());
      if (date == null) continue;

      if (selectedDate != null && !isSameDay(date, selectedDate)) continue;

      data[date.toLocal().hour]++;
    }

    return data;
  }

  /// מוציא רכב מהחניון באמצעות פעולת מנהל.
  /// מה זה עושה? מוציא רכב מהחניון דרך שירות המנהל ומרענן נתונים.
  Future<void> adminExitCar(Map<String, dynamic> car) async {
    try {
      await adminService.adminExitCar(car);
      showMsg('הרכב ${car['plate']} הוצא על ידי מנהל');
      await loadData();
    } catch (e) {
      showMsg('שגיאה בהוצאת רכב: $e', error: true);
    }
  }

  /// פותח בחירת תאריך לצורך סינון הנתונים.
  /// מה זה עושה? פותח חלון לבחירת תאריך לסינון הרכבים והגרף.
  Future<void> pickDate() async {
    // לא מאפשר לבחור מחר או כל תאריך עתידי.
    // בכל פתיחה מחושב היום מחדש, כך שמ־00:00 ניתן לבחור את היום החדש.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial = selectedDate != null && !selectedDate!.isAfter(today)
        ? selectedDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: textDark,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;
    // מוודא שהתאריך עדיין אינו עתידי גם אם השעון השתנה.
    final current = DateTime.now();
    final currentDay = DateTime(current.year, current.month, current.day);
    if (picked.isAfter(currentDay)) return;

    setState(() => selectedDate = picked);
  }

  /// מנקה את כל הסינונים והחיפושים.
  /// מה זה עושה? מנקה חיפוש, תאריך וסינונים ומחזיר לברירות המחדל.
  void clearFilters() {
    searchController.clear();
    parkingSearchController.clear();

    setState(() {
      searchText = '';
      parkingSearchText = '';
      statusFilter = 'all';
      parkingFilter = 'all';
      selectedDate = null;
    });
  }


  /// מה זה עושה? מחזיר את המזהה של חניון מתוך אחת מעמודות המזהה האפשריות.
  dynamic parkingId(Map<String, dynamic> parking) {
    return parking['id'] ??
        parking['parking_id'] ??
        parking['lot_id'] ??
        parking['uuid'];
  }

  /// מה זה עושה? מסיר רווחים מיותרים וממיר לאותיות קטנות לצורך השוואה.
  String normalizeText(String value) {
    return value.trim().toLowerCase();
  }

  /// מה זה עושה? קורא מספר עם נקודה עשרונית מתוך נתונים של חניון.
  double readDouble(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];

      if (value == null) continue;

      final parsed = double.tryParse(value.toString());

      if (parsed != null) return parsed;
    }

    return 0;
  }

  /// מה זה עושה? קורא מספר שלם מתוך נתונים של חניון.
  int readInt(Map<String, dynamic> item, List<String> keys) {
    for (final key in keys) {
      final value = item[key];

      if (value == null) continue;

      final parsed = int.tryParse(value.toString());

      if (parsed != null) return parsed;
    }

    return 0;
  }

  /// מה זה עושה? מכין את המחיר לדקה, המקסימום היומי וזמן החסד לשמירה.
  Map<String, dynamic> normalizedParkingUpdate({
    required double pricePerMinute,
    required double dailyMax,
    required int graceMinutes,
  }) => {
    'price_per_minute': pricePerMinute,
    'daily_max': dailyMax,
    'grace_minutes': graceMinutes,
  };

  /// Update a single lot by immutable ID; fail visibly if DB did not accept it.
  /// מה זה עושה? שומר מחירון חניון ב-Supabase ובודק שהערכים נשמרו כמו שהוזנו.
  Future<Map<String, dynamic>> updateParkingRatesDirect({
    required Map<String, dynamic> parking,
    required double pricePerMinute,
    required double dailyMax,
    required int graceMinutes,
  }) async {
    final id = parkingId(parking);
    if (id == null) throw StateError('לחניון אין מזהה id');
    final update = normalizedParkingUpdate(
      pricePerMinute: pricePerMinute,
      dailyMax: dailyMax,
      graceMinutes: graceMinutes,
    );
    final response = await supabase.from('parking_lots')
        .update(update).eq('id', id).select().maybeSingle();
    if (response == null) {
      throw StateError('לא התקבל עדכון מ־Supabase. בדקי הרשאות UPDATE / RLS');
    }
    final saved = Map<String, dynamic>.from(response);
    if ((readDouble(saved, ['price_per_minute']) - pricePerMinute).abs() > 0.001 ||
        (readDouble(saved, ['daily_max']) - dailyMax).abs() > 0.001 ||
        readInt(saved, ['grace_minutes']) != graceMinutes) {
      throw StateError('הנתונים שנשמרו שונים מהתעריפים שהוזנו');
    }
    return saved;
  }

  /// פותח חלון לעריכת תעריפי חניון.
  /// מה זה עושה? פותח חלון לשינוי מחיר לדקה, תקרה יומית וזמן חסד.
  Future<void> openEditRatesDialog(Map<String, dynamic> parking) async {
    final priceController = TextEditingController(
      text: readDouble(parking, ['price_per_minute']).toString(),
    );
    final dailyController = TextEditingController(
      text: readDouble(parking, ['daily_max']).toString(),
    );
    final graceController = TextEditingController(
      text: readInt(parking, ['grace_minutes', 'GRACE_MINUTES']).toString(),
    );

    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> saveRates() async {
              final price = double.tryParse(priceController.text.trim());
              final daily = double.tryParse(dailyController.text.trim());
              final grace = int.tryParse(graceController.text.trim());

              if (price == null || price < 0) {
                showMsg('מחיר לדקה לא תקין', error: true);
                return;
              }

              if (daily == null || daily < 0) {
                showMsg('תקרה יומית לא תקינה', error: true);
                return;
              }

              if (grace == null || grace < 0) {
                showMsg('זמן חסד לא תקין', error: true);
                return;
              }

              setDialogState(() => saving = true);

              try {
                final updatedParking = await updateParkingRatesDirect(
                  parking: parking,
                  pricePerMinute: price,
                  dailyMax: daily,
                  graceMinutes: grace,
                );

                if (!mounted) return;

                setState(() {
                  final updatedId = parkingId(updatedParking);
                  final oldId = parkingId(parking);
                  final index = parkings.indexWhere((item) {
                    final itemId = parkingId(item);

                    if (updatedId != null &&
                        itemId != null &&
                        itemId.toString() == updatedId.toString()) {
                      return true;
                    }

                    if (oldId != null &&
                        itemId != null &&
                        itemId.toString() == oldId.toString()) {
                      return true;
                    }

                    return normalizeText(parkingName(item)) ==
                        normalizeText(parkingName(parking));
                  });

                  if (index >= 0) {
                    parkings[index] = {
                      ...parkings[index],
                      ...updatedParking,
                    };
                  }
                });

                Navigator.pop(dialogContext);

                showMsg(
                  'המחירון עודכן ואומת מול ה־DB: ₪${price.toStringAsFixed(2)} לדקה | יומי ₪${daily.toStringAsFixed(2)} | חסד $grace דקות',
                );

                await loadData(showLoading: false);
              } catch (e) {
                if (!mounted) return;

                setDialogState(() => saving = false);

                showMsg('שגיאה בעדכון המחירון ב־DB: $e', error: true);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'שינוי מחירון - ${parkingName(parking)}',
                style: const TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 14),
                        decoration: BoxDecoration(
                          color: lightBlue,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: borderColor),
                        ),
                        child: Text(
                          'העדכון נשמר ישירות בטבלת parking_lots ב־Supabase ומאומת אחרי השמירה.',
                          style: const TextStyle(
                            color: darkBlue,
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                        ),
                      ),
                      rateInput('מחיר לדקה', priceController),
                      const SizedBox(height: 12),
                      rateInput('תקרה יומית', dailyController),
                      const SizedBox(height: 12),
                      rateInput('זמן חסד בדקות', graceController),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text(
                    'ביטול',
                    style: TextStyle(
                      color: darkBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  onPressed: saving ? null : saveRates,
                  icon: saving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save, size: 17),
                  label: Text(
                    saving ? 'שומר...' : 'שמור ועדכן DB',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    priceController.dispose();
    dailyController.dispose();
    graceController.dispose();
  }

  /// פותח חלון עם פרטי הודעת לקוח.
  /// מה זה עושה? פותח חלון עם פרטי הודעת לקוח.
  Future<void> openContactMessageDialog(Map<String, dynamic> item) async {
    final name = customerNameFromMessage(item);
    final firstName = (item['first_name'] ?? '').toString().trim();
    final lastName = (item['last_name'] ?? '').toString().trim();
    final email = (item['email'] ?? '').toString();
    final phone = (item['phone'] ?? '').toString();
    final messageCarNumber = carNumberFromMessage(item);
    final subject = (item['subject'] ?? 'פנייה חדשה').toString();
    final message = (item['message'] ?? '').toString();
    final createdAt = formatDateTime(item['created_at']);

    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: lightRed,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.mark_email_unread,
                  color: red,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'הודעת לקוח',
                  style: TextStyle(
                    color: darkBlue,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  contactInfoRow(Icons.person, 'שם מלא', name),
                  if (firstName.isNotEmpty)
                    contactInfoRow(Icons.badge, 'שם פרטי', firstName),
                  if (lastName.isNotEmpty)
                    contactInfoRow(Icons.badge_outlined, 'שם משפחה', lastName),
                  if (email.isNotEmpty)
                    contactInfoRow(Icons.email, 'אימייל', email),
                  if (phone.isNotEmpty)
                    contactInfoRow(Icons.phone, 'טלפון', phone),
                  // מציג את הרכב שעליו הפנייה, מתוך הרשומה ב-DB.
                  contactInfoRow(
                    Icons.directions_car,
                    'מספר רכב',
                    messageCarNumber.isEmpty ? 'לא צוין' : messageCarNumber,
                  ),
                  if (createdAt.isNotEmpty)
                    contactInfoRow(Icons.access_time, 'תאריך', createdAt),
                  const SizedBox(height: 14),
                  sectionLabel('נושא'),
                  infoBox(subject, color: lightBlue),
                  const SizedBox(height: 12),
                  sectionLabel('תוכן ההודעה'),
                  infoBox(
                    message.isEmpty ? 'ללא תוכן הודעה' : message,
                    color: bg,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'סגור',
                style: TextStyle(
                  color: darkBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// מה זה עושה? מציג שורה אחת של מידע על הלקוח, למשל טלפון או אימייל.
  Widget contactInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: blue, size: 18),
          const SizedBox(width: 7),
          Text(
            '$label: ',
            style: const TextStyle(
              color: darkBlue,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: textDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// מה זה עושה? מציג כותרת קטנה בתוך חלון.
  Widget sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: darkBlue,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  /// מה זה עושה? יוצר תיבת טקסט שאפשר לשנות לה צבע רקע.
  Widget infoBox(String text, {Color color = lightBlue}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Text(
        text,
        style: const TextStyle(
          height: 1.45,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// מה זה עושה? יוצר שדה להקלדת ערך במחירון.
  Widget rateInput(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: false,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: darkBlue),
        filled: true,
        fillColor: lightBlue,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: blue, width: 1.4),
        ),
      ),
    );
  }

  /// מה זה עושה? יוצר מסגרת מעוצבת סביב שדה קלט.
  Widget modernInput({required Widget child}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  /// מה זה עושה? יוצר כפתור עם כיתוב, סמל וצבע שאפשר לקבוע.
  Widget modernButton({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
    Color color = red,
  }) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16),
        label: Text(text, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  /// מה זה עושה? יוצר כפתור בתפריט הצד ועובר לדף שבוחרים.
  Widget sideButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required AdminPanel panel,
  }) {
    final selected = selectedPanel == panel;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() => selectedPanel = panel);
          if (panel == AdminPanel.messages) unawaited(_loadMessages());
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? blue : cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: selected ? blue : borderColor),
            boxShadow: [
              if (selected)
                BoxShadow(
                  color: blue.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.2) : lightBlue,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: selected ? Colors.white : blue,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : darkBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      subtitle,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white70 : textMuted,
                        fontWeight: FontWeight.w600,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// מחזיר את כותרת הפאנל שנבחר.
  /// מה זה עושה? קובע את הכותרת של החלק הפתוח במערכת.
  String selectedPanelTitle() {
    switch (selectedPanel) {
      case AdminPanel.dashboard:
        return 'Dashboard';
      case AdminPanel.parkings:
        return 'חניונים';
      case AdminPanel.cars:
        return 'רכבים וחניות';
      case AdminPanel.messages:
        return 'הודעות לקוחות';
      case AdminPanel.chart:
        return 'ניתוח לפי שעה';
    }
  }

  /// מחזיר את תיאור הפאנל שנבחר.
  /// מה זה עושה? קובע את שורת ההסבר שמתחת לכותרת החלק.
  String selectedPanelSubtitle() {
    switch (selectedPanel) {
      case AdminPanel.dashboard:
        return 'סיכום מרכזי של המערכת';
      case AdminPanel.parkings:
        return 'ניהול חניונים, תפוסה ותעריפים';
      case AdminPanel.cars:
        return 'חיפוש וסינון רכבים לפי תאריך, סטטוס וחניון';
      case AdminPanel.messages:
        return 'פניות לקוחות מתוך מסד הנתונים';
      case AdminPanel.chart:
        return 'גרף כניסות לפי שעה לחניון נבחר';
    }
  }

  /// מחזיר את התוכן המתאים לפאנל שנבחר.
  /// מה זה עושה? מחליט איזה תוכן להציג לפי הבחירה בתפריט.
  Widget mainContent() {
    switch (selectedPanel) {
      case AdminPanel.dashboard:
        return buildDashboardPanel();
      case AdminPanel.parkings:
        return buildParkingsPanel();
      case AdminPanel.cars:
        return buildCarsPanel();
      case AdminPanel.messages:
        return buildMessagesPanel();
      case AdminPanel.chart:
        return buildChartPanel();
    }
  }

  /// בונה ומציג את מסך הניהול הראשי.
  @override
  /// מה זה עושה? בונה את המסך הראשי ומתאים את סידור התפריט לרוחב החלון.
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          toolbarHeight: 78,
          elevation: 0,
          backgroundColor: cardBg,
          surfaceTintColor: cardBg,
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: lightRed,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.admin_panel_settings,
                  color: red,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Parking',
                    style: TextStyle(
                      color: darkBlue,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      color: textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: IconButton(
                onPressed: _quickRefreshInProgress ? null : _refreshQuickly,
                tooltip: 'רענון מהיר (עד 5 שניות)',
                style: IconButton.styleFrom(
                  backgroundColor: blue,
                  foregroundColor: Colors.white,
                ),
                icon: _quickRefreshInProgress
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.refresh),
              ),
            ),
          ],
        ),
        body: loading
            ? const Center(child: CircularProgressIndicator(color: blue))
            : LayoutBuilder(
                builder: (context, constraints) {
                  // מתחת לרוחב 980 המערכת עוברת לתפריט עליון. אפשר לשנות את הסף.
                  final narrow = constraints.maxWidth < 980;

                  if (narrow) {
                    return Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        children: [
                          buildTopMenuForSmallScreen(),
                          const SizedBox(height: 12),
                          Expanded(child: buildMainFrame()),
                        ],
                      ),
                    );
                  }

                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          // רוחב תפריט הצד במסך גדול. אפשר לשנות את המספר כדי להרחיב או לצמצם.
                          width: 270,
                          child: buildSideMenu(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: buildMainFrame()),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  /// יוצר תפריט עליון למסכים קטנים.
  /// מה זה עושה? בונה תפריט עליון כשאין מספיק מקום לתפריט צד.
  Widget buildTopMenuForSmallScreen() {
    return SizedBox(
      height: 58,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          topMenuButton('Dashboard', Icons.dashboard, AdminPanel.dashboard),
          topMenuButton('חניונים', Icons.local_parking, AdminPanel.parkings),
          topMenuButton('רכבים', Icons.directions_car, AdminPanel.cars),
          topMenuButton('הודעות', Icons.mark_email_unread, AdminPanel.messages),
          topMenuButton('גרף', Icons.bar_chart, AdminPanel.chart),
        ],
      ),
    );
  }

  /// מה זה עושה? יוצר כפתור בתפריט העליון ומחליף את החלק המוצג.
  Widget topMenuButton(String title, IconData icon, AdminPanel panel) {
    final selected = selectedPanel == panel;

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ElevatedButton.icon(
        onPressed: () => setState(() => selectedPanel = panel),
        icon: Icon(icon),
        label: Text(title),
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? blue : cardBg,
          foregroundColor: selected ? Colors.white : darkBlue,
          elevation: 0,
          side: BorderSide(color: selected ? blue : borderColor),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }

  /// יוצר את תפריט הניווט הצדדי.
  /// מה זה עושה? בונה תפריט צד עם קישורים לחלקי מערכת המנהל.
  Widget buildSideMenu() {
    return Scrollbar(
      controller: sideMenuScrollController,
      thumbVisibility: true,
      thickness: 5,
      radius: const Radius.circular(8),
      child: SingleChildScrollView(
        controller: sideMenuScrollController,
        padding: const EdgeInsetsDirectional.only(end: 8, bottom: 8),
        child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: darkBlue,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: darkBlue.withOpacity(0.15),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.dashboard_customize, color: Colors.white, size: 24),
                const SizedBox(height: 5),
                const Text(
                  'ניהול מערכת',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'עודכן: ${formatDateTime(DateTime.now().toIso8601String())}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          sideButton(
            title: 'Dashboard',
            subtitle: 'סיכום כללי',
            icon: Icons.dashboard,
            panel: AdminPanel.dashboard,
          ),
          sideButton(
            title: 'חניונים',
            subtitle: 'ניהול תפוסה ותעריפים',
            icon: Icons.local_parking,
            panel: AdminPanel.parkings,
          ),
          sideButton(
            title: 'רכבים',
            subtitle: 'חיפוש לפי תאריך וסטטוס',
            icon: Icons.directions_car,
            panel: AdminPanel.cars,
          ),
          sideButton(
            title: 'הודעות',
            subtitle: 'פניות לקוחות',
            icon: Icons.mark_email_unread,
            panel: AdminPanel.messages,
          ),
          sideButton(
            title: 'גרף שעות',
            subtitle: 'כניסות לפי שעה',
            icon: Icons.bar_chart,
            panel: AdminPanel.chart,
          ),
          const SizedBox(height: 5),
          buildDateSummary(),
        ],
      ),
      ),
    );
  }

  /// יוצר את המסגרת הראשית של תוכן הניהול.
  /// מה זה עושה? יוצר את האזור הלבן שמכיל את התוכן הראשי.
  Widget buildMainFrame() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: blue.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          buildMainHeader(),
          const SizedBox(height: 16),
          Expanded(child: mainContent()),
        ],
      ),
    );
  }

  /// יוצר את כותרת אזור התוכן הראשי.
  /// מה זה עושה? מציג את שם החלק, בחירת תאריך וכפתור ניקוי.
  Widget buildMainHeader() {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: lightRed,
            borderRadius: BorderRadius.circular(17),
          ),
          child: const Icon(Icons.analytics, color: red),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedPanelTitle(),
                style: const TextStyle(
                  color: darkBlue,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                selectedPanelSubtitle(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 155,
          child: modernButton(
            text: formatDate(selectedDate),
            icon: Icons.date_range,
            onTap: pickDate,
            color: blue,
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: modernButton(
            text: 'נקה',
            icon: Icons.close,
            onTap: clearFilters,
            color: red,
          ),
        ),
      ],
    );
  }

  /// יוצר את פאנל הדשבורד הראשי.
  /// מה זה עושה? בונה את דף הסיכום: מספרים, גרף, הודעות ורכבים אחרונים.
  Widget buildDashboardPanel() {
    return SingleChildScrollView(
      child: Column(
        children: [
          buildStatsGrid(),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 7,
                child: SizedBox(
                  height: 280,
                  child: InkWell(
                     borderRadius: BorderRadius.circular(24),
                     onTap: () {
                       final active = parkings
                           .where((p) => p['is_active'] != false)
                           .toList();
                       if (active.isEmpty) return;
                       final currentLot = active[dashboardChartIndex % active.length];
                       setState(() {
                         selectedChartParkingName = parkingName(currentLot);
                         chartSearchText = '';
                         chartSearchController.clear();
                         selectedPanel = AdminPanel.chart;
                       });
                     },
                     child: buildHourlyChart(),
                   ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: 280,
                  child: buildMiniMessages(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 340,
            child: buildRecentCars(),
          ),
        ],
      ),
    );
  }

  /// יוצר רשת כרטיסי סטטיסטיקה.
  /// מה זה עושה? יוצר כרטיסים עם סיכומי חניונים, רכבים ותשלומים.
  /// אפשר לשנות כאן את הבחירות, הכיתובים או התנאים לפי הצורך.
  Widget buildStatsGrid() {
    final cards = [
      statBox('חניונים פעילים', parkings.where((p) => p['is_active'] != false).length.toString(), Icons.local_parking),
      statBox('רכבים חונים', activeCars.toString(), Icons.directions_car),
      statBox('רכבים שיצאו', exitedCars.toString(), Icons.exit_to_app),
      statBox('רכבים ששילמו', paidCars.toString(), Icons.paid),
      statBox(
        'ממתינים לתשלום',
        waitingPaymentCars.toString(),
        Icons.hourglass_bottom,
        warning: true,
      ),
      statBox('בתאריך שנבחר', dateCarsCount.toString(), Icons.date_range),
      statBox(
        'הכנסות כלליות',
        // מפריד אלפים בפסיקים ומציג שתי ספרות אחרי הנקודה.
        formatMoneyWithCommas(totalIncome),
        Icons.attach_money,
      ),
      statBox(
        'הכנסות בסינון',
        // מפריד אלפים בפסיקים גם בסכום המסונן.
        formatMoneyWithCommas(filteredIncome),
        Icons.query_stats,
      ),
    ];

    return GridView.builder(
      itemCount: cards.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 245,
        mainAxisExtent: 110,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (_, index) => cards[index],
    );
  }

  /// מה זה עושה? יוצר כרטיס מידע אחד; אפשר לשנות צבע, סמל וכיתוב.
  Widget statBox(
    String title,
    String value,
    IconData icon, {
    bool warning = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: warning ? lightRed : lightBlue,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: warning ? red.withOpacity(0.35) : borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              icon,
              color: warning ? red : blue,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: darkBlue,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shared create / edit form. Persists ALL supplied details in parking_lots.
  /// מה זה עושה? פותח טופס הוספת חניון חדש.
  Future<void> openAddParkingDialog() => openParkingDetailsDialog();

  /// מה זה עושה? פותח טופס להוספת חניון או עריכת פרטיו ושמירתם.
  /// אפשר לשנות כאן את הבחירות, הכיתובים או התנאים לפי הצורך.
  Future<void> openParkingDetailsDialog([Map<String, dynamic>? existing]) async {
    final editing = existing != null;
    final values = <String, TextEditingController>{};
    // כאן מגדירים את השדות בטופס חניון. אפשר לשנות את הכותרות בעברית.
    final fields = <String, String>{
      'name_en': 'שם החניון באנגלית *',
      'name_he': 'שם החניון בעברית *',
      'name_ar': 'שם החניון בערבית',
      'city': 'עיר *',
      'address': 'כתובת מלאה *',
      'latitude': 'קו רוחב - Latitude (למפה)',
      'longitude': 'קו אורך - Longitude (למפה)',
      'phone': 'טלפון של החניון',
      'opening_hours': 'שעות פעילות, למשל 24/7',
      'description_he': 'תיאור והערות ללקוחות',
      'price_per_minute': 'מחיר לדקה (₪) *',
      'daily_max': 'תקרה יומית (₪) *',
      'grace_minutes': 'זמן חסד בדקות *',
      'total_spots': 'מספר מקומות בסך הכול *',
      'available_spots': 'מספר מקומות פנויים *',
    };
    for (final key in fields.keys) {
      values[key] = TextEditingController(text: (key == 'available_spots' && existing != null ? availableSpots(existing) : existing?[key] ?? '').toString());
    }
    if (!editing) {
      // ברירת מחדל לחניון חדש: מחיר לדקה. שינוי המספר משנה רק את הערך ההתחלתי בטופס.
      values['price_per_minute']!.text = '0.50';
      // ברירת מחדל לחניון חדש: תקרה יומית.
      values['daily_max']!.text = '80';
      // ברירת מחדל לחניון חדש: מספר דקות ללא חיוב.
      values['grace_minutes']!.text = '10';
      // ברירת מחדל לחניון חדש: מספר מקומות החנייה.
      values['total_spots']!.text = '100';
      // ברירת מחדל לחניון חדש: מספר מקומות פנויים.
      values['available_spots']!.text = '100';
    }
    // Only the three parking features requested by the administrator.
    // כאן נמצאות אפשרויות המאפיינים שאפשר לסמן לחניון.
    final featureChoices = <String, String>{
      'disabled_regular': 'תו נכה רגיל',
      'disabled_wheelchair': 'תו נכה כיסא גלגלים',
      'payment_machines': 'מכונות תשלום',
    };
    // Supported payment methods are informational; no payment gateway is called.
    // כאן נמצאות אפשרויות אמצעי התשלום שמוצגות למנהל כמידע.
    final paymentChoices = <String, String>{
      'pango': 'פנגו',
      'cellopark': 'סלופארק',
      'cash': 'מזומן',
      'credit_card': 'אשראי',
    };
    // Keep only currently supported values when opening an older parking lot.
    // This also removes obsolete choices when that lot is saved again.
    bool flag(dynamic value) => value == true || value == 1 ||
        value.toString().toLowerCase() == 'true';
    final selectedFeatures = <String>{
      ...((existing?['ipi_features'] is List ? existing!['ipi_features'] as List : <dynamic>[]))
          .map((v) => v.toString()).where(featureChoices.containsKey),
      if (existing?['ipi_features'] == null && flag(existing?['disabled_regular'])) 'disabled_regular',
      if (existing?['ipi_features'] == null && flag(existing?['disabled_wheelchair'])) 'disabled_wheelchair',
      if (existing?['ipi_features'] == null && flag(existing?['has_ticket_machine'])) 'payment_machines',
    };
    final selectedPayments = <String>{
      ...((existing?['ipi_payment_methods'] is List ? existing!['ipi_payment_methods'] as List : <dynamic>[]))
          .map((v) => v.toString()).where(paymentChoices.containsKey),
      if (existing?['ipi_payment_methods'] == null && flag(existing?['payment_pango'])) 'pango',
      if (existing?['ipi_payment_methods'] == null && flag(existing?['payment_cellopark'])) 'cellopark',
      if (existing?['ipi_payment_methods'] == null && flag(existing?['payment_cash'])) 'cash',
      if (existing?['ipi_payment_methods'] == null && flag(existing?['payment_card'])) 'credit_card',
    };
    bool saving = false;

    try {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, updateDialog) {
            Widget field(String key) {
              final numeric = {
                'latitude', 'longitude', 'price_per_minute', 'daily_max',
                'grace_minutes', 'total_spots', 'available_spots'
              }.contains(key);
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: TextField(
                  controller: values[key],
                  keyboardType: numeric
                      ? const TextInputType.numberWithOptions(decimal: true, signed: true)
                      : TextInputType.text,
                  maxLines: key == 'description_he' ? 2 : 1,
                  decoration: InputDecoration(
                    labelText: fields[key],
                    filled: true, fillColor: lightBlue,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    isDense: true,
                  ),
                ),
              );
            }

            Widget options(String title, Map<String, String> choices, Set<String> selected) =>
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 8),
                  Text(title, style: const TextStyle(fontSize: 16, color: darkBlue,
                      fontWeight: FontWeight.bold)),
                  Wrap(spacing: 6, runSpacing: 2, children: choices.entries.map((entry) =>
                    FilterChip(
                      label: Text(entry.value),
                      selected: selected.contains(entry.key),
                      onSelected: saving ? null : (checked) => updateDialog(() {
                        if (checked) { selected.add(entry.key); }
                        else { selected.remove(entry.key); }
                      }),
                    ),
                  ).toList()),
                ]);

            Future<void> save() async {
              String value(String k) => values[k]!.text.trim();
              final rate = double.tryParse(value('price_per_minute'));
              final daily = double.tryParse(value('daily_max'));
              final grace = int.tryParse(value('grace_minutes'));
              final capacity = int.tryParse(value('total_spots'));
              final free = int.tryParse(value('available_spots'));
              final lat = value('latitude').isEmpty ? null : double.tryParse(value('latitude'));
              final lon = value('longitude').isEmpty ? null : double.tryParse(value('longitude'));
              final coordsValid = (value('latitude').isEmpty || (lat != null && lat >= -90 && lat <= 90)) &&
                  (value('longitude').isEmpty || (lon != null && lon >= -180 && lon <= 180));
              // City and full street address are mandatory for every parking lot.
              if (value('city').isEmpty) {
                showMsg('חובה למלא עיר לפני שמירת החניון', error: true);
                return;
              }
              if (value('address').isEmpty) {
                showMsg('חובה למלא כתובת מלאה לפני שמירת החניון', error: true);
                return;
              }
              if (['name_en', 'name_he'].any((k) => value(k).isEmpty) ||
                  rate == null || rate < 0 || daily == null || daily < 0 ||
                  grace == null || grace < 0 || capacity == null || capacity < 1 ||
                  free == null || free < 0 || free > capacity || !coordsValid) {
                showMsg('בדקי שמות, מחירים, קיבולת וקואורדינטות', error: true);
                return;
              }
              updateDialog(() => saving = true);
              try {
                final row = <String, dynamic>{
                  for (final k in ['name_en','name_he','name_ar','city','address',
                      'phone','opening_hours','description_he']) k: value(k),
                  'latitude': lat, 'longitude': lon,
                  'price_per_minute': rate, 'daily_max': daily,
                  'grace_minutes': grace,
                  'total_spots': capacity, 'available_spots': free,
                  'ipi_features': selectedFeatures.toList()..sort(),
                  'ipi_payment_methods': selectedPayments.toList()..sort(),
                };
                // Preserve historic compatibility only when those fields exist.
                final known = parkings.isEmpty ? <String>{} : parkings.first.keys.toSet();
                if (known.contains('name')) row['name'] = value('name_en');
                if (known.contains('display_name')) row['display_name'] = value('name_en');
                if (known.contains('GRACE_MINUTES')) row['GRACE_MINUTES'] = grace;
                // Keep legacy boolean columns in sync where the DB defines them.
                final legacyFlags = <String, bool>{
                  'disabled_regular': selectedFeatures.contains('disabled_regular'),
                  'disabled_wheelchair': selectedFeatures.contains('disabled_wheelchair'),
                  'has_ticket_machine': selectedFeatures.contains('payment_machines'),
                  'payment_pango': selectedPayments.contains('pango'),
                  'payment_cellopark': selectedPayments.contains('cellopark'),
                  'payment_cash': selectedPayments.contains('cash'),
                  'payment_card': selectedPayments.contains('credit_card'),
                };
                for (final entry in legacyFlags.entries) {
                  if (known.contains(entry.key)) row[entry.key] = entry.value;
                }
                Map<String, dynamic> saved;
                if (editing) {
                  final id = parkingId(existing!);
                  if (id == null) throw StateError('חסר id לחניון');
                  final result = await supabase.from('parking_lots')
                      .update(row).eq('id', id).select().maybeSingle();
                  if (result == null) throw StateError('לא התקבל עדכון. בדקי הרשאות RLS');
                  saved = Map<String, dynamic>.from(result);
                } else {
                  row['is_active'] = true;
                  final result = await supabase.from('parking_lots').insert(row).select().single();
                  saved = Map<String, dynamic>.from(result);
                }
                // Do not claim success unless the actual saved DB row matches the choices.
                Set<String> savedValues(String key) {
                  final raw = saved[key];
                  if (raw is List) return raw.map((e) => e.toString()).toSet();
                  throw StateError('העמודה $key לא הוחזרה מ־Supabase. יש לוודא שהיא קיימת וגלויה לקריאה.');
                }
                if (!savedValues('ipi_features').containsAll(selectedFeatures) ||
                    savedValues('ipi_features').length != selectedFeatures.length ||
                    !savedValues('ipi_payment_methods').containsAll(selectedPayments) ||
                    savedValues('ipi_payment_methods').length != selectedPayments.length) {
                  throw StateError('ערכי המאפיינים או התשלומים שנשמרו ב־DB אינם תואמים לבחירה.');
                }
                if (!mounted) return;
                Navigator.of(dialogContext).pop();
                setState(() {
                  final id = parkingId(saved);
                  parkings.removeWhere((p) => parkingId(p).toString() == id.toString());
                  parkings.add(saved);
                });
                showMsg(editing ? 'פרטי החניון עודכנו ב־DB' : 'החניון נוסף ל־DB');
                await loadData(showLoading: false);
              } catch (e) {
                if (mounted) showMsg('השמירה נכשלה: $e', error: true);
                updateDialog(() => saving = false);
              }
            }

            return AlertDialog(
              title: Text(editing ? 'עריכת פרטי חניון' : 'הוספת חניון - פרטים מלאים',
                  style: const TextStyle(color: darkBlue)),
              content: SizedBox(
                width: 570,
                height: MediaQuery.sizeOf(context).height * .63,
                child: SingleChildScrollView(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('שם, מיקום ופרטי קשר', style: TextStyle(
                        color: darkBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                    ...['name_en','name_he','name_ar','city','address','latitude','longitude',
                        'phone','opening_hours','description_he'].map(field),
                    const Text('מחירים ותפוסה', style: TextStyle(
                        color: darkBlue, fontWeight: FontWeight.w900, fontSize: 16)),
                    ...['price_per_minute','daily_max','grace_minutes','total_spots',
                        'available_spots'].map(field),
                    options('מאפייני החניון', featureChoices, selectedFeatures),
                    options('אמצעי תשלום נתמכים (מידע בלבד)', paymentChoices, selectedPayments),
                    const SizedBox(height: 12),
                  ]),
                ),
              ),
              actions: [
                TextButton(onPressed: saving ? null : () => Navigator.of(dialogContext).pop(),
                    child: const Text('ביטול')),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
                  onPressed: saving ? null : save,
                  icon: const Icon(Icons.save),
                  label: Text(saving ? 'שומר...' : 'שמור ב־Supabase'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      for (final controller in values.values) { controller.dispose(); }
    }
  }

  /// Soft delete: hide lot without deleting its historical sessions/receipts.
  /// מה זה עושה? משהה חניון או מפעיל אותו מחדש, בלי למחוק היסטוריה.
  Future<void> changeParkingActive(Map<String, dynamic> parking) async {
    final isActive = parking['is_active'] != false;
    final action = isActive ? 'השהיית חניון' : 'הפעלת חניון מחדש';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('$action - ${parkingName(parking)}'),
        content: Text(isActive
            ? 'החניון יושהה ב־DB ויוסר מרשימת החניונים הפעילים. המחולל לא יוכל ליצור בו כניסות חדשות. נתונים וקבלות יישמרו לשחזור.'
            : 'החניון יחזור לרשימת החניונים הפעילים ויוכל לקבל כניסות חדשות לאחר רענון.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('ביטול')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(isActive ? 'השהה חניון' : 'הפעל חניון')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final id = parkingId(parking);
      if (id == null) throw StateError('לחניון אין id');
      final response = await supabase.from('parking_lots')
          .update({'is_active': !isActive}).eq('id', id).select().maybeSingle();
      if (response == null) throw StateError('אין הרשאת UPDATE / RLS או שהחניון לא נמצא');
      if ((response['is_active'] != false) != !isActive) {
        throw StateError('מצב החניון לא נשמר ב־DB');
      }
      setState(() {
        final idx = parkings.indexWhere((p) => parkingId(p).toString() == id.toString());
        if (idx >= 0) parkings[idx] = Map<String, dynamic>.from(response);
      });
      showMsg(isActive ? 'החניון הושהה ב־DB' : 'החניון הופעל מחדש ב־DB');
      await loadData(showLoading: false);
    } catch (e) {
      if (mounted) showMsg('שגיאה בשינוי מצב החניון: $e', error: true);
    }
  }

  /// יוצר את פאנל ניהול החניונים.
  /// מה זה עושה? מציג רשימת חניונים, חיפוש, מיון והוספה.
  Widget buildParkingsPanel() {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
          children: [
            const Text(
              'רשימת חניונים',
              style: TextStyle(
                color: darkBlue,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: openAddParkingDialog,
              icon: const Icon(Icons.add),
              label: const Text('הוסף חניון'),
              style: ElevatedButton.styleFrom(backgroundColor: blue, foregroundColor: Colors.white),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 320,
              child: modernInput(
                child: TextField(
                  controller: parkingSearchController,
                  onChanged: (value) {
                    setState(() => parkingSearchText = value);
                  },
                  decoration: InputDecoration(
                    hintText: 'חיפוש חניון לפי שם / עיר / כתובת',
                    prefixIcon: const Icon(Icons.search, color: blue),
                    suffixIcon: parkingSearchText.trim().isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, color: red),
                            onPressed: () {
                              parkingSearchController.clear();
                              setState(() => parkingSearchText = '');
                            },
                          ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 165,
              child: modernInput(
                child: DropdownButtonFormField<String>(
                  value: parkingSort,
                  isExpanded: true,
                  decoration: const InputDecoration(border: InputBorder.none),
                  items: const [
                    DropdownMenuItem(value: 'default', child: Text('רגיל')),
                    DropdownMenuItem(value: 'busy', child: Text('עמוס')),
                    DropdownMenuItem(value: 'free', child: Text('פנוי')),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => parkingSort = value);
                  },
                ),
              ),
            ),
          ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            parkingSearchText.trim().isEmpty
                ? 'מוצגים ${filteredParkings.length} חניונים'
                : 'נמצאו ${filteredParkings.length} חניונים לחיפוש: $parkingSearchText',
            style: const TextStyle(
              color: textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Expanded(child: buildParkingList()),
      ],
    );
  }

  /// יוצר את רשימת החניונים.
  /// מה זה עושה? בונה כרטיס לכל חניון עם תפוסה, מחיר וכפתורי ניהול.
  Widget buildParkingList() {
    final list = filteredParkings;

    if (list.isEmpty) {
      return emptyState('לא נמצאו חניונים לפי החיפוש', Icons.local_parking);
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final p = list[index];

        final available = availableSpots(p);
        final total = totalSpots(p);
        final occupied = occupiedSpots(p);
        final percent = occupancyPercent(p);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: percent > 0.8 ? lightRed : lightBlue,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.local_parking,
                  color: percent > 0.8 ? red : blue,
                  size: 32,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parkingName(p),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p['is_active'] == false ? textMuted : darkBlue,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        decoration: p['is_active'] == false
                            ? TextDecoration.lineThrough : TextDecoration.none,
                        decorationThickness: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('פנויים: $available | סה״כ: $total | תפוסים: $occupied'),
                    if (p['is_active'] == false) const Text('מושהה — מוסתר ללקוחות ואסור לכניסות חדשות', style: TextStyle(color: red, fontWeight: FontWeight.bold)),
                    Text(
                      '₪${readDouble(p, ['price_per_minute']).toStringAsFixed(2)} לדקה | יומי ₪${readDouble(p, ['daily_max']).toStringAsFixed(2)} | חסד ${readInt(p, ['grace_minutes', 'GRACE_MINUTES'])} דקות',
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: lightBlue,
                      color: percent > 0.8 ? red : blue,
                      minHeight: 7,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 135,
                height: 42,
                child: ElevatedButton.icon(
                  onPressed: () => openEditRatesDialog(p),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('תעריף'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: red,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'עריכת כל פרטי החניון',
                onPressed: () => openParkingDetailsDialog(p),
                icon: const Icon(Icons.tune, color: blue),
              ),
              IconButton(
                tooltip: p['is_active'] == false ? 'הפעלת חניון מחדש' : 'השהיית חניון',
                onPressed: () => changeParkingActive(p),
                icon: Icon(p['is_active'] == false ? Icons.restore : Icons.delete_outline,
                    color: red),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 42,
                width: 45,
                child: IconButton(
                  tooltip: 'הצג בגרף',
                  onPressed: () {
                    setState(() {
                      selectedChartParkingName = parkingName(p);
                      selectedPanel = AdminPanel.chart;
                    });
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.bar_chart, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// יוצר את פאנל הרכבים והחניות.
  /// מה זה עושה? בונה את אזור הרכבים עם סינונים ורשימה.
  Widget buildCarsPanel() {
    return Column(
      children: [
        buildFilters(),
        const SizedBox(height: 14),
        Expanded(child: buildCarsList()),
      ],
    );
  }

  /// יוצר את אזור הסינון של הרכבים.
  /// מה זה עושה? יוצר שדות חיפוש ובחירה לסינון רכבים.
  /// אפשר לשנות כאן את הבחירות, הכיתובים או התנאים לפי הצורך.
  Widget buildFilters() {
    final parkingNames = parkings.where((p) => p['is_active'] != false).map(parkingName).toSet().toList()..sort();

    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          SizedBox(
            width: 420,
            child: modernInput(
              child: TextField(
                controller: searchController,
                onChanged: (value) => setState(() => searchText = value),
                decoration: const InputDecoration(
                  hintText: 'חיפוש לפי רכב / לקוח / חניון',
                  prefixIcon: Icon(Icons.search, color: blue),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: modernInput(
              child: DropdownButtonFormField<String>(
                value: statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(border: InputBorder.none),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('הכול')),
                  DropdownMenuItem(value: 'parking', child: Text('חונה')),
                  DropdownMenuItem(value: 'exited', child: Text('יצא')),
                  DropdownMenuItem(value: 'paid', child: Text('שילם')),
                  DropdownMenuItem(
                    value: 'waiting_payment',
                    child: Text('ממתין'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => statusFilter = value);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 230,
            child: modernInput(
              child: DropdownButtonFormField<String>(
                value: parkingFilter,
                isExpanded: true,
                decoration: const InputDecoration(border: InputBorder.none),
                items: [
                  const DropdownMenuItem(
                    value: 'all',
                    child: Text('כל החניונים'),
                  ),
                  ...parkingNames.map(
                    (name) => DropdownMenuItem(
                      value: name,
                      child: Text(name, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => parkingFilter = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// יוצר את רשימת הרכבים המסוננת.
  /// מה זה עושה? מציג רשימת רכבים שמתאימים לסינון, או הודעה אם אין תוצאות.
  Widget buildCarsList() {
    final list = filteredSessions;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          // זה הכיתוב שמראה כמה רכבים נמצאו בחיפוש.
          'רכבים (${list.length})',
          style: const TextStyle(
            color: darkBlue,
            fontSize: 21,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: list.isEmpty
              ? emptyState('לא נמצאו רכבים', Icons.directions_car)
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final car = list[index];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: CarSessionCard(
                        car: car,
                        onAdminExit: () => adminExitCar(car),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// יוצר את פאנל הודעות הלקוחות.
  /// מה זה עושה? מציג את כל הודעות הלקוחות.
  Widget buildMessagesPanel() {
    return panel(
      title: 'הודעות לקוחות',
      icon: Icons.mark_email_unread,
      child: buildContactMessagesList(),
    );
  }

  /// מציג תקציר של הודעות הלקוחות האחרונות.
  /// מה זה עושה? מציג חלק מההודעות האחרונות בדף הסיכום.
  Widget buildMiniMessages() {
    return panel(
      title: 'הודעות אחרונות',
      icon: Icons.mark_email_unread,
      openPanel: AdminPanel.messages,
      child: buildContactMessagesList(limit: 4),
    );
  }

  /// יוצר את רשימת הודעות הלקוחות.
  /// מה זה עושה? בונה את רשימת הודעות הלקוחות עם פרטים בסיסיים.
  Widget buildContactMessagesList({int? limit}) {
    final list =
        limit == null ? contactMessages : contactMessages.take(limit).toList();

    if (list.isEmpty) {
      return emptyState('אין הודעות מלקוחות כרגע', Icons.mark_email_unread);
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, index) {
        final item = list[index];

        final name = customerNameFromMessage(item);
        final firstName = (item['first_name'] ?? '').toString().trim();
        final lastName = (item['last_name'] ?? '').toString().trim();
        final email = (item['email'] ?? '').toString();
        final phone = (item['phone'] ?? '').toString();
        final messageCarNumber = carNumberFromMessage(item);
        final subject = (item['subject'] ?? 'פנייה חדשה').toString();
        final message = (item['message'] ?? '').toString();
        final createdAt = formatDateTime(item['created_at']);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => openContactMessageDialog(item),
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lightBlue,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: lightRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: red,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: darkBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          // מציג את מספר הרכב גם ברשימה המקוצרת וגם בדף ההודעות.
                          Text(
                            'מספר רכב: ${messageCarNumber.isEmpty ? 'לא צוין' : messageCarNumber}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: darkBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (firstName.isNotEmpty || lastName.isNotEmpty)
                            Text(
                              'שם פרטי: $firstName | משפחה: $lastName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          if (createdAt.isNotEmpty)
                            Text(
                              createdAt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: textMuted,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.isEmpty ? 'ללא תוכן הודעה' : message,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (email.isNotEmpty)
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(Icons.email, size: 13, color: blue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: textMuted,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Row(
                        children: [
                          const Icon(Icons.phone, size: 13, color: blue),
                          const SizedBox(width: 4),
                          Text(
                            phone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// מה זה עושה? מציג בתפריט הצד כמה כניסות היו בתאריך שנבחר.
  Widget buildDateSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      decoration: BoxDecoration(
        color: darkBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_month, color: Colors.white, size: 20),
          const SizedBox(height: 4),
          const Text(
            'סיכום תאריך',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            formatDate(selectedDate),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 6),
          Text(
            selectedDate == null
                ? '$dateCarsCount רכבים חנו בכל התאריכים'
                : '$dateCarsCount רכבים חנו בתאריך הזה',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// מה זה עושה? מציג חמש כניסות אחרונות המתאימות לסינון.
  Widget buildRecentCars() {
    final recent = filteredSessions.take(5).toList();

    return panel(
      title: 'רכבים אחרונים',
      icon: Icons.directions_car,
      openPanel: AdminPanel.cars,
      child: recent.isEmpty
          ? emptyState('אין רכבים להצגה', Icons.directions_car)
          : ListView.builder(
              itemCount: recent.length,
              itemBuilder: (context, index) {
                final car = recent[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: CarSessionCard(
                    car: car,
                    onAdminExit: () => adminExitCar(car),
                  ),
                );
              },
            ),
    );
  }

  /// מה זה עושה? יוצר מסגרת עם כותרת ותוכן, ולעיתים מאפשר מעבר לדף אחר.
  Widget panel({
    required String title,
    required IconData icon,
    required Widget child,
    AdminPanel? openPanel,
  }) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: blue, size: 20),
              const SizedBox(width: 7),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: openPanel == null
                      ? null
                      : () => setState(() => selectedPanel = openPanel),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: openPanel == null ? darkBlue : blue,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              decoration: openPanel == null
                                  ? TextDecoration.none
                                  : TextDecoration.underline,
                            ),
                          ),
                        ),
                        if (openPanel != null) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios, color: blue, size: 13),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Expanded(child: child),
        ],
      ),
    );
  }

  /// מה זה עושה? מציג הודעה וסמל כשאין מידע להראות.
  Widget emptyState(String text, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: blue.withOpacity(0.35), size: 42),
          const SizedBox(height: 8),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: textMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// מה זה עושה? מציג מסך גרף עם חיפוש חניון ובחירת תאריך.
  Widget buildChartPanel() {
    final candidates = parkings.where((p) {
      if (p['is_active'] == false) return false;
      final q = chartSearchText.toLowerCase().trim();
      if (q.isEmpty) return true;
      return ['name_he', 'name_en', 'name_ar', 'name', 'display_name', 'city']
          .any((k) => (p[k] ?? '').toString().toLowerCase().contains(q));
    }).toList();
    final names = candidates.map(parkingName).toSet().toList()..sort();
    final dropdownValue = names.contains(selectedChartParkingName)
        ? selectedChartParkingName : null;

    return Column(children: [
      Wrap(spacing: 10, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        const Text('בחירת חניון לגרף', style: TextStyle(
          color: darkBlue, fontSize: 18, fontWeight: FontWeight.w900)),
        SizedBox(width: 240, child: TextField(
          controller: chartSearchController,
          onChanged: (v) => setState(() => chartSearchText = v),
          decoration: InputDecoration(
            hintText: 'חיפוש חניון בעברית / אנגלית',
            prefixIcon: const Icon(Icons.search, color: blue),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        )),
         // Date selection dedicated to the full-sized chart.
         OutlinedButton.icon(
           onPressed: pickDate,
           icon: const Icon(Icons.calendar_month),
           label: Text(formatDate(selectedDate)),
           style: OutlinedButton.styleFrom(
             foregroundColor: darkBlue,
             side: const BorderSide(color: blue),
           ),
         ),
         SizedBox(width: 280, child: DropdownButtonFormField<String>(
          value: dropdownValue,
          isExpanded: true,
          decoration: InputDecoration(isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
          hint: Text(names.isEmpty ? 'אין חניון תואם' : 'בחרי חניון'),
          items: names.map((name) => DropdownMenuItem<String>(
            value: name, child: Text(name, overflow: TextOverflow.ellipsis))).toList(),
          onChanged: (v) { if (v != null) setState(() => selectedChartParkingName = v); },
        )),
      ]),
      const SizedBox(height: 12),
      Expanded(child: buildHourlyChart()),
    ]);
  }

  /// מה זה עושה? מוסיף סימון צבע עם הסבר מתחת לכותרת הגרף.
  Widget _legendDot(Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 11, height: 11,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 5),
      Flexible(child: Text(label, style: const TextStyle(fontSize: 11, color: darkBlue))),
    ],
  );

  /// מה זה עושה? מצייר גרף כניסות לפי שעה. אדום מסמן שעות עם המספר הגבוה ביותר.
  /// אפשר לשנות כאן את הבחירות, הכיתובים או התנאים לפי הצורך.
  Widget buildHourlyChart() {
    final name = selectedPanel == AdminPanel.dashboard
        ? (parkings.where((p) => p['is_active'] != false).isEmpty ? '' : parkingName(parkings.where((p) => p['is_active'] != false).toList()[dashboardChartIndex % parkings.where((p) => p['is_active'] != false).length]))
        : selectedChartParkingName;
    final data = hourlyData();
    final maxValue = data.isEmpty ? 0 : data.reduce((a, b) => a > b ? a : b);
    final safeMax = maxValue == 0 ? 1 : maxValue;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(color: lightBlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
          children: [
            Expanded(
              child: Text('כניסות לפי שעה - ${name.isEmpty ? '-' : name}',
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: darkBlue, fontSize: 15, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(width: 6),
            // On the left: selected report date, or the date the chart is viewed.
            Text(
              selectedDate == null
                  ? 'עודכן: ${formatDate(DateTime.now())}'
                  : 'תאריך: ${formatDate(selectedDate)}',
              style: const TextStyle(color: textMuted, fontSize: 10, fontWeight: FontWeight.w700),
            ),
            if (selectedPanel == AdminPanel.dashboard) ...[
              IconButton(
                tooltip: 'גרף קודם',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_right, color: darkBlue),
                onPressed: () => _moveDashboardChart(-1),
              ),
              IconButton(
                tooltip: 'גרף הבא',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.chevron_left, color: darkBlue),
                onPressed: () => _moveDashboardChart(1),
              ),
            ],
          ],
        ),
        const SizedBox(height: 5),
        Wrap(spacing: 16, runSpacing: 4, children: [
          _legendDot(red, 'אדום: השעה העמוסה ביותר'),
          _legendDot(blue, 'כחול: שאר שעות הכניסה'),
        ]),
        const SizedBox(height: 8),
        Expanded(child: Row(crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(24, (i) {
            final value = data[i];
            return Expanded(child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(value > 0 ? '$value' : '',
                  style: const TextStyle(fontSize: 9, color: darkBlue)),
                const SizedBox(height: 3),
                Flexible(child: FractionallySizedBox(
                  heightFactor: value == 0 ? 0.01 : (value / safeMax).clamp(0.03, 1.0).toDouble(),
                  alignment: Alignment.bottomCenter,
                  child: Container(width: 10,
                    decoration: BoxDecoration(
                      color: value > 0 && value == maxValue ? red : blue,
                      borderRadius: BorderRadius.circular(10))),
                )),
                const SizedBox(height: 3),
                Text('$i', style: const TextStyle(fontSize: 8)),
              ],
            ));
          }),
        )),
      ]),
    );
  }
}


