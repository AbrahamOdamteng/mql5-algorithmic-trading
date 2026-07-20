param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ExperimentDir = '',
  [string]$OptimizerXml = '',
  [string]$ForwardXml = '',
  [string]$DiscoverySymbol = 'EURUSD',
  [string]$TemplateSetFile = 'ThreeDayTrendSignal_EURUSD_Genetic_20260718.set',
  [string]$TempSetFile = 'ThreeDayTrendSignal_WalkForward_Current.set',
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'tdts_walk_forward_current.ini'),
  [switch]$RunOptimizer,
  [switch]$OptimizerOnlyCandidates,
  [int]$OptimizationTimeoutMinutes = 1440,
  [string[]]$Symbols = @('GBPUSD', 'USDJPY', 'EURJPY', 'XAUUSD', 'XAGUSD', 'US500', 'US30', 'UK100', 'USOIL', 'UKOIL'),
  [int]$TopN = 8,
  [double]$CandidateMinRatio = 2.0,
  [double]$CandidateMaxDrawdownPct = 30.0,
  [int]$CandidateMinInSampleTrades = 200,
  [int]$CandidateMinForwardTrades = 100,
  [double]$CrossSymbolMinRatio = 2.0,
  [double]$CrossSymbolMaxDrawdownPct = 30.0,
  [int]$CrossSymbolMinTrades = 0,
  [double]$StartingDeposit = 100000.0,
  [string]$InSampleStart = '2000.01.01',
  [string]$InSampleEnd = '2012.01.01',
  [string]$ValidationStart = '2012.01.01',
  [string]$ValidationEnd = '2018.01.01',
  [string]$OutOfSampleStart = '2018.01.01',
  [string]$OutOfSampleEnd = '2026.05.31',
  [int]$MaxRuntimeMinutes = 10,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function Get-SafeId {
  param([string]$Text)

  return ($Text -replace '[^A-Za-z0-9_\-]', '_')
}

function Convert-ReportPathToFullPath {
  param([string]$ReportRoot, [string]$ExpectedReport)

  return Join-Path $ReportRoot ($ExpectedReport -replace '/', '\')
}

function Read-Mt5Spreadsheet {
  param([Parameter(Mandatory = $true)][string]$Path)

  [xml]$xml = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
  $nsm = [System.Xml.XmlNamespaceManager]::new($xml.NameTable)
  $nsm.AddNamespace('ss', 'urn:schemas-microsoft-com:office:spreadsheet')

  $rows = $xml.SelectNodes('//ss:Worksheet/ss:Table/ss:Row', $nsm)
  if ($rows.Count -lt 2) {
    return @()
  }

  $headers = @()
  foreach ($cell in $rows[0].SelectNodes('ss:Cell', $nsm)) {
    $data = $cell.SelectSingleNode('ss:Data', $nsm)
    if ($null -ne $data) {
      $headers += $data.InnerText
    }
  }

  $result = [System.Collections.Generic.List[object]]::new()
  for ($i = 1; $i -lt $rows.Count; $i++) {
    $cells = $rows[$i].SelectNodes('ss:Cell', $nsm)
    $obj = [ordered]@{}
    $columnIndex = 0

    foreach ($cell in $cells) {
      $indexAttr = $cell.GetAttribute('Index', 'urn:schemas-microsoft-com:office:spreadsheet')
      if ($indexAttr) {
        $columnIndex = [int]$indexAttr - 1
      }

      if ($columnIndex -lt $headers.Count) {
        $data = $cell.SelectSingleNode('ss:Data', $nsm)
        $text = ''
        if ($null -ne $data) {
          $text = $data.InnerText
        }

        $num = 0.0
        if ([double]::TryParse($text, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$num)) {
          $obj[$headers[$columnIndex]] = $num
        } else {
          $obj[$headers[$columnIndex]] = $text
        }
      }

      $columnIndex++
    }

    $result.Add([pscustomobject]$obj)
  }

  return $result
}

function Get-PropValue {
  param([object]$Object, [string[]]$Names, $Default = $null)

  foreach ($name in $Names) {
    $prop = $Object.PSObject.Properties[$name]
    if ($null -ne $prop -and $null -ne $prop.Value -and $prop.Value -ne '') {
      return $prop.Value
    }
  }

  return $Default
}

function Convert-Mt5Number {
  param([AllowNull()]$Text)

  if ($null -eq $Text -or [string]::IsNullOrWhiteSpace("$Text")) {
    return $null
  }

  if ($Text -is [double] -or $Text -is [int]) {
    return [double]$Text
  }

  $match = [regex]::Match("$Text", '-?[0-9][0-9\s]*([.,][0-9]+)?')
  if (-not $match.Success) {
    return $null
  }

  $number = $match.Value -replace '\s', ''
  $number = $number -replace ',', '.'
  return [double]::Parse($number, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Decode-Report {
  param([Parameter(Mandatory = $true)][string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
    return [System.Text.Encoding]::Unicode.GetString($bytes)
  }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) {
    return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes)
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    return [System.Text.Encoding]::UTF8.GetString($bytes)
  }

  return [System.Text.Encoding]::Default.GetString($bytes)
}

function Clean-HtmlText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) {
    return $null
  }

  $value = [System.Net.WebUtility]::HtmlDecode($Text)
  $value = $value -replace '<[^>]+>', ' '
  $value = $value -replace '\s+', ' '
  return $value.Trim()
}

