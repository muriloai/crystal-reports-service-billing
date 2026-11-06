# Resultados de validação da base de dados

Execução do script de integridade e regras de negócio [`database/04-validate.sql`](file:///c:/GITHUB/crystal-reports-service-billing/database/04-validate.sql) no PostgreSQL.

---

## Log de execução

```text
psql:database/04-validate.sql: NOTA:  Executando verificações de integridade do banco...
psql:database/04-validate.sql: NOTA:  [OK] Volume de registros validado (3504 linhas).
psql:database/04-validate.sql: NOTA:  [OK] Todas as 600 cobranças possuem 3 itens.
psql:database/04-validate.sql: NOTA:  [OK] Distribuição de status no corte: 360 pagas, 120 parciais, 90 em aberto, 30 canceladas.
psql:database/04-validate.sql: NOTA:  [OK] 12 pagamentos posteriores ao corte confirmados.
psql:database/04-validate.sql: NOTA:  [OK] Consistência de alocações e saldos confirmada.
psql:database/04-validate.sql: NOTA:  [OK] Integridade referencial e datas validadas.
psql:database/04-validate.sql: NOTA:  [OK] Cálculos de referência de C001 aprovados.
psql:database/04-validate.sql: NOTA:  [OK] Cliente C040 sem movimentação confirmado.
psql:database/04-validate.sql: NOTA:  Validação concluída com sucesso.
```

---

## Contagens por tabela

| Tabela                        | Registros |
| ----------------------------- | --------: |
| `billing.customers`           |        40 |
| `billing.product_categories`  |         5 |
| `billing.products`            |        15 |
| `billing.contracts`           |        60 |
| `billing.invoices`            |       600 |
| `billing.invoice_items`       |     1.800 |
| `billing.payments`            |       492 |
| `billing.payment_allocations` |       492 |
| **Total**                     | **3.504** |

---

## Distribuição de cobranças por situação na data de corte (30/06/2026)

| Situação              | Quantidade | Descrição                                                                  |
| --------------------- | ---------: | -------------------------------------------------------------------------- |
| **Paga**              |        360 | Cobranças com 100% do saldo liquidado até 30/06/2026                       |
| **Parcialmente Paga** |        120 | Cobranças com pagamento parcial até 30/06/2026 (12 quitadas em 05/07/2026) |
| **Em Aberto**         |         90 | Cobranças sem pagamento registrado                                         |
| **Cancelada**         |         30 | Cobranças canceladas antes ou na data de corte                             |
| **Total**             |    **600** | Total de cobranças emitidas no primeiro semestre de 2026                   |

---

## Conferência do cliente C001 - Aurora Restaurante & Buffet

### Posição em 30/06/2026

| Documento  | Valor Itens     |       Total | Recebido até 30/06 | Vencimento | Situação          |       Saldo |
| ---------- | --------------- | ----------: | -----------------: | :--------: | ----------------- | ----------: |
| `DEMO-001` | 500 + 300 + 200 | R$ 1.000,00 |        R$ 1.000,00 | 15/02/2026 | Paga              |     R$ 0,00 |
| `DEMO-002` | 600 + 500 + 400 | R$ 1.500,00 |          R$ 600,00 | 10/06/2026 | Parcialmente Paga |   R$ 900,00 |
| `DEMO-003` | 400 + 250 + 150 |   R$ 800,00 |            R$ 0,00 | 15/05/2026 | Em Aberto         |   R$ 800,00 |
| `DEMO-004` | 600 + 400 + 200 | R$ 1.200,00 |            R$ 0,00 | 15/07/2026 | Em Aberto         | R$ 1.200,00 |
| `DEMO-005` | 250 + 150 + 100 |   R$ 500,00 |            R$ 0,00 | 25/06/2026 | Cancelada (12/06) |    Excluído |
| `DEMO-006` | 400 + 300 + 200 |   R$ 900,00 |          R$ 300,00 | 15/06/2026 | Parcialmente Paga |   R$ 600,00 |

- Total faturado válido: **R$ 5.400,00**
- Total recebido até 30/06: **R$ 1.900,00**
- Saldo em aberto: **R$ 3.500,00**
- Saldo vencido: **R$ 2.300,00** (DEMO-002: 900 + DEMO-003: 800 + DEMO-006: 600)
- Saldo a vencer: **R$ 1.200,00** (DEMO-004)
- Cobrança cancelada: **R$ 500,00** (DEMO-005)

### Posição em 05/07/2026

- Total recebido: **R$ 2.500,00** (inclui liquidação de R$ 600,00 da DEMO-006)
- Saldo em aberto: **R$ 2.900,00**
- Saldo vencido: **R$ 1.700,00**
- Saldo a vencer: **R$ 1.200,00**
