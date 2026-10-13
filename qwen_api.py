from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import requests
import base64
import json
import re

app = FastAPI(title="PFA Dialyse AI Server (Qwen)")

import os

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434/api/generate")
MODEL = os.environ.get("OLLAMA_MODEL", "qwen2.5vl:3b")

def sanitize_extracted_dict(data: dict) -> dict:
    """Ensure output keys match standard format with float values or null."""
    standard_keys = {
        "qb": ["qb", "debit_sang", "blood_flow"],
        "pa": ["pa", "pression_arterielle", "arterial_pressure"],
        "pv": ["pv", "pression_veineuse", "venous_pressure"],
        "ptm": ["ptm", "tmp", "pression_transmembranaire"],
        "uf_volume": ["uf_volume", "volume_uf", "uf_vol"],
        "uf_rate": ["uf_rate", "taux_uf", "rate_uf"],
        "heparin": ["heparin", "heparine"]
    }
    
    result = {
        "qb": None,
        "pa": None,
        "pv": None,
        "ptm": None,
        "uf_volume": None,
        "uf_rate": None,
        "heparin": None
    }
    
    if not isinstance(data, dict):
        return result

    lower_data = {str(k).lower(): v for k, v in data.items()}
    
    for std_key, aliases in standard_keys.items():
        val = None
        for alias in aliases:
            if alias in lower_data and lower_data[alias] is not None:
                val = lower_data[alias]
                break
        
        if val is not None:
            try:
                if isinstance(val, (int, float)):
                    result[std_key] = float(val)
                elif isinstance(val, str):
                    num_match = re.search(r"[-+]?\d*\.?\d+", val)
                    if num_match:
                        result[std_key] = float(num_match.group())
            except Exception:
                result[std_key] = None
                
    return result


@app.get("/health")
def health():
    return {
        "status": "ok",
        "model": MODEL
    }


@app.post("/analyze")
@app.post("/analyze/")
async def analyze(file: UploadFile = File(...)):
    try:
        image_bytes = await file.read()
        if not image_bytes:
            return JSONResponse(status_code=400, content={"error": "Empty image file"})
            
        image_b64 = base64.b64encode(image_bytes).decode("utf-8")

        prompt = """
Analyze this dialysis machine screen image.

Extract these numeric values if visible:
- Qb: blood flow rate in mL/min
- PA: arterial pressure in mmHg
- PV: venous pressure in mmHg
- PTM: transmembrane pressure in mmHg
- UF_volume: ultrafiltration volume in mL
- UF_rate: ultrafiltration rate in mL/h
- Heparin: heparin rate in UI/h

Return ONLY valid JSON with no markdown formatting.
Format:
{
  "qb": number or null,
  "pa": number or null,
  "pv": number or null,
  "ptm": number or null,
  "uf_volume": number or null,
  "uf_rate": number or null,
  "heparin": number or null
}

IMPORTANT RULES:
1. Do NOT swap PA and PV. PA is arterial pressure, PV is venous pressure.
2. If a value is not clearly visible or uncertain, return null. Do NOT guess.
"""

        payload = {
            "model": MODEL,
            "prompt": prompt,
            "images": [image_b64],
            "stream": False
        }

        try:
            response = requests.post(OLLAMA_URL, json=payload, timeout=60)
            if response.status_code == 200:
                result_json = response.json()
                raw_response = result_json.get("response", "")
                
                start = raw_response.find("{")
                end = raw_response.rfind("}") + 1
                if start != -1 and end != 0:
                    raw_data = json.loads(raw_response[start:end])
                    extracted = sanitize_extracted_dict(raw_data)
                    extracted["_source"] = "qwen_ollama"
                    return JSONResponse(content=extracted)
        except Exception as err:
            print(f"[QWEN_API] Ollama call error: {err}")

        # Fallback response if Ollama fails or is unreachable
        return JSONResponse(
            status_code=200,
            content={
                "qb": None, "pa": None, "pv": None, "ptm": None,
                "uf_volume": None, "uf_rate": None, "heparin": None,
                "_source": "ollama_fallback",
                "warning": "Ollama service unavailable or failed to parse image"
            }
        )

    except Exception as e:
        print(f"[QWEN_API] Exception: {e}")
        return JSONResponse(
            status_code=200,
            content={
                "error": str(e),
                "qb": None, "pa": None, "pv": None, "ptm": None,
                "uf_volume": None, "uf_rate": None, "heparin": None
            }
        )