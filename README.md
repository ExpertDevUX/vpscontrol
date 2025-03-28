# VPS Control Panel - Complete Installation Guide
# A sophisticated VPS control panel that simplifies server management through an intelligent and visually engaging administrative platform.

Author: Tony Pham
Contact: info@hwosecurity.org

Features
# 🖥️ Complete VPS management and provisioning;
# 💳 Integrated billing and invoicing system;
# 🎫 Support ticket system;
# 🔑 License key generation and management;
# 🛒 Shopping cart and product configuration;
# 💬 AI-powered customer support chat;
# 🌐 Multi-cloud provider integration;
# 📊 Comprehensive admin dashboard;
# 🔐 Secure authentication system;
# 💰 Multiple payment gateway integration
Tech Stack;
#Python 3.11+ with Flask framework
#PostgreSQL database with SQLAlchemy ORM
#Modern responsive web interface
#Anthropic Claude AI integration for customer support
#Cloud provider APIs (AWS, Digital Ocean, Vultr)
#PayPal payment processing
#Detailed Installation Guide
####System Requirements
#Operating System: Linux (Ubuntu/Debian recommended), macOS, or Windows
#Python: 3.11 or higher
#PostgreSQL: 12.0 or higher
#Memory: Minimum 2GB RAM
#Storage: Minimum 10GB free space
#Internet Connection: Required for external API access
Step 1: System Preparation
On Ubuntu/Debian:
# Update system packages
sudo apt update && sudo apt upgrade -y
# Install required system dependencies
sudo apt install -y python3 python3-pip python3-venv postgresql postgresql-contrib git
# Start PostgreSQL service
sudo systemctl start postgresql
sudo systemctl enable postgresql
On macOS (using Homebrew):
# Install Homebrew if not installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# Install dependencies
brew install python postgresql git
# Start PostgreSQL service
brew services start postgresql
On Windows:
Install Python 3.11+ from python.org
Install PostgreSQL from postgresql.org
Install Git from git-scm.com
Step 2: PostgreSQL Database Setup
# Connect to PostgreSQL
sudo -u postgres psql
# Create database and user
CREATE DATABASE vpscontrolpanel;
CREATE USER vpsadmin WITH ENCRYPTED PASSWORD 'your_secure_password';
GRANT ALL PRIVILEGES ON DATABASE vpscontrolpanel TO vpsadmin;
# Exit PostgreSQL
\q
Step 3: Clone Repository
# Clone the repository
git clone https://github.com/yourusername/vps-control-panel.git
cd vps-control-panel
Step 4: Python Environment Setup
# Create virtual environment
python3 -m venv venv
# Activate virtual environment
# On Linux/macOS:
source venv/bin/activate
# On Windows:
venv\Scripts\activate
# Install dependencies
pip install -r requirements.txt
Step 5: Environment Configuration
Create a .env file in the root directory with the following content:

# Required settings
DATABASE_URL=postgresql://vpsadmin:your_secure_password@localhost:5432/vpscontrolpanel
SESSION_SECRET=your_secure_random_string
# Application settings
FLASK_ENV=development
PORT=5000
COMPANY_NAME=Your Company
ADMIN_EMAIL=admin@example.com
# Payment settings (optional)
PAYPAL_CLIENT_ID=your_paypal_client_id
PAYPAL_SECRET_KEY=your_paypal_secret_key
PAYPAL_SANDBOX=true
# AI support settings (optional)
ANTHROPIC_API_KEY=your_anthropic_api_key
AI_ENABLED=true
# Security settings (optional)
TURNSTILE_SITE_KEY=your_turnstile_site_key
TURNSTILE_SECRET_KEY=your_turnstile_secret_key
CAPTCHA_ENABLED=false
Replace placeholders with your actual values.

Step 6: Database Initialization
The application will automatically initialize the database on first run. If you prefer to do it manually:

# Run the database initialization script
python -c "from database import init_database; init_database()"
Step 7: Run the Application
# Start the application
python main.py
The application will start and be available at http://localhost:5000

