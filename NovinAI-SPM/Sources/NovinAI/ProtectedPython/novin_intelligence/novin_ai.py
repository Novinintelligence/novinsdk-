import json
from novin_intelligence.security import NovinAISecuritySystem, SecurityConfig
from novin_intelligence.crime_intelligence import CrimeIntelligence

CONFIG = SecurityConfig()
CRIME = CrimeIntelligence(CONFIG, crime_data_path="crime_data.db")
SYSTEM = NovinAISecuritySystem(CONFIG)

def process_request(json_payload: str) -> dict:
    data = json.loads(json_payload)
    result = SYSTEM.process_request(data, client_id=data.get("clientId", "spm_client"))
    return result
