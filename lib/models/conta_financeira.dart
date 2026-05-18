class ContaFinanceira {
  final int? id;
  final int clienteId;
  final String tipo;
  final String grupo;
  final String descricao;
  final double valor;
  final String dataEmissao;
  final String dataVencimento;
  final String? dataPagamento;
  final String status;
  final double? valorRecebido;
  final String? fotoPath;

  const ContaFinanceira({
    this.id,
    required this.clienteId,
    required this.tipo,
    required this.grupo,
    required this.descricao,
    required this.valor,
    required this.dataEmissao,
    required this.dataVencimento,
    required this.status,
    this.dataPagamento,
    this.valorRecebido,
    this.fotoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente_id': clienteId,
      'tipo': tipo,
      'grupo': grupo,
      'descricao': descricao,
      'valor': valor,
      'data_emissao': dataEmissao,
      'data_vencimento': dataVencimento,
      'data_pagamento': dataPagamento,
      'status': status,
      'valor_recebido': valorRecebido,
      'foto_path': fotoPath,
    };
  }

  factory ContaFinanceira.fromMap(Map<String, dynamic> map) {
    return ContaFinanceira(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      tipo: map['tipo'] as String,
      grupo: map['grupo'] as String? ?? 'Sem grupo',
      descricao: map['descricao'] as String? ?? '',
      valor: (map['valor'] as num).toDouble(),
      dataEmissao: map['data_emissao'] as String,
      dataVencimento:
          map['data_vencimento'] as String? ?? map['data_emissao'] as String,
      dataPagamento: map['data_pagamento'] as String?,
      status: map['status'] as String,
      valorRecebido: (map['valor_recebido'] as num?)?.toDouble(),
      fotoPath: map['foto_path'] as String?,
    );
  }
}
