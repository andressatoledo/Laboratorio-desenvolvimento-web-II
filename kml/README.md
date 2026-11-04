# KML – Quilômetros e lucratividade

App Flutter (Dart) + SQLite para motoristas autônomos controlarem viagens, abastecimentos e despesas.

## Como rodar
1. `flutter create kml` e entre na pasta.
2. Substitua a pasta `lib/` e o `pubspec.yaml` pelos deste projeto (apague `test/widget_test.dart`, que referencia o app de exemplo).
3. `flutter pub get` e `flutter run` (Android/iOS).

## Estrutura
- `lib/core` tema, formatação, validações
- `lib/data` esquema SQLite, modelos, repositório (todas as consultas)
- `lib/state` estado global (filtro e veículos)
- `lib/widgets` componentes compartilhados
- `lib/screens` painel, viagens, abastecimentos, despesas, configurações (tema, veículos, cadastros)

## Regras de integridade
- Dinheiro em centavos (inteiro); datas ISO.
- Chaves estrangeiras ativas, CHECKs e triggers no banco.
- Abastecimento gera a despesa de combustível na mesma transação (sem lançamento duplo).
- Consumo (km/L) pelo método tanque cheio a tanque cheio.

## Tema e filtros
- Configurações (engrenagem no Painel): tema Claro, Escuro ou Sistema, salvo no aparelho (`shared_preferences`).
- Cores que mudam com o tema ficam em `KmlColors` (`context.kml.*`); não use cores fixas nas telas.
- Filtro de período/veículo é global e vale para as 4 abas; "Limpar filtros" volta ao mês atual.
