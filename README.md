# Desafio Técnico: Coleta e Armazenamento de Dados de Criptomoedas

## Visão Geral

Este projeto foi desenvolvido como parte de um desafio técnico para uma vaga de trabalho, com o objetivo de demonstrar habilidades em Python, boas práticas de programação e manipulação de dados. A solução implementa um sistema completo para consumir dados da API pública CoinCap, processar essas informações e armazená-las em um banco de dados PostgreSQL, utilizando o Apache Airflow para orquestração e automação de todo o fluxo de trabalho.

## Objetivos do Desafio

- Implementar conexão com a API CoinCap para extração de dados de criptomoedas
- Projetar um mecanismo eficiente para coleta periódica de informações atualizadas
- Modelar estruturas de dados adequadas para armazenamento das informações
- Configurar um banco de dados PostgreSQL para persistência dos dados
- Implementar mecanismos eficientes de armazenamento e atualização
- Permitir configuração externa de parâmetros importantes
- Seguir boas práticas de programação em Python
- Documentar adequadamente o projeto

## Funcionalidades Implementadas

- **Consumo da API CoinCap**: Extração de dados como nome, preço, volume, capitalização de mercado e outras métricas relevantes
- **Armazenamento em PostgreSQL**: Utilização de duas tabelas relacionais:
  - `cryptocurrencies`: Armazena dados principais das criptomoedas
  - `price_history`: Mantém o histórico de preços para análise temporal
- **Orquestração com Apache Airflow**: Automatização completa do fluxo de trabalho com dois DAGs:
  - `cryptocurrency_etl`: Coleta dados das top 10 criptomoedas a cada 30 minutos
  - `cryptocurrency_continuous_collection`: Coleta dados das top 5 criptomoedas a cada 5 minutos
- **Análise de Dados**: Estrutura preparada para visualização e análise dos dados coletados
- **Configuração via Variáveis de Ambiente**: Flexibilidade para configurar API, banco de dados e Airflow
- **Containerização com Docker**: Facilidade de implantação e execução em qualquer ambiente
- **Tratamento de Erros**: Implementação robusta de mecanismos de retry e fallback
- **Scripts SQL Organizados**: Separação das operações de banco em arquivos SQL específicos para melhor manutenibilidade
- **Stored Procedures**: Utilização de procedures PostgreSQL para operações complexas de inserção/atualização
- **Consultas de Relatórios**: Scripts SQL dedicados para geração de relatórios e análises

## Tecnologias Utilizadas

- **Python**: Linguagem principal de desenvolvimento
- **Apache Airflow**: Orquestração e agendamento de tarefas
- **PostgreSQL**: Banco de dados relacional

- **Docker & Docker Compose**: Containerização e gerenciamento de serviços
- **Requests**: Biblioteca para consumo de APIs
- **Psycopg2**: Conector PostgreSQL para Python
- **dotenv**: Gerenciamento de variáveis de ambiente

## Pré-requisitos

- Docker e Docker Compose
- Chave de API da CoinCap (opcional, mas recomendado para evitar limitações de taxa)

## Instalação e Configuração Rápida

### Opção 1: Inicialização Automática (Recomendado)

**Para usuários Linux/Mac:**
```bash
git clone <url-do-repositorio>
cd cryptocurrency-etl
chmod +x start.sh
./start.sh
```

**Para usuários Windows:**
```cmd
git clone <url-do-repositorio>
cd cryptocurrency-etl
start.bat
```

**Isso é tudo!** Os scripts automaticamente:
- Verificam se Docker e Docker Compose estão instalados
- Criam e configuram o arquivo `.env` com valores padrão
- Constroem e iniciam todos os serviços
- Aguardam os serviços ficarem prontos
- Mostram informações de acesso

### Opção 2: Configuração Manual

1. **Clone o repositório:**
   ```bash
git clone <url-do-repositorio>
cd cryptocurrency-etl
```

2. **Configure as variáveis de ambiente:**
   ```bash
   cp env_example.txt .env
   ```

