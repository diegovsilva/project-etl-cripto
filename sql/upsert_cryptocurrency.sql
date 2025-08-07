-- Script para inserção/atualização de dados de criptomoedas
-- Este script será executado pelo PostgresOperator do Airflow

-- Função para inserir ou atualizar dados de criptomoeda
CREATE OR REPLACE FUNCTION upsert_cryptocurrency(
    p_id VARCHAR(50),
    p_rank INTEGER,
    p_symbol VARCHAR(20),
    p_name VARCHAR(100),
    p_supply DECIMAL(20, 8),
    p_max_supply DECIMAL(20, 8),
    p_market_cap_usd DECIMAL(20, 2),
    p_volume_usd_24hr DECIMAL(20, 2),
    p_price_usd DECIMAL(20, 8),
    p_change_percent_24hr DECIMAL(10, 4),
    p_vwap_24hr DECIMAL(20, 8),
    p_explorer VARCHAR(255)
) RETURNS VOID AS $$
BEGIN
    -- Upsert na tabela cryptocurrencies
    INSERT INTO cryptocurrencies (
        id, rank, symbol, name, supply, max_supply, 
        market_cap_usd, volume_usd_24hr, price_usd, 
        change_percent_24hr, vwap_24hr, explorer
    ) VALUES (
        p_id, p_rank, p_symbol, p_name, p_supply, p_max_supply,
        p_market_cap_usd, p_volume_usd_24hr, p_price_usd,
        p_change_percent_24hr, p_vwap_24hr, p_explorer
    ) ON CONFLICT (id) DO UPDATE SET
        rank = EXCLUDED.rank,
        symbol = EXCLUDED.symbol,
        name = EXCLUDED.name,
        supply = EXCLUDED.supply,
        max_supply = EXCLUDED.max_supply,
        market_cap_usd = EXCLUDED.market_cap_usd,
        volume_usd_24hr = EXCLUDED.volume_usd_24hr,
        price_usd = EXCLUDED.price_usd,
        change_percent_24hr = EXCLUDED.change_percent_24hr,
        vwap_24hr = EXCLUDED.vwap_24hr,
        explorer = EXCLUDED.explorer,
        created_at = CURRENT_TIMESTAMP;
    
    -- Insere no histórico de preços
    INSERT INTO price_history (
        cryptocurrency_id, price_usd, market_cap_usd, volume_usd_24hr
    ) VALUES (
        p_id, p_price_usd, p_market_cap_usd, p_volume_usd_24hr
    );
END;
$$ LANGUAGE plpgsql;