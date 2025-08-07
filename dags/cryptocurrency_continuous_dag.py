from datetime import datetime, timedelta
import os
import sys

from airflow import DAG
from airflow.operators.python import PythonOperator
from airflow.providers.postgres.operators.postgres import PostgresOperator

# Adiciona o caminho para os módulos personalizados
sys.path.append('/opt/airflow')
sys.path.append('/opt/airflow/dags')

# Importa funções dos módulos utils
from utils.database_utils import read_sql_file, check_database_health
from utils.api_utils import fetch_and_store_crypto_data
import os

# Configurações lidas das variáveis de ambiente
DEFAULT_RETRIES = int(os.getenv('DEFAULT_RETRIES', '3'))
CONTINUOUS_RETRY_DELAY_MINUTES = int(os.getenv('CONTINUOUS_RETRY_DELAY_MINUTES', '1'))
CONTINUOUS_SCHEDULE_MINUTES = int(os.getenv('CONTINUOUS_SCHEDULE_MINUTES', '5'))
CONTINUOUS_API_LIMIT = int(os.getenv('CONTINUOUS_API_LIMIT', '5'))
SQL_BASE_PATH = os.getenv('SQL_BASE_PATH', '/opt/airflow/sql')
SQL_FILES = {
    'upsert_cryptocurrency': os.getenv('SQL_UPSERT_CRYPTOCURRENCY', f'{SQL_BASE_PATH}/upsert_cryptocurrency.sql')
}
DAG_TAGS = os.getenv('DAG_TAGS_CONTINUOUS', 'cryptocurrency,coincap,continuous,postgres').split(',')
EMAIL_CONFIG = {
    'email_on_failure': os.getenv('EMAIL_ON_FAILURE', 'false').lower() == 'true',
    'email_on_retry': os.getenv('EMAIL_ON_RETRY', 'false').lower() == 'true',
    'email_on_success': os.getenv('EMAIL_ON_SUCCESS', 'false').lower() == 'true'
}

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'retries': DEFAULT_RETRIES,
    'retry_delay': timedelta(minutes=CONTINUOUS_RETRY_DELAY_MINUTES),
    **EMAIL_CONFIG
}

dag = DAG(
    'cryptocurrency_continuous_collection',
    default_args=default_args,
    description='Coleta contínua de dados de criptomoedas da API CoinCap usando operadores PostgreSQL',
    schedule_interval=timedelta(minutes=CONTINUOUS_SCHEDULE_MINUTES),
    start_date=datetime(2023, 1, 1),
    catchup=False,
    tags=DAG_TAGS,
)

# As funções foram movidas para os módulos utils

# Ensure upsert function exists
ensure_upsert_function_task = PostgresOperator(
        task_id='ensure_upsert_function',
        postgres_conn_id='postgres_default',
        sql=read_sql_file(SQL_FILES['upsert_cryptocurrency']),
        dag=dag
    )

# Tarefa para verificar saúde do banco
health_check_task = PythonOperator(
    task_id='database_health_check',
    python_callable=check_database_health,
    dag=dag,
)

# Tarefa principal para buscar e armazenar dados
fetch_and_store_task = PythonOperator(
    task_id='fetch_and_store_top_cryptos',
    python_callable=fetch_and_store_crypto_data,
    op_kwargs={'limit': CONTINUOUS_API_LIMIT},
    dag=dag,
)

# Definição do fluxo de tarefas
ensure_upsert_function_task >> health_check_task >> fetch_and_store_task
