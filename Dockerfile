FROM debian:stable-slim

# Set noninteractive installation
ENV DEBIAN_FRONTEND=noninteractive

# Add repositories for Fish shell
RUN apt-get update && apt-get install -y --no-install-recommends \
    gnupg \
    lsb-release \
    ca-certificates \
    curl

# Add Fish repository
RUN echo 'deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_11/ /' > /etc/apt/sources.list.d/fish.list && \
    curl -fsSL https://download.opensuse.org/repositories/shells:fish:release:3/Debian_11/Release.key | gpg --dearmor > /etc/apt/trusted.gpg.d/shells_fish_release_3.gpg

# Update and install common dependencies
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
    wget \
    curl \
    git \
    build-essential \
    python3 \
    python3-pip \
    python3-dev \
    unzip \
    ca-certificates \
    nmap \
    apt-transport-https \
    sudo \
    fish

# Install latest Go version manually
RUN curl -sSL https://golang.org/dl/go1.21.0.linux-amd64.tar.gz | tar -C /usr/local -xzf -

# Set up Go environment properly
ENV GOPATH /root/go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

# Create Go directory structure and ensure permissions
RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"

# Verify Go installation
RUN go version

# Install Go tools individually with error handling
RUN go install -v github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest || echo "Failed to install subfinder, continuing..."
RUN go install -v github.com/owasp-amass/amass/v3/...@master || echo "Failed to install amass, continuing..."
RUN go install -v github.com/projectdiscovery/httpx/cmd/httpx@latest || echo "Failed to install httpx, continuing..."
RUN go install -v github.com/projectdiscovery/nuclei/v2/cmd/nuclei@latest || echo "Failed to install nuclei, continuing..."
RUN go install -v github.com/ffuf/ffuf@latest || echo "Failed to install ffuf, continuing..."
RUN go install -v github.com/lc/gau/v2/cmd/gau@latest || echo "Failed to install gau, continuing..."
RUN go install -v github.com/tomnomnom/anew@latest || echo "Failed to install anew, continuing..."
RUN go install -v github.com/tomnomnom/gf@latest || echo "Failed to install gf, continuing..."
# Install kxss manually to avoid GitHub authentication issues
RUN git clone https://github.com/tomnomnom/kxss.git /tmp/kxss && \
    cd /tmp/kxss && \
    go build -o /root/go/bin/kxss . && \
    ln -sf /root/go/bin/kxss /usr/local/bin/kxss && \
    rm -rf /tmp/kxss || echo "Failed to install kxss, continuing..."

# Verify Go tools installation and create symlinks if needed
RUN ls -la $GOPATH/bin && \
    # Create symlinks in /usr/local/bin for easier access
    for tool in $GOPATH/bin/*; do \
        ln -sf "$tool" /usr/local/bin/$(basename "$tool"); \
    done

# Set up gf patterns
RUN mkdir -p /root/.gf && \
    git clone https://github.com/tomnomnom/gf.git /tmp/gf && \
    cp -r /tmp/gf/examples/* /root/.gf && \
    rm -rf /tmp/gf

# Install Python packages properly using virtual environments
RUN apt-get update && apt-get install -y python3-venv python3-full

# Install pipx using venv
RUN python3 -m venv /opt/venvs/pipx
RUN /opt/venvs/pipx/bin/pip install pipx
RUN ln -sf /opt/venvs/pipx/bin/pipx /usr/local/bin/pipx
RUN pipx ensurepath

# Install uro using pipx
RUN pipx install uro || echo "Failed to install uro, continuing..."

# Install ParamSpider using pipx
RUN git clone https://github.com/devanshbatham/ParamSpider.git /opt/ParamSpider || echo "Failed to clone ParamSpider"
RUN if [ -d "/opt/ParamSpider" ]; then \
      cd /opt/ParamSpider && \
      pipx install . && \
      ln -sf /root/.local/bin/paramspider /usr/local/bin/paramspider; \
    fi

# Create virtual environment for dirsearch
RUN python3 -m venv /opt/venvs/dirsearch
RUN /opt/venvs/dirsearch/bin/pip install --upgrade pip setuptools wheel

# Install dirsearch with virtual environment
RUN git clone https://github.com/maurosoria/dirsearch.git /opt/dirsearch || echo "Failed to clone dirsearch"
RUN if [ -d "/opt/dirsearch" ]; then \
      cd /opt/dirsearch && \
      /opt/venvs/dirsearch/bin/pip install -r requirements.txt && \
      echo '#!/bin/bash\n/opt/venvs/dirsearch/bin/python3 /opt/dirsearch/dirsearch.py "$@"' > /usr/local/bin/dirsearch && \
      chmod +x /usr/local/bin/dirsearch; \
    fi

# Create a virtual environment for sqlmap
RUN python3 -m venv /opt/venvs/sqlmap

# Install sqlmap with virtual environment
RUN git clone --depth 1 https://github.com/sqlmapproject/sqlmap.git /opt/sqlmap || echo "Failed to clone sqlmap"
RUN if [ -d "/opt/sqlmap" ]; then \
      echo '#!/bin/bash\n/opt/venvs/sqlmap/bin/python3 /opt/sqlmap/sqlmap.py "$@"' > /usr/local/bin/sqlmap && \
      chmod +x /usr/local/bin/sqlmap; \
    fi

# Add path and env export to bashrc to ensure tools are available
RUN echo 'export GOPATH=/root/go' >> /root/.bashrc && \
    echo 'export PATH=$GOPATH/bin:/usr/local/go/bin:/root/.local/bin:$PATH' >> /root/.bashrc

# Clean up
RUN apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Make sure Python basics are working
RUN python3 -V

# Create a working directory
WORKDIR /work

# Set hostname to pintu
RUN echo "pintu" > /etc/hostname

# Add hostname entry to hosts file
RUN echo "127.0.0.1 pintu" >> /etc/hosts

# Set Fish as the default shell properly
RUN chsh -s /usr/bin/fish root

# Add Go path to Fish config
RUN mkdir -p /root/.config/fish/
RUN echo 'set -x GOPATH /root/go' >> /root/.config/fish/config.fish
RUN echo 'set -x PATH $GOPATH/bin /usr/local/go/bin /root/.local/bin $PATH' >> /root/.config/fish/config.fish

# Set the entrypoint and cmd explicitly for Fish
ENTRYPOINT ["/usr/bin/fish"]
CMD []
