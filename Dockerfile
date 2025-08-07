FROM apache/airflow:2.7.1

USER root

# Instala dependências do sistema
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

USER airflow

# Copia os arquivos de dependências
COPY requirements.txt /opt/airflow/

# Instala as dependências Python
RUN pip install --no-cache-dir -r /opt/airflow/requirements.txt

# Copia os scripts e DAGs
COPY --chown=airflow:root scripts/ /opt/airflow/scripts/
COPY --chown=airflow:root dags/ /opt/airflow/dags/

# Variáveis de ambiente para o Airflow
ENV AIRFLOW__CORE__LOAD_EXAMPLES=False
ENV AIRFLOW__CORE__EXECUTOR=LocalExecutor
ENV AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}
ENV AIRFLOW_CONN_POSTGRES_DEFAULT=postgresql://${DB_USER}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_NAME}