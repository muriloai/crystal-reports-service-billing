# Service Billing | Crystal Reports

É um projeto de relatórios corporativos de faturamento, liquidação financeira e contas a receber desenvolvidos com SAP Crystal Reports 2020 conectados ao PostgreSQL via driver ODBC de 64 bits.

## Qual o objetivo deste projeto?

Este projeto existe para demonstrar um pouco de minha experiência com estes relatórios criados em Crystal Reports e que algumas empresas ainda, atualmente, os usam tanto dentro de um sistema quanto fora, para obter balanços confiáveis sobre os dados de negócio.

## Resumo do que comporta este projeto

O sistema compreende a modelagem relacional do ciclo de vendas e distribuição comercial atacadista, consultas parametrizadas, visões de consolidação financeira por data de corte, categorização de receitas e regras de negócio para apuração de saldos, amortizações e faixas de atraso.

---

## Documentação técnica

- [Guia de Configuração e Ambiente (`docs/setup.md`)](docs/setup.md)
  Pré-requisitos de instalação, configuração da DSN ODBC x64 e procedimentos de conexão no Designer.

- [Modelo de Dados e Regras (`docs/data-model.md`)](docs/data-model.md)
  Entidades, granularidades, cálculo de saldos por corte, faixas de atraso e dicionário de dados.

- [Resultados de Validação (`docs/validation-results.md`)](docs/validation-results.md)
  Evidência de execução e aprovação dos testes de integridade.

- [Scripts de Banco de Dados (`database/`)](database/)
  Definição de tabelas, chaves, carga de dados, views analíticas e validações.

- [Dados de Referência (`samples/reference/`)](samples/reference/)
  Parâmetros e valores esperados para conferência dos relatórios.

- [Identidade Visual e Ativos (`docs/images/`)](docs/images/)
  Logotipos institucionais transparentes e ativos gráficos para os cabeçalhos.

- [Guia de Construção dos Relatórios (`reports/README.md`)](reports/README.md)
  Passo a passo para criação das seções, agrupamentos, fórmulas e gráficos no Crystal Reports 2020.

---

## Contexto de negócio

O modelo atende à operação da empresa **Horizonte Distribuidora de Alimentos & Bebidas**, empresa atacadista focada no canal Food Service (restaurantes, pizzarias, padarias, confeitarias, hotéis e empórios gastronômicos).

O catálogo comercial contempla **cinco** linhas de produtos: mercearia seca, laticínios e frios, bebidas e sucos, embalagens/descartáveis e produtos de limpeza profissional.

O **fluxo** cobre:

- Acordos comerciais de fornecimento com clientes;
- emissão de faturas detalhadas por produto comercializado com unidades de medida (`FD`, `GL`, `UN`, `CX`)
- controle de recebimentos com alocação financeira.

O conjunto de relatórios aqui demonstrados atende a **quatro** necessidades centrais de gestão:

1. **Demonstrativo do Cliente**
   Discriminação dos itens faturados, status de cancelamento e posição de pagamentos alocados até uma data de corte informada.

2. **Posição de Recebíveis**
   Totalização de saldos em aberto e vencidos na data de corte, classificados por faixas temporais de atraso (a vencer, 1 a 30 dias, 31 a 60 dias, 61 a 90 dias e acima de 90 dias).

3. **Distribuição de Receita**
   Faturamento líquido consolidado mês a mês por categoria de produto ao longo do semestre.

4. **Rastreabilidade Financeira**
   Segregação rigorosa entre competência de emissão e data efetiva de liquidação, garantindo que pagamentos posteriores à data de corte não alterem a posição histórica apurada.

---

## Relatórios do sistema

| Relatório                            | Finalidade Operacional                                                                                | Arquivo                                               | Status             |
| ------------------------------------ | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------- | ------------------ |
| **Demonstrativo por cliente**        | Detalhamento de faturas, subtotais por acordo comercial e sub-relatório de recebimentos vinculados.   | `reports/customer-statement/customer-statement.rpt`   | Em desenvolvimento |
| **Contas a receber na dta de corte** | Análise de aging de documentos em aberto e vencidos, com filtro opcional de títulos em atraso.        | `reports/accounts-receivable/accounts-receivable.rpt` | Em desenvolvimento |
| **Resumo mensal por categoria**      | Matriz cross-tab e gráfico de distribuição da receita líquida por categoria de produto e competência. | `reports/monthly-revenue/monthly-revenue.rpt`         | Em desenvolvimento |

---

## Resumo da base de dados

Busquei trazer um cenário bem interessante com uma base populada, de forma consistente por scripts versionados, somando 3.504 registros, contendo os seguintes itens:

- **40 Clientes (`customers`)**
  Estabelecimentos do setor gastronômico e hoteleiro (C001 com casos de conferência e C040 sem faturamento).

- **5 Categorias de Produto (`product_categories`)**
  Mercearia Seca, Laticínios e Frios, Bebidas e Sucos, Embalagens e Descartáveis, Higiene e Limpeza Profissional.

- **15 Produtos (`products`)**
  3 mercadorias por categoria com preços de referência de atacado e unidades de medida.

- **60 Contratos (`contracts`)**
  Acordos comerciais de fornecimento contínuo.

- **600 Cobranças (`invoices`)**
  Faturas emitidas de janeiro a junho de 2026 (360 pagas, 120 parciais, 90 em aberto e 30 canceladas no corte de 30/06).

- **1.800 Itens de Cobrança (`invoice_items`)**
  3 itens por cobrança com cálculo de bruto, desconto e líquido.

- **492 Pagamentos (`payments`)**
  480 liquidações até 30/06/2026 e 12 liquidações em 05/07/2026.

- **492 Alocações (`payment_allocations`)**
  Vinculação entre pagamento e fatura correspondente.

---

## Ambiente homologado

Versões de software e componentes validados localmente:

- **Sistema Operacional:** Microsoft Windows (x64)
- **Gerenciador de Banco de Dados:** PostgreSQL 18.6 (x86_64-windows, 64-bit)
- **Driver de Conectividade:** psqlODBC 13.02.0000 64-bit (`PostgreSQL ODBC Driver(UNICODE)`)
- **Ferramenta de Relatórios:** SAP Crystal Reports 2020 SP04 (versão 14.3.4.5284, 64-bit)
- **Nome da Fonte de Dados (DSN):** `CrystalServiceBilling` (User DSN de 64 bits)
- **Base de Dados:** `crystal_service_billing` (Codificação de caracteres: UTF-8)
- **Schema de Trabalho:** `billing`

Instruções completas para configuração de rede, criação da DSN e conexão com o Crystal Reports constam no [Guia de Configuração](docs/setup.md).

---

## Propriedade intelectual

SAP e SAP Crystal Reports são marcas registradas da SAP SE na Alemanha e em outros países. Este projeto não possui afiliação com a SAP SE e não redistribui softwares, bibliotecas ou instaladores de terceiros.
