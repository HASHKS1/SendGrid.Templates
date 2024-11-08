# SendGrid.Templates
Simple tool that automates migration templates between Sendgird accounts (or subuser accounts) using their API keys.

# Description 

This script is used to obtain a list of all the templates available in the source account, storing them in a hash table which associates the template name with the template ID.

When exporting all available templates from the source account, we flag duplicate templates names, which must be reported and reviewed by the marketing team.

The HTML content of each template is stored locally in the specific "Sendgrid-HTML" folder.
Each file name corresponds to a unique email template ID that will be import in the destination account via script.
The HTML file will be exported. All the metadata from Sendgrid template editor will be created via script.

Create the new templates version in the destination account, if it doesn't exist already.
If a template does not have a version, the script will raise a WARNING, ignore it and it will not be created to the destination account.
Create a json object containing the version name with the HTML-based design editor, then send a creation request to the destination account.

# Utilization
The script expect two arguments to provide  the following information:
- fromBearerToken for making  API calls (required) to source Sendgrid subuser account. 
- toBearerToken for making API  calls (required) to destination Sendgrid subuser account.
- This can be obtained by logging into your SendGrid subuser account and navigating to  
    "Settings" > "API Keys". Click on "Create API Key" with the API key name "faccess" with full access. In Actual field, copy the API key for "faccess"

```
# Transfer Templates between Sendgrid accounts.
# Replace <> with you API Keys.

PS> ./Set-MigrateTransacTemplates.ps1 -fromBearerToken <src_account> -toBearerToken <dst_account>

```


# Notice

This Tool does not delete exsiting templates in SendGrid.

