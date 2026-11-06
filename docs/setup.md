# Guia de configuração e ambiente

Aqui descrevo os pré-requisitos, versões de software testadas e o procedimento passo a passo para configurar o ambiente deste projeto.

---

## Ambiente testado e homologado localmente

| Componente               | Especificação / Versão                        | Arquitetura             | Observações                               |
| ------------------------ | --------------------------------------------- | ----------------------- | ----------------------------------------- |
| **Sistema operacional**  | Microsoft Windows (Windows 11 / Server)       | x64 (64-bit)            | Plataforma nativa dos executáveis         |
| **Banco de dados**       | PostgreSQL 18.6                               | x86_64-windows (64-bit) | Porta padrão: `5432`                      |
| **Driver ODBC**          | psqlODBC `13.02.0000` (`psqlodbc35w.dll`)     | 64-bit (UNICODE)        | Requisito obrigatório para CR 2020        |
| **Crystal Reports**      | SAP Crystal Reports 2020 SP04 (`14.3.4.5284`) | x64 (64-bit nativo)     | Executável: `crw64.exe`                   |
| **Banco de dados local** | `crystal_service_billing`                     | UTF-8                   | Schema de negócio: `billing`              |
| **Nome da DSN ODBC**     | `CrystalServiceBilling`                       | 64-bit User/System DSN  | Driver: `PostgreSQL ODBC Driver(UNICODE)` |

> [!NOTE]
> A partir do Crystal Reports 2020, o software opera em **arquitetura de 64 bits nativa** (`crw64.exe`), portanto, tanto o driver ODBC quanto a DSN configurada devem ser obrigatoriamente de **64 bits**. O uso de drivers de 32 bits não é reconhecido pelo Crystal Reports 2020.
> Caso você queira usar em versões antigas, de ODBC + Crystal Reports, atente-se a estes detalhes de versão do driver e possíveis ajustes nos scripts de banco de dados.

---

## Preparação do banco de dados no PostgreSQL

### Criação do Banco Vazio

O projeto utiliza um banco de dados exclusivo com codificação UTF-8 e para criar a base vazia faça:

**Via `psql`:**

```bash
psql -U postgres -h localhost -p 5432 -c "CREATE DATABASE crystal_service_billing WITH OWNER = postgres ENCODING = 'UTF8';"
```

**Via pgAdmin 4:**

1. Conecte ao servidor PostgreSQL local.
2. Clique com o botão direito em **Databases** > **Create** > **Database...**.
3. Em **Database**, informe `crystal_service_billing`.
4. Na aba **Definition**, certifique-se de que o **Encoding** é `UTF8`.
5. Clique em **Save**.

### Ordem de Execução dos Scripts SQL

Os scripts devem ser executados nesta **ordem estrita** em uma base recém-criada:

1. `database/01-schema.sql`
   Cria o schema `billing`, tabelas, restrições, chaves e índices.

2. `database/02-seed.sql`
   Popula o catálogo de produtos, clientes, acordos comerciais, casos manuais de conferência (`C001`) e os 3.504 registros totais.

3. `database/03-reporting.sql`
   Cria as views de agregação e suporte aos relatórios.

4. `database/04-validate.sql`
   Executa bateria de asserções estritas e validação determinística de regras.

**Comando de execução automatizado (`psql`):**

```powershell
$env:PGPASSWORD = "sua_senha_local"
$psql = "C:\Program Files\PostgreSQL\18\bin\psql.exe"
& $psql -U postgres -h localhost -p 5432 -d crystal_service_billing -v ON_ERROR_STOP=1 -f "database/01-schema.sql"
& $psql -U postgres -h localhost -p 5432 -d crystal_service_billing -v ON_ERROR_STOP=1 -f "database/02-seed.sql"
& $psql -U postgres -h localhost -p 5432 -d crystal_service_billing -v ON_ERROR_STOP=1 -f "database/03-reporting.sql"
& $psql -U postgres -h localhost -p 5432 -d crystal_service_billing -v ON_ERROR_STOP=1 -f "database/04-validate.sql"
```

> [!IMPORTANT]
> O script `01-schema.sql` contém validação de segurança que bloqueia a execução caso o schema `billing` já contenha tabelas, evitando sobrescritas acidentais.

> [!NOTE]
> Você pode usar dados além dos sugeridos para nome de usuários e senhas do banco de dados, do modo que melhor desejar, os informados são apenas uma sugestão.

---

## Configuração da fonte de dados ODBC

### Criação automática via PowerShell (Recomendado)

Execute no terminal PowerShell:

```powershell
Add-OdbcDsn -Name "CrystalServiceBilling" `
            -DriverName "PostgreSQL ODBC Driver(UNICODE)" `
            -DsnType "User" `
            -Platform "64-bit" `
            -SetPropertyValue @(
                "Server=localhost",
                "Port=5432",
                "Database=crystal_service_billing",
                "Username=postgres",
                "BoolsAsChar=0",
                "TextAsLongVarchar=1",
                "UseServerSidePrepare=1"
            )
```

