param(
  [Parameter(Mandatory = $true)]
  [string]$ReportsDir,

  [string]$Pattern = '*.xml.htm'
)

$reports = Get-ChildItem -LiteralPath $ReportsDir -Filter $Pattern -File | Sort-Object Name

foreach ($report in $reports) {
  $content = Get-Content -LiteralPath $report.FullName -Raw

  $symbol = $null
  if ($report.Name -match '^([A-Z0-9]+)_') {
    $symbol = $Matches[1]
  }

  $requestedRange = $null
  if ($content -match 'H1 \((\d{4}\.\d{2}\.\d{2}) - (\d{4}\.\d{2}\.\d{2})\)') {
    $requestedRange = "$($Matches[1]) -> $($Matches[2])"
  }

  $firstEvent = $null
  $eventCount = 0
  $rowPattern = '<tr[^>]*><td>(\d{4}\.\d{2}\.\d{2} \d{2}:\d{2}:\d{2})</td><td>[^<]*</td><td>'
  if ($symbol) {
    $rowPattern += [regex]::Escape($symbol)
  } else {
    $rowPattern += '[^<]+'
  }
  $rowPattern += '</td><td>([^<]+)</td>'

  $matches = [regex]::Matches($content, $rowPattern)
  foreach ($match in $matches) {
    $eventType = $match.Groups[2].Value
    if ($eventType -in @('buy stop', 'sell stop', 'buy', 'sell')) {
      $eventCount++
      if (-not $firstEvent) {
        $firstEvent = $match.Groups[1].Value
      }
    }
  }

  [pscustomobject]@{
    Symbol = $symbol
    RequestedRange = $requestedRange
    FirstTradeOrOrderTime = $firstEvent
    EventCount = $eventCount
    File = $report.Name
  }
}
