#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/nvidia-cosmos/cosmos-transfer2.5.git"
REPO_DIR="cosmos_transfer2_5"
KERNEL_NAME="cosmos-transfer2.5"
EXTRA_DEFAULT="cu128"  

echo "[1/7] Cloning repo..."
if [ -d "$REPO_DIR" ]; then
  echo " - $REPO_DIR already exists, skipping clone."
else
  echo " - Cloning $REPO_DIR..."
  git clone "$REPO_URL" "$REPO_DIR"
fi

cd "$REPO_DIR"

echo "[2/7] Installing system packages (curl, ffmpeg, tree, wget)..."
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y curl ffmpeg tree wget python3 python3-venv
  apt-get install -y libgl1 libglib2.0-0
fi

echo "[3/7] Installing uv (Astral)..."
curl -LsSf https://astral.sh/uv/install.sh | sh

export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  echo "!! uv not found. Add to PATH: export PATH=\$HOME/.local/bin:\$PATH"
  exit 1
fi

echo "[4/7] Resolving Python environment with uv..."
EXTRA="${EXTRA_OVERRIDE:-$EXTRA_DEFAULT}"
if ! command -v nvidia-smi >/dev/null 2>&1; then
  EXTRA="cpu"
fi
echo " - Using extra: $EXTRA"
uv sync --extra="$EXTRA"

echo "[5/7] Activating virtual environment..."
if [ ! -d ".venv" ]; then
  uv venv .venv
fi
source .venv/bin/activate

echo "[6/7] Installing Jupyter + kernel..."
uv pip install --upgrade pip
uv pip install jupyterlab notebook ipykernel

python -m ipykernel install --user --name "$KERNEL_NAME" --display-name "Python ($KERNEL_NAME)"

###############################################
# 7/7 — SAM2 INSTALL (clone only if missing) #
###############################################

echo "[7/7] Installing SAM2..."

cd ..

SAM2_DIR="sam2"
SAM2_URL="https://github.com/facebookresearch/sam2.git"

if [ -d "$SAM2_DIR" ]; then
  echo " - $SAM2_DIR already exists, skipping clone."
else
  echo " - Cloning SAM2..."
  git clone "$SAM2_URL" "$SAM2_DIR"
fi

cd "$SAM2_DIR"
uv pip install -e .

# Model directory
cd ..
mkdir -p models
cd models

# SAM2 checkpoint
SAM2p1_BASE_URL="https://dl.fbaipublicfiles.com/segment_anything_2/092824"
SAM2_CKPT_URL="${SAM2p1_BASE_URL}/sam2.1_hiera_large.pt"
SAM2_CKPT_FILE="sam2.1_hiera_large.pt"

# Only download if missing
if [ -f "$SAM2_CKPT_FILE" ]; then
    echo "✔ SAM2 checkpoint already exists: $SAM2_CKPT_FILE"
else
    echo "⬇ Downloading SAM2 checkpoint..."
    curl -O "$SAM2_CKPT_URL" || {
        echo "❌ Failed to download checkpoint from $SAM2_CKPT_URL"
        exit 1
    }
    echo "✅ Download complete: $SAM2_CKPT_FILE"
fi


echo "[*] Installing Hugging Face CLI via uv..."
uv tool install -U "huggingface_hub[cli]"
mkdir ~/.cache/huggingface



echo
echo "✅ Done!"
echo "------------------------------------------------------------"
echo "Repo root:     $(pwd)"
echo "Venv:          ../$REPO_DIR/.venv (activated earlier)"
echo "Kernel name:   Python ($KERNEL_NAME)"