# Use a base image with compatible GLIBC & CMake
FROM ubuntu:20.04

# Set up environment variables to prevent tzdata interactive prompt
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC
ENV PYTHONUNBUFFERED=1

# Set working directory
WORKDIR /app

# Install system dependencies (CMake, GCC, OpenMP, Python, and missing tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    cmake ninja-build libomp-dev \
    build-essential git wget curl unzip \
    gawk bison flex autoconf automake \
    tzdata && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# Install the correct GLIBC version (Required for some dependencies)
RUN wget http://ftp.gnu.org/gnu/libc/glibc-2.36.tar.gz && \
    tar -xvzf glibc-2.36.tar.gz && \
    cd glibc-2.36 && \
    mkdir build && cd build && \
    ../configure --prefix=/usr && \
    make -j$(nproc) && \
    make install && \
    cd /app && rm -rf glibc-2.36*

# Copy project files
COPY . /app

# Create a virtual environment and install Python dependencies
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade pip
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt

# Manually install torchmcubes (since it fails in requirements.txt)
RUN . venv/bin/activate && pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git

# Expose port for Flask
EXPOSE 5000

# Start the application using Gunicorn for better performance
CMD ["venv/bin/gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
