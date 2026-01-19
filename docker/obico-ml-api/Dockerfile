# Obico ML API with CUDA 12 support
#
# Based on TheSpaghettiDetective/obico-server ml_api Dockerfile
# Modified to use CUDA 12.4 for compatibility with modern drivers
#
# Build: docker build -t ghcr.io/wdiazux/obico-ml-api:cuda12 .
# Push: docker push ghcr.io/wdiazux/obico-ml-api:cuda12

# Stage 1: Build Darknet with GPU support
FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-devel-ubuntu22.04 AS darknet_builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    build-essential \
    gcc \
    g++ \
    cmake \
    git \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /darknet_build

# Clone darknet and lock to specific commit for reproducibility
RUN git clone https://github.com/AlexeyAB/darknet.git . \
    && git checkout 59c86222c5387bffd9108a21885f80e980ece234

# Build GPU version
RUN sed -i 's/GPU=0/GPU=1/g' Makefile \
    && sed -i 's/CUDNN=0/CUDNN=1/g' Makefile \
    && sed -i 's/CUDNN_HALF=0/CUDNN_HALF=1/g' Makefile \
    && sed -i 's/LIBSO=0/LIBSO=1/g' Makefile \
    && make -j$(nproc) \
    && cp libdarknet.so libdarknet_gpu.so

# Build CPU version
RUN sed -i 's/GPU=1/GPU=0/g' Makefile \
    && sed -i 's/CUDNN=1/CUDNN=0/g' Makefile \
    && sed -i 's/CUDNN_HALF=1/CUDNN_HALF=0/g' Makefile \
    && make clean \
    && make -j$(nproc) \
    && cp libdarknet.so libdarknet_cpu.so

# Stage 2: Runtime image
FROM nvcr.io/nvidia/cuda:12.4.1-cudnn-runtime-ubuntu22.04 AS ml_api

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    python3 \
    python3-pip \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Copy compiled darknet libraries
COPY --from=darknet_builder /darknet_build/libdarknet_gpu.so /darknet/
COPY --from=darknet_builder /darknet_build/libdarknet_cpu.so /darknet/

# Install Python dependencies
RUN pip3 install --no-cache-dir \
    opencv_python_headless \
    onnxruntime-gpu \
    flask \
    gunicorn \
    requests \
    pillow \
    numpy

WORKDIR /app

# Clone ML API code
RUN wget -q https://github.com/TheSpaghettiDetective/obico-server/archive/refs/heads/master.tar.gz \
    && tar -xzf master.tar.gz --strip-components=2 obico-server-master/ml_api \
    && rm master.tar.gz

# Install additional requirements if present
RUN if [ -f requirements.txt ]; then pip3 install --no-cache-dir -r requirements.txt; fi

# Link darknet libraries
ENV LD_LIBRARY_PATH=/darknet:$LD_LIBRARY_PATH

EXPOSE 3333

# Health check endpoint
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD wget -q --spider http://localhost:3333/hc/ || exit 1

CMD ["gunicorn", "--bind", "0.0.0.0:3333", "--workers", "1", "wsgi:app"]
