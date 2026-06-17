#!/bin/bash
set -e

MODEL_LOCAL_DIR="${MODEL_LOCAL_DIR:-/tmp/model-cache/Qwen3-TTS-12Hz-0.6B-CustomVoice}"
GCS_MODEL_BUCKET="${GCS_MODEL_BUCKET:-qwen3-tts-model-cache}"
GCS_MODEL_PATH="${GCS_MODEL_PATH:-Qwen3-TTS-12Hz-0.6B-CustomVoice}"
GCS_URI="gs://${GCS_MODEL_BUCKET}/${GCS_MODEL_PATH}"

echo "🔍 Checking for model at ${MODEL_LOCAL_DIR}..."

if [ ! -f "${MODEL_LOCAL_DIR}/config.json" ]; then
    echo "📥 Downloading 0.6B CustomVoice model from GCS..."
    mkdir -p "${MODEL_LOCAL_DIR}"
    gsutil -m cp -r "${GCS_URI}/*" "${MODEL_LOCAL_DIR}/"

    if [ ! -f "${MODEL_LOCAL_DIR}/config.json" ]; then
        echo "❌ Download failed!"
        ls -la "${MODEL_LOCAL_DIR}/" || echo "Directory empty"
        exit 1
    fi

    echo "✅ Model downloaded!"
else
    echo "✅ Model already cached — skipping download"
fi

echo "📂 Model files:"
ls -la "${MODEL_LOCAL_DIR}/"

# Point server at local path — prevents HuggingFace calls
export TTS_MODEL_ID="${MODEL_LOCAL_DIR}"
export TTS_MODEL_NAME="${MODEL_LOCAL_DIR}"

echo "🚀 Starting server..."
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

echo "🔥 Warming up model..."
curl -s -X POST http://localhost:8080/v1/audio/speech \
    -H "Content-Type: application/json" \
    -d '{
        "model": "qwen3-tts",
        "voice": "Vivian",
        "input": "Warming up.",
        "instruct": "Warm and clear female voice",
        "response_format": "mp3"
    }' \
    --output /dev/null \
    --max-time 120 \
    && echo "✅ Warmed up!" \
    || echo "⚠️ Warmup failed"

wait $SERVER_PID
