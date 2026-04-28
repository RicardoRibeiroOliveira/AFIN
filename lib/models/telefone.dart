class Telefone {
  final int? id;
  final int clienteId;
  final String numero;

  const Telefone({
    this.id,
    required this.clienteId,
    required this.numero,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'numero': numero,
    };
  }

  factory Telefone.fromMap(Map<String, dynamic> map) {
    return Telefone(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      numero: map['numero'] as String,
    );
  }
}