function Get-ReportMetric {
  param([string]$Html, [string]$Label)

  $pattern = [regex]::Escape($Label) + ':</td>\s*<td[^>]*>\s*<b>(.*?)</b>'
  $match = [regex]::Match($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($match.Success) {
    return Clean-HtmlText $match.Groups[1].Value
  }

  return $null
}

function Read-Mt5ReportMetrics {
  param([string]$Path, [double]$Deposit)

  $html = Decode-Report -Path $Path
  $profit = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Net Profit')
  $equityDdMaxText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Maximal'
  $equityDdRelText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Relative'
  $ddPct = $null

  if ($equityDdMaxText -match '\(([-0-9.,\s]+)%\)') {
    $ddPct = Convert-Mt5Number $Matches[1]
  } elseif ($equityDdRelText -match '([-0-9.,\s]+)%') {
    $ddPct = Convert-Mt5Number $Matches[1]
  }

  $ratio = $null
  if ($null -ne $ddPct -and $ddPct -ne 0 -and $null -ne $profit) {
    $ratio = [Math]::Round(($profit / ($Deposit / 100.0)) / $ddPct, 3)
  }

  return [pscustomobject]@{
    Profit = if ($null -ne $profit) { [Math]::Round($profit, 2) } else { $null }
    EquityDDPct = if ($null -ne $ddPct) { [Math]::Round($ddPct, 2) } else { $null }
    Ratio = $ratio
    Trades = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Trades'))
    ProfitFactor = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Profit Factor')
  }
}

function Get-SetFileEncoding {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) {
    return [System.Text.Encoding]::Unicode
  }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
    return [System.Text.Encoding]::UTF8
  }

  return [System.Text.Encoding]::ASCII
}

function Set-InputLine {
  param([System.Collections.Generic.List[string]]$Lines, [string]$Name, [string]$Value)

  $line = "$Name=$Value||$Value||0||$Value||N"
  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -like "$Name=*") {
      $Lines[$i] = $line
      return
    }
  }

  $Lines.Add($line)
}

function New-TestSetFile {
  param([object]$Test, [string]$TemplateSetPath, [string]$TempSetPath)

  $encoding = Get-SetFileEncoding -Path $TemplateSetPath
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($TemplateSetPath, $encoding)) {
    $lines.Add($line)
  }

  Set-InputLine -Lines $lines -Name 'g_ATR_Period' -Value $Test.ATR
  Set-InputLine -Lines $lines -Name 'g_ATR_Multiplier' -Value $Test.ATRMult
  Set-InputLine -Lines $lines -Name 'g_ContiguousCandles' -Value $Test.ContiguousCandles
  Set-InputLine -Lines $lines -Name 'g_StopLossATRMultiple' -Value $Test.StopLossATRMultiple
  Set-InputLine -Lines $lines -Name 'g_TakeProfitSLMultiple' -Value $Test.TakeProfitSLMultiple
  Set-InputLine -Lines $lines -Name 'g_EnableTrading' -Value 'true'
  Set-InputLine -Lines $lines -Name 'g_StartingBalance' -Value ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $StartingDeposit))

  [System.IO.File]::WriteAllLines($TempSetPath, $lines, $encoding)
  return $TempSetFile
}