3. **Edite o arquivo `.env` (opcional - valores padrão funcionam):**
   ```env
   # API CoinCap (opcional)
   COINCAP_API_KEY=sua_chave_api_aqui
   
   # PostgreSQL
   DB_HOST=postgres
   DB_PORT=5432
   DB_NAME=cryptocurrency_db
   DB_USER=postgres
   DB_PASSWORD=postgres123
   
   # Airflow
   AIRFLOW_FERNET_KEY=dGhpcyBpcyBhIHNhbXBsZSBmZXJuZXQga2V5IGZvciBkZW1vIHB1cnBvc2Vz
   AIRFLOW_SECRET_KEY=thisisasamplesecretkeyfordemo12345678901234567890
   AIRFLOW_USERNAME=airflow
   AIRFLOW_PASSWORD=airflow
   ```

4. **Inicie os serviços:**
   ```bash
   docker-compose up -d
   ```

### Acesso aos Serviços

Após a inicialização (automática ou manual):

- **Airflow Web UI**: http://localhost:8080
  - Usuário: `airflow`
  - Senha: `airflow`

- **PostgreSQL**: `localhost:5432`
  - Database: `cryptocurrency_db`
  - Usuário: `postgres`
  - Senha: `postgres123`

## Como Usar

### Interface Web do Airflow

1. Acesse http://localhost:8080
2. Faça login com as credenciais configuradas
3. Ative os DAGs desejados:
   - `cryptocurrency_etl`: Para coleta periódica das top 10 criptomoedas
   - `cryptocurrency_continuous_collection`: Para coleta contínua das top 5 criptomoedas

### DAGs Disponíveis

#### cryptocurrency_etl
- **Frequência**: A cada 30 minutos
- **Função**: Coleta dados das top 10 criptomoedas
- **Tarefas**:
  - Configuração do banco de dados
  - Criação de stored procedures
  - Busca de dados da API
  - Armazenamento no PostgreSQL
  - Geração de relatórios

#### cryptocurrency_continuous_collection
- **Frequência**: A cada 5 minutos
- **Função**: Coleta contínua das top 5 criptomoedas
- **Tarefas**:
  - Verificação de saúde do banco
  - Busca e armazenamento de dados
  - Monitoramento contínuo

## Monitoramento e Logs

- **Logs do Airflow**: Disponíveis na interface web em cada tarefa
- **Logs dos containers**: `docker-compose logs [nome_do_serviço]`
- **Monitoramento do banco**: Scripts SQL disponíveis na pasta `sql/`

## Estrutura do Projeto

```
cryptocurrency-etl/
├── dags/                # Diretório com os DAGs do Airflow
│   ├── cryptocurrency_dag.py            # DAG principal para coleta de dados
│   └── cryptocurrency_continuous_dag.py  # DAG para coleta contínua
├── scripts/             # Scripts Python utilizados pelos DAGs
│   └── api.py           # Módulo para interação com a API CoinCap
├── sql/                 # Scripts SQL para processamento no PostgreSQL
│   ├── create_tables.sql      # Script para criação das tabelas
│   ├── upsert_cryptocurrency.sql # Stored procedure para inserção/atualização
│   ├── generate_report.sql    # Consultas para relatórios
│   ├── maintenance.sql        # Scripts de manutenção do banco
│   └── useful_queries.sql     # Consultas úteis para análise
├── teste.py             # Script para testar a API (não usado em produção)
├── requirements.txt     # Dependências Python
├── env_example.txt      # Exemplo de variáveis de ambiente
├── .env                 # Variáveis de ambiente (criado automaticamente)
├── Dockerfile           # Configuração do container Docker
├── docker-compose.yml   # Orquestração dos serviços
├── init.sql             # Script de inicialização do PostgreSQL
├── start.sh             # Script de inicialização automática (Linux/Mac)
├── start.bat            # Script de inicialização automática (Windows)
├── .dockerignore        # Arquivos ignorados no build Docker
├── DOCKER_README.md     # Documentação específica do Docker
└── README.md            # Este arquivo
```

## Estrutura do Banco de Dados

### Tabela `cryptocurrencies`
- `id`: ID único da criptomoeda
- `rank`: Ranking por market cap
- `symbol`: Símbolo (ex: BTC, ETH)
- `name`: Nome completo
- `supply`: Supply atual
- `max_supply`: Supply máximo
- `market_cap_usd`: Market cap em USD
- `volume_usd_24hr`: Volume 24h em USD
- `price_usd`: Preço atual em USD
- `change_percent_24hr`: Variação 24h (%)
- `vwap_24hr`: VWAP 24h
- `explorer`: URL do explorer
- `created_at`: Timestamp de criação

