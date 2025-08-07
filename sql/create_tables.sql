-- Script para criação das tabelas de criptomoedas
-- Este script será executado pelo PostgresOperator do Airflow

-- Tabela de criptomoedas
CREATE TABLE IF NOT EXISTS cryptocurrencies (
    id VARCHAR(50) PRIMARY KEY,
    rank INTEGER,
    symbol VARCHAR(20) NOT NULL,
    name VARCHAR(100) NOT NULL,
    supply DECIMAL(20, 8),
    max_supply DECIMAL(20, 8),
    market_cap_usd DECIMAL(20, 2),
    volume_usd_24hr DECIMAL(20, 2),
    price_usd DECIMAL(20, 8),
    change_percent_24hr DECIMAL(10, 4),
    vwap_24hr DECIMAL(20, 8),
    explorer VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela de histórico de preços
CREATE TABLE IF NOT EXISTS price_history (
    id SERIAL PRIMARY KEY,
    cryptocurrency_id VARCHAR(50) REFERENCES cryptocurrencies(id),
    price_usd DECIMAL(20, 8) NOT NULL,
    market_cap_usd DECIMAL(20, 2),
    volume_usd_24hr DECIMAL(20, 2),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Cria índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_cryptocurrencies_rank ON cryptocurrencies(rank);
CREATE INDEX IF NOT EXISTS idx_price_history_crypto_id ON price_history(cryptocurrency_id);
CREATE INDEX IF NOT EXISTS idx_price_history_timestamp ON price_history(timestamp);

-- Log de sucesso
SELECT 'Tabelas criadas com sucesso!' as status;