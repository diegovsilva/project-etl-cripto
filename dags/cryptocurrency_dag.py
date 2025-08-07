from datetime import datetime, timedelta
import os
import sys

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

# Adiciona o caminho para os módulos personalizados
sys.path.append('/opt/airflow')
sys.path.append('/opt/airflow/dags')

# Importa funções dos módulos utils e report
from utils.database_utils import read_sql_file
from utils.api_utils import fetch_crypto_data, store_crypto_data_from_xcom
from report.crypto_reports import generate_crypto_report
import os

# Configurações lidas das variáveis de ambiente
DEFAULT_RETRIES = int(os.getenv('DEFAULT_RETRIES', '3'))
DEFAULT_RETRY_DELAY_MINUTES = int(os.getenv('DEFAULT_RETRY_DELAY_MINUTES', '5'))
ETL_SCHEDULE_MINUTES = int(os.getenv('ETL_SCHEDULE_MINUTES', '30'))
DEFAULT_API_LIMIT = int(os.getenv('DEFAULT_API_LIMIT', '10'))
SQL_BASE_PATH = os.getenv('SQL_BASE_PATH', '/opt/airflow/sql')
SQL_FILES = {
    'create_tables': os.getenv('SQL_CREATE_TABLES', f'{SQL_BASE_PATH}/create_tables.sql'),
    'upsert_cryptocurrency': os.getenv('SQL_UPSERT_CRYPTOCURRENCY', f'{SQL_BASE_PATH}/upsert_cryptocurrency.sql'),
    'generate_report': os.getenv('SQL_GENERATE_REPORT', f'{SQL_BASE_PATH}/generate_report.sql')
}
DAG_TAGS = os.getenv('DAG_TAGS_ETL', 'cryptocurrency,coincap,etl,postgres').split(',')
EMAIL_CONFIG = {
    'email_on_failure': os.getenv('EMAIL_ON_FAILURE', 'false').lower() == 'true',
    'email_on_retry': os.getenv('EMAIL_ON_RETRY', 'false').lower() == 'true',
    'email_on_success': os.getenv('EMAIL_ON_SUCCESS', 'false').lower() == 'true'
}

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'retries': DEFAULT_RETRIES,
    'retry_delay': timedelta(minutes=DEFAULT_RETRY_DELAY_MINUTES),
    **EMAIL_CONFIG
}

dag = DAG(
    'cryptocurrency_etl',
    default_args=default_args,
    description='ETL para dados de criptomoedas da API CoinCap usando operadores PostgreSQL',
    schedule_interval=timedelta(minutes=ETL_SCHEDULE_MINUTES), 
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=DAG_TAGS,
)

# As funções foram movidas para os módulos utils e report

# Tarefa para criar tabelas usando PostgresOperator
setup_db_task = PostgresOperator(
        task_id='setup_database',
        postgres_conn_id='postgres_default',
        sql=read_sql_file(SQL_FILES['create_tables']),
        dag=dag
    )

# Tarefa para criar função stored procedure
create_upsert_function_task = PostgresOperator(
        task_id='create_upsert_function',
        postgres_conn_id='postgres_default',
        sql=read_sql_file(SQL_FILES['upsert_cryptocurrency']),
        dag=dag
    )

# Tarefa para buscar dados da API
fetch_data_task = PythonOperator(
    task_id='fetch_crypto_data',
    python_callable=fetch_crypto_data,
    op_kwargs={'limit': DEFAULT_API_LIMIT},
    dag=dag,
)

# Tarefa para armazenar dados no banco
store_data_task = PythonOperator(
    task_id='store_crypto_data',
    python_callable=store_crypto_data_from_xcom,
    dag=dag,
)

# Tarefa para gerar relatório usando PostgresOperator
generate_report_task = PostgresOperator(
        task_id='generate_sql_report',
        postgres_conn_id='postgres_default',
        sql=read_sql_file(SQL_FILES['generate_report']),
        dag=dag
    )

# Tarefa para gerar relatório customizado
generate_custom_report_task = PythonOperator(
    task_id='generate_custom_report',
    python_callable=generate_crypto_report,
    op_kwargs={'limit': 10},
    dag=dag,
)

# Definição do fluxo de tarefas
setup_db_task >> create_upsert_function_task >> fetch_data_task >> store_data_task >> [generate_report_task, generate_custom_report_task]