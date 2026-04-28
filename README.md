# AFIN

Base de projeto Flutter para gestao financeira offline-first com SQLite e backup manual no Google Drive.

## Arquitetura

- `lib/models`: entidades de dominio.
- `lib/services`: banco local e integracao com o Google Drive.
- `lib/view`: telas iniciais de login, dashboard, clientes e financeiro.

## Regras implementadas

- Persistencia local com SQLite (`afin.db`).
- Backup manual apenas quando o usuario solicitar.
- Uso do escopo `appDataFolder` do Google Drive.
- Dados pessoais reduzidos ao minimo necessario para a operacao.

## Dependencias principais

- `sqflite`
- `google_sign_in`
- `googleapis`
- `connectivity_plus`
- `mask_text_input_formatter`

## Observacoes para Android

- Configurar projeto Firebase/Google Cloud com OAuth para Android.
- Habilitar Google Drive API no projeto.
- Registrar SHA-1/SHA-256 do app.
- Adicionar `google-services.json` se optar por Firebase como apoio de autenticacao.

## LGPD

- Coletar apenas nome, documento e telefone.
- Exibir termo/aviso de finalidade no login ou cadastro.
- Manter backup na pasta oculta do app no Drive.
- Permitir restauracao apenas mediante acao explicita do usuario.
