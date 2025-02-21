# Use an official Ubuntu base image
FROM ubuntu:20.04

# Set environment variables to prevent interactive prompts and set timezone
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set working directory
WORKDIR /app

# Install system dependencies (CMake, GCC, OpenMP, Python, and required tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    software-properties-common \
    cmake ninja-build libomp-dev \
    build-essential git wget curl unzip \
    gawk bison flex autoconf automake \
    tzdata libcrypt-dev && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# Upgrade to Python 3.9 (required by torchmcubes)
RUN add-apt-repository ppa:deadsnakes/ppa -y && \
    apt-get update && \
    apt-get install -y python3.9 python3.9-venv python3.9-dev && \
    update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.9 1

# Verify Python version
RUN python3 --version

# Copy project files into the container
COPY . /app

# Create a virtual environment using Python 3.9 and upgrade pip
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade pip

# Install the CPU-only versions of torch, torchvision, and torchaudio explicitly
RUN . venv/bin/activate && \
    pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 -f https://download.pytorch.org/whl/cpu

# Uninstall any CUDA-related packages that might have been installed (ignore errors)
RUN . venv/bin/activate && pip uninstall -y \
    nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 nvidia-cudnn-cu12 \
    nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
    nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-nccl-cu12 nvidia-nvtx-cu12 \
    nvidia-nvjitlink-cu12 || true

# Install your remaining Python dependencies from requirements.txt
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt

# Set environment variables to force CPU-only build for torchmcubes
ENV FORCE_CUDA=0
ENV TORCH_CUDA_ARCH_LIST=""

# Install torchmcubes from GitHub (this should now build for CPU only)
RUN . venv/bin/python -m pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git

# Expose the port for Flask (or your API)
EXPOSE 5000

# Start the application using Gunicorn
CMD ["venv/bin/gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
