# AFIN

Base de projeto Flutter para gestao financeira offline-first com SQLite e backup manual

## Arquitetura

- `lib/models`: entidades de dominio.
- `lib/services`: banco local e integracao com o Google Drive.
- `lib/view`: telas iniciais de login, dashboard, clientes e financeiro.

## Regras implementadas

- Persistencia local com SQLite (`afin.db`).
- Backup manual apenas quando o usuario solicitar.
- Dados pessoais reduzidos ao minimo necessario para a operacao.

## Dependencias principais

- `sqflite`
- `connectivity_plus`
- `mask_text_input_formatter`

## LGPD

- Coletar apenas nome, documento e telefone.
- Manter backup na pasta oculta do app
- Permitir restauracao apenas mediante acao explicita do usuario.
