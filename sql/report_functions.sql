-- Funções para inserção e manipulação de dados de relatórios

-- Função para inserir relatório básico
CREATE OR REPLACE FUNCTION insert_crypto_report(
    p_report_type VARCHAR(50),
    p_total_cryptos INTEGER,
    p_avg_price DECIMAL(20, 8),
    p_total_market_cap DECIMAL(30, 2),
    p_report_content TEXT DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    report_id INTEGER;
BEGIN
    INSERT INTO crypto_reports (
        report_type,
        total_cryptos,
        avg_price,
        total_market_cap,
        report_content
    ) VALUES (
        p_report_type,
        p_total_cryptos,
        p_avg_price,
        p_total_market_cap,
        p_report_content
    ) RETURNING id INTO report_id;
    
    RETURN report_id;
END;
$$ LANGUAGE plpgsql;

-- Função para inserir análise de volatilidade
CREATE OR REPLACE FUNCTION insert_volatility_analysis(
    p_symbol VARCHAR(10),
    p_name VARCHAR(100),
    p_price_usd DECIMAL(20, 8),
    p_change_percent_24hr DECIMAL(10, 4),
    p_market_cap_usd DECIMAL(30, 2),
    p_volume_24hr DECIMAL(30, 2)
) RETURNS VOID AS $$
DECLARE
    v_abs_change DECIMAL(10, 4);
    v_category VARCHAR(20);
BEGIN
    -- Calcula mudança absoluta
    v_abs_change := ABS(p_change_percent_24hr);
    
    -- Determina categoria de volatilidade
    IF v_abs_change > 10 THEN
        v_category := 'high';
    ELSIF v_abs_change > 3 THEN
        v_category := 'medium';
    ELSE
        v_category := 'low';
    END IF;
    
    INSERT INTO volatility_analysis (
        symbol,
        name,
        price_usd,
        change_percent_24hr,
        volatility_category,
        abs_change,
        market_cap_usd,
        volume_24hr
    ) VALUES (
        p_symbol,
        p_name,
        p_price_usd,
        p_change_percent_24hr,
        v_category,
        v_abs_change,
        p_market_cap_usd,
        p_volume_24hr
    );
END;
$$ LANGUAGE plpgsql;

-- Função para inserir top movers
CREATE OR REPLACE FUNCTION insert_top_mover(
    p_symbol VARCHAR(10),
    p_name VARCHAR(100),
    p_price_usd DECIMAL(20, 8),
    p_change_percent_24hr DECIMAL(10, 4),
    p_rank_position INTEGER,
    p_market_cap_usd DECIMAL(30, 2),
    p_volume_24hr DECIMAL(30, 2)
) RETURNS VOID AS $$
DECLARE
    v_movement_type VARCHAR(10);
BEGIN
    -- Determina tipo de movimento
    IF p_change_percent_24hr > 0 THEN
        v_movement_type := 'gainer';
    ELSE
        v_movement_type := 'loser';
    END IF;
    
    INSERT INTO top_movers (
        symbol,
        name,
        price_usd,
        change_percent_24hr,
        movement_type,
        rank_position,
        market_cap_usd,
        volume_24hr
    ) VALUES (
        p_symbol,
        p_name,
        p_price_usd,
        p_change_percent_24hr,
        v_movement_type,
        p_rank_position,
        p_market_cap_usd,
        p_volume_24hr
    );
END;
$$ LANGUAGE plpgsql;

-- Função para calcular e inserir sentimento do mercado
CREATE OR REPLACE FUNCTION calculate_market_sentiment() RETURNS VOID AS $$
DECLARE
    v_total_analyzed INTEGER;
    v_assets_up INTEGER;
    v_assets_down INTEGER;
    v_assets_stable INTEGER;
    v_positive_ratio DECIMAL(5, 2);
    v_sentiment_score VARCHAR(20);
    v_avg_volatility DECIMAL(10, 4);
    v_max_volatility DECIMAL(10, 4);
BEGIN
    -- Conta ativos por categoria baseado nos dados mais recentes
    SELECT 
        COUNT(*),
        COUNT(CASE WHEN change_percent_24hr > 0 THEN 1 END),
        COUNT(CASE WHEN change_percent_24hr < 0 THEN 1 END),
        COUNT(CASE WHEN change_percent_24hr = 0 OR change_percent_24hr IS NULL THEN 1 END)
    INTO v_total_analyzed, v_assets_up, v_assets_down, v_assets_stable
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE;
    
    -- Calcula estatísticas de volatilidade
    SELECT 
        AVG(ABS(change_percent_24hr)),
        MAX(ABS(change_percent_24hr))
    INTO v_avg_volatility, v_max_volatility
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE
    AND change_percent_24hr IS NOT NULL;
    
    -- Calcula ratio positivo
    IF v_total_analyzed > 0 THEN
        v_positive_ratio := (v_assets_up::DECIMAL / v_total_analyzed) * 100;
    ELSE
        v_positive_ratio := 0;
    END IF;
    
    -- Determina sentimento
    IF v_positive_ratio > 60 THEN
        v_sentiment_score := 'optimistic';
    ELSIF v_positive_ratio > 40 THEN
        v_sentiment_score := 'neutral';
    ELSE
        v_sentiment_score := 'pessimistic';
    END IF;
    
    -- Insere dados
    INSERT INTO market_sentiment (
        total_analyzed,
        assets_up,
        assets_down,
        assets_stable,
        positive_ratio,
        sentiment_score,
        avg_volatility,
        max_volatility
    ) VALUES (
        v_total_analyzed,
        v_assets_up,
        v_assets_down,
        v_assets_stable,
        v_positive_ratio,
        v_sentiment_score,
        v_avg_volatility,
        v_max_volatility
    );
END;
$$ LANGUAGE plpgsql;

-- Função para inserir snapshot do ranking
CREATE OR REPLACE FUNCTION insert_ranking_snapshot() RETURNS VOID AS $$
BEGIN
    INSERT INTO ranking_history (
        symbol,
        name,
        rank_position,
        price_usd,
        market_cap_usd,
        volume_24hr,
        change_percent_24hr
    )
    SELECT 
        symbol,
        name,
        ROW_NUMBER() OVER (ORDER BY market_cap_usd DESC NULLS LAST) as rank_position,
        price_usd,
        market_cap_usd,
        volume_usd_24hr,
        change_percent_24hr
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE
    ORDER BY market_cap_usd DESC NULLS LAST;
END;
$$ LANGUAGE plpgsql;

-- Função para calcular performance diária
CREATE OR REPLACE FUNCTION calculate_daily_performance(
    p_date DATE DEFAULT CURRENT_DATE
) RETURNS VOID AS $$
DECLARE
    v_total_gainers INTEGER;
    v_total_losers INTEGER;
    v_total_stable INTEGER;
    v_biggest_gainer_symbol VARCHAR(10);
    v_biggest_gainer_change DECIMAL(10, 4);
    v_biggest_loser_symbol VARCHAR(10);
    v_biggest_loser_change DECIMAL(10, 4);
    v_market_cap_change DECIMAL(10, 4);
    v_avg_volume DECIMAL(30, 2);
BEGIN
    -- Conta por categoria
    SELECT 
        COUNT(CASE WHEN change_percent_24hr > 5 THEN 1 END),
        COUNT(CASE WHEN change_percent_24hr < -5 THEN 1 END),
        COUNT(CASE WHEN change_percent_24hr BETWEEN -5 AND 5 THEN 1 END)
    INTO v_total_gainers, v_total_losers, v_total_stable
    FROM cryptocurrencies
    WHERE DATE(created_at) = p_date;
    
    -- Encontra maior alta
    SELECT symbol, change_percent_24hr
    INTO v_biggest_gainer_symbol, v_biggest_gainer_change
    FROM cryptocurrencies
    WHERE DATE(created_at) = p_date
    AND change_percent_24hr IS NOT NULL
    ORDER BY change_percent_24hr DESC
    LIMIT 1;
    
    -- Encontra maior queda
    SELECT symbol, change_percent_24hr
    INTO v_biggest_loser_symbol, v_biggest_loser_change
    FROM cryptocurrencies
    WHERE DATE(created_at) = p_date
    AND change_percent_24hr IS NOT NULL
    ORDER BY change_percent_24hr ASC
    LIMIT 1;
    
    -- Calcula mudança do market cap e volume médio
    SELECT 
        AVG(change_percent_24hr),
        AVG(volume_usd_24hr)
    INTO v_market_cap_change, v_avg_volume
    FROM cryptocurrencies
    WHERE DATE(created_at) = p_date
    AND change_percent_24hr IS NOT NULL;
    
    -- Insere ou atualiza dados
    INSERT INTO daily_performance (
        report_date,
        total_gainers,
        total_losers,
        total_stable,
        biggest_gainer_symbol,
        biggest_gainer_change,
        biggest_loser_symbol,
        biggest_loser_change,
        market_cap_change,
        avg_volume
    ) VALUES (
        p_date,
        v_total_gainers,
        v_total_losers,
        v_total_stable,
        v_biggest_gainer_symbol,
        v_biggest_gainer_change,
        v_biggest_loser_symbol,
        v_biggest_loser_change,
        v_market_cap_change,
        v_avg_volume
    )
    ON CONFLICT (report_date) DO UPDATE SET
        total_gainers = EXCLUDED.total_gainers,
        total_losers = EXCLUDED.total_losers,
        total_stable = EXCLUDED.total_stable,
        biggest_gainer_symbol = EXCLUDED.biggest_gainer_symbol,
        biggest_gainer_change = EXCLUDED.biggest_gainer_change,
        biggest_loser_symbol = EXCLUDED.biggest_loser_symbol,
        biggest_loser_change = EXCLUDED.biggest_loser_change,
        market_cap_change = EXCLUDED.market_cap_change,
        avg_volume = EXCLUDED.avg_volume;
END;
$$ LANGUAGE plpgsql;

-- Função para limpeza de dados antigos
CREATE OR REPLACE FUNCTION cleanup_old_report_data(
    p_days_to_keep INTEGER DEFAULT 90
) RETURNS VOID AS $$
BEGIN
    -- Remove dados antigos de volatilidade
    DELETE FROM volatility_analysis 
    WHERE analysis_date < CURRENT_DATE - INTERVAL '1 day' * p_days_to_keep;
    
    -- Remove dados antigos de top movers
    DELETE FROM top_movers 
    WHERE analysis_date < CURRENT_DATE - INTERVAL '1 day' * p_days_to_keep;
    
    -- Remove dados antigos de sentimento (manter mais tempo)
    DELETE FROM market_sentiment 
    WHERE analysis_date < CURRENT_DATE - INTERVAL '1 day' * (p_days_to_keep * 2);
    
    -- Remove dados antigos de ranking (manter histórico maior)
    DELETE FROM ranking_history 
    WHERE snapshot_date < CURRENT_DATE - INTERVAL '1 day' * (p_days_to_keep * 3);
    
    RAISE NOTICE 'Limpeza concluída. Dados anteriores a % dias foram removidos.', p_days_to_keep;
END;
$$ LANGUAGE plpgsql;