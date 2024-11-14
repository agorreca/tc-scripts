#!/bin/bash

# Include the common file
source "$TC_SCRIPTS_PATH/bash/common.sh"

# ==============================
# Login to WEB and MOBILE
# ==============================

echo "Logging into WEB platform..."
obtain_token_web

echo "Logging into MOBILE platform..."
obtain_token_mobile

echo "Both WEB and MOBILE tokens obtained successfully."
