@echo off
setlocal enabledelayedexpansion

REM =============================================================================
REM Script de Inicialização do Projeto Cryptocurrency ETL (Windows)
REM =============================================================================
REM Este script automatiza a configuração e inicialização completa do projeto
REM para que qualquer pessoa possa clonar e executar facilmente no Windows.
REM =============================================================================

echo ===============================================================================
echo            CRYPTOCURRENCY ETL - SCRIPT DE INICIALIZACAO
echo ===============================================================================
echo.

REM 1. Verificar dependências
echo [INFO] Verificando dependencias do sistema...

where docker >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker nao esta instalado. Por favor, instale o Docker primeiro.
    echo [INFO] Visite: https://docs.docker.com/get-docker/
    pause
    exit /b 1
)

where docker-compose >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker Compose nao esta instalado. Por favor, instale o Docker Compose primeiro.
    echo [INFO] Visite: https://docs.docker.com/compose/install/
    pause
    exit /b 1
)

echo [SUCCESS] Docker e Docker Compose estao instalados.

REM 2. Verificar se o Docker está rodando
echo [INFO] Verificando se o Docker esta rodando...
docker info >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Docker nao esta rodando. Por favor, inicie o Docker primeiro.
    pause
    exit /b 1
)
echo [SUCCESS] Docker esta rodando.

REM 3. Configurar arquivo .env
echo [INFO] Configurando arquivo de ambiente...

if not exist ".env" (
    echo [INFO] Arquivo .env nao encontrado. Criando a partir do template...
    
    if not exist "env_example.txt" (
        echo [ERROR] Arquivo env_example.txt nao encontrado!
        pause
        exit /b 1
    )
    
    copy env_example.txt .env >nul
    
    REM Configurar chaves padrão
    echo [INFO] Configurando chaves de seguranca...
    
    REM Usar PowerShell para substituições mais robustas
    powershell -Command "(Get-Content .env) -replace 'your_fernet_key_here', 'dGhpcyBpcyBhIHNhbXBsZSBmZXJuZXQga2V5IGZvciBkZW1vIHB1cnBvc2Vz' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'your_secret_key_here', 'thisisasamplesecretkeyfordemo12345678901234567890' | Set-Content .env"
    powershell -Command "(Get-Content .env) -replace 'your_password', 'postgres123' | Set-Content .env"
    
    echo [SUCCESS] Arquivo .env criado e configurado!
) else (
    echo [SUCCESS] Arquivo .env ja existe.
)

REM 4. Limpar containers e volumes antigos (opcional)
set /p cleanup="Deseja limpar containers e volumes antigos? (y/N): "
if /i "!cleanup!"=="y" (
    echo [INFO] Limpando containers e volumes antigos...
    docker-compose down -v --remove-orphans 2>nul
    docker system prune -f >nul 2>nul
    echo [SUCCESS] Limpeza concluida.
)

REM 5. Construir e iniciar os serviços
echo [INFO] Construindo e iniciando os servicos...
echo [INFO] Isso pode levar alguns minutos na primeira execucao...

REM Construir as imagens
docker-compose build
if %errorlevel% neq 0 (
    echo [ERROR] Erro ao construir as imagens Docker.
    pause
    exit /b 1
)

REM Iniciar PostgreSQL primeiro
echo [INFO] Iniciando PostgreSQL...
docker-compose up -d postgres
if %errorlevel% neq 0 (
    echo [ERROR] Erro ao iniciar PostgreSQL.
    pause
    exit /b 1
)

REM Aguardar PostgreSQL ficar pronto
echo [INFO] Aguardando PostgreSQL ficar pronto...
timeout /t 10 /nobreak >nul

REM Verificar se PostgreSQL está pronto (loop simples)
set attempt=1
set max_attempts=30

:wait_postgres
echo [INFO] Tentativa !attempt!/!max_attempts! - Aguardando PostgreSQL...
docker-compose exec -T postgres pg_isready -U postgres >nul 2>nul
if %errorlevel% equ 0 (
    echo [SUCCESS] PostgreSQL esta pronto!
    goto postgres_ready
)

if !attempt! geq !max_attempts! (
    echo [ERROR] PostgreSQL nao ficou pronto apos !max_attempts! tentativas.
    echo [ERROR] Verifique os logs: docker-compose logs postgres
    pause
    exit /b 1
)

set /a attempt+=1
timeout /t 5 /nobreak >nul
goto wait_postgres

:postgres_ready

REM Inicializar Airflow
echo [INFO] Inicializando Airflow...
docker-compose up -d airflow-init
if %errorlevel% neq 0 (
    echo [ERROR] Erro ao inicializar Airflow.
    pause
    exit /b 1
)

REM Aguardar inicialização do Airflow
echo [INFO] Aguardando inicializacao do Airflow...
timeout /t 15 /nobreak >nul

REM Iniciar todos os serviços
echo [INFO] Iniciando todos os servicos...
docker-compose up -d
if %errorlevel% neq 0 (
    echo [ERROR] Erro ao iniciar todos os servicos.
    pause
    exit /b 1
)

REM Aguardar todos os serviços ficarem prontos
echo [INFO] Aguardando todos os servicos ficarem prontos...
timeout /t 20 /nobreak >nul

REM 6. Verificar status dos serviços
echo [INFO] Verificando status dos servicos...

REM Verificar PostgreSQL
docker-compose exec -T postgres pg_isready -U postgres >nul 2>nul
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ PostgreSQL esta funcionando
) else (
    echo [ERROR] ✗ PostgreSQL nao esta respondendo
)

REM Verificar Airflow Webserver (usando curl se disponível, senão pular)
curl -f http://localhost:8080/health >nul 2>nul
if %errorlevel% equ 0 (
    echo [SUCCESS] ✓ Airflow Webserver esta funcionando
) else (
    echo [WARNING] ⚠ Airflow Webserver ainda esta inicializando (pode levar alguns minutos)
)

REM 7. Mostrar informações de acesso
echo.
echo ===============================================================================
echo                     PROJETO INICIALIZADO COM SUCESSO!
echo ===============================================================================
echo.
echo 🔗 ACESSOS:
echo    • Airflow Web UI: http://localhost:8080
echo      Usuario: airflow
echo      Senha: airflow
echo.
echo    • PostgreSQL: localhost:5432
echo      Database: cryptocurrency_db
echo      Usuario: postgres
echo      Senha: postgres123
echo.
echo 📊 DAGS DISPONIVEIS:
echo    • cryptocurrency_etl: Coleta dados das top 10 criptomoedas (30 min)
echo    • cryptocurrency_continuous_collection: Coleta continua das top 5 (5 min)
echo    • cryptocurrency_reports: Gera relatorios diarios
echo.
echo 🛠 COMANDOS UTEIS:
echo    • Ver logs: docker-compose logs [servico]
echo    • Parar tudo: docker-compose down
echo    • Reiniciar: docker-compose restart
echo    • Limpar tudo: docker-compose down -v
echo.
echo 📝 PROXIMOS PASSOS:
echo    1. Acesse http://localhost:8080 para ver a interface do Airflow
echo    2. Ative os DAGs desejados na interface web
echo    3. Monitore a coleta de dados nos logs
echo.
echo [WARNING] ⚠ NOTA: Se algum servico nao estiver funcionando, aguarde alguns minutos
echo [WARNING]    para a inicializacao completa ou verifique os logs.
echo.
echo ===============================================================================
echo                          SETUP CONCLUIDO!
echo ===============================================================================
echo.
echo Pressione qualquer tecla para continuar...
pause >nul