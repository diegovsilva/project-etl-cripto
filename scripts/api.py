import requests
import os
from dotenv import load_dotenv

# Carrega as variáveis de ambiente
load_dotenv()

class CoinCapAPI:
    def __init__(self):
        self.base_url = os.getenv('COINCAP_API_BASE_URL', 'https://rest.coincap.io/v3')
        self.api_key = os.getenv('COINCAP_API_KEY')
        self.headers = {
            'Authorization': f'Bearer {self.api_key}'
        } if self.api_key else {}
    
    def get_assets(self, limit=20):
        """Busca lista de criptomoedas da API CoinCap"""
        try:
            url = f"{self.base_url}/assets"
            params = {'limit': limit}
            
            response = requests.get(url, params=params, timeout=10, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            return data.get('data', [])
            
        except requests.RequestException as e:
            print(f"Erro ao buscar dados da API: {e}")
            return []
    
    def get_asset_by_id(self, asset_id):
        """Busca dados de uma criptomoeda específica por ID"""
        try:
            url = f"{self.base_url}/assets/{asset_id}"
            
            response = requests.get(url, timeout=10, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            return data.get('data')
            
        except requests.RequestException as e:
            print(f"Erro ao buscar dados da criptomoeda {asset_id}: {e}")
            return None
    
    def get_top_assets(self, limit=10):
        """Busca as top criptomoedas por market cap"""
        try:
            url = f"{self.base_url}/assets"
            params = {'limit': limit}
            
            response = requests.get(url, params=params, timeout=10, headers=self.headers)
            response.raise_for_status()
            
            data = response.json()
            return data.get('data', [])
            
        except requests.RequestException as e:
            print(f"Erro ao buscar top assets: {e}")
            return []
    
    def format_crypto_data(self, crypto_data):
        """Formata os dados da API para o formato do banco de dados"""
        return {
            'id': crypto_data.get('id'),
            'rank': int(crypto_data.get('rank', 0)) if crypto_data.get('rank') else None,
            'symbol': crypto_data.get('symbol'),
            'name': crypto_data.get('name'),
            'supply': float(crypto_data.get('supply', 0)) if crypto_data.get('supply') else None,
            'maxSupply': float(crypto_data.get('maxSupply', 0)) if crypto_data.get('maxSupply') else None,
            'marketCapUsd': float(crypto_data.get('marketCapUsd', 0)) if crypto_data.get('marketCapUsd') else None,
            'volumeUsd24Hr': float(crypto_data.get('volumeUsd24Hr', 0)) if crypto_data.get('volumeUsd24Hr') else None,
            'priceUsd': float(crypto_data.get('priceUsd', 0)) if crypto_data.get('priceUsd') else None,
            'changePercent24Hr': float(crypto_data.get('changePercent24Hr', 0)) if crypto_data.get('changePercent24Hr') else None,
            'vwap24Hr': float(crypto_data.get('vwap24Hr', 0)) if crypto_data.get('vwap24Hr') else None,
            'explorer': crypto_data.get('explorer')
        }