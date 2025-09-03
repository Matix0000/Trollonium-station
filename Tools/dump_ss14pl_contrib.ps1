#!/usr/bin/env pwsh

$scriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
. $(join-path $scriptDir contribs_shared.ps1)

if ($null -eq $env:GITHUB_TOKEN)
{
    throw "A GitHub API token is required to run this script properly without being rate limited. If you're a user, generate a personal access token and use that. If you're running this in a GitHub action, make sure you expose the GITHUB_TOKEN secret as an environment variable."
}

function load_contribs([string] $repo)
{
    $qParams = @{
        "per_page" = 100
        "anon" = 1
    }

    $headers = @{
        Authorization="Bearer $env:GITHUB_TOKEN"
    }

    $url = "https://api.github.com/repos/{0}/contributors" -f $repo
    $r = @()

    while ($null -ne $url)
    {
        $resp = Invoke-WebRequest $url -Body $qParams -Headers $headers
        $url = $resp.RelationLink.next
        $j = ConvertFrom-Json $resp.Content
        $r += $j
    }

    foreach ($contributor in $r)
    {
        if ($null -ne $contributor.name `
            -And $null -ne $contributor.email `
            -And $contributor.email -match '\d+\+(.*)@users\.noreply\.github\.com$')
        {
            $username = $Matches.1
            if ($contributor.name.ToLower() -eq $username) {
                $username = $contributor.name
            }
            if (($r).login -contains $username) { continue }
            $contributor | Add-Member -MemberType NoteProperty -Name "login" -Value $username
        }
        elseif ($null -eq $contributor.login `
                 -And $null -ne $contributor.name `
                 -And !$contributor.name.Contains(" "))
        {
            $username = $contributor.name
            if (($r).login -contains $username) { continue }
            $userUrl = "https://api.github.com/users/{0}" -f $username
            try {
                $userResp = Invoke-WebRequest $userUrl -Headers $headers
                $userJ = ConvertFrom-Json $userResp.Content
                $contributor | Add-Member -MemberType NoteProperty -Name "login" -Value $userJ.login
            }
            catch {}
        }
    }

    return $r
}

$poloniumJson = load_contribs("polonium14/polonium-station")

($poloniumJson).login + ($add) `
    | select -unique `
    | Where-Object { -not $ignore[$_] } `
    | ForEach-Object { if($replacements[$_] -eq $null){ $_ } else { $replacements[$_] }} `
    | Sort-object `
    | Join-String -Separator ", "
