param 
(
    [Parameter(Mandatory = $True)][string]$source_jwt, 
    [Parameter(Mandatory = $True)][string]$target_jwt, 
    [Parameter(Mandatory = $True)][string]$source_tenant_name, 
    [Parameter(Mandatory = $True)][string]$target_tenant_name, 
    # Note that we are using us.healthbot.microsoft.com not healthbot.microsoft.com
    [Parameter(Mandatory = $False)][string]$base_url = "https://us.healthbot.microsoft.com/api/account/",
    [Parameter(Mandatory = $False)][int16]$retries = 5
)
##################################################################################################################
# This script gets the scenarios from a source Heatlh Bot and 
# uploads them to a target Health Bot one at a time
# Adapted from: https://docs.microsoft.com/en-us/healthbot/integrations/managementapi
# and https://github.com/Microsoft/HealthBotCodeSnippets/tree/master/HealthAgentAPI
##################################################################################################################

function Request(
    [Parameter(Mandatory = $True)]
    [string]$jwt = $null,
    [Parameter(Mandatory = $True)]
    [string]$url = $null,
    [Parameter(Mandatory = $False)]
    [string]$method = 'Get',
    [Parameter(Mandatory = $False)]
    [string]$body = $null
) {    
    $headers = @{
        "Content-type" = "application/json"
        "Authorization" = "Bearer " + $jwt 
    }
    # Make a web request    
    $i = 0
    while ($i -lt $retries)
    {
        try {
            $i++
            if ($method -eq 'get') {        
                # Use Invoke-WebRequest here to get back the raw JSON so we can use this
                # for uploading to the target. Using Invoke-RestMethod impacts the JSON
                # in such a way that it can't easily be uploaded
                $result = (Invoke-WebRequest -Uri $url -Method $method -Headers $headers).Content                
            }
            else {
                # Using Invoke-RestMethod here since we aren't expecting raw JSON back
                $result = Invoke-RestMethod -Method $method -Uri $url -Headers $headers -Body $body    
            }
            break    
        }
        catch {
            # Retry here in case API call fails
            if ($i -lt $retries) {
                Write-Host "Failed invoking web request - will retry :" $Error[0] 
                Start-Sleep -s 1
            }
            else
            {
                Write-Error $_
            }
        }
        
    }
    return $result
}

function PostScenarios([Parameter(Mandatory = $False)][string]$scenarios) {
    # Post all scenarios to the target environment, one at a time

    if ($scenarios.Length  -eq 0)
    {
        throw "No scenarios found."
    }
    
    $json = convertfrom-json $scenarios    
    $target_url = $base_url + $target_tenant_name + "/scenarios"

    Write-Host $json.Count " scenarios to post."
    
    # Loop through each scenario and upload to the target
    foreach($i in 0..($json.Count-1)){        
        $body = @($json[$i]) | ConvertTo-Json                
        $name = $json[$i].name
        $i++    
        $post = (Request -jwt $target_jwt -url $target_url -method "Post"  -body $body)
        Write-Host $i"." $name $post        
    }
}

# Upload scenarios from source to target
$sourceUrl = $base_url + $source_tenant_name + "/scenarios"  
$scenarios = Request -jwt $source_jwt -url $sourceUrl
PostScenarios $scenarios
