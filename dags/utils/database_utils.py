from airflow.providers.postgres.hooks.postgres import PostgresHook
from datetime import datetime


def read_sql_file(file_path):
    """Read SQL file content"""
    with open(file_path, 'r') as file:
        return file.read()


def store_crypto_data_to_db(crypto_data_list, postgres_conn_id='postgres_default'):
    """Insere dados de criptomoedas no banco usando PostgresHook"""
    if not crypto_data_list:
        raise Exception("Nenhum dado de criptomoeda encontrado")
    
    # Conecta ao banco usando PostgresHook
    postgres_hook = PostgresHook(postgres_conn_id=postgres_conn_id)
    
    success_count = 0
    error_count = 0
    
    for crypto_data in crypto_data_list:
        try:
            # Chama a função stored procedure para upsert
            postgres_hook.run(
                sql="SELECT upsert_cryptocurrency(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
                parameters=(
                    crypto_data['id'],
                    crypto_data.get('rank'),
                    crypto_data['symbol'],
                    crypto_data['name'],
                    crypto_data.get('supply'),
                    crypto_data.get('maxSupply'),
                    crypto_data.get('marketCapUsd'),
                    crypto_data.get('volumeUsd24Hr'),
                    crypto_data.get('priceUsd'),
                    crypto_data.get('changePercent24Hr'),
                    crypto_data.get('vwap24Hr'),
                    crypto_data.get('explorer')
                )
            )
            success_count += 1
            print(f"{crypto_data['name']} ({crypto_data['symbol']}) - ${crypto_data.get('priceUsd', 'N/A')}")
        except Exception as e:
            error_count += 1
            print(f"Erro ao inserir {crypto_data['name']}: {e}")
    
    if error_count > 0:
        print(f"{error_count} erros durante a inserção")
    
    return f"Dados inseridos: {success_count}/{len(crypto_data_list)} (Erros: {error_count})"


def check_database_health(postgres_conn_id='postgres_default'):
    """Verifica a saúde do banco de dados e estatísticas básicas"""
    postgres_hook = PostgresHook(postgres_conn_id=postgres_conn_id)
    
    try:
        # Verifica quantos registros temos
        count_result = postgres_hook.get_first(
            sql="SELECT COUNT(*) FROM cryptocurrencies"
        )
        
        # Verifica o último update
        last_update = postgres_hook.get_first(
            sql="SELECT MAX(created_at) FROM cryptocurrencies"
        )
        
        # Verifica registros no histórico
        history_count = postgres_hook.get_first(
            sql="SELECT COUNT(*) FROM price_history"
        )
        
        crypto_count = count_result[0] if count_result else 0
        last_update_time = last_update[0] if last_update else "Nunca"
        history_records = history_count[0] if history_count else 0
        
        health_report = f"SAÚDE DO BANCO DE DADOS:\n"
        health_report += f"  Criptomoedas registradas: {crypto_count}\n"
        health_report += f"  Registros de histórico: {history_records}\n"
        health_report += f"  Última atualização: {last_update_time}\n"
        
        print(health_report)
        return f"Banco saudável - {crypto_count} cryptos, {history_records} históricos"
        
    except Exception as e:
        error_msg = f"Erro ao verificar saúde do banco: {e}"
        print(error_msg)
        return error_msg


def get_top_cryptocurrencies(limit=10, postgres_conn_id='postgres_default'):
    """Busca as top criptomoedas do banco de dados"""
    postgres_hook = PostgresHook(postgres_conn_id=postgres_conn_id)
    
    records = postgres_hook.get_records(
        sql="""
        SELECT rank, symbol, name, 
               ROUND(price_usd::numeric, 4) as price_usd,
               ROUND(market_cap_usd::numeric, 2) as market_cap_usd,
               ROUND(volume_usd_24hr::numeric, 2) as volume_24h,
               ROUND(change_percent_24hr::numeric, 2) as change_24h_percent
        FROM cryptocurrencies 
        WHERE market_cap_usd IS NOT NULL
        ORDER BY rank ASC
        LIMIT %s
        """,
        parameters=(limit,)
    )
    
    return records


def get_database_statistics(postgres_conn_id='postgres_default'):
    """Busca estatísticas gerais do banco de dados"""
    postgres_hook = PostgresHook(postgres_conn_id=postgres_conn_id)
    
    stats = postgres_hook.get_first(
        sql="""
        SELECT COUNT(*) as total,
               ROUND(AVG(price_usd)::numeric, 4) as avg_price,
               ROUND(SUM(market_cap_usd)::numeric, 2) as total_market_cap
        FROM cryptocurrencies
        WHERE price_usd IS NOT NULL
        """
    )
    
    return stats