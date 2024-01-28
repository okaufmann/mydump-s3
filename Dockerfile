# Use MySQL 8 as the base image
FROM mysql:8.0-debian as final

# Install necessary packages for S3 interaction and clean up in one RUN to keep the image size small
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    python3 \
    python3-pip \
    bash \
    gettext-base \
    && pip3 install awscli \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy your custom entrypoint script into the container
COPY entrypoint.sh /
RUN chmod +x /entrypoint.sh

# Set the entrypoint script to be executed
ENTRYPOINT ["/entrypoint.sh"]

