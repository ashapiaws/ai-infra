FROM nvcr.io/nvidia/pytorch:24.07-py3

# Install EFA and additional dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    libfabric-dev \
    libfabric1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY train.py .
COPY metrics/ ./metrics/

ENTRYPOINT ["torchrun"]
