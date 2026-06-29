---
title: "Recast Application Workspace (RAW) Detailed license overview"
parent: "Blog"
nav_order: 1
---

# Recast Application Workspace (RAW) Detailed license overview



## Why I Started This

Recast Software provides a PowerShell module as the officially supported way to interact with Recast Application Workspace. Their goal is to cover most actions available in the portal, but there are still gaps especially when you want to automate or integrate deeper functionality.

Together with my colleague Ivan de Mes, I started exploring the underlying REST API to see how far we could push it. Our biggest challenge was obtaining a valid access token, and getting OAuth authentication to work wasn’t straightforward.

With help from Copilot and additional information provided by Recast Software with the JavaScript reference at
https://api.liquit.com/workspace/v2/liquit.workspace.js. I managed to build a working script that retrieves an OAuth access token. Once we had that token, the REST API opened up and we were finally able to experiment with endpoints beyond what the PowerShell module currently supports.

This gives us a lot more flexibility and allows us to automate scenarios that weren’t possible before.

## Why I Created This Blog

In my conversations with Recast Software, Donny van der Linde expressed the need for more comprehensive license information from partners and customers. The existing PowerShell module provides only limited data, which makes it difficult to obtain a complete overview.

Because I had previously shared how I use GitHub Copilot to simplify REST API work, Donny asked me to look into retrieving the missing license information through the Recast Application Workspace API. Based on my earlier experience with similar integrations, I was able to achieve this within an hour, with Copilot assisting in several of the more repetitive or detailed steps.

This reminded me how much I appreciate working through practical technical challenges, and it motivated me to document the results. I wanted to ensure the effort was recognized and to share the outcome with peers who may benefit from it. It also provides a good opportunity to demonstrate how AI-assisted tooling can support our daily work and help us approach tasks more efficiently. Due to limited time and energy, this blog was created with Copilot and edited by Roel Beijnes.

## Important Support Note

Using the Recast Application Workspace REST API directly is not a supported practice for customer support scenarios.

For supported automation and supportability, use the official PowerShell module from Recast Software:

 `Liquit.Server.Powershell`

This blog is about exploration and learning, not replacing the supported path.


## General flow of the script with RESTAPI and OAuth authentication

![Diagram of script](img/diagram-process.png)

## Step-by-Step: How I Build the Calls

### Technologies Used

- REST API for direct endpoint communication with Recast Application Workspace
- OAuth2 password grant for authentication and bearer token retrieval
- OData query parameters for filtering, sorting, and paging API responses
- PowerShell `Invoke-RestMethod` for HTTP requests and JSON parsing
- Cache-busting query parameter (`_`) to avoid stale browser/proxy responses

### 1. Authenticate with OAuth2 (Password Grant)

#### 🔑 Authentication Flow

![Authentication Flow](img/authentication-flow.png){: .img-small }

The first step is obtaining an access token from the OAuth2 token endpoint. In PowerShell, this is done with a form-encoded POST request:

```powershell
$tokenResponse = Invoke-RestMethod `
	-Method POST `
	-Uri "$server/api/oauth2/token" `
	-ContentType 'application/x-www-form-urlencoded' `
	-Body @{
		grant_type = 'password'
		client_id  = $clientId
		scope      = 'idtoken content'
		username   = $username
		password   = $password
	}
```

### 2. Extract the Access Token and Build Auth Header

After successful authentication, the script reads the `access_token` and injects it into an Authorization header for all next requests:

```powershell
$token = $tokenResponse.access_token
$headers = @{ Authorization = "Bearer $token" }
```

### 3. Query Zones with OData Parameters

#### 🔍 OData Query Parameters
| Parameter          | Purpose                          | Example                     |
|:-------------------|:---------------------------------|:----------------------------|
| **$count=true**    | Include total count in response  | Enables pagination info     |
| **$skip=0**        | Pagination: Skip N records       | Skip first 0 records        |
| **$top=50**        | Pagination: Return max N records | Return max 50 per request   |
| **$orderby=name**  | Sort results                     | Sort by name ascending      |
| **$select=id,name**| Select specific fields           | Reduces response payload    |
| **_=timestamp**    | Cache buster                     | Force fresh data each call  |

| head1        | head two          | three |
|:-------------|:------------------|:------|
| ok           | good swedish fish | nice  |
| out of stock | good and plenty   | nice  |
| ok           | good `oreos`      | hmm   |
| ok           | good `zoute` drop | yumm  |



To keep responses efficient and predictable, I used OData parameters such as `$count`, `$top`, `$orderby`, and `$select`:

```powershell
$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$uri2 = "$server/api/v3/system/zones?`$count=true&`$skip=0&`$top=50&`$orderby=name&`$select=id,name,enabled,primary,license/state,virtualHost,license/expires&_=$cacheBuster"
$zonesResponse = Invoke-RestMethod -Method GET -Uri $uri2 -Headers $headers
$allZones = $zonesResponse.value
```

This call retrieves the zone list and basic license-related fields while minimizing payload size.

### 4. Loop Zones and Retrieve Detailed License Data

#### 🔄 Loop Through All Zones
```
FOR EACH zone:
  ├─ Extract Zone ID & Name
  ├─ GET /api/v3/system/zones/{zoneId}/?$select=id,license
  ├─ Retrieve License Object
  └─ Append to Results Array
RETURN allLicenses
```

For each zone, I make a second API call to fetch detailed license information:

```powershell
foreach ($zone in $allZones) {
	$zoneId = $zone.id
	$cacheBuster = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
	$uri3 = "$server/api/v3/system/zones/$zoneId/?`$select=id,license&_=$cacheBuster"
	$zoneDetail = Invoke-RestMethod -Method GET -Uri $uri3 -Headers $headers

	$licenseObject = [pscustomobject]@{
		ZoneId   = $zoneDetail.id
		ZoneName = $zone.name
		License  = $zoneDetail.license
	}

	$allLicenses += $licenseObject
}
```

### 5. Return Structured Objects for Reporting

The script returns `$allLicenses`, a structured object collection that is easy to export, filter, and reuse in reporting pipelines.

In short: authenticate once, query the zone collection, enrich per zone, and return normalized PowerShell objects.

## How to Discover REST Endpoints Yourself

One very practical technique is to inspect network traffic in the portal and read the actual URL and payload of each click.

In **Brave**, this looks like:

1. Open the Recast Application Workspace portal.
2. Press `F12`.
3. Go to **Network** and clear the network history.

![Brave Developer Tools Network Overview](img/DeveloperEdit.png)

4. Perform the UI action you want to automate.
5. Inspect URL, method, headers, and payload.
6. Paste those details into Copilot and ask for a PowerShell equivalent.

![Captured Request URL and Payload Details](img/RequestURL.png)

For other browsers, the screens are different, but the method is the same: inspect requests, understand payloads, then translate them into script calls.

## Final Outcome

Using this approach, I created a script that:

- Authenticates against Recast Application Workspace
- Retrieves zones
- Pulls license details per zone
- Returns reusable PowerShell objects for reporting and automation

Final script: [restapi-blog.ps1](restapi-blog.ps1)

```
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


```


The main gain was not just script output, but a repeatable method to learn and build quickly with AI assistance. Start small, validate one call at a time, and use Copilot as a technical translator between portal behavior and script implementation.