function New-PairedCandidates {
  param([object[]]$OptimizerRows, [object[]]$ForwardRows)

  $forwardByPass = @{}
  foreach ($row in $ForwardRows) {
    $forwardByPass[[int](Get-PropValue -Object $row -Names @('Pass') -Default 0)] = $row
  }

  foreach ($is in $OptimizerRows) {
    $pass = [int](Get-PropValue -Object $is -Names @('Pass') -Default 0)
    if (-not $forwardByPass.ContainsKey($pass)) {
      continue
    }

    $fw = $forwardByPass[$pass]
    $isProfit = [double](Get-PropValue -Object $is -Names @('Profit') -Default 0.0)
    $fwProfit = [double](Get-PropValue -Object $fw -Names @('Profit') -Default 0.0)
    $isDD = [double](Get-PropValue -Object $is -Names @('Equity DD %') -Default 0.0)
    $fwDD = [double](Get-PropValue -Object $fw -Names @('Equity DD %') -Default 0.0)
    $isRatio = if ($isDD -gt 0) { $isProfit / ($StartingDeposit * $isDD / 100.0) } else { 0.0 }
    $fwRatio = if ($fwDD -gt 0) { $fwProfit / ($StartingDeposit * $fwDD / 100.0) } else { 0.0 }

    [pscustomobject]@{
      Pass = $pass
      ManifoldId = "TDTS_Pass$pass"
      MinRatio = [Math]::Round([Math]::Min($isRatio, $fwRatio), 3)
      ISProfit = [Math]::Round($isProfit, 2)
      ISDD = [Math]::Round($isDD, 2)
      ISRatio = [Math]::Round($isRatio, 3)
      ISTrades = [int](Get-PropValue -Object $is -Names @('Trades') -Default 0)
      FwdProfit = [Math]::Round($fwProfit, 2)
      FwdDD = [Math]::Round($fwDD, 2)
      FwdRatio = [Math]::Round($fwRatio, 3)
      FwdTrades = [int](Get-PropValue -Object $fw -Names @('Trades') -Default 0)
      ATR = [int](Get-PropValue -Object $is -Names @('g_ATR_Period') -Default 0)
      ATRMult = [double](Get-PropValue -Object $is -Names @('g_ATR_Multiplier') -Default 0.0)
      ContiguousCandles = [int](Get-PropValue -Object $is -Names @('g_ContiguousCandles') -Default 0)
      StopLossATRMultiple = [double](Get-PropValue -Object $is -Names @('g_StopLossATRMultiple') -Default 0.0)
      TakeProfitSLMultiple = [double](Get-PropValue -Object $is -Names @('g_TakeProfitSLMultiple') -Default 0.0)
    }
  }
}

function New-OptimizerOnlyCandidates {
  param([object[]]$OptimizerRows)

  foreach ($is in $OptimizerRows) {
    $pass = [int](Get-PropValue -Object $is -Names @('Pass') -Default 0)
    $isProfit = [double](Get-PropValue -Object $is -Names @('Profit') -Default 0.0)
    $isDD = [double](Get-PropValue -Object $is -Names @('Equity DD %') -Default 0.0)
    $isRatio = if ($isDD -gt 0) { $isProfit / ($StartingDeposit * $isDD / 100.0) } else { 0.0 }

    [pscustomobject]@{
      Pass = $pass
      ManifoldId = "TDTS_Pass$pass"
      MinRatio = [Math]::Round($isRatio, 3)
      ISProfit = [Math]::Round($isProfit, 2)
      ISDD = [Math]::Round($isDD, 2)
      ISRatio = [Math]::Round($isRatio, 3)
      ISTrades = [int](Get-PropValue -Object $is -Names @('Trades') -Default 0)
      FwdProfit = $null
      FwdDD = $null
      FwdRatio = $null
      FwdTrades = $null
      ATR = [int](Get-PropValue -Object $is -Names @('g_ATR_Period') -Default 0)
      ATRMult = [double](Get-PropValue -Object $is -Names @('g_ATR_Multiplier') -Default 0.0)
      ContiguousCandles = [int](Get-PropValue -Object $is -Names @('g_ContiguousCandles') -Default 0)
      StopLossATRMultiple = [double](Get-PropValue -Object $is -Names @('g_StopLossATRMultiple') -Default 0.0)
      TakeProfitSLMultiple = [double](Get-PropValue -Object $is -Names @('g_TakeProfitSLMultiple') -Default 0.0)
    }
  }
}

