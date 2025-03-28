#!/bin/bash

# VPS Control Panel Complete Production Setup Script
# Author: Tony Pham
# Contact: info@hwosecurity.org

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
DB_USER="vpscontrol"
DB_PASSWORD="vpscontrol123"  # You should change this in production
DB_NAME="vpscontrolpanel"
INSTALL_DIR="$(pwd)"
SESSION_SECRET=$(openssl rand -hex 32)  # Generate random secret key

# Display banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║          VPS CONTROL PANEL PRODUCTION DEPLOYMENT             ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Prompt for domain name
echo -e "${YELLOW}Please enter your domain name (e.g., vpscontrol.yourdomain.com):${NC}"
read -p "> " DOMAIN_NAME

if [ -z "$DOMAIN_NAME" ]; then
    echo -e "${RED}Domain name is required. Exiting.${NC}"
    exit 1
fi

# Prompt for email address for Let's Encrypt
echo -e "${YELLOW}Please enter an email address for SSL certificate notifications:${NC}"
read -p "> " EMAIL_ADDRESS

if [ -z "$EMAIL_ADDRESS" ]; then
    echo -e "${RED}Email address is required for Let's Encrypt. Exiting.${NC}"
    exit 1
fi

echo -e "${YELLOW}This script will setup a complete production environment including:${NC}"
echo " - System packages installation"
echo " - PostgreSQL database configuration"
echo " - Python environment and dependencies"
echo " - Nginx as a reverse proxy"
echo " - Let's Encrypt SSL certificate for HTTPS"
echo " - Systemd service for automatic startup"
echo " - Production-ready environment settings"
echo
echo -e "${YELLOW}It will be deployed at: ${GREEN}https://$DOMAIN_NAME${NC}"
echo
echo -e "${RED}WARNING: This script requires sudo privileges and will modify system configuration.${NC}"
echo
read -p "Continue with installation? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Installation aborted."
    exit 1
fi

# Detect OS
echo -e "\n${BLUE}Detecting operating system...${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
    echo -e "Detected: ${GREEN}$OS $VER${NC}"
else
    echo -e "${RED}Cannot detect OS. This script supports Ubuntu, Debian, CentOS, and RHEL.${NC}"
    exit 1
fi

# Install system dependencies
echo -e "\n${BLUE}Installing system dependencies...${NC}"
if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
    echo -e "Using ${GREEN}apt${NC} package manager..."
    sudo apt update
    sudo apt install -y python3 python3-pip python3-venv git postgresql postgresql-contrib libpq-dev
    sudo apt install -y libcairo2-dev libjpeg-dev libgif-dev nginx certbot python3-certbot-nginx
elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]]; then
    echo -e "Using ${GREEN}dnf${NC} package manager..."
    sudo dnf update -y
    sudo dnf install -y python3 python3-pip git postgresql-server postgresql-devel
    sudo dnf install -y cairo-devel libjpeg-devel nginx certbot python3-certbot-nginx
    
    # Initialize PostgreSQL on CentOS/RHEL
    if [ ! -d /var/lib/pgsql/data/base ]; then
        echo -e "\n${BLUE}Initializing PostgreSQL database...${NC}"
        sudo postgresql-setup --initdb
    fi
else
    echo -e "${RED}Unsupported OS. Please install dependencies manually.${NC}"
    exit 1
fi

# Start and enable PostgreSQL service
echo -e "\n${BLUE}Configuring PostgreSQL service...${NC}"
sudo systemctl start postgresql
sudo systemctl enable postgresql
echo -e "${GREEN}PostgreSQL service started and enabled.${NC}"

# Create database and user
echo -e "\n${BLUE}Creating database and user...${NC}"
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
    echo -e "${YELLOW}Database $DB_NAME already exists. Skipping database creation.${NC}"
else
    echo -e "Creating database ${GREEN}$DB_NAME${NC} and user ${GREEN}$DB_USER${NC}..."
    
    # Create script to be executed as postgres user
    cat > /tmp/create_db.sql << EOF
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';
CREATE DATABASE $DB_NAME;
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER USER $DB_USER WITH SUPERUSER;
EOF
    
    # Execute SQL script as postgres user
    sudo -u postgres psql -f /tmp/create_db.sql
    
    # Clean up
    rm /tmp/create_db.sql
    
    echo -e "${GREEN}Database and user created successfully.${NC}"
