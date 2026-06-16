#!/bin/bash
set -e

MODEL_DIR="/model-cache/Qwen3-TTS-12Hz-0.6B-CustomVoice"
MODEL_ID="Qwen/Qwen3-TTS-12Hz-0.6B-CustomVoice"

echo "🔍 Checking for model at ${MODEL_DIR}..."

# Check if model is already downloaded
# We check for config.json as a proxy for a complete download
if [ ! -f "${MODEL_DIR}/config.json" ]; then
    echo "📥 Model not found. Downloading ${MODEL_ID}..."
    echo "⏳ This will take a few minutes on first boot only..."

    python -c "
from huggingface_hub import snapshot_download
import os

path = snapshot_download(
    repo_id='${MODEL_ID}',
    local_dir='${MODEL_DIR}',
    ignore_patterns=[
        '*.msgpack',
        '*.h5',
        'flax_model*',
        'tf_model*',
        'rust_model*',
        '*.ot',
    ],
)
print(f'✅ Model downloaded to: {path}')
"
    echo "✅ Download complete!"
else
    echo "✅ Model already cached at ${MODEL_DIR} — skipping download"
fi

echo "🚀 Starting Qwen3-TTS API server..."
exec python -m api.main
