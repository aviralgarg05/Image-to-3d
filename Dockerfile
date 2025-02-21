# Use a base image with compatible GLIBC & CMake
FROM ubuntu:20.04

# Set up environment variables
ENV PYTHONUNBUFFERED=1
WORKDIR /app

# Install system dependencies (CMake, GCC, OpenMP, GLIBC)
RUN apt-get update && apt-get install -y \
    python3 python3-pip python3-venv \
    cmake ninja-build libomp-dev \
    build-essential git wget curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Install the correct GLIBC version
RUN wget http://ftp.gnu.org/gnu/libc/glibc-2.36.tar.gz && \
    tar -xvzf glibc-2.36.tar.gz && \
    cd glibc-2.36 && \
    mkdir build && cd build && \
    ../configure --prefix=/usr && \
    make -j$(nproc) && \
    make install

# Copy project files
COPY . /app

# Install Python dependencies
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade pip
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt

# Manually install torchmcubes (since it's failing in requirements.txt)
RUN . venv/bin/activate && pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git

# Expose port for Flask
EXPOSE 5000

# Start the application
CMD ["venv/bin/python", "app.py"]
