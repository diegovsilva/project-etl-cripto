#!/bin/bash

# =============================================================================
# Script de Inicialização do Projeto Cryptocurrency ETL
# =============================================================================
# Este script automatiza a configuração e inicialização completa do projeto
# para que qualquer pessoa possa clonar e executar facilmente.
# =============================================================================

set -e  # Para o script se houver erro

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Função para imprimir mensagens coloridas
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para gerar chave Fernet
generate_fernet_key() {
    python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
}

# Função para gerar chave secreta
generate_secret_key() {
    openssl rand -hex 32
}

print_info "=============================================================================="
print_info "           CRYPTOCURRENCY ETL - SCRIPT DE INICIALIZAÇÃO"
print_info "=============================================================================="
echo

# 1. Verificar dependências
print_info "Verificando dependências do sistema..."

if ! command_exists docker; then
    print_error "Docker não está instalado. Por favor, instale o Docker primeiro."
    print_info "Visite: https://docs.docker.com/get-docker/"
    exit 1
fi

if ! command_exists docker-compose; then
    print_error "Docker Compose não está instalado. Por favor, instale o Docker Compose primeiro."
    print_info "Visite: https://docs.docker.com/compose/install/"
    exit 1
fi

print_success "Docker e Docker Compose estão instalados."

# 2. Verificar se o Docker está rodando
print_info "Verificando se o Docker está rodando..."
if ! docker info >/dev/null 2>&1; then
    print_error "Docker não está rodando. Por favor, inicie o Docker primeiro."
    exit 1
fi
print_success "Docker está rodando."

# 3. Configurar arquivo .env
print_info "Configurando arquivo de ambiente..."

if [ ! -f ".env" ]; then
    print_info "Arquivo .env não encontrado. Criando a partir do template..."
    
    if [ ! -f "env_example.txt" ]; then
        print_error "Arquivo env_example.txt não encontrado!"
        exit 1
    fi
    
    cp env_example.txt .env
    
    # Gerar chaves automaticamente
    print_info "Gerando chaves de segurança..."
    
    # Verificar se Python está disponível para gerar Fernet key
    if command_exists python3; then
        if python3 -c "import cryptography" 2>/dev/null; then
            FERNET_KEY=$(generate_fernet_key)
            sed -i "s/your_fernet_key_here/$FERNET_KEY/g" .env
            print_success "Chave Fernet gerada automaticamente."
        else
            print_warning "Biblioteca cryptography não encontrada. Usando chave padrão."
            sed -i "s/your_fernet_key_here/dGhpcyBpcyBhIHNhbXBsZSBmZXJuZXQga2V5IGZvciBkZW1vIHB1cnBvc2Vz/g" .env
        fi
    else
        print_warning "Python3 não encontrado. Usando chave Fernet padrão."
        sed -i "s/your_fernet_key_here/dGhpcyBpcyBhIHNhbXBsZSBmZXJuZXQga2V5IGZvciBkZW1vIHB1cnBvc2Vz/g" .env
    fi
    
    # Gerar secret key
    if command_exists openssl; then
        SECRET_KEY=$(generate_secret_key)
        sed -i "s/your_secret_key_here/$SECRET_KEY/g" .env
        print_success "Chave secreta gerada automaticamente."
    else
        print_warning "OpenSSL não encontrado. Usando chave secreta padrão."
        sed -i "s/your_secret_key_here/thisisasamplesecretkeyfordemo12345678901234567890/g" .env
    fi
    
    # Configurar senha padrão do PostgreSQL
    sed -i "s/your_password/postgres123/g" .env
    
    print_success "Arquivo .env criado e configurado!"
else
    print_success "Arquivo .env já existe."
fi

# 4. Limpar containers e volumes antigos (opcional)
read -p "Deseja limpar containers e volumes antigos? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    print_info "Limpando containers e volumes antigos..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    docker system prune -f >/dev/null 2>&1 || true
    print_success "Limpeza concluída."
fi

# 5. Construir e iniciar os serviços
print_info "Construindo e iniciando os serviços..."
print_info "Isso pode levar alguns minutos na primeira execução..."

# Construir as imagens
docker-compose build

# Iniciar PostgreSQL primeiro
print_info "Iniciando PostgreSQL..."
docker-compose up -d postgres

# Aguardar PostgreSQL ficar pronto
print_info "Aguardando PostgreSQL ficar pronto..."
sleep 10

# Verificar se PostgreSQL está pronto
max_attempts=30
attempt=1
while [ $attempt -le $max_attempts ]; do
    if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
        print_success "PostgreSQL está pronto!"
        break
    fi
    
    if [ $attempt -eq $max_attempts ]; then
        print_error "PostgreSQL não ficou pronto após $max_attempts tentativas."
        print_error "Verifique os logs: docker-compose logs postgres"
        exit 1
    fi
    
    print_info "Tentativa $attempt/$max_attempts - Aguardando PostgreSQL..."
    sleep 5
    ((attempt++))
done

# Inicializar Airflow
print_info "Inicializando Airflow..."
docker-compose up -d airflow-init

# Aguardar inicialização do Airflow
print_info "Aguardando inicialização do Airflow..."
sleep 15

# Iniciar todos os serviços
print_info "Iniciando todos os serviços..."
docker-compose up -d

# Aguardar todos os serviços ficarem prontos
print_info "Aguardando todos os serviços ficarem prontos..."
sleep 20

# 6. Verificar status dos serviços
print_info "Verificando status dos serviços..."

# Verificar PostgreSQL
if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
    print_success "✓ PostgreSQL está funcionando"
else
    print_error "✗ PostgreSQL não está respondendo"
fi

# Verificar Airflow Webserver
if curl -f http://localhost:8080/health >/dev/null 2>&1; then
    print_success "✓ Airflow Webserver está funcionando"
else
    print_warning "⚠ Airflow Webserver ainda está inicializando (pode levar alguns minutos)"
fi

# 7. Mostrar informações de acesso
echo
print_info "=============================================================================="
print_success "                    PROJETO INICIALIZADO COM SUCESSO!"
print_info "=============================================================================="
echo
print_info "🔗 ACESSOS:"
echo "   • Airflow Web UI: http://localhost:8080"
echo "     Usuário: airflow"
echo "     Senha: airflow"
echo
echo "   • PostgreSQL: localhost:5432"
echo "     Database: cryptocurrency_db"
echo "     Usuário: postgres"
echo "     Senha: postgres123"
echo
print_info "📊 DAGS DISPONÍVEIS:"
echo "   • cryptocurrency_etl: Coleta dados das top 10 criptomoedas (30 min)"
echo "   • cryptocurrency_continuous_collection: Coleta contínua das top 5 (5 min)"
echo "   • cryptocurrency_reports: Gera relatórios diários"
echo
print_info "🛠 COMANDOS ÚTEIS:"
echo "   • Ver logs: docker-compose logs [serviço]"
echo "   • Parar tudo: docker-compose down"
echo "   • Reiniciar: docker-compose restart"
echo "   • Limpar tudo: docker-compose down -v"
echo
print_info "📝 PRÓXIMOS PASSOS:"
echo "   1. Acesse http://localhost:8080 para ver a interface do Airflow"
echo "   2. Ative os DAGs desejados na interface web"
echo "   3. Monitore a coleta de dados nos logs"
echo
print_warning "⚠ NOTA: Se algum serviço não estiver funcionando, aguarde alguns minutos"
print_warning "   para a inicialização completa ou verifique os logs."
echo
print_success "=============================================================================="
print_success "                         SETUP CONCLUÍDO!"
print_success "=============================================================================="