fi

# Create virtual environment
echo -e "\n${BLUE}Setting up Python virtual environment...${NC}"
if [ -d "venv" ]; then
    echo -e "${YELLOW}Virtual environment already exists. Skipping creation.${NC}"
else
    python3 -m venv venv
    echo -e "${GREEN}Virtual environment created.${NC}"
fi

# Activate virtual environment
echo -e "\n${BLUE}Activating virtual environment...${NC}"
source venv/bin/activate
echo -e "${GREEN}Virtual environment activated.${NC}"

# Install Python dependencies
echo -e "\n${BLUE}Installing Python dependencies...${NC}"
pip install --upgrade pip
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
else
    echo -e "${YELLOW}requirements.txt not found. Installing core dependencies...${NC}"
    pip install Flask Flask-SQLAlchemy Flask-Login Flask-WTF SQLAlchemy Werkzeug gunicorn email-validator psycopg2-binary pycryptodome pyotp boto3 reportlab PyPDF2 qrcode anthropic html2text python-dotenv
fi
echo -e "${GREEN}Python dependencies installed.${NC}"

# Create .env file
echo -e "\n${BLUE}Creating environment configuration...${NC}"
if [ -f ".env" ]; then
    echo -e "${YELLOW}.env file already exists. Creating backup at .env.bak${NC}"
    cp .env .env.bak
fi

cat > .env << EOF
# VPS Control Panel Environment Configuration
# Created by auto-installer on $(date)

# Database Connection
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME

# Security Settings
SESSION_SECRET=$SESSION_SECRET

# Company Information
COMPANY_NAME=HWO Security
ADMIN_EMAIL=$EMAIL_ADDRESS

# Production Flag
PRODUCTION=true

# Flask Environment
FLASK_ENV=production
EOF

echo -e "${GREEN}.env file created with production configuration.${NC}"

# Initialize database
echo -e "\n${BLUE}Initializing database...${NC}"
python -c "from database import init_database; print(init_database())"
echo -e "${GREEN}Database initialized.${NC}"

# Create systemd service file
echo -e "\n${BLUE}Creating and installing systemd service...${NC}"
cat > /tmp/vpscontrol.service << EOF
[Unit]
Description=VPS Control Panel
After=network.target postgresql.service
Wants=postgresql.service

[Service]
User=$(whoami)
Group=www-data
WorkingDirectory=$INSTALL_DIR
Environment="PATH=$INSTALL_DIR/venv/bin"
ExecStart=$INSTALL_DIR/venv/bin/gunicorn --bind 127.0.0.1:5000 --workers 3 main:app
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo cp /tmp/vpscontrol.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable vpscontrol
echo -e "${GREEN}Systemd service installed and enabled.${NC}"

# Configure Nginx
echo -e "\n${BLUE}Configuring Nginx as reverse proxy...${NC}"
cat > /tmp/vpscontrol.conf << EOF
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

sudo cp /tmp/vpscontrol.conf /etc/nginx/sites-available/
sudo ln -sf /etc/nginx/sites-available/vpscontrol.conf /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx
echo -e "${GREEN}Nginx configured as reverse proxy.${NC}"

# Set up SSL with Let's Encrypt
echo -e "\n${BLUE}Setting up SSL with Let's Encrypt...${NC}"
sudo certbot --nginx -d $DOMAIN_NAME --non-interactive --agree-tos --email $EMAIL_ADDRESS
echo -e "${GREEN}SSL certificate installed.${NC}"

# Set up automatic renewal
echo -e "\n${BLUE}Setting up automatic SSL certificate renewal...${NC}"
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo -e "${GREEN}Automatic SSL certificate renewal configured.${NC}"

# Create update script
echo -e "\n${BLUE}Creating maintenance scripts...${NC}"
cat > update.sh << EOF
#!/bin/bash
# VPS Control Panel Update Script

set -e

echo "Updating VPS Control Panel..."
cd $INSTALL_DIR

# Activate virtual environment
source venv/bin/activate

# Pull latest changes if using git
if [ -d ".git" ]; then
    git pull
    echo "Code updated from repository."
fi

# Update dependencies
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "Dependencies updated."
fi

# Restart service
sudo systemctl restart vpscontrol
echo "Service restarted."

