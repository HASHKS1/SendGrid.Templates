<#
.SYNOPSIS

    Script used to migrate templates when a new sub-user account is created in sendgrid, such as a Test account, and you want to import all production templates into this account.


.DESCRIPTION

    README.md


.NOTES

    Version:        1.0
    Author:         Hamza Chahid Ksabi
    Creation Date:  29/04/2024
    Purpose/Change: Initial script development

    Document Your API : https://any-api.com/sendgrid_com/sendgrid_com/docs/_templates
#>

[CmdletBinding()]
param(
    # The Bearer Token for the source Subuser Account in sendgrid .
    # Full access key (faccess)
    [Parameter(Mandatory)]
    [string]$fromBearerToken,

    # The Bearer Token for the destination Subuser Account in sendgrid .
    # Full access key (faccess)
    [Parameter(Mandatory)]
    [string]$toBearerToken
  )

function Get-fromAccountBanner {
    Write-Host "`n"
    Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |        Starting to fetch all Templates        |            " -ForegroundColor Cyan
    Write-Host "                    |           From souce subuser account          |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
    Write-Host "`n"
} 

function Get-toAccountBanner {
    Write-Host "`n"
    Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |        Starting to create all Templates       |            " -ForegroundColor Cyan
    Write-Host "                    |         To destination subuser account        |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    |                                               |            " -ForegroundColor Cyan
    Write-Host "                    -------------------------------------------------            " -ForegroundColor Cyan
    Write-Host "`n"
} 
function Set-SendgridHomeDir {
    $outputDirectory = $PSScriptRoot
    $directoryName = "Sendgird-HTML"
    $outputDirectory = Join-Path -Path $outputDirectory -ChildPath $directoryName
    # Check if the directory exists, if not, create it
    if (-not (Test-Path -Path $outputDirectory -PathType Container)) {
        New-Item -Path $outputDirectory -ItemType Directory | Out-Null
        Write-Host "Output directory created: $outputDirectory"
    }
    Write-Host "Output directory: $outputDirectory"
    return $outputDirectory.ToString() 
}
function Remove-InvalidFilenameCharacters {
    param (
        [string]$filename
    )
    #Error saving HTML content to file, add  invalid filename characters to be removed
    $invalidCharsPattern = '[\\/:*?"<>|[\]#%]'
    return ($filename -replace $invalidCharsPattern, " ")
}
function Get-TemplateId {
    [CmdletBinding()]
    param(
        # The Bearer Token for Subuser Account in sendgrid .
        # Full access key (faccess)
        [Parameter(Mandatory)]
        [string]$apiKey

      )
    $endpointUrl = "$($sendgrid_template_url)?generations=dynamic"
    $headers = @{
        'Authorization' = "Bearer $apiKey"
    }
    $response = Invoke-RestMethod -Uri $endpointUrl -Headers $headers -Method Get

    # Deserialize the JSON response
    $templates = $response.templates

    # Output the count of template IDs
    $templateCount = $templates.Count

    Write-Host "Count existing Templates in the subuser account: $templateCount" -Foregroundcolor DarkBlue
    $templateHashMap = @{}
    $counter = 1
    # Output the IDs Names of the templates
    foreach ($template in $templates) {
        $templateId = $template.id
        $templateName = $template.name
        if ($templateHashMap.ContainsKey($templateName)) {
            Write-Warning "Duplicate template name found in the source subuser account: $templateName -->  with the Template ID: $templateId"
            $newTemplateName = "Copy-$counter-$templateName"
            $templateHashMap[$newTemplateName] += $templateId
            $counter++
        }  
        else {
            # Add the template name and ID to the hashmap
            $templateHashMap[$templateName] += $templateId
        }
    }
    return $templateHashMap
}
function Get-TemplateHTMLContent {
    $versionTemplateHashMap = [ordered]@{}
    $headers = @{
        'Authorization' = "Bearer $fromBearerToken"
    }
    # Script Banner
    Get-fromAccountBanner
    $templateHashMap = Get-TemplateId -apiKey $fromBearerToken
    $templateHashMap.GetEnumerator() | % { 
        $templateName = $_.Key
        $templateId = $_.Value
        Save-TemplateHTMLContent -templateName $templateName -templateId $templateId -headers $headers 
    } 
    return $versionTemplateHashMap
}

