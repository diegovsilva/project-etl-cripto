-- Tabelas para armazenamento de relatórios de criptomoedas
-- Criado para permitir análises históricas e consultas estruturadas

-- Tabela principal para relatórios básicos de criptomoedas
CREATE TABLE IF NOT EXISTS crypto_reports (
    id SERIAL PRIMARY KEY,
    report_type VARCHAR(50) NOT NULL, -- 'basic', 'market_summary', 'performance'
    report_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_cryptos INTEGER,
    avg_price DECIMAL(20, 8),
    total_market_cap DECIMAL(30, 2),
    report_content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para análise de volatilidade
CREATE TABLE IF NOT EXISTS volatility_analysis (
    id SERIAL PRIMARY KEY,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(100),
    price_usd DECIMAL(20, 8),
    change_percent_24hr DECIMAL(10, 4),
    volatility_category VARCHAR(20), -- 'high', 'medium', 'low'
    abs_change DECIMAL(10, 4),
    market_cap_usd DECIMAL(30, 2),
    volume_24hr DECIMAL(30, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para top movers (maiores movimentações)
CREATE TABLE IF NOT EXISTS top_movers (
    id SERIAL PRIMARY KEY,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(100),
    price_usd DECIMAL(20, 8),
    change_percent_24hr DECIMAL(10, 4),
    movement_type VARCHAR(10), -- 'gainer', 'loser'
    rank_position INTEGER,
    market_cap_usd DECIMAL(30, 2),
    volume_24hr DECIMAL(30, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para análise de tendências de mercado
CREATE TABLE IF NOT EXISTS market_trends (
    id SERIAL PRIMARY KEY,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(100),
    avg_change_7d DECIMAL(10, 4),
    trend_direction VARCHAR(20), -- 'bullish', 'bearish', 'neutral', 'volatile'
    price_trend VARCHAR(20), -- 'up', 'down', 'stable'
    data_points INTEGER, -- número de pontos de dados analisados
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para sentimento do mercado
CREATE TABLE IF NOT EXISTS market_sentiment (
    id SERIAL PRIMARY KEY,
    analysis_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total_analyzed INTEGER,
    assets_up INTEGER,
    assets_down INTEGER,
    assets_stable INTEGER,
    positive_ratio DECIMAL(5, 2),
    sentiment_score VARCHAR(20), -- 'optimistic', 'neutral', 'pessimistic'
    avg_volatility DECIMAL(10, 4),
    max_volatility DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabela para performance diária agregada
CREATE TABLE IF NOT EXISTS daily_performance (
    id SERIAL PRIMARY KEY,
    report_date DATE DEFAULT CURRENT_DATE,
    total_gainers INTEGER,
    total_losers INTEGER,
    total_stable INTEGER,
    biggest_gainer_symbol VARCHAR(10),
    biggest_gainer_change DECIMAL(10, 4),
    biggest_loser_symbol VARCHAR(10),
    biggest_loser_change DECIMAL(10, 4),
    market_cap_change DECIMAL(10, 4),
    avg_volume DECIMAL(30, 2),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(report_date)
);

-- Tabela para histórico de rankings
CREATE TABLE IF NOT EXISTS ranking_history (
    id SERIAL PRIMARY KEY,
    snapshot_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    symbol VARCHAR(10) NOT NULL,
    name VARCHAR(100),
    rank_position INTEGER,
    price_usd DECIMAL(20, 8),
    market_cap_usd DECIMAL(30, 2),
    volume_24hr DECIMAL(30, 2),
    change_percent_24hr DECIMAL(10, 4),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Índices para melhor performance
CREATE INDEX IF NOT EXISTS idx_crypto_reports_type_date ON crypto_reports(report_type, report_date);
CREATE INDEX IF NOT EXISTS idx_volatility_symbol_date ON volatility_analysis(symbol, analysis_date);
CREATE INDEX IF NOT EXISTS idx_top_movers_type_date ON top_movers(movement_type, analysis_date);
CREATE INDEX IF NOT EXISTS idx_market_trends_symbol_date ON market_trends(symbol, analysis_date);
CREATE INDEX IF NOT EXISTS idx_market_sentiment_date ON market_sentiment(analysis_date);
CREATE INDEX IF NOT EXISTS idx_daily_performance_date ON daily_performance(report_date);
CREATE INDEX IF NOT EXISTS idx_ranking_history_symbol_date ON ranking_history(symbol, snapshot_date);

-- Views para consultas comuns

-- View para últimos relatórios por tipo
CREATE OR REPLACE VIEW latest_reports AS
SELECT DISTINCT ON (report_type) 
    report_type,
    report_date,
    total_cryptos,
    avg_price,
    total_market_cap
FROM crypto_reports
ORDER BY report_type, report_date DESC;

-- View para análise de volatilidade atual
CREATE OR REPLACE VIEW current_volatility AS
SELECT 
    volatility_category,
    COUNT(*) as count,
    AVG(abs_change) as avg_change,
    MAX(abs_change) as max_change
FROM volatility_analysis
WHERE analysis_date >= CURRENT_DATE
GROUP BY volatility_category;

-- View para sentimento de mercado atual
CREATE OR REPLACE VIEW current_market_sentiment AS
SELECT 
    analysis_date,
    sentiment_score,
    positive_ratio,
    total_analyzed,
    avg_volatility
FROM market_sentiment
WHERE analysis_date >= CURRENT_DATE - INTERVAL '1 day'
ORDER BY analysis_date DESC
LIMIT 1;

-- View para top performers histórico
CREATE OR REPLACE VIEW top_performers_7d AS
SELECT 
    symbol,
    name,
    AVG(change_percent_24hr) as avg_change_7d,
    COUNT(*) as data_points
FROM ranking_history
WHERE snapshot_date >= CURRENT_DATE - INTERVAL '7 days'
GROUP BY symbol, name
HAVING COUNT(*) >= 3
ORDER BY avg_change_7d DESC
LIMIT 20;

-- Comentários das tabelas
COMMENT ON TABLE crypto_reports IS 'Armazena relatórios básicos de criptomoedas com estatísticas gerais';
COMMENT ON TABLE volatility_analysis IS 'Análise de volatilidade das criptomoedas por período';
COMMENT ON TABLE top_movers IS 'Registro dos maiores movimentadores (altas e quedas) do mercado';
COMMENT ON TABLE market_trends IS 'Análise de tendências de mercado baseada em dados históricos';
COMMENT ON TABLE market_sentiment IS 'Indicadores de sentimento do mercado';
COMMENT ON TABLE daily_performance IS 'Performance diária agregada do mercado';
COMMENT ON TABLE ranking_history IS 'Histórico de rankings e posições das criptomoedas';