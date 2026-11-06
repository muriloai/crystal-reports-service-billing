# Dados de referência | Cliente C001

Parâmetros e valores esperados para **conferência** das regras de negócio e relatórios.

---

## Documentos do cliente C001 - Aurora Restaurante & Buffet

O cliente **C001** (Aurora Restaurante & Buffet) possui 6 documentos de cobrança no primeiro semestre de 2026, vinculados ao contrato **CTR-001**:

| Documento  | Itens (BRL)              | Total Líquido |  Emissão   | Vencimento | Cancelamento | Recebido até 30/06 | Situação em 30/06/2026      |  Saldo em 30/06/2026 |
| ---------- | ------------------------ | ------------: | :--------: | :--------: | :----------: | -----------------: | --------------------------- | -------------------: |
| `DEMO-001` | 500,00 + 300,00 + 200,00 |   R$ 1.000,00 | 15/01/2026 | 15/02/2026 |      —       |        R$ 1.000,00 | Paga                        |              R$ 0,00 |
| `DEMO-002` | 600,00 + 500,00 + 400,00 |   R$ 1.500,00 | 10/05/2026 | 10/06/2026 |      —       |          R$ 600,00 | Parcialmente Paga (Vencida) |            R$ 900,00 |
| `DEMO-003` | 400,00 + 250,00 + 150,00 |     R$ 800,00 | 15/04/2026 | 15/05/2026 |      —       |            R$ 0,00 | Em Aberto (Vencida)         |            R$ 800,00 |
| `DEMO-004` | 600,00 + 400,00 + 200,00 |   R$ 1.200,00 | 15/06/2026 | 15/07/2026 |      —       |            R$ 0,00 | Em Aberto (A Vencer)        |          R$ 1.200,00 |
| `DEMO-005` | 250,00 + 150,00 + 100,00 |     R$ 500,00 | 10/06/2026 | 25/06/2026 |  12/06/2026  |            R$ 0,00 | Cancelada                   | Excluído dos válidos |
| `DEMO-006` | 400,00 + 300,00 + 200,00 |     R$ 900,00 | 20/05/2026 | 15/06/2026 |      —       |          R$ 300,00 | Parcialmente Paga (Vencida) |            R$ 600,00 |

---

## Totais por cenário de corte

### Data de corte: 30/06/2026

- Parâmetros: `p_customer_id = 1`, `p_start_date = 2026-01-01`, `p_end_date = 2026-06-30`, `p_as_of_date = 2026-06-30`
- Total faturado válido: **R$ 5.400,00**
- Total recebido até o corte: **R$ 1.900,00**
- Saldo em aberto: **R$ 3.500,00**
- Saldo vencido: **R$ 2.300,00**
- Saldo a vencer: **R$ 1.200,00**
- Cobrança cancelada: **R$ 500,00**

### Data de corte: 05/07/2026

- Parâmetros: `p_customer_id = 1`, `p_start_date = 2026-01-01`, `p_end_date = 2026-06-30`, `p_as_of_date = 2026-07-05`
- Total faturado válido: **R$ 5.400,00**
- Total recebido até o corte: **R$ 2.500,00** (inclui liquidação de R$ 600,00 da DEMO-006)
- Saldo em aberto: **R$ 2.900,00**
- Saldo vencido: **R$ 1.700,00**
- Saldo a vencer: **R$ 1.200,00**
