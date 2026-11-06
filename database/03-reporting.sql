-- Views analíticas e funções de agregação

-- Detalhe de itens faturados com dados de contrato e cliente
CREATE OR REPLACE VIEW billing.v_invoice_lines AS
SELECT 
    ii.id AS item_id,
    i.id AS invoice_id,
    i.number AS invoice_number,
    c.id AS customer_id,
    c.code AS customer_code,
    c.name AS customer_name,
    ct.id AS contract_id,
    ct.code AS contract_code,
    ct.description AS contract_description,
    pc.id AS category_id,
    pc.name AS category_name,
    p.id AS product_id,
    p.code AS product_code,
    p.name AS product_name,
    ii.unit_of_measure,
    ii.description AS item_description,
    i.issue_date,
    i.due_date,
    i.cancelled_on,
    ii.quantity,
    ii.unit_price,
    ROUND(ii.quantity * ii.unit_price, 2) AS gross_amount,
    ii.discount_amount,
    ROUND(ii.quantity * ii.unit_price, 2) - ii.discount_amount AS net_amount
FROM billing.invoice_items ii
JOIN billing.invoices i ON i.id = ii.invoice_id
JOIN billing.contracts ct ON ct.id = i.contract_id
JOIN billing.customers c ON c.id = ct.customer_id
JOIN billing.products p ON p.id = ii.product_id
JOIN billing.product_categories pc ON pc.id = p.category_id;

COMMENT ON VIEW billing.v_invoice_lines IS 'Itens faturados com dados de cliente, contrato, produto e valores calculados';

-- Totais consolidados por cobrança
CREATE OR REPLACE VIEW billing.v_invoice_totals AS
SELECT 
    i.id AS invoice_id,
    i.number AS invoice_number,
    ct.customer_id,
    c.code AS customer_code,
    c.name AS customer_name,
    i.contract_id,
    ct.code AS contract_code,
    ct.description AS contract_description,
    i.issue_date,
    i.due_date,
    i.cancelled_on,
    COUNT(ii.id) AS item_count,
    ROUND(SUM(ii.quantity * ii.unit_price), 2) AS gross_total,
    ROUND(SUM(ii.discount_amount), 2) AS discount_total,
    ROUND(SUM(ROUND(ii.quantity * ii.unit_price, 2) - ii.discount_amount), 2) AS net_total
FROM billing.invoices i
JOIN billing.contracts ct ON ct.id = i.contract_id
JOIN billing.customers c ON c.id = ct.customer_id
JOIN billing.invoice_items ii ON ii.invoice_id = i.id
GROUP BY 
    i.id, i.number, ct.customer_id, c.code, c.name, 
    i.contract_id, ct.code, ct.description, i.issue_date, i.due_date, i.cancelled_on;

COMMENT ON VIEW billing.v_invoice_totals IS 'Totais consolidados por documento de cobrança';

-- Alocações de recebimento por cobrança
CREATE OR REPLACE VIEW billing.v_payment_allocations AS
SELECT 
    pa.id AS allocation_id,
    p.id AS payment_id,
    pa.invoice_id,
    i.number AS invoice_number,
    p.customer_id,
    c.code AS customer_code,
    c.name AS customer_name,
    p.payment_date,
    p.method,
    p.reference,
    p.amount AS payment_total_amount,
    pa.allocated_amount
FROM billing.payment_allocations pa
JOIN billing.payments p ON p.id = pa.payment_id
JOIN billing.invoices i ON i.id = pa.invoice_id
JOIN billing.customers c ON c.id = p.customer_id;

COMMENT ON VIEW billing.v_payment_allocations IS 'Histórico de alocações e pagamentos por cobrança';

