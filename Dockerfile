# Use an official Ubuntu base image
FROM ubuntu:20.04

# Set up environment variables to prevent tzdata interactive prompt
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Etc/UTC

# Set working directory
WORKDIR /app

# Install system dependencies (CMake, GCC, OpenMP, Python, and missing tools)
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip python3-venv \
    cmake ninja-build libomp-dev \
    build-essential git wget curl unzip \
    gawk bison flex autoconf automake \
    tzdata libcrypt-dev && \
    ln -fs /usr/share/zoneinfo/Etc/UTC /etc/localtime && \
    dpkg-reconfigure --frontend noninteractive tzdata && \
    rm -rf /var/lib/apt/lists/*

# ✅ Download and extract a precompiled GLIBC 2.31 package
RUN wget -qO glibc-2.31.tar.gz http://ftp.gnu.org/gnu/libc/glibc-2.31.tar.gz && \
    tar -xvzf glibc-2.31.tar.gz && \
    rm glibc-2.31.tar.gz

# ✅ Set up GLIBC and libcrypt correctly
ENV LD_LIBRARY_PATH=/app/glibc-2.31/lib:$LD_LIBRARY_PATH
RUN ln -s /app/glibc-2.31/lib/libcrypt.so.1 /lib64/libcrypt.so.1

# ✅ Verify GLIBC installation
RUN /app/glibc-2.31/lib/ld-2.31.so --version

# Copy project files
COPY . /app

# ✅ Ensure Python works correctly before creating a virtual environment
RUN python3 --version

# ✅ Create a virtual environment and install Python dependencies
RUN python3 -m venv venv
RUN . venv/bin/activate && pip install --upgrade pip
RUN . venv/bin/activate && pip install --no-cache-dir -r requirements.txt

# ✅ Manually install torchmcubes (since it fails in requirements.txt)
RUN . venv/bin/activate && pip install --no-cache-dir git+https://github.com/tatsy/torchmcubes.git

# Expose port for Flask
EXPOSE 5000

# Start the application with Gunicorn
CMD ["venv/bin/gunicorn", "-w", "4", "-b", "0.0.0.0:5000", "app:app"]