function Invoke-OptimizerRun {
  param([string]$ConfigPath, [string]$Report, [string]$TemplateSetFileName)

  $configContent = @(
    '[Tester]',
    'Expert=ThreeDayTrendSignal\ThreeDayTrendSignalEA.ex5',
    "Symbol=$DiscoverySymbol",
    'Period=H1',
    '',
    "FromDate=$InSampleStart",
    "ToDate=$InSampleEnd",
    '',
    'Model=4',
    'Optimization=2',
    'Visual=0',
    '',
    "ExpertParameters=$TemplateSetFileName",
    "Report=$Report",
    '',
    '; ForwardMode intentionally omitted for rolling discovery.',
    'OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $configContent | Set-Content -LiteralPath $ConfigPath -Encoding ASCII

  Write-Host "Running optimizer: $DiscoverySymbol $InSampleStart -> $InSampleEnd"
  $startTime = Get-Date
  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$ConfigPath`"" -PassThru
  while (-not $process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    $process.Refresh()
    if (((Get-Date) - $startTime).TotalMinutes -ge $OptimizationTimeoutMinutes) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw "Optimizer timed out after $OptimizationTimeoutMinutes minutes."
    }
  }
}

function New-IsValManifest {
  param([object[]]$Candidates, [string[]]$TestSymbols, [string]$ReportSubdir)

  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  $segments = @(
    [pscustomobject]@{ Name = 'IS'; From = $InSampleStart; To = $InSampleEnd },
    [pscustomobject]@{ Name = 'VAL'; From = $ValidationStart; To = $ValidationEnd }
  )

  foreach ($candidate in $Candidates) {
    foreach ($symbol in $TestSymbols) {
      foreach ($segment in $segments) {
        $safeSymbol = Get-SafeId $symbol
        $dateLabel = ($segment.From -replace '\.', '') + '_' + ($segment.To -replace '\.', '')
        $report = "$ReportSubdir\is_val\$safeSymbol`_$($candidate.ManifoldId)_$($segment.Name)_$dateLabel.xml"
        $rows.Add([pscustomobject]@{
          TestIndex = $index
          TestId = ('{0:D5}_{1}_{2}_{3}' -f $index, $candidate.ManifoldId, $safeSymbol, $segment.Name)
          Stage = 'ISVAL'
          ManifoldId = $candidate.ManifoldId
          Pass = $candidate.Pass
          Symbol = $symbol
          Segment = $segment.Name
          FromDate = $segment.From
          ToDate = $segment.To
          Report = $report
          ExpectedReport = "$report.htm"
          ATR = $candidate.ATR
          ATRMult = $candidate.ATRMult
          ContiguousCandles = $candidate.ContiguousCandles
          StopLossATRMultiple = $candidate.StopLossATRMultiple
          TakeProfitSLMultiple = $candidate.TakeProfitSLMultiple
        })
        $index++
      }
    }
  }

  return $rows
}

function Append-Progress {
  param([object]$Test, [string]$Status, [double]$DurationSeconds, [string]$ReportPath, [string]$Note, [string]$ProgressPath)

  $row = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('s')
    TestIndex = $Test.TestIndex
    TestId = $Test.TestId
    Stage = $Test.Stage
    ManifoldId = $Test.ManifoldId
    Pass = $Test.Pass
    Symbol = $Test.Symbol
    Segment = $Test.Segment
    FromDate = $Test.FromDate
    ToDate = $Test.ToDate
    Status = $Status
    DurationSeconds = [Math]::Round($DurationSeconds, 2)
    ReportPath = $ReportPath
    Note = $Note
  }

  if (Test-Path -LiteralPath $ProgressPath) {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Append -Encoding ASCII
  } else {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Encoding ASCII
  }
}

