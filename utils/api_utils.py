import sys
sys.path.append('/opt/airflow')
from scripts.api import CoinCapAPI
from datetime import datetime
from utils.database_utils import store_crypto_data_to_db


def fetch_crypto_data(limit=10, **kwargs):
    """Busca dados da API CoinCap e prepara para inserção no banco"""
    api = CoinCapAPI()
    
    print(f"Buscando dados das top {limit} criptomoedas...")
    crypto_data = api.get_top_assets(limit=limit)
    
    if not crypto_data:
        raise Exception("Erro ao buscar dados da API.")
    
    print(f"Encontradas {len(crypto_data)} criptomoedas")
    
    # Formata os dados para o formato esperado pelo banco
    formatted_data = [api.format_crypto_data(crypto) for crypto in crypto_data]
    
    # Passa os dados para a próxima tarefa via XCom
    if 'ti' in kwargs:
        kwargs['ti'].xcom_push(key='crypto_data', value=formatted_data)
    
    return f"Dados de {len(formatted_data)} criptomoedas obtidos com sucesso"


def fetch_and_store_crypto_data(limit=5, postgres_conn_id='postgres_default', **kwargs):
    """Busca e armazena dados das top criptomoedas diretamente no banco"""
    api = CoinCapAPI()
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"{timestamp} - Buscando dados das top {limit} criptomoedas...")
    
    crypto_data = api.get_top_assets(limit=limit)
    
    if not crypto_data:
        print("Erro ao buscar dados da API.")
        return "Falha na coleta de dados"
    
    # Formata os dados
    formatted_data = [api.format_crypto_data(crypto) for crypto in crypto_data]
    
    # Armazena no banco
    result = store_crypto_data_to_db(formatted_data, postgres_conn_id)
    
    # Log adicional para monitoramento
    for crypto in crypto_data:
        price = crypto.get('priceUsd', 'N/A')
        change = crypto.get('changePercent24Hr')
        change_indicator = "UP" if change and float(change) > 0 else "DOWN" if change and float(change) < 0 else "STABLE"
        print(f"{crypto['name']} ({crypto['symbol']}) - ${price} {change_indicator}")
    
    return result


def store_crypto_data_from_xcom(**kwargs):
    """Insere dados de criptomoedas no banco usando dados do XCom"""
    ti = kwargs['ti']
    crypto_data_list = ti.xcom_pull(key='crypto_data', task_ids='fetch_crypto_data')
    
    return store_crypto_data_to_db(crypto_data_list)