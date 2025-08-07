-- Script para gerar relatório de criptomoedas
-- Este arquivo é usado pelo DAG cryptocurrency_etl

-- ========================================
-- RELATÓRIO DIÁRIO DE CRIPTOMOEDAS
-- ========================================

-- 1. Resumo geral do mercado
SELECT 
    'RESUMO_MERCADO' as tipo_relatorio,
    COUNT(*) as total_criptomoedas,
    SUM(market_cap_usd) as market_cap_total,
    SUM(volume_usd_24hr) as volume_total_24h,
    AVG(change_percent_24hr) as variacao_media_24h,
    CURRENT_TIMESTAMP as data_relatorio
FROM cryptocurrencies
WHERE created_at >= CURRENT_DATE;

-- 2. Top 5 maiores por market cap
SELECT 
    'TOP_MARKET_CAP' as tipo_relatorio,
    rank,
    symbol,
    name,
    price_usd,
    market_cap_usd,
    change_percent_24hr,
    CURRENT_TIMESTAMP as data_relatorio
FROM cryptocurrencies 
WHERE created_at >= CURRENT_DATE
ORDER BY market_cap_usd DESC NULLS LAST
LIMIT 5;

-- 3. Maiores variações positivas do dia
SELECT 
    'MAIORES_GANHOS' as tipo_relatorio,
    symbol,
    name,
    price_usd,
    change_percent_24hr,
    volume_usd_24hr,
    CURRENT_TIMESTAMP as data_relatorio
FROM cryptocurrencies 
WHERE created_at >= CURRENT_DATE
  AND change_percent_24hr > 0
ORDER BY change_percent_24hr DESC NULLS LAST
LIMIT 5;

-- 4. Maiores variações negativas do dia
SELECT 
    'MAIORES_PERDAS' as tipo_relatorio,
    symbol,
    name,
    price_usd,
    change_percent_24hr,
    volume_usd_24hr,
    CURRENT_TIMESTAMP as data_relatorio
FROM cryptocurrencies 
WHERE created_at >= CURRENT_DATE
  AND change_percent_24hr < 0
ORDER BY change_percent_24hr ASC NULLS LAST
LIMIT 5;

-- 5. Estatísticas de volume
SELECT 
    'ESTATISTICAS_VOLUME' as tipo_relatorio,
    COUNT(*) as total_ativos,
    AVG(volume_usd_24hr) as volume_medio,
    MAX(volume_usd_24hr) as volume_maximo,
    MIN(volume_usd_24hr) as volume_minimo,
    SUM(volume_usd_24hr) as volume_total,
    CURRENT_TIMESTAMP as data_relatorio
FROM cryptocurrencies 
WHERE created_at >= CURRENT_DATE
  AND volume_usd_24hr IS NOT NULL;