function Invoke-TestManifest {
  param([object[]]$Manifest, [string]$ProgressPath, [string]$ReportRoot, [string]$TemplateSetPath, [string]$TempSetPath)

  $completedStatuses = @('Completed', 'SkippedExistingReport')
  $completedByProgress = @{}
  if (Test-Path -LiteralPath $ProgressPath) {
    Import-Csv -LiteralPath $ProgressPath | ForEach-Object {
      if ($completedStatuses -contains $_.Status) {
        $completedByProgress[$_.TestId] = $true
      }
    }
  }

  $testsRunThisSession = 0
  foreach ($test in ($Manifest | Sort-Object { [int]$_.TestIndex })) {
    $testIndex = [int]$test.TestIndex
    if ($testIndex -lt $StartAtIndex) {
      continue
    }
    if ($MaxTests -gt 0 -and $testsRunThisSession -ge $MaxTests) {
      break
    }

    $expectedReportPath = Convert-ReportPathToFullPath -ReportRoot $ReportRoot -ExpectedReport $test.ExpectedReport
    if (-not $RunExistingReports -and ($completedByProgress.ContainsKey($test.TestId) -or (Test-Path -LiteralPath $expectedReportPath))) {
      if (-not $completedByProgress.ContainsKey($test.TestId)) {
        Append-Progress -Test $test -Status 'SkippedExistingReport' -DurationSeconds 0 -ReportPath $expectedReportPath -Note 'Report already existed before run.' -ProgressPath $ProgressPath
      }
      continue
    }

    Write-Host ''
    Write-Host '====================================='
    Write-Host "Running $($test.TestIndex): $($test.TestId)"
    Write-Host "$($test.Symbol) $($test.Segment) $($test.FromDate) -> $($test.ToDate)"
    Write-Host '====================================='

    if ($ClearTesterCache) {
      Write-Host 'Clearing tester cache'
      Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 5
    }

    $expertParameters = New-TestSetFile -Test $test -TemplateSetPath $TemplateSetPath -TempSetPath $TempSetPath
    $configContent = @(
      '[Tester]',
      'Expert=ThreeDayTrendSignal\ThreeDayTrendSignalEA.ex5',
      "Symbol=$($test.Symbol)",
      'Period=H1',
      '',
      "FromDate=$($test.FromDate)",
      "ToDate=$($test.ToDate)",
      '',
      'Model=4',
      'Optimization=0',
      'Visual=0',
      '',
      "ExpertParameters=$expertParameters",
      "Report=$($test.Report)",
      '',
      '; ForwardMode=2',
      '; OptimizationCriterion=7',
      '',
      'ShutdownTerminal=1'
    )

    $configContent | Set-Content -LiteralPath $TempConfigPath -Encoding ASCII
    $startTime = Get-Date
    $status = 'FailedNoReport'
    $note = ''
    $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$TempConfigPath`"" -PassThru

    while (-not $process.HasExited) {
      Start-Sleep -Seconds $PollSeconds
      $process.Refresh()
      if (((Get-Date) - $startTime).TotalMinutes -ge $MaxRuntimeMinutes) {
        $status = 'TimedOut'
        $note = "Timeout after $MaxRuntimeMinutes minutes."
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        break
      }
    }

    Start-Sleep -Seconds 2
    $duration = ((Get-Date) - $startTime).TotalSeconds
    if (Test-Path -LiteralPath $expectedReportPath) {
      $status = 'Completed'
      if (-not $note) {
        $note = 'Report file found.'
      }
    } elseif (-not $note) {
      $note = 'MT5 exited but expected report was not found.'
    }

    Append-Progress -Test $test -Status $status -DurationSeconds $duration -ReportPath $expectedReportPath -Note $note -ProgressPath $ProgressPath
    $testsRunThisSession++
    Write-Host "Finished $($test.TestId): $status"
  }

  return $testsRunThisSession
}

function Read-ManifestReportRows {
  param([object[]]$Manifest, [string]$ReportRoot)

  foreach ($test in $Manifest) {
    $path = Convert-ReportPathToFullPath -ReportRoot $ReportRoot -ExpectedReport $test.ExpectedReport
    if (-not (Test-Path -LiteralPath $path)) {
      continue
    }

    $metrics = Read-Mt5ReportMetrics -Path $path -Deposit $StartingDeposit
    [pscustomobject]@{
      TestIndex = $test.TestIndex
      TestId = $test.TestId
      Stage = $test.Stage
      ManifoldId = $test.ManifoldId
      Pass = $test.Pass
      Symbol = $test.Symbol
      Segment = $test.Segment
      FromDate = $test.FromDate
      ToDate = $test.ToDate
      Profit = $metrics.Profit
      EquityDDPct = $metrics.EquityDDPct
      Ratio = $metrics.Ratio
      Trades = $metrics.Trades
      ProfitFactor = $metrics.ProfitFactor
      Accepted = ($metrics.Profit -gt 0 -and $metrics.Ratio -ge $CrossSymbolMinRatio -and $metrics.EquityDDPct -le $CrossSymbolMaxDrawdownPct -and $metrics.Trades -ge $CrossSymbolMinTrades)
      ReportPath = $path
      ATR = $test.ATR
      ATRMult = $test.ATRMult
      ContiguousCandles = $test.ContiguousCandles
      StopLossATRMultiple = $test.StopLossATRMultiple
      TakeProfitSLMultiple = $test.TakeProfitSLMultiple
    }
  }
}

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'

if (-not $ExperimentDir) {
  $ExperimentDir = Join-Path $terminalDataRoot 'reports\three_day_trend_signal_walk_forward_20260719'
}
if (-not $OptimizerXml) {
  if ($RunOptimizer -or $OptimizerOnlyCandidates) {
    $dateLabel = ($InSampleStart -replace '\.', '') + '_' + ($InSampleEnd -replace '\.', '')
    $OptimizerXml = Join-Path $terminalDataRoot ("reports\" + (Split-Path -Leaf $ExperimentDir) + "\optimizer\TDTS_$DiscoverySymbol`_H1_Genetic_$dateLabel.xml")
  } else {
    $OptimizerXml = Join-Path $terminalDataRoot 'reports\three_day_trend_signal_eurusd_genetic_20260718_risk_sizing\TDTS_EURUSD_H1_Genetic_2000_2018_FWD_20260718_RiskSizing.xml'
  }
}
if (-not $ForwardXml) {
  if (-not $OptimizerOnlyCandidates) {
    $ForwardXml = Join-Path $terminalDataRoot 'reports\three_day_trend_signal_eurusd_genetic_20260718_risk_sizing\TDTS_EURUSD_H1_Genetic_2000_2018_FWD_20260718_RiskSizing.forward.xml'
  }
}

