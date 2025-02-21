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
    tzdata libcrypt-dev python3-pip && \
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

# Ensure that a virtual environment is created before installing dependencies
RUN python3.9 -m venv /app/venv

# Activate the virtual environment and upgrade essential build tools
RUN /app/venv/bin/pip install --upgrade pip setuptools wheel cmake ninja scikit-build

# Install the CPU-only versions of torch, torchvision, and torchaudio
RUN /app/venv/bin/pip install --no-cache-dir torch==2.1.0 torchvision==0.16.0 torchaudio==2.1.0 -f https://download.pytorch.org/whl/cpu

# Remove any CUDA-related packages if they exist
RUN /app/venv/bin/pip uninstall -y \
    nvidia-cuda-runtime-cu12 nvidia-cuda-cupti-cu12 nvidia-cudnn-cu12 \
    nvidia-cublas-cu12 nvidia-cufft-cu12 nvidia-curand-cu12 \
    nvidia-cusolver-cu12 nvidia-cusparse-cu12 nvidia-nccl-cu12 nvidia-nvtx-cu12 \
    nvidia-nvjitlink-cu12 || true

# Install all dependencies from requirements.txt
RUN /app/venv/bin/pip install --no-cache-dir -r requirements.txt

# Set environment variables to force CPU-only mode
ENV FORCE_CUDA=0
ENV TORCH_CUDA_ARCH_LIST=""
ENV CUDA_TOOLKIT_ROOT_DIR=""
ENV CUDA_VISIBLE_DEVICES=""
ENV CUDA_HOME=""
ENV CUDA_PATH=""
ENV CMAKE_ARGS="-DOpenMP_CXX_FLAGS=-fopenmp -DUSE_CUDA=OFF -DCAFFE2_DISABLE_CUDA=ON"

# Clone and manually patch torchmcubes to disable CUDA
RUN git clone https://github.com/tatsy/torchmcubes.git && \
    cd torchmcubes && \
    # Debug: Check if setup.py exists
    ls -l && \
    # Remove CUDA requirement and force USE_CUDA OFF in CMakeLists.txt
    sed -i 's/find_package(CUDA REQUIRED)//g' CMakeLists.txt && \
    sed -i 's/SET(USE_CUDA TRUE)/SET(USE_CUDA OFF)/g' CMakeLists.txt && \
    sed -i '/find_package(Torch REQUIRED)/a set(CAFFE2_DISABLE_CUDA ON)' CMakeLists.txt && \
    # Check if setup.py exists before modifying
    if [ -f "setup.py" ]; then \
        sed -i 's/cmake_args=\[\]/cmake_args=["-DUSE_CUDA=OFF", "-DCAFFE2_DISABLE_CUDA=ON"]/' setup.py; \
    fi && \
    /app/venv/bin/python -m pip install --no-cache-dir . && \
    cd .. && rm -rf torchmcubes

# Expose the API port
EXPOSE 5000

# Start the application using Gunicorn
CMD ["/app/venv/bin/gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