Step 8: First Login
Open your browser and navigate to http://localhost:5000
Log in with the default admin credentials:
Username: admin
Email: admin@example.com
Password: admin123
Immediately change the default password by navigating to the admin profile settings
Step 9: Production Deployment (Optional)
For production environments, it's recommended to use a production-ready WSGI server like Gunicorn with Nginx:

Install additional components:
pip install gunicorn
Create a systemd service (on Linux):
Create a file /etc/systemd/system/vpscontrolpanel.service:

[Unit]
Description=VPS Control Panel
After=network.target
[Service]
User=your_user
WorkingDirectory=/path/to/vps-control-panel
Environment="PATH=/path/to/vps-control-panel/venv/bin"
ExecStart=/path/to/vps-control-panel/venv/bin/gunicorn --bind 0.0.0.0:5000 --workers 3 main:app
Restart=always
[Install]
WantedBy=multi-user.target
Start and enable the service:

sudo systemctl start vpscontrolpanel
sudo systemctl enable vpscontrolpanel
Configuration Details
Database Configuration
The database connection is configured using the DATABASE_URL environment variable. The application will automatically:

Check if the specified database exists
Create it if it doesn't exist
Initialize all required tables
Create default data (admin user, settings)
You can also manually back up the database using the utility function:

from database import backup_database
backup_file = backup_database()
print(f"Database backed up to {backup_file}")
Security Settings
The application includes several security features:

Session security: Configured via SESSION_SECRET
CAPTCHA protection: Optional Cloudflare Turnstile integration
Password hashing: Secure password storage using advanced algorithms
Rate limiting: Protection against brute force attacks
CSRF protection: For form submissions
Payment Gateway Integration
PayPal
Create a PayPal Developer account at developer.paypal.com
Create a new application to get your Client ID and Secret Key
Configure the credentials in the admin dashboard or environment variables
Cloud Provider Setup
The application supports multiple cloud providers:

AWS
Create an AWS IAM user with EC2 access
Note the Access Key and Secret Key
Add these credentials in the admin dashboard under Cloud Providers
DigitalOcean
Generate an API token in your DigitalOcean account
Add the token in the admin dashboard under Cloud Providers
Vultr
Generate an API key in your Vultr account
Add the key in the admin dashboard under Cloud Providers
AI Support Integration
To enable the AI-powered customer support chat:

Register for an Anthropic API key at console.anthropic.com
Add the API key to your environment variables or admin settings
Enable the AI chat feature in the admin dashboard
Troubleshooting
Database Connection Issues
If you encounter database connection problems:

Verify your DATABASE_URL is correct
Ensure PostgreSQL is running: systemctl status postgresql
Check PostgreSQL logs: tail -f /var/log/postgresql/postgresql-*.log
Application Errors
For application errors:

Check the application logs in the console
Enable debug mode in config.py
Verify all required environment variables are set
Payment Integration Issues
If payment integrations aren't working:

Verify API credentials are correct
Ensure sandbox mode is enabled for testing
Check network connectivity to payment provider APIs
Maintenance
Database Backups
Regularly back up your database:

# Using the built-in backup function
python -c "from database import backup_database; backup_database()"
# Or using pg_dump directly
pg_dump -U vpsadmin -d vpscontrolpanel -F c -f backup_filename.dump
Updating the Application
To update to the latest version:

git pull
pip install -r requirements.txt
python main.py
Development and Customization
Project Structure
app.py: Flask application initialization
main.py: Application entry point
config.py: Configuration settings
database.py: Database initialization and utilities
models.py: SQLAlchemy models
routes/: Route blueprints
utils/: Utility functions
templates/: HTML templates
static/: Static assets (CSS, JS, images)
Adding New Features
Create appropriate models in models.py
Add routes in the routes/ directory
Create templates in the templates/ directory
Register blueprints in app.py
Customizing the UI
The application uses Bootstrap for styling:

Modify templates in the templates/ directory
Custom CSS can be added to static/css/custom.css
JavaScript customizations go in static/js/ directory
License
This project is licensed under the MIT License - see the LICENSE file for details.

Support
For support, please open an issue on the repository or contact the administrator at the configured admin email.
