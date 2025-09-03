#!/usr/bin/env pwsh

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $(join-path $scriptDir contribs_shared.ps1)

if ($null -eq $env:GITHUB_TOKEN)
{
    throw "A GitHub API token is required to run this script properly. Make sure you expose the GITHUB_TOKEN secret as an environment variable."
}

function load_contribs([string] $repo)
{
    $headers = @{
        Authorization = "Bearer $env:GITHUB_TOKEN"
        Accept        = "application/vnd.github.v3+json"
    }

    $url = "https://api.github.com/repos/$repo/stats/contributors"

    $maxRetries = 10
    $attempt = 0
    do {
        $resp = Invoke-WebRequest -Uri $url -Headers $headers
        $json = ConvertFrom-Json $resp.Content
        Start-Sleep -Seconds 2
        $attempt++
    } while (($json -eq $null -or $json.Count -eq 0) -and $attempt -lt $maxRetries)

    if ($json -eq $null -or $json.Count -eq 0) {
        Write-Warning "No contributor data returned by Stats API"
        return @()
    }

    $logins = $json | ForEach-Object {
        if ($_.author -ne $null) { $_.author.login }
    } | Sort-Object -Unique

    return $logins
}

$poloniumContributors = load_contribs("polonium14/polonium-station")

$result = $poloniumContributors + ($add) `
    | Select-Object -Unique `
    | Where-Object { -not $ignore[$_] } `
    | ForEach-Object { if ($replacements[$_] -eq $null) { $_ } else { $replacements[$_] } } `
    | Sort-Object `
    | Join-String -Separator ", "

Write-Output $result
