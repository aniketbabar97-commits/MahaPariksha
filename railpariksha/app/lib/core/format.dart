/// Counts with thousands separators ("6870" -> "6,870"), matching the "1,000 questions" /
/// "50,000+" style already used elsewhere in the app.
String fmtCount(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
