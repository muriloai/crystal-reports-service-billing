-- Testes de integridade referencial e validação de regras de faturamento

DO $$
DECLARE
    v_total_rows INTEGER;
    v_cnt_customers INTEGER;
    v_cnt_categories INTEGER;
    v_cnt_products INTEGER;
    v_cnt_contracts INTEGER;
    v_cnt_invoices INTEGER;
    v_cnt_items INTEGER;
    v_cnt_payments INTEGER;
    v_cnt_allocations INTEGER;
    
    v_paid_count INTEGER;
    v_partial_count INTEGER;
    v_unpaid_count INTEGER;
    v_cancelled_count INTEGER;
    
    v_post_cutoff_payments INTEGER;
    v_overallocated_payments INTEGER;
    v_overpaid_invoices INTEGER;
    v_mismatched_customers INTEGER;
    v_invalid_dates INTEGER;
    v_non_3_items INTEGER;
    v_c040_invoices INTEGER;
    
    v_c001_total_valido NUMERIC(14,2);
    v_c001_recebido NUMERIC(14,2);
    v_c001_saldo NUMERIC(14,2);
    v_c001_vencido NUMERIC(14,2);
    v_c001_a_vencer NUMERIC(14,2);
    v_c001_cancelado NUMERIC(14,2);
    
    v_c001_recebido_julho NUMERIC(14,2);
    v_c001_saldo_julho NUMERIC(14,2);
    v_c001_vencido_julho NUMERIC(14,2);
    v_c001_a_vencer_julho NUMERIC(14,2);
