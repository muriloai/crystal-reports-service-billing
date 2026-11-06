-- Sugestão de configuração de perfil somente-leitura para conexões de relatórios

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'billing_readonly') THEN
        CREATE ROLE billing_readonly WITH LOGIN PASSWORD 'DEFINIR_SENHA_AQUI';
    END IF;
END $$;

GRANT CONNECT ON DATABASE crystal_service_billing TO billing_readonly;
GRANT USAGE ON SCHEMA billing TO billing_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA billing TO billing_readonly;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA billing TO billing_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA billing 
    GRANT SELECT ON TABLES TO billing_readonly;

ALTER DEFAULT PRIVILEGES IN SCHEMA billing 
    GRANT EXECUTE ON FUNCTIONS TO billing_readonly;
