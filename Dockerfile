# Use the official Jenkins inbound agent as the base image
FROM jenkins/inbound-agent:latest

# Switch to root user to install Docker CLI
USER root

# Install Docker CLI dependencies and Docker CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    gnupg2 \
    lsb-release && \
    install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y --no-install-recommends docker-ce docker-ce-cli docker-buildx-plugin docker-compose-plugin && \
    rm -rf /var/lib/apt/lists/*

# Add the Jenkins user to the Docker group (so it can use Docker)
RUN if ! getent group docker; then groupadd docker; fi && \
    usermod -aG docker jenkins

# Switch back to Jenkins user
USER jenkins
