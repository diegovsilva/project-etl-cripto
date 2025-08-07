-- Scripts de automação para execução de relatórios

-- Script para executar análise completa diária
CREATE OR REPLACE FUNCTION run_daily_report_analysis() RETURNS TEXT AS $$
DECLARE
    v_result TEXT := '';
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration INTERVAL;
    v_crypto_count INTEGER;
    v_report_id INTEGER;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    v_result := 'Iniciando análise diária de relatórios em ' || v_start_time || E'\n';
    
    -- Limpa dados do dia atual para reprocessamento
    DELETE FROM volatility_analysis WHERE analysis_date = CURRENT_DATE;
    DELETE FROM top_movers WHERE analysis_date = CURRENT_DATE;
    DELETE FROM market_sentiment WHERE analysis_date = CURRENT_DATE;
    
    v_result := v_result || 'Dados anteriores do dia limpos.' || E'\n';
    
    -- Conta total de criptomoedas ativas
    SELECT COUNT(*) INTO v_crypto_count
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE;
    
    v_result := v_result || 'Total de criptomoedas encontradas: ' || v_crypto_count || E'\n';
    
    -- Insere análise de volatilidade para todas as criptomoedas
    INSERT INTO volatility_analysis (
        symbol, name, price_usd, change_percent_24hr, 
        volatility_category, abs_change, market_cap_usd, volume_24hr
    )
    SELECT 
        symbol,
        name,
        price_usd,
        change_percent_24hr,
        CASE 
            WHEN ABS(COALESCE(change_percent_24hr, 0)) > 10 THEN 'high'
            WHEN ABS(COALESCE(change_percent_24hr, 0)) > 3 THEN 'medium'
            ELSE 'low'
        END as volatility_category,
        ABS(COALESCE(change_percent_24hr, 0)) as abs_change,
        market_cap_usd,
        volume_usd_24hr
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE;
    
    v_result := v_result || 'Análise de volatilidade inserida.' || E'\n';
    
    -- Insere top 5 gainers
    INSERT INTO top_movers (
        symbol, name, price_usd, change_percent_24hr,
        movement_type, rank_position, market_cap_usd, volume_24hr
    )
    SELECT 
        symbol, name, price_usd, change_percent_24hr,
        'gainer' as movement_type,
        ROW_NUMBER() OVER (ORDER BY change_percent_24hr DESC) as rank_position,
        market_cap_usd, volume_usd_24hr
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE
    AND change_percent_24hr > 0
    ORDER BY change_percent_24hr DESC
    LIMIT 5;
    
    -- Insere top 5 losers
    INSERT INTO top_movers (
        symbol, name, price_usd, change_percent_24hr,
        movement_type, rank_position, market_cap_usd, volume_24hr
    )
    SELECT 
        symbol, name, price_usd, change_percent_24hr,
        'loser' as movement_type,
        ROW_NUMBER() OVER (ORDER BY change_percent_24hr ASC) as rank_position,
        market_cap_usd, volume_usd_24hr
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE
    AND change_percent_24hr < 0
    ORDER BY change_percent_24hr ASC
    LIMIT 5;
    
    v_result := v_result || 'Top movers inseridos.' || E'\n';
    
    -- Calcula e insere sentimento do mercado
    PERFORM calculate_market_sentiment();
    v_result := v_result || 'Sentimento do mercado calculado.' || E'\n';
    
    -- Calcula performance diária
    PERFORM calculate_daily_performance();
    v_result := v_result || 'Performance diária calculada.' || E'\n';
    
    -- Insere snapshot do ranking
    PERFORM insert_ranking_snapshot();
    v_result := v_result || 'Snapshot do ranking inserido.' || E'\n';
    
    -- Cria relatório básico
    SELECT insert_crypto_report(
        'daily_analysis',
        v_crypto_count,
        (SELECT AVG(price_usd) FROM cryptocurrencies WHERE created_at >= CURRENT_DATE),
        (SELECT SUM(market_cap_usd) FROM cryptocurrencies WHERE created_at >= CURRENT_DATE),
        'Relatório diário automatizado gerado em ' || CURRENT_TIMESTAMP
    ) INTO v_report_id;
    
    v_result := v_result || 'Relatório básico criado com ID: ' || v_report_id || E'\n';
    
    v_end_time := CURRENT_TIMESTAMP;
    v_duration := v_end_time - v_start_time;
    
    v_result := v_result || 'Análise concluída em ' || v_end_time || E'\n';
    v_result := v_result || 'Duração total: ' || v_duration || E'\n';
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Script para gerar relatório de tendências semanais
CREATE OR REPLACE FUNCTION generate_weekly_trends_report() RETURNS TABLE(
    symbol VARCHAR(10),
    name VARCHAR(100),
    avg_price DECIMAL(20, 8),
    price_trend VARCHAR(20),
    volatility_trend VARCHAR(20),
    volume_trend VARCHAR(20),
    days_analyzed INTEGER
) AS $$
BEGIN
    RETURN QUERY
    WITH weekly_stats AS (
        SELECT 
            rh.symbol,
            rh.name,
            AVG(rh.price_usd) as avg_price,
            STDDEV(rh.price_usd) as price_volatility,
            AVG(rh.volume_24hr) as avg_volume,
            COUNT(*) as days_count,
            -- Tendência de preço (comparando primeira e última semana)
            (LAST_VALUE(rh.price_usd) OVER (PARTITION BY rh.symbol ORDER BY rh.snapshot_date 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) - 
             FIRST_VALUE(rh.price_usd) OVER (PARTITION BY rh.symbol ORDER BY rh.snapshot_date 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)) / 
            FIRST_VALUE(rh.price_usd) OVER (PARTITION BY rh.symbol ORDER BY rh.snapshot_date 
                ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) * 100 as price_change_pct
        FROM ranking_history rh
        WHERE rh.snapshot_date >= CURRENT_DATE - INTERVAL '7 days'
        GROUP BY rh.symbol, rh.name
        HAVING COUNT(*) >= 3  -- Pelo menos 3 dias de dados
    )
    SELECT 
        ws.symbol,
        ws.name,
        ws.avg_price,
        CASE 
            WHEN ws.price_change_pct > 5 THEN 'bullish'
            WHEN ws.price_change_pct < -5 THEN 'bearish'
            ELSE 'sideways'
        END as price_trend,
        CASE 
            WHEN ws.price_volatility / ws.avg_price > 0.1 THEN 'high_volatility'
            WHEN ws.price_volatility / ws.avg_price > 0.05 THEN 'medium_volatility'
            ELSE 'low_volatility'
        END as volatility_trend,
        CASE 
            WHEN ws.avg_volume > 1000000 THEN 'high_volume'
            WHEN ws.avg_volume > 100000 THEN 'medium_volume'
            ELSE 'low_volume'
        END as volume_trend,
        ws.days_count::INTEGER as days_analyzed
    FROM weekly_stats ws
    ORDER BY ws.avg_price DESC;
