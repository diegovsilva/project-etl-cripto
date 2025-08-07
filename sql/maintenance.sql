-- Script de manutenção do banco de dados
-- Este script pode ser usado para limpeza e otimização

-- Remove registros de histórico mais antigos que 30 dias
DELETE FROM price_history 
WHERE timestamp < NOW() - INTERVAL '30 days';

-- Atualiza estatísticas das tabelas para melhor performance
ANALYZE cryptocurrencies;
ANALYZE price_history;

-- Reindexação para otimizar consultas
REINDEX INDEX idx_cryptocurrencies_rank;
REINDEX INDEX idx_price_history_crypto_id;
REINDEX INDEX idx_price_history_timestamp;

-- Estatísticas de manutenção
SELECT 
    'MANUTENÇÃO CONCLUÍDA' as status,
    CURRENT_TIMESTAMP as executed_at,
    (
        SELECT COUNT(*) FROM cryptocurrencies
    ) as total_cryptocurrencies,
    (
        SELECT COUNT(*) FROM price_history
    ) as total_price_records,
    (
        SELECT COUNT(*) FROM price_history 
        WHERE timestamp > NOW() - INTERVAL '24 hours'
    ) as records_last_24h;