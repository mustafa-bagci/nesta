/// Firestore ve yerel depolama için ortak serileştirme yardımcıları.
///
/// Tarihler platformdan bağımsız kalmak için epoch milisaniye olarak saklanır.
library;

DateTime? dateFrom(Object? v) => v == null
    ? null
    : DateTime.fromMillisecondsSinceEpoch((v as num).toInt(), isUtc: true);

int? millis(DateTime? d) => d?.millisecondsSinceEpoch;

Map<String, Object?> mapFrom(Object? v) =>
    v == null ? <String, Object?>{} : Map<String, Object?>.from(v as Map);

T enumById<T extends Enum>(
    List<T> values, Object? id, T fallback, String Function(T) idOf) {
  for (final v in values) {
    if (idOf(v) == id) return v;
  }
  return fallback;
}