BEGIN
    RAISE NOTICE 'Executando verificações de integridade do banco...';

    -- Contagem de registros por tabela
    SELECT count(*) INTO v_cnt_customers FROM billing.customers;
    SELECT count(*) INTO v_cnt_categories FROM billing.product_categories;
    SELECT count(*) INTO v_cnt_products FROM billing.products;
    SELECT count(*) INTO v_cnt_contracts FROM billing.contracts;
    SELECT count(*) INTO v_cnt_invoices FROM billing.invoices;
    SELECT count(*) INTO v_cnt_items FROM billing.invoice_items;
    SELECT count(*) INTO v_cnt_payments FROM billing.payments;
    SELECT count(*) INTO v_cnt_allocations FROM billing.payment_allocations;

    IF v_cnt_customers <> 40 OR v_cnt_categories <> 5 OR v_cnt_products <> 15 OR
       v_cnt_contracts <> 60 OR v_cnt_invoices <> 600 OR v_cnt_items <> 1800 OR
       v_cnt_payments <> 492 OR v_cnt_allocations <> 492 THEN
        RAISE EXCEPTION 'Falha na contagem individual de tabelas.';
    END IF;

    v_total_rows := v_cnt_customers + v_cnt_categories + v_cnt_products + 
                    v_cnt_contracts + v_cnt_invoices + v_cnt_items + 
                    v_cnt_payments + v_cnt_allocations;

    IF v_total_rows <> 3504 THEN
        RAISE EXCEPTION 'Total geral divergente. Esperado: 3504, obtido: %', v_total_rows;
    END IF;
    RAISE NOTICE '[OK] Volume de registros validado (% linhas).', v_total_rows;

    -- Itens por cobrança
    SELECT count(*) INTO v_non_3_items
    FROM (
        SELECT invoice_id
        FROM billing.invoice_items
        GROUP BY invoice_id
        HAVING count(*) <> 3
    ) sub;

    IF v_non_3_items > 0 THEN
        RAISE EXCEPTION 'Existem cobranças com quantidade irregular de itens.';
    END IF;
    RAISE NOTICE '[OK] Todas as 600 cobranças possuem 3 itens.';

    -- Situações das cobranças na data de corte (30/06/2026)
    WITH paid_cut AS (
        SELECT pa.invoice_id, sum(pa.allocated_amount) AS paid_amt
        FROM billing.payment_allocations pa
        JOIN billing.payments p ON p.id = pa.payment_id
        WHERE p.payment_date <= '2026-06-30'
        GROUP BY pa.invoice_id
    ),
    situations AS (
        SELECT 
            vt.invoice_id,
            CASE 
                WHEN vt.cancelled_on IS NOT NULL AND vt.cancelled_on <= '2026-06-30' THEN 'CANCELLED'
                WHEN COALESCE(pc.paid_amt, 0.00) >= vt.net_total THEN 'PAID'
                WHEN COALESCE(pc.paid_amt, 0.00) > 0.00 THEN 'PARTIAL'
                ELSE 'UNPAID'
            END AS sit
        FROM billing.v_invoice_totals vt
        LEFT JOIN paid_cut pc ON pc.invoice_id = vt.invoice_id
    )
    SELECT 
        count(*) FILTER (WHERE sit = 'PAID'),
        count(*) FILTER (WHERE sit = 'PARTIAL'),
        count(*) FILTER (WHERE sit = 'UNPAID'),
        count(*) FILTER (WHERE sit = 'CANCELLED')
    INTO v_paid_count, v_partial_count, v_unpaid_count, v_cancelled_count
    FROM situations;

    IF v_paid_count <> 360 OR v_partial_count <> 120 OR v_unpaid_count <> 90 OR v_cancelled_count <> 30 THEN
        RAISE EXCEPTION 'Divergência nas situações das cobranças em 30/06/2026.';
    END IF;
    RAISE NOTICE '[OK] Distribuição de status no corte: 360 pagas, 120 parciais, 90 em aberto, 30 canceladas.';

    -- Pagamentos posteriores ao corte
    SELECT count(*) INTO v_post_cutoff_payments
    FROM billing.payments
    WHERE payment_date > '2026-06-30';

    IF v_post_cutoff_payments <> 12 THEN
        RAISE EXCEPTION 'Divergência em pagamentos posteriores ao corte.';
    END IF;
    RAISE NOTICE '[OK] 12 pagamentos posteriores ao corte confirmados.';

    -- Integridade de pagamentos e alocações
    SELECT count(*) INTO v_overallocated_payments
    FROM (
        SELECT p.id
        FROM billing.payments p
        JOIN billing.payment_allocations pa ON pa.payment_id = p.id
        GROUP BY p.id, p.amount
        HAVING sum(pa.allocated_amount) > p.amount
    ) sub;

    IF v_overallocated_payments > 0 THEN
        RAISE EXCEPTION 'Existem pagamentos com alocação superior ao montante recebido.';
    END IF;

    SELECT count(*) INTO v_overpaid_invoices
    FROM (
        SELECT vt.invoice_id
        FROM billing.v_invoice_totals vt
        JOIN billing.payment_allocations pa ON pa.invoice_id = vt.invoice_id
        GROUP BY vt.invoice_id, vt.net_total
        HAVING sum(pa.allocated_amount) > vt.net_total
    ) sub;

    IF v_overpaid_invoices > 0 THEN
        RAISE EXCEPTION 'Existem cobranças sobrepagas.';
    END IF;
    RAISE NOTICE '[OK] Consistência de alocações e saldos confirmada.';

    -- Correspondência de cliente
    SELECT count(*) INTO v_mismatched_customers
    FROM billing.payment_allocations pa
    JOIN billing.payments p ON p.id = pa.payment_id
    JOIN billing.invoices i ON i.id = pa.invoice_id
    JOIN billing.contracts ct ON ct.id = i.contract_id
    WHERE p.customer_id <> ct.customer_id;

    IF v_mismatched_customers > 0 THEN
        RAISE EXCEPTION 'Inconsistência de titularidade entre pagamento e cobrança.';
    END IF;

    -- Validação de datas
    SELECT count(*) INTO v_invalid_dates
    FROM billing.invoices i
    JOIN billing.payment_allocations pa ON pa.invoice_id = i.id
    JOIN billing.payments p ON p.id = pa.payment_id
    WHERE p.payment_date < i.issue_date OR i.due_date < i.issue_date;

    IF v_invalid_dates > 0 THEN
        RAISE EXCEPTION 'Inconsistência cronológica de datas.';
    END IF;
    RAISE NOTICE '[OK] Integridade referencial e datas validadas.';

    -- Conferência do cliente C001
    SELECT 
        COALESCE(SUM(vt.net_total) FILTER (WHERE vt.cancelled_on IS NULL OR vt.cancelled_on > '2026-06-30'), 0.00),
        COALESCE(SUM(vt.net_total) FILTER (WHERE vt.cancelled_on IS NOT NULL AND vt.cancelled_on <= '2026-06-30'), 0.00)
    INTO v_c001_total_valido, v_c001_cancelado
    FROM billing.v_invoice_totals vt
    WHERE vt.customer_id = 1;

    SELECT COALESCE(SUM(pa.allocated_amount), 0.00)
    INTO v_c001_recebido
    FROM billing.payment_allocations pa
    JOIN billing.payments p ON p.id = pa.payment_id
    JOIN billing.invoices i ON i.id = pa.invoice_id
    JOIN billing.contracts ct ON ct.id = i.contract_id
    WHERE ct.customer_id = 1
      AND (i.cancelled_on IS NULL OR i.cancelled_on > '2026-06-30')
      AND p.payment_date <= '2026-06-30';

    v_c001_saldo := v_c001_total_valido - v_c001_recebido;

    SELECT 
        COALESCE(SUM(ar.balance_at_cutoff) FILTER (WHERE ar.days_overdue > 0), 0.00),
        COALESCE(SUM(ar.balance_at_cutoff) FILTER (WHERE ar.days_overdue = 0), 0.00)
    INTO v_c001_vencido, v_c001_a_vencer
    FROM billing.fn_accounts_receivable('2026-06-30', FALSE) ar
    WHERE ar.customer_id = 1;

    IF v_c001_total_valido <> 5400.00 OR v_c001_recebido <> 1900.00 OR 
       v_c001_saldo <> 3500.00 OR v_c001_vencido <> 2300.00 OR 
       v_c001_a_vencer <> 1200.00 OR v_c001_cancelado <> 500.00 THEN
        RAISE EXCEPTION 'Valores divergentes para o cliente C001 em 30/06/2026.';
    END IF;

    SELECT COALESCE(SUM(pa.allocated_amount), 0.00)
    INTO v_c001_recebido_julho
    FROM billing.payment_allocations pa
    JOIN billing.payments p ON p.id = pa.payment_id
    JOIN billing.invoices i ON i.id = pa.invoice_id
    JOIN billing.contracts ct ON ct.id = i.contract_id
    WHERE ct.customer_id = 1
      AND (i.cancelled_on IS NULL OR i.cancelled_on > '2026-07-05')
      AND p.payment_date <= '2026-07-05';

    v_c001_saldo_julho := v_c001_total_valido - v_c001_recebido_julho;

    SELECT 
        COALESCE(SUM(ar.balance_at_cutoff) FILTER (WHERE ar.days_overdue > 0), 0.00),
        COALESCE(SUM(ar.balance_at_cutoff) FILTER (WHERE ar.days_overdue = 0), 0.00)
    INTO v_c001_vencido_julho, v_c001_a_vencer_julho
    FROM billing.fn_accounts_receivable('2026-07-05', FALSE) ar
    WHERE ar.customer_id = 1;

    IF v_c001_recebido_julho <> 2500.00 OR v_c001_saldo_julho <> 2900.00 OR 
       v_c001_vencido_julho <> 1700.00 OR v_c001_a_vencer_julho <> 1200.00 THEN
        RAISE EXCEPTION 'Valores divergentes para o cliente C001 em 05/07/2026.';
    END IF;
    RAISE NOTICE '[OK] Cálculos de referência de C001 aprovados.';

    -- Cliente sem movimentação
    SELECT count(*) INTO v_c040_invoices
    FROM billing.invoices i
    JOIN billing.contracts ct ON ct.id = i.contract_id
    WHERE ct.customer_id = 40;

    IF v_c040_invoices <> 0 THEN
        RAISE EXCEPTION 'Cliente C040 não deveria possuir cobranças.';
    END IF;
    RAISE NOTICE '[OK] Cliente C040 sem movimentação confirmado.';

    RAISE NOTICE 'Validação concluída com sucesso.';
END $$;