### Criação manual via administrador ODBC do Windows

1. Abra o Administrador de Fonte de Dados ODBC de 64 bits pelo comando `Win + R` e digite:
   ```cmd
   C:\Windows\System32\odbcad32.exe
   ```
2. Acesse a aba **DSN de Usuário** (ou **DSN de Sistema**) e clique em **Adicionar...**.
3. Selecione o driver **PostgreSQL ODBC Driver(UNICODE)** e clique em **Concluir**.
4. No diálogo de configuração do psqlODBC:
   - **Data Source**: `CrystalServiceBilling`
   - **Database**: `crystal_service_billing`
   - **Server**: `localhost`
   - **Port**: `5432`
   - **User Name**: `postgres` (ou seu usuário local)
   - **Password**: informe a senha local (não versionada)
5. Clique no botão **Test** para confirmar a conectividade com o PostgreSQL.
6. Clique em **Save**.

---

## Validação da conexão e tipos de dados

Durante a homologação da conectividade ODBC de 64 bits com o PostgreSQL, os seguintes requisitos foram validados com sucesso:

1. **Codificação e Acentuação UTF-8**:
   - Strings com acentuação em português foram inseridas e recuperadas sem perdas ou corrupção de caracteres.
   - `client_encoding` confirmado como `UTF8`.

2. **Precisão Numérica Decimal**:
   - Colunas do tipo `NUMERIC(14,2)` mantiveram exatidão de duas casas decimais sem aproximações de ponto flutuante.

3. **Tratamento de Nulos**:
   - Valores `NULL` em campos opcionais (ex: `cancelled_on`, `end_date`) foram mapeados corretamente.

4. **Campos Temporais (`DATE`)**:
   - Formatos de data foram preservados e validados no padrão ISO (`YYYY-MM-DD`).

5. **Comandos Parametrizados via ODBC**:
   - Consultas com parâmetros vinculados foram executadas com sucesso pelo driver `PostgreSQL ODBC Driver(UNICODE)`.

---

## Identidade visual e recursos de layout

Para padronização visual nos cabeçalhos dos relatórios conforme a identidade corporativa da **Horizonte Distribuidora de Alimentos & Bebidas**:

- **Logo Horizontal com Fundo Transparente**
  Localizado em [`docs/images/logo-horizonte.png`](file:///c:/GITHUB/crystal-reports-service-billing/docs/images/logo-horizonte.png) (1200x320 px, 300 DPI).

- **Emblema / Ícone**
  Localizado em [`docs/images/logo-horizonte-mark.png`](file:///c:/GITHUB/crystal-reports-service-billing/docs/images/logo-horizonte-mark.png) (512x512 px).

- **Vetor SVG**
  Localizado em [`docs/images/logo-horizonte.svg`](file:///c:/GITHUB/crystal-reports-service-billing/docs/images/logo-horizonte.svg).

- **Paleta de Cores Homologada**:
  - Destaque Principal (Azul-petróleo escuro): `#006D77` (RGB: 0, 109, 119)
  - Destaque Secundário (Azul-petróleo médio): `#0E94A0` (RGB: 14, 148, 160)
  - Destaque Claro (Acqua suave): `#83C5BE` (RGB: 131, 197, 190)
  - Texto e Títulos (Grafite escuro): `#1E293B` (RGB: 30, 41, 59)
  - Legendas e Mudos (Grafite ardósia): `#64748B` (RGB: 100, 116, 139)

---

## Procedimento de edição e remapeamento dos arquivos `.rpt`

Ao abrir os arquivos de relatório no SAP Crystal Reports 2020:

1. **Abrir o relatório**:
   - Inicie o SAP Crystal Reports 2020.
   - Abra o arquivo correspondente (ex: `reports/customer-statement/customer-statement.rpt`).

2. **Definir origem da conexão (`Set Datasource Location`)**:
   - Caso o Crystal Reports solicite remapeamento da fonte de dados:
     - No menu principal, vá em **Database** > **Set Datasource Location...**.
     - Na árvore superior (_Current Data Source_), selecione o comando ou conexão atual.
     - Na árvore inferior (_Replace with_), navegue até **Create New Connection** > **ODBC (RDO)**.
     - Selecione a DSN **CrystalServiceBilling**.
     - Informe o usuário (`postgres`) e sua senha local.
     - Clique em **Update**.

3. **Sub-relatórios**:
   - Para relatórios que contenham sub-relatórios (ex: demonstrativo por cliente):
     - Na janela **Set Datasource Location**, expanda a pasta **Subreports**.
     - Remapeie igualmente a conexão do sub-relatório para a mesma DSN `CrystalServiceBilling`.

4. **Verificar conexão e atualizar**:
   - Execute **Database** > **Verify Database** (deve retornar a mensagem _"The database is up to date"_).
   - Pressione **F5** (ou clique no ícone de atualização) para informar os parâmetros de teste e gerar a visualização.
