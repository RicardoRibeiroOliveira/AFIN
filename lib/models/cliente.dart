class Cliente {
  final int? id;
  final String nome;
  final String documento;
  final String tipoPessoa;

  const Cliente({
    this.id,
    required this.nome,
    required this.documento,
    required this.tipoPessoa,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nome': nome,
      'documento': documento,
      'tipo_pessoa': tipoPessoa,
    };
  }

  factory Cliente.fromMap(Map<String, dynamic> map) {
    return Cliente(
      id: map['id'] as int?,
      nome: map['nome'] as String,
      documento: map['documento'] as String,
      tipoPessoa: map['tipo_pessoa'] as String,
    );
  }
}
