"""Doku Üretici — Vertex AI proxy (Cloud Run).
Tarayıcıdaki HTML uygulaması Vertex AI'yi doğrudan çağıramaz (CORS + OAuth).
Bu küçük proxy, Cloud Run servis hesabının kimliğiyle Vertex AI'yi çağırır;
kullanım PROJENİN faturasına = $300 kredine yazılır. CORS başlıkları ekler.

Gövde (POST JSON):
  { "project": "...", "location": "us-central1" | "global",
    "model": "gemini-3-pro-image-preview",
    "contents": [...], "generationConfig": {...} }
Başlık: X-Proxy-Secret: <gizli>   (PROXY_SECRET env ile eşleşmeli)
"""
import os
import requests
import google.auth
import google.auth.transport.requests
from flask import Flask, request, jsonify, make_response

app = Flask(__name__)
SECRET = os.environ.get("PROXY_SECRET", "")
DEF_PROJECT = os.environ.get("PROJECT", "")
DEF_LOCATION = os.environ.get("LOCATION", "us-central1")


def _cors(resp):
    resp.headers["Access-Control-Allow-Origin"] = "*"
    resp.headers["Access-Control-Allow-Headers"] = "Content-Type, X-Proxy-Secret"
    resp.headers["Access-Control-Allow-Methods"] = "POST, OPTIONS"
    return resp


@app.route("/", methods=["OPTIONS"])
def _options():
    return _cors(make_response("", 204))


@app.route("/", methods=["GET"])
def _health():
    return _cors(jsonify({"ok": True, "msg": "doku-proxy ayakta"}))


@app.route("/", methods=["POST"])
def generate():
    if SECRET and request.headers.get("X-Proxy-Secret", "") != SECRET:
        return _cors(make_response(jsonify({"error": {"message": "Gizli kod yanlış"}}), 403))
    try:
        body = request.get_json(force=True) or {}
    except Exception:
        return _cors(make_response(jsonify({"error": {"message": "Geçersiz JSON"}}), 400))

    project = body.get("project") or DEF_PROJECT
    location = body.get("location") or DEF_LOCATION
    model = body.get("model")
    contents = body.get("contents")
    gen_cfg = body.get("generationConfig", {"responseModalities": ["Text", "Image"]})
    if not (project and model and contents):
        return _cors(make_response(jsonify({"error": {"message": "project, model ve contents gerekli"}}), 400))

    try:
        creds, _ = google.auth.default(scopes=["https://www.googleapis.com/auth/cloud-platform"])
        creds.refresh(google.auth.transport.requests.Request())
    except Exception as e:
        return _cors(make_response(jsonify({"error": {"message": "Kimlik (ADC) alınamadı: %s" % e}}), 500))

    if location == "global":
        host = "aiplatform.googleapis.com"
    else:
        host = "%s-aiplatform.googleapis.com" % location
    url = ("https://%s/v1/projects/%s/locations/%s/publishers/google/models/%s:generateContent"
           % (host, project, location, model))

    try:
        r = requests.post(
            url,
            headers={"Authorization": "Bearer %s" % creds.token, "Content-Type": "application/json"},
            json={"contents": contents, "generationConfig": gen_cfg},
            timeout=180,
        )
    except Exception as e:
        return _cors(make_response(jsonify({"error": {"message": "Vertex isteği başarısız: %s" % e}}), 502))

    resp = make_response(r.content, r.status_code)
    resp.headers["Content-Type"] = "application/json"
    return _cors(resp)


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("PORT", 8080)))
