-- Schema: billing
-- Estrutura de tabelas, integridade referencial e índices

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM information_schema.tables 
        WHERE table_schema = 'billing' AND table_name = 'invoices'
    ) THEN
        RAISE EXCEPTION 'O schema "billing" já contém objetos criados. Execute em uma base vazia.';
    END IF;
END $$;

CREATE SCHEMA IF NOT EXISTS billing;
COMMENT ON SCHEMA billing IS 'Gestão comercial, faturamento e contas a receber';

-- Clientes
CREATE TABLE billing.customers (
    id SERIAL PRIMARY KEY,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state_code CHAR(2) NOT NULL,
    created_at DATE NOT NULL DEFAULT '2026-01-01',
    CONSTRAINT chk_customers_state CHECK (LENGTH(state_code) = 2)
);

COMMENT ON TABLE billing.customers IS 'Cadastro de clientes';
COMMENT ON COLUMN billing.customers.code IS 'Código do cliente';
COMMENT ON COLUMN billing.customers.name IS 'Razão social / Nome fantasia';
COMMENT ON COLUMN billing.customers.city IS 'Município';
COMMENT ON COLUMN billing.customers.state_code IS 'UF';

-- Categorias de Produtos
CREATE TABLE billing.product_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE
);

COMMENT ON TABLE billing.product_categories IS 'Categorias do catálogo de produtos';

-- Catálogo de Produtos
CREATE TABLE billing.products (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES billing.product_categories(id) ON DELETE RESTRICT,
    code VARCHAR(20) NOT NULL UNIQUE,
    name VARCHAR(150) NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL DEFAULT 'UN',
    reference_price NUMERIC(14,2) NOT NULL,
    CONSTRAINT chk_products_ref_price CHECK (reference_price > 0),
    CONSTRAINT uq_products_cat_name UNIQUE (category_id, name)
);

COMMENT ON TABLE billing.products IS 'Catálogo de produtos';
COMMENT ON COLUMN billing.products.code IS 'Código SKU do produto';
COMMENT ON COLUMN billing.products.unit_of_measure IS 'Unidade comercial de medida (CX, FD, UN, GL, KG)';
COMMENT ON COLUMN billing.products.reference_price IS 'Preço de tabela de referência (BRL)';