-- Demonstrativo do cliente: linhas de cobrança e saldos na data de corte
CREATE OR REPLACE FUNCTION billing.fn_customer_statement_lines(
    p_customer_id INTEGER,
    p_start_date DATE,
    p_end_date DATE,
    p_as_of_date DATE
)
RETURNS TABLE (
    item_id INTEGER,
    invoice_id INTEGER,
    invoice_number VARCHAR(30),
    contract_id INTEGER,
    contract_code VARCHAR(30),
    contract_description VARCHAR(255),
    category_id INTEGER,
    category_name VARCHAR(100),
    product_id INTEGER,
    product_code VARCHAR(30),
    product_name VARCHAR(150),
    unit_of_measure VARCHAR(10),
    item_description VARCHAR(255),
    issue_date DATE,
    due_date DATE,
    cancelled_on DATE,
    is_cancelled_at_cutoff BOOLEAN,
    quantity NUMERIC(10,2),
    unit_price NUMERIC(14,2),
    gross_amount NUMERIC(14,2),
    discount_amount NUMERIC(14,2),
    net_amount NUMERIC(14,2),
    invoice_net_total NUMERIC(14,2),
    invoice_paid_at_cutoff NUMERIC(14,2),
    invoice_balance_at_cutoff NUMERIC(14,2),
    invoice_status_at_cutoff VARCHAR(30)
)
LANGUAGE sql
STABLE
AS $$
    WITH paid_agg AS (
        SELECT 
            pa.invoice_id,
            COALESCE(SUM(pa.allocated_amount), 0.00) AS total_paid
        FROM billing.payment_allocations pa
        JOIN billing.payments p ON p.id = pa.payment_id
        WHERE p.payment_date <= p_as_of_date
        GROUP BY pa.invoice_id
    ),
    inv_calc AS (
        SELECT 
            vt.invoice_id,
            vt.net_total,
            COALESCE(pa.total_paid, 0.00) AS paid_at_cutoff,
            vt.net_total - COALESCE(pa.total_paid, 0.00) AS balance_at_cutoff,
            (vt.cancelled_on IS NOT NULL AND vt.cancelled_on <= p_as_of_date) AS is_canc,
            CASE 
                WHEN vt.cancelled_on IS NOT NULL AND vt.cancelled_on <= p_as_of_date THEN 'Cancelada'
                WHEN COALESCE(pa.total_paid, 0.00) >= vt.net_total THEN 'Paga'
                WHEN COALESCE(pa.total_paid, 0.00) > 0.00 THEN 'Parcialmente Paga'
                ELSE 'Em Aberto'
            END AS status_at_cutoff
        FROM billing.v_invoice_totals vt
        LEFT JOIN paid_agg pa ON pa.invoice_id = vt.invoice_id
        WHERE vt.customer_id = p_customer_id
          AND vt.issue_date >= p_start_date
          AND vt.issue_date <= p_end_date
          AND vt.issue_date <= p_as_of_date
    )
    SELECT 
        vl.item_id,
        vl.invoice_id,
        vl.invoice_number,
        vl.contract_id,
        vl.contract_code,
        vl.contract_description,
        vl.category_id,
        vl.category_name,
        vl.product_id,
        vl.product_code,
        vl.product_name,
        vl.unit_of_measure,
        vl.item_description,
        vl.issue_date,
        vl.due_date,
        vl.cancelled_on,
        ic.is_canc AS is_cancelled_at_cutoff,
        vl.quantity,
        vl.unit_price,
        vl.gross_amount,
        vl.discount_amount,
        vl.net_amount,
        ic.net_total AS invoice_net_total,
        ic.paid_at_cutoff AS invoice_paid_at_cutoff,
        ic.balance_at_cutoff AS invoice_balance_at_cutoff,
        ic.status_at_cutoff AS invoice_status_at_cutoff
    FROM billing.v_invoice_lines vl
    JOIN inv_calc ic ON ic.invoice_id = vl.invoice_id
    ORDER BY vl.contract_code, vl.issue_date, vl.invoice_number, vl.item_id;
$$;

