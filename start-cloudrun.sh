#!/bin/bash
set -e

MODEL_LOCAL_DIR="${MODEL_LOCAL_DIR:-/tmp/model-cache/Qwen3-TTS-12Hz-1.7B-VoiceDesign}"
GCS_MODEL_BUCKET="${GCS_MODEL_BUCKET:-qwen3-tts-model-cache}"
GCS_MODEL_PATH="${GCS_MODEL_PATH:-Qwen3-TTS-12Hz-1.7B-VoiceDesign}"
GCS_URI="gs://${GCS_MODEL_BUCKET}/${GCS_MODEL_PATH}"

echo "🔍 Checking for model..."

if [ ! -f "${MODEL_LOCAL_DIR}/config.json" ]; then
    echo "📥 Downloading 1.7B VoiceDesign model from GCS..."
    mkdir -p "${MODEL_LOCAL_DIR}"
    gsutil -m cp -r "${GCS_URI}/*" "${MODEL_LOCAL_DIR}/"
    echo "✅ Model ready!"
else
    echo "✅ Model found — skipping download"
fi

echo "🚀 Starting server..."
python -m api.main &
SERVER_PID=$!

echo "⏳ Waiting for server..."
for i in $(seq 1 60); do
    if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Server ready!"
        break
    fi
    sleep 3
done

echo "🔥 Warming up VoiceDesign model..."
curl -s -X POST http://localhost:8080/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen3-tts",
        "voice": "Vivian",
        "input": "Ready.",
        "instruct": "Warm and clear female voice",
        "response_format": "mp3"
    }' \
    --output /dev/null \
    --max-time 120 \
    && echo "✅ Warmed up!" \
    || echo "⚠️ Warmup failed"

wait $SERVER_PID
