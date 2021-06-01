# Get tenant domain name for tenant id

# based on work from @jseerden and @joslieben
# from this Twitter thread
# https://twitter.com/joslieben/status/1394587924130418692

# !!! it is only possible if the tenant has customized their sign in pages.

$tenantid = "type-your-tenant-id-here"
$authInfo = Invoke-RestMethod -Uri "https://login.microsoftonline.com/$tenantid/oauth2/authorize?client_id=c44b4083-3bb0-49c1-b47d-974e53cbdf3c" -Method GET
([regex]::match($authInfo, '"UserIdLabel":"(\D+)",').Groups[1].Value).Split("@")[1]

# result should include the domain name :-)