END;
$$ LANGUAGE plpgsql;

-- Script para relatório de correlações
CREATE OR REPLACE FUNCTION analyze_market_correlations() RETURNS TABLE(
    correlation_type VARCHAR(50),
    description TEXT,
    correlation_value DECIMAL(5, 4),
    significance VARCHAR(20)
) AS $$
BEGIN
    RETURN QUERY
    WITH market_data AS (
        SELECT 
            DATE(created_at) as trade_date,
            AVG(price_usd) as avg_price,
            SUM(market_cap_usd) as total_market_cap,
            AVG(volume_usd_24hr) as avg_volume,
            AVG(change_percent_24hr) as avg_change
        FROM cryptocurrencies
        WHERE created_at >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY DATE(created_at)
        HAVING COUNT(*) > 10  -- Pelo menos 10 criptomoedas por dia
    )
    SELECT 
        'price_volume'::VARCHAR(50) as correlation_type,
        'Correlação entre preço médio e volume médio'::TEXT as description,
        CORR(md.avg_price, md.avg_volume)::DECIMAL(5, 4) as correlation_value,
        CASE 
            WHEN ABS(CORR(md.avg_price, md.avg_volume)) > 0.7 THEN 'strong'
            WHEN ABS(CORR(md.avg_price, md.avg_volume)) > 0.3 THEN 'moderate'
            ELSE 'weak'
        END::VARCHAR(20) as significance
    FROM market_data md
    
    UNION ALL
    
    SELECT 
        'marketcap_change'::VARCHAR(50),
        'Correlação entre market cap total e mudança média'::TEXT,
        CORR(md.total_market_cap, md.avg_change)::DECIMAL(5, 4),
        CASE 
            WHEN ABS(CORR(md.total_market_cap, md.avg_change)) > 0.7 THEN 'strong'
            WHEN ABS(CORR(md.total_market_cap, md.avg_change)) > 0.3 THEN 'moderate'
            ELSE 'weak'
        END::VARCHAR(20)
    FROM market_data md;
