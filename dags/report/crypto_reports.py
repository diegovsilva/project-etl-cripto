from utils.database_utils import get_top_cryptocurrencies, get_database_statistics
from datetime import datetime


def generate_crypto_report(limit=10, **kwargs):
    """Gera relatório detalhado das criptomoedas"""
    # Busca as top criptomoedas
    records = get_top_cryptocurrencies(limit=limit)
    
    # Gera relatório
    report = "RELATÓRIO DE CRIPTOMOEDAS\n\n"
    report += f"TOP {limit} CRIPTOMOEDAS POR MARKET CAP:\n\n"
    
    for record in records:
        rank, symbol, name, price, market_cap, volume, change = record
        change_indicator = "UP" if change and change > 0 else "DOWN" if change and change < 0 else "STABLE"
        report += f"  {rank}. {name} ({symbol})\n"
        report += f"     Preço: ${price}\n"
        report += f"     Market Cap: ${market_cap:,.2f}\n"
        report += f"     Volume 24h: ${volume:,.2f}\n"
        report += f"     Variação 24h: {change}% ({change_indicator})\n\n"
    
    # Busca estatísticas gerais
    stats = get_database_statistics()
    
    if stats:
        total, avg_price, total_market_cap = stats
        report += f"ESTATÍSTICAS GERAIS:\n"
        report += f"  - Total de criptomoedas: {total}\n"
        report += f"  - Preço médio: ${avg_price}\n"
        report += f"  - Market cap total: ${total_market_cap:,.2f}\n\n"
    
    # Adiciona timestamp
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    report += f"Relatório gerado em: {timestamp}\n"
    
    print(report)
    return "Relatório gerado com sucesso"


def generate_market_summary(**kwargs):
    """Gera resumo do mercado de criptomoedas"""
    # Busca top 5 para resumo
    top_cryptos = get_top_cryptocurrencies(limit=5)
    stats = get_database_statistics()
    
    summary = "RESUMO DO MERCADO DE CRIPTOMOEDAS\n\n"
    
    if stats:
        total, avg_price, total_market_cap = stats
        summary += f"📊 VISÃO GERAL:\n"
        summary += f"  • Total de criptomoedas monitoradas: {total}\n"
        summary += f"  • Market cap total: ${total_market_cap:,.2f}\n"
        summary += f"  • Preço médio: ${avg_price}\n\n"
    
    summary += "🏆 TOP 5 CRIPTOMOEDAS:\n"
    for record in top_cryptos:
        rank, symbol, name, price, market_cap, volume, change = record
        change_emoji = "📈" if change and change > 0 else "📉" if change and change < 0 else "➡️"
        summary += f"  {rank}. {symbol}: ${price} {change_emoji} {change}%\n"
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    summary += f"\n⏰ Atualizado em: {timestamp}\n"
    
    print(summary)
    return "Resumo do mercado gerado com sucesso"


def generate_performance_report(**kwargs):
    """Gera relatório de performance das criptomoedas"""
    records = get_top_cryptocurrencies(limit=20)
    
    # Separa por performance
    gainers = []
    losers = []
    stable = []
    
    for record in records:
        rank, symbol, name, price, market_cap, volume, change = record
        if change and change > 5:
            gainers.append((symbol, name, change))
        elif change and change < -5:
            losers.append((symbol, name, change))
        else:
            stable.append((symbol, name, change))
    
    report = "RELATÓRIO DE PERFORMANCE - 24H\n\n"
    
    if gainers:
        report += "📈 MAIORES ALTAS (>5%):\n"
        for symbol, name, change in sorted(gainers, key=lambda x: x[2], reverse=True):
            report += f"  • {symbol} ({name}): +{change}%\n"
        report += "\n"
    
    if losers:
        report += "📉 MAIORES QUEDAS (<-5%):\n"
        for symbol, name, change in sorted(losers, key=lambda x: x[2]):
            report += f"  • {symbol} ({name}): {change}%\n"
        report += "\n"
    
    if stable:
        report += f"➡️ ESTÁVEIS (-5% a +5%): {len(stable)} criptomoedas\n\n"
    
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    report += f"Relatório gerado em: {timestamp}\n"
    
    print(report)
    return "Relatório de performance gerado com sucesso"