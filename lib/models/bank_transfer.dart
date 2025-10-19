class BankTransfer {
  final String id;
  final String fromAccountId;
  final String toAlias;
  final String toNumberMasked;
  final String currency;
  final double amount;
  final DateTime createdAt;

  const BankTransfer({
    required this.id,
    required this.fromAccountId,
    required this.toAlias,
    required this.toNumberMasked,
    required this.currency,
    required this.amount,
    required this.createdAt,
  });
}


