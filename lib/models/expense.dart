
enum ExpenseCategory { academica, transporte, alojamiento, otros }

class Expense {
  final String id;
  final String descripcion;
  final double monto;
  final DateTime fecha;
  final ExpenseCategory categoria;

  const Expense({
    required this.id,
    required this.descripcion,
    required this.monto,
    required this.fecha,
    required this.categoria,
  });

  Expense copyWith({
    String? id,
    String? descripcion,
    double? monto,
    DateTime? fecha,
    ExpenseCategory? categoria,
  }) => Expense(
        id: id ?? this.id,
        descripcion: descripcion ?? this.descripcion,
        monto: monto ?? this.monto,
        fecha: fecha ?? this.fecha,
        categoria: categoria ?? this.categoria,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'descripcion': descripcion,
        'monto': monto,
        'fecha': fecha.toIso8601String(),
        'categoria': categoria.name,
      };

  static Expense fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'] as String,
        descripcion: json['descripcion'] as String,
        monto: (json['monto'] as num).toDouble(),
        fecha: DateTime.parse(json['fecha'] as String),
        categoria: ExpenseCategory.values.firstWhere((e) => e.name == json['categoria']),
      );
}