COMMENT ON FUNCTION billing.fn_customer_statement_lines IS 'Linhas de cobrança para demonstrativo financeiro por período e data de corte';

-- Demonstrativo do cliente: pagamentos alocados às cobranças selecionadas
CREATE OR REPLACE FUNCTION billing.fn_customer_statement_payments(
    p_customer_id INTEGER,
    p_start_date DATE,
    p_end_date DATE,
    p_as_of_date DATE
)
RETURNS TABLE (
    payment_id INTEGER,
    allocation_id INTEGER,
    invoice_id INTEGER,
    invoice_number VARCHAR(30),
    payment_date DATE,
    method VARCHAR(50),
    reference VARCHAR(100),
    allocated_amount NUMERIC(14,2)
)
LANGUAGE sql
STABLE
AS $$
    SELECT 
        pa.payment_id,
        pa.allocation_id,
        pa.invoice_id,
        pa.invoice_number,
        pa.payment_date,
        pa.method,
        pa.reference,
        pa.allocated_amount
    FROM billing.v_payment_allocations pa
    JOIN billing.invoices i ON i.id = pa.invoice_id
    JOIN billing.contracts ct ON ct.id = i.contract_id
    WHERE ct.customer_id = p_customer_id
      AND i.issue_date >= p_start_date
      AND i.issue_date <= p_end_date
      AND i.issue_date <= p_as_of_date
      AND pa.payment_date <= p_as_of_date
    ORDER BY pa.payment_date, pa.invoice_number, pa.allocation_id;
$$;

COMMENT ON FUNCTION billing.fn_customer_statement_payments IS 'Pagamentos alocados às cobranças no período';

-- Contas a receber por data de corte e faixas de atraso (aging)
CREATE OR REPLACE FUNCTION billing.fn_accounts_receivable(
    p_as_of_date DATE,
    p_only_overdue BOOLEAN DEFAULT FALSE
)
RETURNS TABLE (
    invoice_id INTEGER,
    invoice_number VARCHAR(30),
    customer_id INTEGER,
    customer_code VARCHAR(20),
    customer_name VARCHAR(150),
    contract_code VARCHAR(30),
    issue_date DATE,
    due_date DATE,
    net_total NUMERIC(14,2),
    paid_at_cutoff NUMERIC(14,2),
    balance_at_cutoff NUMERIC(14,2),
    days_overdue INTEGER,
    aging_bucket_order INTEGER,
    aging_bucket_label VARCHAR(50)
)
LANGUAGE sql
STABLE
AS $$
    WITH paid_agg AS (
        SELECT 
            pa.invoice_id,
            COALESCE(SUM(pa.allocated_amount), 0.00) AS total_paid
        FROM billing.payment_allocations pa
        JOIN billing.payments p ON p.id = pa.payment_id
        WHERE p.payment_date <= p_as_of_date
        GROUP BY pa.invoice_id
    ),
    raw_ar AS (
        SELECT 
            vt.invoice_id,
            vt.invoice_number,
            vt.customer_id,
            vt.customer_code,
            vt.customer_name,
            vt.contract_code,
            vt.issue_date,
            vt.due_date,
            vt.net_total,
            COALESCE(pa.total_paid, 0.00) AS paid_at_cutoff,
            vt.net_total - COALESCE(pa.total_paid, 0.00) AS balance_at_cutoff,
            CASE 
                WHEN p_as_of_date > vt.due_date THEN (p_as_of_date - vt.due_date)
                ELSE 0 
            END AS days_overdue,
            CASE 
                WHEN vt.due_date >= p_as_of_date THEN 1
                WHEN (p_as_of_date - vt.due_date) BETWEEN 1 AND 30 THEN 2
                WHEN (p_as_of_date - vt.due_date) BETWEEN 31 AND 60 THEN 3
                WHEN (p_as_of_date - vt.due_date) BETWEEN 61 AND 90 THEN 4
                ELSE 5
            END AS aging_bucket_order,
            CASE 
                WHEN vt.due_date >= p_as_of_date THEN 'A Vencer / No Vencimento'
                WHEN (p_as_of_date - vt.due_date) BETWEEN 1 AND 30 THEN '1 a 30 dias'
                WHEN (p_as_of_date - vt.due_date) BETWEEN 31 AND 60 THEN '31 a 60 dias'
                WHEN (p_as_of_date - vt.due_date) BETWEEN 61 AND 90 THEN '61 a 90 dias'
                ELSE 'Acima de 90 dias'
            END AS aging_bucket_label
        FROM billing.v_invoice_totals vt
        LEFT JOIN paid_agg pa ON pa.invoice_id = vt.invoice_id
        WHERE vt.issue_date <= p_as_of_date
          AND (vt.cancelled_on IS NULL OR vt.cancelled_on > p_as_of_date)
    )
    SELECT *
    FROM raw_ar
    WHERE balance_at_cutoff > 0.00
      AND (NOT p_only_overdue OR days_overdue > 0)
    ORDER BY aging_bucket_order, customer_name, due_date, invoice_number;