END;
$$ LANGUAGE plpgsql;

-- Script para limpeza e manutenção automática
CREATE OR REPLACE FUNCTION run_maintenance_tasks() RETURNS TEXT AS $$
DECLARE
    v_result TEXT := '';
    v_deleted_count INTEGER;
BEGIN
    v_result := 'Iniciando tarefas de manutenção em ' || CURRENT_TIMESTAMP || E'\n';
    
    -- Limpa dados antigos (mantém 90 dias)
    PERFORM cleanup_old_report_data(90);
    v_result := v_result || 'Limpeza de dados antigos concluída.' || E'\n';
    
    -- Remove relatórios básicos antigos (mantém 30 dias)
    DELETE FROM crypto_reports 
    WHERE created_at < CURRENT_DATE - INTERVAL '30 days';
    
    GET DIAGNOSTICS v_deleted_count = ROW_COUNT;
    v_result := v_result || 'Removidos ' || v_deleted_count || ' relatórios básicos antigos.' || E'\n';
    
    -- Atualiza estatísticas das tabelas
    ANALYZE cryptocurrencies;
    ANALYZE crypto_reports;
    ANALYZE volatility_analysis;
    ANALYZE top_movers;
    ANALYZE market_sentiment;
    ANALYZE daily_performance;
    ANALYZE ranking_history;
    
    v_result := v_result || 'Estatísticas das tabelas atualizadas.' || E'\n';
    
    -- Reindexação se necessário
    REINDEX INDEX CONCURRENTLY idx_volatility_date_category;
    REINDEX INDEX CONCURRENTLY idx_movers_date_type;
    
    v_result := v_result || 'Reindexação concluída.' || E'\n';
    v_result := v_result || 'Manutenção finalizada em ' || CURRENT_TIMESTAMP || E'\n';
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Script para verificação de integridade dos dados
CREATE OR REPLACE FUNCTION check_data_integrity() RETURNS TABLE(
    check_name VARCHAR(100),
    status VARCHAR(20),
    details TEXT
) AS $$
BEGIN
    RETURN QUERY
    -- Verifica dados de criptomoedas atualizados hoje
    SELECT 
        'cryptocurrencies_today'::VARCHAR(100) as check_name,
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END::VARCHAR(20) as status,
        'Encontradas ' || COUNT(*) || ' criptomoedas atualizadas hoje'::TEXT as details
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE
    
    UNION ALL
    
    -- Verifica dados nulos críticos
    SELECT 
        'null_prices'::VARCHAR(100),
        CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'ERROR' END::VARCHAR(20),
        'Encontrados ' || COUNT(*) || ' registros com preço nulo hoje'::TEXT
    FROM cryptocurrencies
    WHERE created_at >= CURRENT_DATE AND price_usd IS NULL
    
    UNION ALL
    
    -- Verifica análise de volatilidade
    SELECT 
        'volatility_analysis_today'::VARCHAR(100),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END::VARCHAR(20),
        'Análise de volatilidade: ' || COUNT(*) || ' registros hoje'::TEXT
    FROM volatility_analysis
    WHERE analysis_date = CURRENT_DATE
    
    UNION ALL
    
    -- Verifica sentimento do mercado
    SELECT 
        'market_sentiment_today'::VARCHAR(100),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END::VARCHAR(20),
        'Sentimento do mercado: ' || COUNT(*) || ' análises hoje'::TEXT
    FROM market_sentiment
    WHERE analysis_date = CURRENT_DATE
    
    UNION ALL
    
    -- Verifica performance diária
    SELECT 
        'daily_performance_today'::VARCHAR(100),
        CASE WHEN COUNT(*) > 0 THEN 'OK' ELSE 'WARNING' END::VARCHAR(20),
        'Performance diária: ' || COUNT(*) || ' registros hoje'::TEXT
    FROM daily_performance
    WHERE report_date = CURRENT_DATE;
END;
$$ LANGUAGE plpgsql;