function Save-TemplateHTMLContent {
    param (
        [string]$templateName,
        [string]$templateId,
        [hashtable]$headers
    )
    $outputDirectory = Set-SendgridHomeDir
    $url = "$($sendgrid_template_url)/$($templateId.ToString())"
    $templates = Invoke-RestMethod -Uri $url -Headers $headers -Method Get
    if ($templates.versions) {
        foreach ($version in $templates.versions){
            # Retrieve the active version's HTML content
            if ($version.active -eq 1) {
                # Store in the version template hashtable
                # Add the template name and versionInfo to the hashmap
                if  ($templateId -eq $version.template_id) {
                    $versionTemplateHashMap[$version.template_id] += @($templateName,$version.name,$version.subject)
                }
                
                $htmlContent = $version.html_content
                # Generate filename with template Name and template ID
                $versionID = $version.template_id
                $cleanedTemplateName = Remove-InvalidFilenameCharacters -filename $templateName
                $filename = "$cleanedTemplateName--$versionID.html"
                $outputPath = Join-Path -Path $outputDirectory -ChildPath $filename
                # Try to save HTML content to file with error handling
                try {
                    $htmlContent | Set-Content -Path $outputPath -ErrorAction Stop
                    Write-Host "HTML Content saved to: $outputPath" -ForegroundColor Green
                    Write-Host "Template Name: $($templateName)" -ForegroundColor Green
                    Write-Host "Template ID: $($templateId)" -ForegroundColor Blue
                    Write-Host "`n"
                } catch {
                    Write-Host "Error saving HTML content to file: $_" -ForegroundColor Red
                    Write-Host "Template Name: $($templateName)" -ForegroundColor Red
                    Write-Host "Template ID: $($templateId)" -ForegroundColor Red
                    Write-Warning  "Error saving HTML content for: '$($templateName)' (Template ID: $($templateId))" 3>&1 >> $PSScriptRoot/warning.log
                    Write-Host "`n"
                }

            }
        }
    } else {
        Write-Warning  "Skipping empty Template Version for '$($templateName)' (Template ID: $($templateId))"
    }
}
    
function Set-MigrateTransacTemplate {
    $headers = @{
        'Authorization' = "Bearer $toBearerToken"
        'Content-Type' = 'application/json'
        'Accept-Encoding' = 'gzip, deflate, br'
    }   
    $versionInfoHashMap = Get-TemplateHTMLContent
    Get-toAccountBanner
    if ($versionInfoHashMap.Count -ne 0) {
        $to_templateHashMap = Get-TemplateId -apiKey $toBearerToken
        $versionInfoHashMap.GetEnumerator() | % {
            $templateId = $_.Key
            $templateName =  $_.Value[0]
            $versionName = $_.Value[1]
            $versionSubject = $_.Value[2]
     
            Write-Debug ($versionInfoHashMap)
            # HTML version info
            $versionFilePath = Get-ChildItem -Path $PSScriptRoot/Sendgird-HTML -Filter "*$($templateId)*" -File

            $htmlContent =  Get-Content -Path  "$versionFilePath" -Raw

            # Make Json Object for template creation
            $JsonBody_template = @{
                name = $templateName
                generation = "dynamic"
            } | ConvertTo-Json

            # Make Json Object for template version 
            $JsonBody_template_version = @{
                name = $versionName
                subject = $versionSubject
                active = 1
                editor = "design"
                html_content = $htmlContent
            }
    
            try {
                # Check if the template name exists in the destination subuser account
                if ($to_templateHashMap.ContainsKey($templateName)) {
                    $to_templateId =  $to_templateHashMap[$templateName]
                    Write-Warning "Already existing template in the destination subuser account: $templateName -->  with the Template ID: $to_templateId"
                }
                else {
                    # Create a new template
                    Write-Host "Template creation POST request ..."
                    $ntemplate = Invoke-RestMethod -Uri $sendgrid_template_url -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody_template))
                    Write-Host "POST request sent successfully" -ForegroundColor Green
                    
                    # Get New template ID created
                    $ntemplateId = $ntemplate.id.ToString()
                    # Append the template Id 
                    $JsonBody_template_version.Add('template_id',$ntemplateId)
                    # Serialize HTML to json 
                    $JsonBody_template_version = $JsonBody_template_version | ConvertTo-Json
                    Write-Host "UPDATING Template version POST request ..."
                    Invoke-RestMethod -Uri $sendgrid_template_url/$ntemplateId/versions -Method Post -Headers $headers -Body ([System.Text.Encoding]::UTF8.GetBytes($JsonBody_template_version)) | Out-Null
                    Write-Host "POST request sent successfully" -ForegroundColor Green
                }
            } catch {
                Write-Host "Error sending POST request: $_"
            }
        }
    } else {
        Write-Host "No version information provided for templates to be copied."
    }

}

# Main

$sendgrid_template_url = "https://api.sendgrid.com/v3/templates"
Set-MigrateTransacTemplate