$$;

COMMENT ON FUNCTION billing.fn_accounts_receivable IS 'Posição de contas a receber por data de corte e faixas de atraso';

-- Resumo mensal de faturamento líquido por categoria
CREATE OR REPLACE FUNCTION billing.fn_monthly_revenue(
    p_start_month DATE,
    p_end_month DATE
)
RETURNS TABLE (
    category_id INTEGER,
    category_name VARCHAR(100),
    month_date DATE,
    month_label VARCHAR(7),
    gross_revenue NUMERIC(14,2),
    discount_total NUMERIC(14,2),
    net_revenue NUMERIC(14,2)
)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_actual_end_date DATE;
BEGIN
    v_actual_end_date := (p_end_month + INTERVAL '1 month - 1 day')::DATE;

    RETURN QUERY
    WITH calendar AS (
        SELECT generate_series(
            p_start_month::timestamp,
            p_end_month::timestamp,
            '1 month'::interval
        )::date AS cal_month
    ),
    cat_cal AS (
        SELECT 
            pc.id AS cat_id,
            pc.name AS cat_name,
            c.cal_month
        FROM billing.product_categories pc
        CROSS JOIN calendar c
    ),
    valid_revenue AS (
        SELECT 
            vl.category_id,
            date_trunc('month', vl.issue_date)::date AS rev_month,
            COALESCE(SUM(vl.gross_amount), 0.00) AS total_gross,
            COALESCE(SUM(vl.discount_amount), 0.00) AS total_discount,
            COALESCE(SUM(vl.net_amount), 0.00) AS total_net
        FROM billing.v_invoice_lines vl
        WHERE vl.issue_date >= p_start_month
          AND vl.issue_date <= v_actual_end_date
          AND (vl.cancelled_on IS NULL OR vl.cancelled_on > v_actual_end_date)
        GROUP BY vl.category_id, date_trunc('month', vl.issue_date)::date
    )
    SELECT 
        cc.cat_id AS category_id,
        cc.cat_name AS category_name,
        cc.cal_month AS month_date,
        to_char(cc.cal_month, 'YYYY-MM')::varchar(7) AS month_label,
        COALESCE(vr.total_gross, 0.00) AS gross_revenue,
        COALESCE(vr.total_discount, 0.00) AS discount_total,
        COALESCE(vr.total_net, 0.00) AS net_revenue
    FROM cat_cal cc
    LEFT JOIN valid_revenue vr ON vr.category_id = cc.cat_id AND vr.rev_month = cc.cal_month
    ORDER BY cc.cal_month, cc.cat_id;
END;
$$;

COMMENT ON FUNCTION billing.fn_monthly_revenue IS 'Faturamento mensal por categoria de produto';
