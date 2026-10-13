import json
import requests


OLLAMA_URL = "http://127.0.0.1:11434/api/chat"
OLLAMA_MODEL = "qwen2.5:3b"


def analyze_measurement(measurement: dict) -> dict:
    """
    Analyze dialysis measurements using local Ollama model.

    IMPORTANT:
    This AI analysis is advisory only.
    Safety threshold alerts remain handled separately
    by monitoring/alerte.py.
    """

    prompt = f"""
You are an AI assistant for a dialysis machine monitoring system.

Analyze the following machine measurements:

Qb: {measurement.get("Qb")}
PA: {measurement.get("PA")}
PTM: {measurement.get("PTM")}
PV: {measurement.get("PV")}
UF_rate: {measurement.get("UF_rate")}
UF_volume: {measurement.get("UF_volume")}
Heparin: {measurement.get("Heparin")}

Provide a short clinical-support analysis.

IMPORTANT:
- Do NOT diagnose the patient.
- Do NOT replace a doctor or nurse.
- Do NOT invent measurements.
- Identify potentially abnormal values.
- Give a concise recommendation for healthcare staff.

Return ONLY valid JSON in this exact format:

{{
  "risk_level": "LOW",
  "analysis": "short explanation",
  "recommendation": "short recommendation"
}}

risk_level must be one of:
LOW, MEDIUM, HIGH
"""

    payload = {
        "model": OLLAMA_MODEL,
        "messages": [
            {
                "role": "user",
                "content": prompt,
            }
        ],
        "stream": False,
        "format": "json",
    }

    try:
        response = requests.post(
            OLLAMA_URL,
            json=payload,
            timeout=60,
        )

        response.raise_for_status()

        data = response.json()

        content = data["message"]["content"]

        result = json.loads(content)

        return {
            "success": True,
            "model": OLLAMA_MODEL,
            "risk_level": result.get("risk_level", "LOW"),
            "analysis": result.get("analysis", ""),
            "recommendation": result.get("recommendation", ""),
        }

    except requests.RequestException as exc:
        return {
            "success": False,
            "error": f"Ollama connection error: {exc}",
        }

    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        return {
            "success": False,
            "error": f"Invalid Ollama response: {exc}",
        }