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
    tzdata libcrypt-dev python3-pip python3.9 python3.9-venv python3.9-dev && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# Upgrade PIP and install essential build tools
RUN python3.9 -m ensurepip && \
    python3.9 -m pip install --no-cache-dir --upgrade pip setuptools wheel cmake ninja scikit-build

# Create a virtual environment
RUN python3.9 -m venv /app/venv

# Activate the virtual environment
ENV PATH="/app/venv/bin:$PATH"

# Install CPU-only versions of torch, torchvision, and torchaudio
RUN pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 -f https://download.pytorch.org/whl/cpu

# Remove any CUDA-related packages if they exist
RUN pip uninstall -y \
    nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 nvidia-cudnn-cu12 \
    nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
    nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-nccl-cu12 nvidia-nvtx-cu12 \
    nvidia-nvjitlink-cu12 || true

# Install all dependencies from requirements.txt
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Set environment variables to force CPU-only mode
ENV FORCE_CUDA=0
ENV TORCH_CUDA_ARCH_LIST=""
ENV CUDA_TOOLKIT_ROOT_DIR=""
ENV CUDA_VISIBLE_DEVICES=""
ENV CUDA_HOME=""
ENV CUDA_PATH=""
ENV CMAKE_ARGS="-DUSE_CUDA=OFF -DCAFFE2_DISABLE_CUDA=ON"

# Clone and manually patch torchmcubes to disable CUDA
RUN git clone https://github.com/tatsy/torchmcubes.git && \
    cd torchmcubes && \
    echo "Checking torchmcubes directory contents:" && \
    ls -l && \
    # Remove CUDA requirement and force USE_CUDA OFF in CMakeLists.txt
    sed -i 's/find_package(CUDA REQUIRED)//g' CMakeLists.txt && \
    sed -i 's/SET(USE_CUDA TRUE)/SET(USE_CUDA OFF)/g' CMakeLists.txt && \
    sed -i '/find_package(Torch REQUIRED)/a set(CAFFE2_DISABLE_CUDA ON)' CMakeLists.txt && \
    # Explicitly pass CPU-only flags to setup.py
    pip install --no-cache-dir . --global-option="-DUSE_CUDA=OFF" --global-option="-DCAFFE2_DISABLE_CUDA=ON" && \
    cd .. && rm -rf torchmcubes

# Expose the API port
EXPOSE 5000

# Copy the rest of the application files
COPY . /app

# Start the application using Gunicorn
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
