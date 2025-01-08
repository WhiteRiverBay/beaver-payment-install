#!/bin/bash

echo "Installing UI for Cloudflare"

# Check if wrangler is installed
if ! command -v wrangler &> /dev/null; then
    echo "Wrangler is not installed. Installing wrangler..."
    npm install -g wrangler
fi

# Login to Cloudflare
echo "Please login to Cloudflare..."
wrangler login

# Create a new directory for the UI
echo "Creating new directory for UI..."
mkdir -p upay-ui
cd upay-ui

# Initialize a new project
echo "Initializing new project..."
git clone https://github.com/WhiteRiverBay/beaver-payment-ui .

# Install dependencies
echo "Installing dependencies..."
npm install

# Build the project
echo "Building project..."
npm run build:prod

# Create and deploy to Cloudflare Pages
echo "Deploying to Cloudflare Pages..."
wrangler pages project create beaver-payment-ui --production-branch main
wrangler pages deploy ./build --project-name=beaver-payment-ui

echo "Deployment complete! Your site will be available at https://beaver-payment-ui.pages.dev"
echo "You can configure a custom domain in the Cloudflare Dashboard"
