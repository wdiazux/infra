# Obico ML API with CUDA 12 support
#
# Based on TheSpaghettiDetective/obico-server ml_api Dockerfile
# Modified to use CUDA 12.4 for compatibility with modern drivers
#
# Build: docker build -t ghcr.io/wdiazux/obico-ml-api:cuda12.2 .
# Push: docker push ghcr.io/wdiazux/obico-ml-api:cuda12.2
#
# Models are baked into the image (~100MB combined):
# - /model_cache/ml_api/darknet/model-weights.darknet
# - /model_cache/ml_api/onnx/model-weights.onnx

# Stage 1: Build Darknet with GPU support
FROM docker.io/nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS darknet_builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /darknet_build

# Clone darknet, build GPU version only (skip CPU to save space)
RUN git clone --depth 1 https://github.com/AlexeyAB/darknet.git . \
    && sed -i 's/GPU=0/GPU=1/g' Makefile \
    && sed -i 's/CUDNN=0/CUDNN=1/g' Makefile \
    && sed -i 's/CUDNN_HALF=0/CUDNN_HALF=1/g' Makefile \
    && sed -i 's/LIBSO=0/LIBSO=1/g' Makefile \
    && sed -i 's/-gencode arch=compute_35,code=sm_35//g' Makefile \
    && sed -i 's/-gencode arch=compute_50,code=\[sm_50,compute_50\]//g' Makefile \
    && sed -i 's/-gencode arch=compute_52,code=\[sm_52,compute_52\]//g' Makefile \
    && sed -i 's/-gencode arch=compute_61,code=\[sm_61,compute_61\]//g' Makefile \
    && sed -i 's/-gencode arch=compute_70,code=\[sm_70,compute_70\]/-gencode arch=compute_89,code=sm_89/g' Makefile \
    && make -j$(nproc) \
    && strip libdarknet.so

# Stage 2: Runtime image (minimal)
FROM docker.io/nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    VIRTUAL_ENV=/opt/venv \
    PATH="/opt/venv/bin:$PATH" \
    LD_LIBRARY_PATH=/darknet:$LD_LIBRARY_PATH \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install minimal dependencies, setup venv, clone code, download models, cleanup - all in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    python3 \
    python3-pip \
    python3-venv \
    git \
    libxcb1 \
    libgl1 \
    libglib2.0-0 \
    && python3 -m venv $VIRTUAL_ENV \
    && pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir \
        opencv_python_headless \
        onnxruntime-gpu \
        flask \
        gunicorn \
        requests \
        pillow \
        numpy \
    && git clone --depth 1 --filter=blob:none --sparse https://github.com/TheSpaghettiDetective/obico-server.git /tmp/obico \
    && cd /tmp/obico && git sparse-checkout set ml_api \
    && mkdir -p /app && cp -r ml_api/* /app/ \
    && rm -rf /tmp/obico \
    && mkdir -p /model_cache/ml_api/darknet /model_cache/ml_api/onnx \
    && curl -fSL -o /model_cache/ml_api/darknet/model-weights.darknet \
        "https://tsd-pub-static.s3.us-east-1.amazonaws.com/ml-models/model-weights-ef79dacfd0051ab526f3002d5f5f9912.darknet" \
    && curl -fSL -o /model_cache/ml_api/onnx/model-weights.onnx \
        "https://tsd-pub-static.s3.amazonaws.com/ml-models/model-weights-5a6b1be1fa.onnx" \
    && apt-get purge -y git curl \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /root/.cache /tmp/*

WORKDIR /app

# Copy compiled darknet library (GPU only)
COPY --from=darknet_builder /darknet_build/libdarknet.so /darknet/libdarknet_gpu.so

# Install requirements if present
RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt && rm -rf /root/.cache; fi

EXPOSE 3333

CMD ["gunicorn", "--bind", "0.0.0.0:3333", "--workers", "1", "wsgi:application"]