### Tabela `price_history`
- `id`: ID único do registro
- `cryptocurrency_id`: Referência à criptomoeda
- `price_usd`: Preço em USD
- `market_cap_usd`: Market cap em USD
- `volume_usd_24hr`: Volume 24h em USD
- `timestamp`: Timestamp do registro

## 🛠 Comandos Úteis

### Gerenciamento dos Serviços
```bash
# Ver logs de todos os serviços
docker-compose logs

# Ver logs de um serviço específico
docker-compose logs airflow-webserver
docker-compose logs postgres

# Parar todos os serviços
docker-compose down

# Reiniciar todos os serviços
docker-compose restart

# Limpar tudo (containers, volumes, redes)
docker-compose down -v --remove-orphans

# Reconstruir e reiniciar
docker-compose up -d --build
```

### Monitoramento
```bash
# Status dos containers
docker-compose ps

# Uso de recursos
docker stats

# Verificar saúde do PostgreSQL
docker-compose exec postgres pg_isready -U postgres
```

## Solução de Problemas

### Scripts de Inicialização

**Erro: "Docker não está instalado"**
- Instale o Docker Desktop: https://docs.docker.com/get-docker/
- Certifique-se de que o Docker está rodando

**Erro: "Docker não está rodando"**
- Inicie o Docker Desktop
- No Linux: `sudo systemctl start docker`

**Script trava em "Aguardando PostgreSQL"**
- Verifique se a porta 5432 não está em uso
- Execute: `docker-compose logs postgres` para ver erros
- Tente limpar volumes antigos: `docker-compose down -v`

### Problemas Gerais

**Erro de conexão com banco de dados**
- Verifique se o PostgreSQL está rodando: `docker-compose ps`
- Confirme as credenciais no arquivo `.env`
- Teste a conexão: `docker-compose exec postgres psql -U postgres -d cryptocurrency_db`

**Erro ao buscar dados da API**
- Verifique sua conexão com a internet
- A API CoinCap pode estar temporariamente indisponível
- Verifique se sua chave de API é válida (opcional, mas recomendado)

**DAGs não aparecem no Airflow**
- Aguarde alguns minutos para o Airflow detectar os DAGs
- Verifique se não há erros de sintaxe: `docker-compose logs airflow-webserver`
- Reinicie o Airflow: `docker-compose restart airflow-webserver airflow-scheduler`

**Portas em uso**
- PostgreSQL (5432): `netstat -an | grep 5432`
- Airflow (8080): `netstat -an | grep 8080`
- Pare outros serviços usando essas portas ou altere as portas no `docker-compose.yml`

**Problemas de permissão (Linux/Mac)**
```bash
# Dar permissão ao script
chmod +x start.sh

# Se necessário, executar com sudo
sudo ./start.sh
```

## Decisões Técnicas

### Escolha do Apache Airflow
- Facilita o agendamento e monitoramento de tarefas
- Interface web intuitiva para gerenciamento
- Robustez para tratamento de falhas e retry
- Escalabilidade para futuras expansões

### Uso do PostgreSQL
- Banco relacional robusto e confiável
- Suporte nativo a JSON para flexibilidade
- Excelente performance para consultas analíticas
- Integração nativa com Airflow

### Containerização com Docker
- Facilita a implantação em diferentes ambientes
- Isola dependências e configurações
- Simplifica o processo de setup
- Permite escalabilidade horizontal

## Conclusão

Este projeto demonstra a capacidade de desenvolver uma solução completa para coleta, processamento e armazenamento de dados, utilizando tecnologias modernas e seguindo boas práticas de desenvolvimento. A arquitetura refatorada permite escalabilidade, manutenibilidade e robustez, atendendo plenamente aos requisitos do desafio técnico proposto.

## Autor

Diego Vieira da Silva - Desenvolvido como parte de um desafio técnico para demonstração de habilidades em desenvolvimento Python, engenharia de dados e boas práticas de programação.#   c r i p t _ e t l  
 