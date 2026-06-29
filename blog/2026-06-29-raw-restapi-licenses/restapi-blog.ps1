# -------------------------------------------------------
# Liquit REST API – Annotated Example
# Collects zone and license data via OAuth2 authentication
# -------------------------------------------------------

# CONFIGURATION: API credentials and server details
# These are required to authenticate and connect to the API
$server   = "https://zonename.previder.nl"          # Base URL of the Liquit server
$clientId = "74AAE62C-58BE-4F3E-8712-51BAC43EA609"  # OAuth2 client ID (identifies this application)
$username = "local\usr-zonename-script"             # Service account username (create a dedicated account for scripts)
$password = "P@ssword01!"                           # Service account password (store securely, e.g., in a vault)

# Initialize result arrays to store collected data
$allZones = @()      # Will hold all zone information
$allLicenses = @()   # Will hold zone-license pairs

# -------------------------------------------------------
# STEP 1: AUTHENTICATION – Obtain OAuth2 Bearer Token
# -------------------------------------------------------
# OAuth2 password grant flow:
#   - Send username/password to token endpoint
#   - Receive access token valid for API calls
#   - Token used in Authorization header for subsequent requests

$tokenResponse = Invoke-RestMethod `
    -Method POST `
    -Uri "$server/api/oauth2/token" `
    -ContentType 'application/x-www-form-urlencoded' `
    -Body @{
        grant_type = 'password'              # OAuth2 grant type: password credentials
        client_id  = $clientId               # App identifier
        scope      = 'idtoken content'       # Request token + content access scopes
        username   = $username               # Service account
        password   = $password               # Service account password
    }

# Extract the access token from response.
$token = $tokenResponse.access_token

# Prepare Authorization header for all subsequent API calls
# Format: "Authorization: Bearer <token>"
$headers = @{ Authorization = "Bearer $token" }

# Generate cache-buster (timestamp) to bypass browser caching
# Appended as _=<timestamp> query parameter
$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()

# -------------------------------------------------------
# STEP 2: QUERY ZONES – Retrieve list of all zones
# -------------------------------------------------------
# OData parameters explained:
#   $count=true     : Include total count in response
#   $skip=0         : Skip first N records (for pagination)
#   $top=50         : Return max 50 records per request
#   $orderby=name   : Sort by zone name ascending
#   $select=...     : Return only specified fields (reduces payload)
#   _=<timestamp>   : Cache-buster to force fresh data

$uri2 = "$server/api/v3/system/zones?`$count=true&`$skip=0&`$top=50&`$orderby=name&`$select=id,name,enabled,primary,license/state,virtualHost,license/expires&_=$cacheBuster"
$zonesResponse = Invoke-RestMethod -Method GET -Uri $uri2 -Headers $headers
$allZones = $zonesResponse.value  # Extract array of zone objects

# -------------------------------------------------------
# STEP 3: DETAILED LOOKUP – Get license for each zone
# -------------------------------------------------------
# For each zone returned in Step 2:
#   1. Extract zone ID (unique identifier)
#   2. Call zone-specific endpoint: /api/v3/system/zones/{zoneId}/
#   3. Request only license details via $select
#   4. Combine zone name + license into single object
#   5. Append to results array

foreach ($zone in $allZones) {
    $zoneId = $zone.id  # Unique zone identifier (GUID)
    
    # Refresh cache-buster for each individual call
    $cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    
    # Construct zone-specific URI with license selection
    # ?$select=id,license : Only fetch id and license properties
    $uri3 = "$server/api/v3/system/zones/$zoneId/?`$select=id,license&_=$cacheBuster"
    
    # Invoke REST API with authentication header
    $zoneDetail = Invoke-RestMethod -Method GET -Uri $uri3 -Headers $headers
    
    # Create custom object combining zone name and license details
    # This normalizes the data structure for easier downstream processing
    $licenseObject = [pscustomobject]@{
        ZoneId   = $zoneDetail.id           # Zone unique identifier
        ZoneName = $zone.name               # Zone display name
        License  = $zoneDetail.license      # License object (may contain state, expiry, etc.)
    }
    
    # Append to results array
    $allLicenses += $licenseObject
}

# -------------------------------------------------------
# RETURN RESULTS
# -------------------------------------------------------
# Script returns object with both datasets:
#   - $allZones   : Full zone list from Step 2
#   - $allLicenses: Zone+License pairs from Step 3 loop

return $allLicenses