-- Contratos e Acordos Comerciais de Fornecimento
CREATE TABLE billing.contracts (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES billing.customers(id) ON DELETE RESTRICT,
    code VARCHAR(30) NOT NULL UNIQUE,
    description VARCHAR(255) NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE,
    CONSTRAINT chk_contracts_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

COMMENT ON TABLE billing.contracts IS 'Acordos comerciais de fornecimento por cliente';
COMMENT ON COLUMN billing.contracts.code IS 'Código do contrato/acordo de fornecimento';
COMMENT ON COLUMN billing.contracts.end_date IS 'Término de vigência (NULL para fornecimento continuado)';

-- Cobranças / Notas Fiscais de Venda
CREATE TABLE billing.invoices (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER NOT NULL REFERENCES billing.contracts(id) ON DELETE RESTRICT,
    number VARCHAR(30) NOT NULL UNIQUE,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    cancelled_on DATE,
    CONSTRAINT chk_invoices_due_date CHECK (due_date >= issue_date),
    CONSTRAINT chk_invoices_cancelled_on CHECK (cancelled_on IS NULL OR cancelled_on >= issue_date)
);

COMMENT ON TABLE billing.invoices IS 'Faturas e cobranças emitidas';
COMMENT ON COLUMN billing.invoices.number IS 'Número do documento de cobrança';
COMMENT ON COLUMN billing.invoices.issue_date IS 'Data de emissão';
COMMENT ON COLUMN billing.invoices.due_date IS 'Data de vencimento';
COMMENT ON COLUMN billing.invoices.cancelled_on IS 'Data de cancelamento, se aplicável';

-- Itens Faturados
CREATE TABLE billing.invoice_items (
    id SERIAL PRIMARY KEY,
    invoice_id INTEGER NOT NULL REFERENCES billing.invoices(id) ON DELETE CASCADE,
    product_id INTEGER NOT NULL REFERENCES billing.products(id) ON DELETE RESTRICT,
    description VARCHAR(255) NOT NULL,
    unit_of_measure VARCHAR(10) NOT NULL,
    quantity NUMERIC(10,2) NOT NULL,
    unit_price NUMERIC(14,2) NOT NULL,
    discount_amount NUMERIC(14,2) NOT NULL DEFAULT 0.00,
    CONSTRAINT chk_items_quantity CHECK (quantity > 0),
    CONSTRAINT chk_items_unit_price CHECK (unit_price > 0),
    CONSTRAINT chk_items_discount CHECK (discount_amount >= 0.00),
    CONSTRAINT chk_items_discount_limit CHECK (discount_amount <= ROUND(quantity * unit_price, 2))
);

COMMENT ON TABLE billing.invoice_items IS 'Itens de mercadorias faturadas';
COMMENT ON COLUMN billing.invoice_items.unit_of_measure IS 'Unidade de medida faturada';
COMMENT ON COLUMN billing.invoice_items.quantity IS 'Quantidade faturada';
COMMENT ON COLUMN billing.invoice_items.unit_price IS 'Preço unitário praticado';
COMMENT ON COLUMN billing.invoice_items.discount_amount IS 'Desconto comercial aplicado ao item';

-- Pagamentos / Liquidações Financeiras
CREATE TABLE billing.payments (
    id SERIAL PRIMARY KEY,
    customer_id INTEGER NOT NULL REFERENCES billing.customers(id) ON DELETE RESTRICT,
    payment_date DATE NOT NULL,
    amount NUMERIC(14,2) NOT NULL,
    method VARCHAR(50) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    CONSTRAINT chk_payments_amount CHECK (amount > 0)
);

COMMENT ON TABLE billing.payments IS 'Registros de pagamentos e liquidações';
COMMENT ON COLUMN billing.payments.payment_date IS 'Data da liquidação';
COMMENT ON COLUMN billing.payments.amount IS 'Valor pago';
COMMENT ON COLUMN billing.payments.method IS 'Forma de pagamento (Boleto Bancário, PIX, TED)';
COMMENT ON COLUMN billing.payments.reference IS 'Código de autenticação/comprovante bancário';

-- Alocações de Pagamento
CREATE TABLE billing.payment_allocations (
    id SERIAL PRIMARY KEY,
    payment_id INTEGER NOT NULL REFERENCES billing.payments(id) ON DELETE RESTRICT,
    invoice_id INTEGER NOT NULL REFERENCES billing.invoices(id) ON DELETE RESTRICT,
    allocated_amount NUMERIC(14,2) NOT NULL,
    CONSTRAINT chk_allocations_amount CHECK (allocated_amount > 0),
    CONSTRAINT uq_payment_invoice UNIQUE (payment_id, invoice_id)
);

COMMENT ON TABLE billing.payment_allocations IS 'Alocações de pagamento por fatura';
COMMENT ON COLUMN billing.payment_allocations.allocated_amount IS 'Valor liquidado na fatura';

-- Índices de consulta e relacionamento
CREATE INDEX idx_products_category ON billing.products(category_id);
CREATE INDEX idx_contracts_customer ON billing.contracts(customer_id);
CREATE INDEX idx_invoices_contract ON billing.invoices(contract_id);
CREATE INDEX idx_invoices_issue_date ON billing.invoices(issue_date);
CREATE INDEX idx_invoices_due_date ON billing.invoices(due_date);
CREATE INDEX idx_invoices_cancelled_on ON billing.invoices(cancelled_on);
CREATE INDEX idx_invoice_items_invoice ON billing.invoice_items(invoice_id);
CREATE INDEX idx_invoice_items_product ON billing.invoice_items(product_id);
CREATE INDEX idx_payments_customer ON billing.payments(customer_id);
CREATE INDEX idx_payments_date ON billing.payments(payment_date);
CREATE INDEX idx_allocations_payment ON billing.payment_allocations(payment_id);
CREATE INDEX idx_allocations_invoice ON billing.payment_allocations(invoice_id);