$templateSetPath = Join-Path $testerProfilesDir $TemplateSetFile
$tempSetPath = Join-Path $testerProfilesDir $TempSetFile
$candidateCsv = Join-Path $ExperimentDir 'tdts_eurusd_candidates.csv'
$selectedCandidateCsv = Join-Path $ExperimentDir 'tdts_eurusd_selected_candidates.csv'
$isValManifestPath = Join-Path $ExperimentDir 'tdts_cross_symbol_is_val_manifest.csv'
$isValProgressPath = Join-Path $ExperimentDir 'tdts_cross_symbol_is_val_progress.csv'
$isValResultsPath = Join-Path $ExperimentDir 'tdts_cross_symbol_is_val_results.csv'
$oosManifestPath = Join-Path $ExperimentDir 'tdts_cross_symbol_oos_manifest.csv'
$oosProgressPath = Join-Path $ExperimentDir 'tdts_cross_symbol_oos_progress.csv'
$oosResultsPath = Join-Path $ExperimentDir 'tdts_cross_symbol_oos_results.csv'
$reportSubdir = 'reports\' + (Split-Path -Leaf $ExperimentDir)

if (-not (Test-Path -LiteralPath $ExperimentDir)) {
  New-Item -ItemType Directory -Path $ExperimentDir -Force | Out-Null
}
if (-not (Test-Path -LiteralPath (Join-Path $terminalDataRoot "$reportSubdir\optimizer"))) {
  New-Item -ItemType Directory -Path (Join-Path $terminalDataRoot "$reportSubdir\optimizer") -Force | Out-Null
}
if (-not (Test-Path -LiteralPath (Join-Path $terminalDataRoot "$reportSubdir\is_val"))) {
  New-Item -ItemType Directory -Path (Join-Path $terminalDataRoot "$reportSubdir\is_val") -Force | Out-Null
}
if (-not (Test-Path -LiteralPath (Join-Path $terminalDataRoot "$reportSubdir\oos"))) {
  New-Item -ItemType Directory -Path (Join-Path $terminalDataRoot "$reportSubdir\oos") -Force | Out-Null
}

