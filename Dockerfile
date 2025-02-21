# Use an official Ubuntu base image
FROM ubuntu:20.04

# Set environment variables to prevent tzdata interactive prompt
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set working directory
WORKDIR /app

# Install system dependencies (CMake, GCC, OpenMP, Python, and missing tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    cmake ninja-build libomp-dev \
    build-essential git wget curl unzip \
    gawk bison flex autoconf automake \
    tzdata libcrypt-dev && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# ✅ Upgrade to Python 3.9 (Needed for torchmcubes)
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y python3.9 python3.9-venv python3.9-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# ✅ Verify Python version
RUN python3 --version

# Copy project files
COPY . /app

# ✅ Use Python 3.9 to create a virtual environment
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade pip

# ✅ **Remove all previous CUDA-related installations**
RUN . venv/bin/activate && pip uninstall -y torch torchvision torchaudio \
    nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 nvidia-cudnn-cu12 \
    nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
    nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-nccl-cu12 nvidia-nvtx-cu12 \
    nvidia-nvjitlink-cu12

# ✅ **Install the strict CPU-only version of PyTorch to avoid CUDA issues**
RUN . venv/bin/activate && pip install --no-cache-dir \
    torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu

# ✅ Install dependencies from requirements.txt
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt

# ✅ **Force `torchmcubes` to use CPU settings**
ENV FORCE_CUDA=0
RUN CMAKE_ARGS="-DOpenMP_CXX_FLAGS=-fopenmp" venv/bin/python -m pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git

# Expose port for Flask
EXPOSE 5000

# Start the application with Gunicorn
CMD ["venv/bin/gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
