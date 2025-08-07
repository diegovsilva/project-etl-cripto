-- Consultas úteis para análise de dados de criptomoedas
-- Este script contém várias consultas que podem ser executadas pelos operadores PostgreSQL
-- Consolidado com generate_report.sql para reduzir duplicação

-- RELATÓRIO PRINCIPAL - Top 10 criptomoedas por market cap
SELECT 
    'TOP 10 CRIPTOMOEDAS POR MARKET CAP' as report_title,
    CURRENT_TIMESTAMP as generated_at;

SELECT 
    rank,
    symbol,
    name,
    ROUND(price_usd::numeric, 4) as price_usd,
    ROUND(market_cap_usd::numeric, 2) as market_cap_usd,
    ROUND(volume_usd_24hr::numeric, 2) as volume_24h,
    ROUND(change_percent_24hr::numeric, 2) as change_24h_percent,
    created_at
FROM cryptocurrencies 
WHERE market_cap_usd IS NOT NULL
ORDER BY rank ASC
LIMIT 10;

-- ESTATÍSTICAS GERAIS
SELECT 
    'ESTATÍSTICAS GERAIS' as section,
    COUNT(*) as total_cryptocurrencies,
    ROUND(AVG(price_usd)::numeric, 4) as avg_price,
    ROUND(SUM(market_cap_usd)::numeric, 2) as total_market_cap,
    ROUND(SUM(volume_usd_24hr)::numeric, 2) as total_volume_24h
FROM cryptocurrencies
WHERE price_usd IS NOT NULL;

-- 2. Criptomoedas com maior volume de negociação 24h
SELECT 
    'TOP 10 POR VOLUME 24H' as query_type,
    symbol,
    name,
    ROUND(volume_usd_24hr::numeric, 2) as volume_24h,
    ROUND(price_usd::numeric, 4) as price_usd
FROM cryptocurrencies 
WHERE volume_usd_24hr IS NOT NULL
ORDER BY volume_usd_24hr DESC
LIMIT 10;

-- 3. Maiores ganhos nas últimas 24h
SELECT 
    'MAIORES GANHOS 24H' as query_type,
    symbol,
    name,
    ROUND(change_percent_24hr::numeric, 2) as change_percent,
    ROUND(price_usd::numeric, 4) as price_usd
FROM cryptocurrencies 
WHERE change_percent_24hr IS NOT NULL
ORDER BY change_percent_24hr DESC
LIMIT 10;

-- 4. Maiores perdas nas últimas 24h
SELECT 
    'MAIORES PERDAS 24H' as query_type,
    symbol,
    name,
    ROUND(change_percent_24hr::numeric, 2) as change_percent,
    ROUND(price_usd::numeric, 4) as price_usd
FROM cryptocurrencies 
WHERE change_percent_24hr IS NOT NULL
ORDER BY change_percent_24hr ASC
LIMIT 10;

-- 5. Estatísticas gerais do mercado
SELECT 
    'ESTATÍSTICAS GERAIS' as query_type,
    COUNT(*) as total_cryptocurrencies,
    ROUND(AVG(price_usd)::numeric, 4) as avg_price,
    ROUND(SUM(market_cap_usd)::numeric, 2) as total_market_cap,
    ROUND(SUM(volume_usd_24hr)::numeric, 2) as total_volume_24h,
    ROUND(AVG(change_percent_24hr)::numeric, 2) as avg_change_24h
FROM cryptocurrencies
WHERE price_usd IS NOT NULL;

-- 6. Histórico de preços das últimas 24h para Bitcoin
SELECT 
    'HISTÓRICO BITCOIN 24H' as query_type,
    ph.timestamp,
    ROUND(ph.price_usd::numeric, 4) as price_usd,
    ROUND(ph.market_cap_usd::numeric, 2) as market_cap_usd
FROM price_history ph
JOIN cryptocurrencies c ON ph.cryptocurrency_id = c.id
WHERE c.symbol = 'BTC' 
  AND ph.timestamp > NOW() - INTERVAL '24 hours'
ORDER BY ph.timestamp DESC
LIMIT 20;

-- 7. Criptomoedas com maior volatilidade (baseado no histórico)
SELECT 
    'MAIOR VOLATILIDADE' as query_type,
    c.symbol,
    c.name,
    COUNT(ph.id) as price_records,
    ROUND(STDDEV(ph.price_usd)::numeric, 4) as price_volatility,
    ROUND(AVG(ph.price_usd)::numeric, 4) as avg_price
FROM cryptocurrencies c
JOIN price_history ph ON c.id = ph.cryptocurrency_id
WHERE ph.timestamp > NOW() - INTERVAL '24 hours'
GROUP BY c.id, c.symbol, c.name
HAVING COUNT(ph.id) > 5
ORDER BY STDDEV(ph.price_usd) DESC
LIMIT 10;