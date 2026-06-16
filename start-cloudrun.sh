#!/bin/bash
set -e

MODEL_LOCAL_DIR="${MODEL_LOCAL_DIR:-/tmp/model-cache/Qwen3-TTS-12Hz-1.7B-VoiceDesign}"
GCS_MODEL_BUCKET="${GCS_MODEL_BUCKET:-qwen3-tts-model-cache}"
GCS_MODEL_PATH="${GCS_MODEL_PATH:-Qwen3-TTS-12Hz-1.7B-VoiceDesign}"
GCS_URI="gs://${GCS_MODEL_BUCKET}/${GCS_MODEL_PATH}"

echo "🔍 Checking for model at ${MODEL_LOCAL_DIR}..."

if [ ! -f "${MODEL_LOCAL_DIR}/config.json" ]; then
    echo "📥 Downloading model from GCS: ${GCS_URI}"
    mkdir -p "${MODEL_LOCAL_DIR}"

    # Use gsutil to copy from GCS
    gsutil -m cp -r "${GCS_URI}/*" "${MODEL_LOCAL_DIR}/"

    # Verify download worked
    if [ ! -f "${MODEL_LOCAL_DIR}/config.json" ]; then
        echo "❌ Model download failed — config.json not found!"
        echo "📂 Contents of ${MODEL_LOCAL_DIR}:"
        ls -la "${MODEL_LOCAL_DIR}/" || echo "Directory empty or missing"
        echo "📂 GCS bucket contents:"
        gsutil ls "${GCS_URI}/" || echo "Could not list GCS bucket"
        exit 1
    fi

    echo "✅ Model downloaded and verified!"
else
    echo "✅ Model already at ${MODEL_LOCAL_DIR}"
fi

echo "📂 Model files:"
ls -la "${MODEL_LOCAL_DIR}/"

# Override TTS_MODEL_ID to point at local path
# This prevents the server from trying HuggingFace
export TTS_MODEL_ID="${MODEL_LOCAL_DIR}"
export TTS_MODEL_NAME="${MODEL_LOCAL_DIR}"

echo "🚀 Starting server with model: ${TTS_MODEL_ID}"
python -m api.main &
SERVER_PID=$!

echo "⏳ Waiting for server..."
for i in $(seq 1 60); do
    if curl -sf http://localhost:8080/health > /dev/null 2>&1; then
        echo "✅ Server ready!"
        break
    fi
    echo "  ...waiting ($i/60)"
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
