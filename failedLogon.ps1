<#   
================
Created by:     Jan Brekke
Organization:   DigitalBrekke
Filename:       FailedLogons.ps1
===============
.DESCRIPTION
    Scrape, list, and dump all failed logon attempts.
    Useful when you have RDP port open to WAN.
#>
 
# This defines the start date as three months ago from today
$StartDate = (Get-Date).AddMonths(-3)
$EndDate = Get-Date
 
# This defines the event ID 4625 and where to find the log
$Events = Get-WinEvent -FilterHashtable @{
    LogName = 'Security'
    Id = 4625
    StartTime = $StartDate
    EndTime = $EndDate
} | ForEach-Object {
 
    # This goes through each event to find "Source Network Address"
    $SourceNetworkAddress = ($_.Properties | Where-Object { $_.Value -match '(\d{1,3}\.){3}\d{1,3}' }).Value
 
    # This sort out only valid addresses and drops localhost
    if ($SourceNetworkAddress -and $SourceNetworkAddress -ne '::1' -and $SourceNetworkAddress -ne '127.0.0.1') {
        [PSCustomObject]@{
            IPAddress     = $SourceNetworkAddress
            TimeGenerated = $_.TimeCreated
        }
    }
}
 
# This group by IP and count how many attempts, and sort by the count in a descending order
$GroupedEvents = $Events | Group-Object -Property IPAddress | Sort-Object Count -Descending
 
# This specify and prepare the output with IP addresses, the count of attempts, and the first seen timestamp
$Output = $GroupedEvents | ForEach-Object {
    [PSCustomObject]@{
        IPAddress = $_.Name
        Count     = $_.Count
        FirstSeen = ($_.Group | Sort-Object TimeGenerated | Select-Object -First 1).TimeGenerated
    }
}
 
# This creates the table format
$Output | Format-Table -AutoSize
 
# This displays the total count of unique IP addresses
$totalUniqueIPs = $Output.Count
$totalAttempts = ($GroupedEvents | Measure-Object -Property Count -Sum).Sum
 
Write-Host "Total Unique IP Addresses:" $totalUniqueIPs
Write-Host "Total Failed Logon Attempts:" $totalAttempts
 
# This simply ask the user if they would like to export it to a CSV file
$Export = Read-Host "Would you like to export the results to a CSV file? (Y/N)"
if ($Export -eq 'Y' -or $Export -eq 'y') {
    $FilePath = "$env:USERPROFILE\Desktop\FailedLogonAttempts.csv"
    $Output | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
    Write-Host "Results exported to $FilePath"
}