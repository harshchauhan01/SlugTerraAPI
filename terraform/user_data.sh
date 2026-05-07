#!/bin/bash
set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io docker-compose
systemctl start docker
systemctl enable docker
usermod -aG docker ubuntu

# Install git and other tools
apt-get install -y git curl wget vim

# Set up environment variables for database connection
cat >> /etc/environment << EOF
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_NAME=${db_name}
DB_USER=${db_user}
DB_PASSWORD=${db_password}
EOF

source /etc/environment

# Create app directory
mkdir -p /opt/slugapi
cd /opt/slugapi

# Clone repository (adjust URL as needed)
# git clone https://github.com/yourusername/SlugTerraAPI.git .
# For now, create a placeholder docker-compose

cat > /opt/slugapi/docker-compose.yml << 'EOFDC'
version: '3.8'
services:
  api:
    image: python:3.12-slim
    ports:
      - "8000:8000"
    environment:
      - DB_HOST=$${DB_HOST}
      - DB_PORT=$${DB_PORT}
      - DB_NAME=$${DB_NAME}
      - DB_USER=$${DB_USER}
      - DB_PASSWORD=$${DB_PASSWORD}
      - DEBUG=False
    volumes:
      - .:/app
    working_dir: /app
    command: >
      sh -c "pip install --no-cache-dir -r requirements.txt &&
             python manage.py migrate &&
             gunicorn config.wsgi:application --bind 0.0.0.0:8000 --workers 2"
    restart: always
EOFDC

# Start application with docker-compose (will fail without repo, but won't break instance)
cd /opt/slugapi

# Log completion
echo "EC2 instance setup completed at $(date)" >> /var/log/user_data.log