if (-not (Test-Path -LiteralPath $templateSetPath)) { throw "Template set file not found: $templateSetPath" }
if (-not (Test-Path -LiteralPath $TerminalPath) -and -not $PrepareOnly) { throw "MT5 terminal not found: $TerminalPath" }

if ($RunOptimizer -and -not $PrepareOnly) {
  $optimizerReportRelative = ($OptimizerXml.Substring($terminalDataRoot.Length).TrimStart('\') -replace '\.xml$', '.xml')
  Invoke-OptimizerRun -ConfigPath (Join-Path $PSScriptRoot 'tdts_rolling_optimizer_current.ini') -Report $optimizerReportRelative -TemplateSetFileName $TemplateSetFile
}

if (-not (Test-Path -LiteralPath $OptimizerXml)) { throw "Optimizer XML not found: $OptimizerXml" }
if (-not $OptimizerOnlyCandidates -and -not (Test-Path -LiteralPath $ForwardXml)) { throw "Forward XML not found: $ForwardXml" }

$Symbols = @(Expand-FilterValues $Symbols)
$optimizerRows = @(Read-Mt5Spreadsheet -Path $OptimizerXml)
if ($OptimizerOnlyCandidates) {
  $allCandidates = @(New-OptimizerOnlyCandidates -OptimizerRows $optimizerRows)
} else {
  $forwardRows = @(Read-Mt5Spreadsheet -Path $ForwardXml)
  $allCandidates = @(New-PairedCandidates -OptimizerRows $optimizerRows -ForwardRows $forwardRows)
}
$allCandidates | Sort-Object MinRatio -Descending | Export-Csv -LiteralPath $candidateCsv -NoTypeInformation -Encoding ASCII

if ($OptimizerOnlyCandidates) {
  $selectedCandidates = @($allCandidates |
    Where-Object { $_.ISProfit -gt 0 -and $_.ISRatio -ge $CandidateMinRatio -and $_.ISDD -le $CandidateMaxDrawdownPct -and $_.ISTrades -ge $CandidateMinInSampleTrades } |
    Sort-Object MinRatio -Descending |
    Select-Object -First $TopN)
} else {
  $selectedCandidates = @($allCandidates |
    Where-Object { $_.ISProfit -gt 0 -and $_.FwdProfit -gt 0 -and $_.ISRatio -ge $CandidateMinRatio -and $_.FwdRatio -ge $CandidateMinRatio -and $_.ISDD -le $CandidateMaxDrawdownPct -and $_.FwdDD -le $CandidateMaxDrawdownPct -and $_.ISTrades -ge $CandidateMinInSampleTrades -and $_.FwdTrades -ge $CandidateMinForwardTrades } |
    Sort-Object MinRatio -Descending |
    Select-Object -First $TopN)
}

if ($selectedCandidates.Count -eq 0) {
  throw 'No EURUSD optimizer candidates passed the source-candidate filters.'
}

$selectedCandidates | Export-Csv -LiteralPath $selectedCandidateCsv -NoTypeInformation -Encoding ASCII
$isValManifest = @(New-IsValManifest -Candidates $selectedCandidates -TestSymbols $Symbols -ReportSubdir $reportSubdir)
$isValManifest | Export-Csv -LiteralPath $isValManifestPath -NoTypeInformation -Encoding ASCII

Write-Host "Experiment directory: $ExperimentDir"
Write-Host "Optimizer XML: $OptimizerXml"
Write-Host "Forward XML: $ForwardXml"
Write-Host "Selected candidates: $($selectedCandidates.Count)"
Write-Host "Symbols: $($Symbols.Count) ($($Symbols -join ', '))"
Write-Host "IS/VAL manifest tests: $($isValManifest.Count)"

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. No MT5 tests were run.'
  return
}

$isValRunCount = Invoke-TestManifest -Manifest $isValManifest -ProgressPath $isValProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath
$isValMissing = @($isValManifest | Where-Object { -not (Test-Path -LiteralPath (Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $_.ExpectedReport)) })
if ($isValMissing.Count -gt 0) {
  Write-Host "IS/VAL stage incomplete. Missing reports: $($isValMissing.Count). Rerun the same command to resume."
  return
}

$isValRows = @(Read-ManifestReportRows -Manifest $isValManifest -ReportRoot $reportRoot)
$isValRows | Export-Csv -LiteralPath $isValResultsPath -NoTypeInformation -Encoding ASCII

$survivorKeys = @{}
foreach ($group in ($isValRows | Group-Object ManifoldId, Symbol)) {
  $rows = @($group.Group)
  $hasIs = @($rows | Where-Object { $_.Segment -eq 'IS' -and $_.Accepted }).Count -gt 0
  $hasVal = @($rows | Where-Object { $_.Segment -eq 'VAL' -and $_.Accepted }).Count -gt 0
  if ($hasIs -and $hasVal) {
    $survivorKeys[$group.Name] = $rows[0]
  }
}

$oosManifest = [System.Collections.Generic.List[object]]::new()
$index = 1
foreach ($key in ($survivorKeys.Keys | Sort-Object)) {
  $row = $survivorKeys[$key]
  $safeSymbol = Get-SafeId $row.Symbol
  $dateLabel = ($OutOfSampleStart -replace '\.', '') + '_' + ($OutOfSampleEnd -replace '\.', '')
  $report = "$reportSubdir\oos\$safeSymbol`_$($row.ManifoldId)_OOS_$dateLabel.xml"
  $oosManifest.Add([pscustomobject]@{
    TestIndex = $index
    TestId = ('{0:D5}_{1}_{2}_OOS' -f $index, $row.ManifoldId, $safeSymbol)
    Stage = 'OOS'
    ManifoldId = $row.ManifoldId
    Pass = $row.Pass
    Symbol = $row.Symbol
    Segment = 'OOS'
    FromDate = $OutOfSampleStart
    ToDate = $OutOfSampleEnd
    Report = $report
    ExpectedReport = "$report.htm"
    ATR = $row.ATR
    ATRMult = $row.ATRMult
    ContiguousCandles = $row.ContiguousCandles
    StopLossATRMultiple = $row.StopLossATRMultiple
    TakeProfitSLMultiple = $row.TakeProfitSLMultiple
  })
  $index++
}

$oosManifest | Export-Csv -LiteralPath $oosManifestPath -NoTypeInformation -Encoding ASCII
Write-Host "IS/VAL survivors promoted to OOS: $($oosManifest.Count)"

if ($oosManifest.Count -eq 0) {
  Write-Host 'No candidate-symbol pairs passed both IS and VAL. OOS stage skipped.'
  return
}

$oosRunCount = Invoke-TestManifest -Manifest $oosManifest -ProgressPath $oosProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath
$oosRows = @(Read-ManifestReportRows -Manifest $oosManifest -ReportRoot $reportRoot)
$oosRows | Export-Csv -LiteralPath $oosResultsPath -NoTypeInformation -Encoding ASCII

Write-Host "Walk-forward session complete. IS/VAL tests run this session: $isValRunCount. OOS tests run this session: $oosRunCount."
Write-Host "IS/VAL results: $isValResultsPath"
Write-Host "OOS results: $oosResultsPath"
