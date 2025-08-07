from utils.database_utils import get_top_cryptocurrencies, get_database_statistics
from datetime import datetime, timedelta
from airflow.providers.postgres.hooks.postgres import PostgresHook


def generate_market_analysis_report(**kwargs):
    """Gera relatório de análise de mercado com tendências"""
    postgres_hook = PostgresHook(postgres_conn_id='postgres_default')
    
    # Busca dados históricos se disponíveis
    historical_data = postgres_hook.get_records(
        sql="""
        SELECT symbol, name, price_usd, change_percent_24hr, market_cap_usd,
               created_at
        FROM cryptocurrencies 
        WHERE created_at >= NOW() - INTERVAL '7 days'
        ORDER BY symbol, created_at DESC
        """
    )
    
    report = "ANÁLISE DE MERCADO - ÚLTIMOS 7 DIAS\n\n"
    
    if historical_data:
        # Agrupa por símbolo para análise de tendência
        crypto_trends = {}
        for record in historical_data:
            symbol, name, price, change, market_cap, timestamp = record
            if symbol not in crypto_trends:
                crypto_trends[symbol] = {'name': name, 'prices': [], 'changes': []}
            crypto_trends[symbol]['prices'].append(float(price) if price else 0)
            crypto_trends[symbol]['changes'].append(float(change) if change else 0)
        
        report += "📈 ANÁLISE DE TENDÊNCIAS:\n"
        for symbol, data in list(crypto_trends.items())[:10]:  # Top 10
            avg_change = sum(data['changes']) / len(data['changes']) if data['changes'] else 0
            trend_emoji = "🚀" if avg_change > 5 else "📈" if avg_change > 0 else "📉" if avg_change < -5 else "➡️"
            report += f"  {symbol} ({data['name']}): {avg_change:.2f}% média {trend_emoji}\n"
    
    # Estatísticas atuais
    stats = get_database_statistics()
    if stats:
        total, avg_price, total_market_cap = stats
        report += f"\n💰 ESTATÍSTICAS ATUAIS:\n"
        report += f"  • Market Cap Total: ${total_market_cap:,.2f}\n"
        report += f"  • Preço Médio: ${avg_price}\n"
        report += f"  • Total de Ativos: {total}\n"
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    report += f"\n📅 Relatório gerado em: {timestamp}\n"
    
    print(report)
    return "Relatório de análise de mercado gerado com sucesso"


def generate_volatility_report(**kwargs):
    """Gera relatório de volatilidade das criptomoedas"""
    records = get_top_cryptocurrencies(limit=20)
    
    # Classifica por volatilidade
    high_volatility = []
    medium_volatility = []
    low_volatility = []
    
    for record in records:
        rank, symbol, name, price, market_cap, volume, change = record
        abs_change = abs(change) if change else 0
        
        if abs_change > 10:
            high_volatility.append((symbol, name, change, abs_change))
        elif abs_change > 3:
            medium_volatility.append((symbol, name, change, abs_change))
        else:
            low_volatility.append((symbol, name, change, abs_change))
    
    report = "RELATÓRIO DE VOLATILIDADE - 24H\n\n"
    
    if high_volatility:
        report += "🔥 ALTA VOLATILIDADE (>10%):\n"
        for symbol, name, change, abs_change in sorted(high_volatility, key=lambda x: x[3], reverse=True):
            direction = "📈" if change > 0 else "📉"
            report += f"  • {symbol} ({name}): {change}% {direction}\n"
        report += "\n"
    
    if medium_volatility:
        report += "⚡ VOLATILIDADE MÉDIA (3-10%):\n"
        for symbol, name, change, abs_change in sorted(medium_volatility, key=lambda x: x[3], reverse=True):
            direction = "📈" if change > 0 else "📉"
            report += f"  • {symbol} ({name}): {change}% {direction}\n"
        report += "\n"
    
    if low_volatility:
        report += f"😴 BAIXA VOLATILIDADE (<3%): {len(low_volatility)} ativos\n\n"
    
    # Resumo estatístico
    all_changes = [abs(record[6]) for record in records if record[6] is not None]
    if all_changes:
        avg_volatility = sum(all_changes) / len(all_changes)
        max_volatility = max(all_changes)
        report += f"📊 RESUMO ESTATÍSTICO:\n"
        report += f"  • Volatilidade média: {avg_volatility:.2f}%\n"
        report += f"  • Volatilidade máxima: {max_volatility:.2f}%\n"
        report += f"  • Ativos analisados: {len(all_changes)}\n"
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    report += f"\n📅 Relatório gerado em: {timestamp}\n"
    
    print(report)
    return "Relatório de volatilidade gerado com sucesso"


def generate_top_movers_report(**kwargs):
    """Gera relatório dos maiores movimentadores do mercado"""
    records = get_top_cryptocurrencies(limit=50)
    
    # Separa maiores altas e quedas
    top_gainers = []
    top_losers = []
    
    for record in records:
        rank, symbol, name, price, market_cap, volume, change = record
        if change is not None:
            if change > 0:
                top_gainers.append((symbol, name, change, market_cap, volume))
            else:
                top_losers.append((symbol, name, change, market_cap, volume))
    
    # Ordena por mudança percentual
    top_gainers.sort(key=lambda x: x[2], reverse=True)
    top_losers.sort(key=lambda x: x[2])
    
    report = "TOP MOVERS - MAIORES MOVIMENTAÇÕES 24H\n\n"
    
    # Top 5 gainers
    if top_gainers:
        report += "🚀 TOP 5 MAIORES ALTAS:\n"
        for i, (symbol, name, change, market_cap, volume) in enumerate(top_gainers[:5], 1):
            report += f"  {i}. {symbol} ({name})\n"
            report += f"     📈 +{change}%\n"
            report += f"     💰 Market Cap: ${market_cap:,.2f}\n"
            report += f"     📊 Volume: ${volume:,.2f}\n\n"
    
    # Top 5 losers
    if top_losers:
        report += "📉 TOP 5 MAIORES QUEDAS:\n"
        for i, (symbol, name, change, market_cap, volume) in enumerate(top_losers[:5], 1):
            report += f"  {i}. {symbol} ({name})\n"
            report += f"     📉 {change}%\n"
            report += f"     💰 Market Cap: ${market_cap:,.2f}\n"
            report += f"     📊 Volume: ${volume:,.2f}\n\n"
    
    # Estatísticas do movimento
    total_positive = len(top_gainers)
    total_negative = len(top_losers)
    total_analyzed = total_positive + total_negative
    
    if total_analyzed > 0:
        positive_ratio = (total_positive / total_analyzed) * 100
        report += f"📈 SENTIMENTO DO MERCADO:\n"
        report += f"  • Ativos em alta: {total_positive} ({positive_ratio:.1f}%)\n"
        report += f"  • Ativos em queda: {total_negative} ({100-positive_ratio:.1f}%)\n"
        
        if positive_ratio > 60:
            report += f"  • Sentimento: OTIMISTA 😊\n"
        elif positive_ratio > 40:
            report += f"  • Sentimento: NEUTRO 😐\n"
        else:
            report += f"  • Sentimento: PESSIMISTA 😟\n"
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    report += f"\n📅 Relatório gerado em: {timestamp}\n"
    
    print(report)
    return "Relatório de top movers gerado com sucesso"