from datetime import datetime, timedelta
import sys

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

# Adiciona o caminho para os módulos personalizados
sys.path.append('/opt/airflow')
sys.path.append('/opt/airflow/dags')

# Importa funções dos módulos utils e report
import os
from utils.database_utils import read_sql_file
from report.crypto_reports import (
    generate_crypto_report, generate_market_summary, 
    generate_performance_report
)
from report.advanced_reports import (
    generate_market_analysis_report, generate_volatility_report,
    generate_top_movers_report
)

# Configurações lidas das variáveis de ambiente
DEFAULT_RETRIES = int(os.getenv('DEFAULT_RETRIES', '3'))
DEFAULT_RETRY_DELAY_MINUTES = int(os.getenv('DEFAULT_RETRY_DELAY_MINUTES', '5'))
DEFAULT_POSTGRES_CONN_ID = os.getenv('DEFAULT_POSTGRES_CONN_ID', 'postgres_default')
SQL_BASE_PATH = os.getenv('SQL_BASE_PATH', '/opt/airflow/sql')
SQL_FILES = {
    'create_report_tables': os.getenv('SQL_CREATE_REPORT_TABLES', f'{SQL_BASE_PATH}/create_report_tables.sql'),
    'report_functions': os.getenv('SQL_REPORT_FUNCTIONS', f'{SQL_BASE_PATH}/report_functions.sql'),
    'report_automation': os.getenv('SQL_REPORT_AUTOMATION', f'{SQL_BASE_PATH}/report_automation.sql')
}
DAG_TAGS = os.getenv('DAG_TAGS_REPORTS', 'cryptocurrency,reports,analytics,postgres').split(',')
EMAIL_CONFIG = {
    'email_on_failure': os.getenv('EMAIL_ON_FAILURE', 'false').lower() == 'true',
    'email_on_retry': os.getenv('EMAIL_ON_RETRY', 'false').lower() == 'true',
    'email_on_success': os.getenv('EMAIL_ON_SUCCESS', 'false').lower() == 'true'
}

# Configurações padrão da DAG
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'retries': DEFAULT_RETRIES,
    'retry_delay': timedelta(minutes=DEFAULT_RETRY_DELAY_MINUTES),
    **EMAIL_CONFIG
}

# Definição da DAG
dag = DAG(
    'cryptocurrency_reports',
    default_args=default_args,
    description='DAG para geração de relatórios avançados de criptomoedas',
    schedule_interval=timedelta(hours=6),  # Executa a cada 6 horas
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=DAG_TAGS,
)

# Tarefas SQL para configuração das tabelas de relatórios
setup_report_tables_task = PostgresOperator(
    task_id='setup_report_tables',
    postgres_conn_id=DEFAULT_POSTGRES_CONN_ID,
    sql=read_sql_file(SQL_FILES['create_report_tables']),
    dag=dag,
)

setup_report_functions_task = PostgresOperator(
    task_id='setup_report_functions',
    postgres_conn_id=DEFAULT_POSTGRES_CONN_ID,
    sql=read_sql_file(SQL_FILES['report_functions']),
    dag=dag,
)

setup_report_automation_task = PostgresOperator(
    task_id='setup_report_automation',
    postgres_conn_id=DEFAULT_POSTGRES_CONN_ID,
    sql=read_sql_file(SQL_FILES['report_automation']),
    dag=dag,
)

# Tarefa para executar análise diária automatizada
run_daily_analysis_task = PostgresOperator(
    task_id='run_daily_analysis',
    postgres_conn_id=DEFAULT_POSTGRES_CONN_ID,
    sql="SELECT run_daily_report_analysis();",
    dag=dag,
)

# Tarefa para relatório básico
basic_report_task = PythonOperator(
    task_id='generate_basic_report',
    python_callable=generate_crypto_report,
    op_kwargs={'limit': 15},
    dag=dag,
)

# Tarefa para resumo do mercado
market_summary_task = PythonOperator(
    task_id='generate_market_summary',
    python_callable=generate_market_summary,
    dag=dag,
)

# Tarefa para relatório de performance
performance_report_task = PythonOperator(
    task_id='generate_performance_report',
    python_callable=generate_performance_report,
    dag=dag,
)

# Tarefa para análise de mercado
market_analysis_task = PythonOperator(
    task_id='generate_market_analysis',
    python_callable=generate_market_analysis_report,
    dag=dag,
)

# Tarefa para relatório de volatilidade
volatility_report_task = PythonOperator(
    task_id='generate_volatility_report',
    python_callable=generate_volatility_report,
    dag=dag,
)

# Tarefa para top movers
top_movers_task = PythonOperator(
    task_id='generate_top_movers_report',
    python_callable=generate_top_movers_report,
    dag=dag,
)

# Definição do fluxo de tarefas
# 1. Configura tabelas e funções SQL primeiro
setup_report_tables_task >> setup_report_functions_task >> setup_report_automation_task

# 2. Executa análise diária automatizada
setup_report_automation_task >> run_daily_analysis_task

# 3. Executa relatórios Python básicos primeiro, depois os avançados em paralelo
run_daily_analysis_task >> basic_report_task >> market_summary_task
market_summary_task >> [performance_report_task, market_analysis_task, volatility_report_task, top_movers_task]