echo "Update completed successfully!"
EOF

chmod +x update.sh
echo -e "${GREEN}Update script created at $INSTALL_DIR/update.sh${NC}"

# Create database backup script
mkdir -p backups
cat > backup.sh << EOF
#!/bin/bash
# VPS Control Panel Backup Script

set -e

BACKUP_DIR="$INSTALL_DIR/backups"
TIMESTAMP=\$(date +"%Y%m%d_%H%M%S")
mkdir -p \$BACKUP_DIR

# Activate virtual environment
source $INSTALL_DIR/venv/bin/activate

# Run backup
cd $INSTALL_DIR
python -c "from database import backup_database; backup_database('\$BACKUP_DIR/backup_\$TIMESTAMP.sql')"

# Remove backups older than 30 days
find \$BACKUP_DIR -name "backup_*.sql" -type f -mtime +30 -delete

echo "Backup created at \$BACKUP_DIR/backup_\$TIMESTAMP.sql"
EOF

chmod +x backup.sh
echo -e "${GREEN}Backup script created at $INSTALL_DIR/backup.sh${NC}"

# Create daily backup cron job
echo -e "\n${BLUE}Setting up daily database backups...${NC}"
(crontab -l 2>/dev/null; echo "0 3 * * * $INSTALL_DIR/backup.sh > $INSTALL_DIR/backups/backup_log.txt 2>&1") | crontab -
echo -e "${GREEN}Daily backup scheduled for 3:00 AM.${NC}"

# Start the application
echo -e "\n${BLUE}Starting the application...${NC}"
sudo systemctl start vpscontrol
echo -e "${GREEN}VPS Control Panel service started.${NC}"

# Final check
echo -e "\n${BLUE}Verifying deployment...${NC}"
if sudo systemctl is-active --quiet vpscontrol; then
    echo -e "${GREEN}VPS Control Panel service is running.${NC}"
else
    echo -e "${RED}VPS Control Panel service is not running. Please check logs with 'sudo journalctl -u vpscontrol'.${NC}"
fi

if sudo systemctl is-active --quiet nginx; then
    echo -e "${GREEN}Nginx service is running.${NC}"
else
    echo -e "${RED}Nginx service is not running. Please check logs with 'sudo journalctl -u nginx'.${NC}"
fi

# Display completion message and instructions
echo -e "\n${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              PRODUCTION DEPLOYMENT COMPLETED!                 ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo
echo -e "${GREEN}VPS Control Panel has been successfully deployed in production mode!${NC}"
echo
echo -e "${YELLOW}Your site is now available at:${NC} ${GREEN}https://$DOMAIN_NAME${NC}"
echo
echo -e "${YELLOW}Default admin credentials:${NC}"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Email: ${GREEN}admin@example.com${NC}"
echo -e "  Password: ${GREEN}admin123${NC}"
echo -e "${RED}IMPORTANT: Change these credentials immediately after first login!${NC}"
echo
echo -e "${YELLOW}Database information:${NC}"
echo -e "  Database name: ${GREEN}$DB_NAME${NC}"
echo -e "  Username: ${GREEN}$DB_USER${NC}"
echo -e "  Password: ${GREEN}$DB_PASSWORD${NC}"
echo
echo -e "${YELLOW}System services:${NC}"
echo -e "  Application service: ${GREEN}sudo systemctl status vpscontrol${NC}"
echo -e "  Web server: ${GREEN}sudo systemctl status nginx${NC}"
echo -e "  SSL renewal: ${GREEN}sudo systemctl status certbot.timer${NC}"
echo
echo -e "${YELLOW}Maintenance commands:${NC}"
echo -e "  Update application: ${GREEN}./update.sh${NC}"
echo -e "  Backup database: ${GREEN}./backup.sh${NC}"
echo -e "  Restart application: ${GREEN}sudo systemctl restart vpscontrol${NC}"
echo
echo -e "${YELLOW}Automated processes:${NC}"
echo -e "  Daily database backup at 3:00 AM"
echo -e "  Automatic SSL certificate renewal"
echo
echo -e "${BLUE}Thank you for installing VPS Control Panel!${NC}"
echo -e "${BLUE}For support, contact: info@hwosecurity.org${NC}"
echo

# Exit virtual environment
deactivate