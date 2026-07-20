param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ExperimentId = 'tdts_eg_eurusd_is5y_val6m_oos12m_step1m',
  [string]$Symbol = 'EURUSD',
  [string]$Period = 'H1',
  [string]$TemplateSetFile = 'ThreeDayTrendSignal_EURUSD_Genetic_20260718.set',
  [string]$TempSetFile = 'ThreeDayTrendSignal_WalkForward_Current.set',
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'tdts_ephemeral_generator_current.ini'),
  [datetime]$FirstOosStart = '2005-07-01',
  [datetime]$LastOosStart = '2025-05-01',
  [int]$ISYears = 5,
  [int]$ValidationMonths = 6,
  [int]$OosMonths = 12,
  [int]$PrimaryOosMonths = 3,
  [int]$StepMonths = 1,
  [int]$TopOptimizerCandidates = 25,
  [double]$StartingDeposit = 100000.0,
  [int]$OptimizationTimeoutMinutes = 1440,
  [int]$MaxRuntimeMinutes = 20,
  [int]$PollSeconds = 30,
  [int]$StartAtWindow = 1,
  [int]$MaxWindows = 0,
  [int]$MaxFixedTests = 0,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'

function Get-DateLabel {
  param([datetime]$Date)
  return $Date.ToString('yyyyMMdd', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-Mt5Date {
  param([datetime]$Date)
  return $Date.ToString('yyyy.MM.dd', [System.Globalization.CultureInfo]::InvariantCulture)
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
  if ($rows.Count -lt 2) { return @() }

  $headers = @()
  foreach ($cell in $rows[0].SelectNodes('ss:Cell', $nsm)) {
    $data = $cell.SelectSingleNode('ss:Data', $nsm)
    if ($null -ne $data) { $headers += $data.InnerText }
  }

  $result = [System.Collections.Generic.List[object]]::new()
  for ($i = 1; $i -lt $rows.Count; $i++) {
    $cells = $rows[$i].SelectNodes('ss:Cell', $nsm)
    $obj = [ordered]@{}
    $columnIndex = 0

    foreach ($cell in $cells) {
      $indexAttr = $cell.GetAttribute('Index', 'urn:schemas-microsoft-com:office:spreadsheet')
      if ($indexAttr) { $columnIndex = [int]$indexAttr - 1 }

      if ($columnIndex -lt $headers.Count) {
        $data = $cell.SelectSingleNode('ss:Data', $nsm)
        $text = ''
        if ($null -ne $data) { $text = $data.InnerText }

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

  if ($null -eq $Text -or [string]::IsNullOrWhiteSpace("$Text")) { return $null }
  if ($Text -is [double] -or $Text -is [int]) { return [double]$Text }

  if ("$Text" -match 'inf|infinity|∞') { return [double]::PositiveInfinity }

  $match = [regex]::Match("$Text", '-?[0-9][0-9\s]*([.,][0-9]+)?')
  if (-not $match.Success) { return $null }

  $number = $match.Value -replace '\s', ''
  $number = $number -replace ',', '.'
  return [double]::Parse($number, [System.Globalization.CultureInfo]::InvariantCulture)
}

function Decode-Report {
  param([Parameter(Mandatory = $true)][string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Path))
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { return [System.Text.Encoding]::Unicode.GetString($bytes) }
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 254 -and $bytes[1] -eq 255) { return [System.Text.Encoding]::BigEndianUnicode.GetString($bytes) }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { return [System.Text.Encoding]::UTF8.GetString($bytes) }
  return [System.Text.Encoding]::Default.GetString($bytes)
}

function Clean-HtmlText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) { return $null }
  $value = [System.Net.WebUtility]::HtmlDecode($Text)
  $value = $value -replace '<[^>]+>', ' '
  $value = $value -replace '\s+', ' '
  return $value.Trim()
}

function Get-ReportMetric {
  param([string]$Html, [string]$Label)

  $pattern = [regex]::Escape($Label) + ':</td>\s*<td[^>]*>\s*<b>(.*?)</b>'
  $match = [regex]::Match($Html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
  if ($match.Success) { return Clean-HtmlText $match.Groups[1].Value }
  return $null
}

function Get-PercentFromText {
  param([AllowNull()][string]$Text)

  if ($null -eq $Text) { return $null }
  $match = [regex]::Match($Text, '\(([-0-9.,\s]+)%\)')
  if ($match.Success) { return Convert-Mt5Number $match.Groups[1].Value }
  $match = [regex]::Match($Text, '([-0-9.,\s]+)%')
  if ($match.Success) { return Convert-Mt5Number $match.Groups[1].Value }
  return $null
}

function Read-Mt5ReportMetrics {
  param([string]$Path, [double]$Deposit)

  $html = Decode-Report -Path $Path
  $profit = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Net Profit')
  $equityDdMaxText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Maximal'
  $equityDdRelText = Get-ReportMetric -Html $html -Label 'Equity Drawdown Relative'
  $profitTradesText = Get-ReportMetric -Html $html -Label 'Profit Trades (% of total)'

  $ddPct = Get-PercentFromText $equityDdMaxText
  if ($null -eq $ddPct) { $ddPct = Get-PercentFromText $equityDdRelText }

  $ratio = $null
  if ($null -ne $ddPct -and $ddPct -ne 0 -and $null -ne $profit) {
    $ratio = [Math]::Round(($profit / ($Deposit / 100.0)) / $ddPct, 3)
  }

  $returnPct = $null
  if ($null -ne $profit -and $Deposit -ne 0) {
    $returnPct = [Math]::Round(($profit / $Deposit) * 100.0, 3)
  }

  return [pscustomobject]@{
    Profit = if ($null -ne $profit) { [Math]::Round($profit, 2) } else { $null }
    ReturnPct = $returnPct
    EquityDDPct = if ($null -ne $ddPct) { [Math]::Round($ddPct, 2) } else { $null }
    Ratio = $ratio
    Trades = [int](Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Total Trades'))
    ProfitFactor = Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Profit Factor')
    WinRatePct = Get-PercentFromText $profitTradesText
  }
}

function Get-SetFileEncoding {
  param([string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254) { return [System.Text.Encoding]::Unicode }
  if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) { return [System.Text.Encoding]::UTF8 }
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
  foreach ($line in [System.IO.File]::ReadAllLines($TemplateSetPath, $encoding)) { $lines.Add($line) }

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

function New-Windows {
  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  $oosStart = [datetime]::new($FirstOosStart.Year, $FirstOosStart.Month, 1)
  $lastStart = [datetime]::new($LastOosStart.Year, $LastOosStart.Month, 1)

  while ($oosStart -le $lastStart) {
    $valStart = $oosStart.AddMonths(-1 * $ValidationMonths)
    $isEnd = $valStart
    $isStart = $isEnd.AddYears(-1 * $ISYears)
    $oosEnd = $oosStart.AddMonths($OosMonths)
    $windowId = ('W{0:D4}_{1}' -f $index, (Get-DateLabel $oosStart))

    $rows.Add([pscustomobject]@{
      WindowIndex = $index
      WindowId = $windowId
      Symbol = $Symbol
      ISStart = Get-Mt5Date $isStart
      ISEnd = Get-Mt5Date $isEnd
      ValidationStart = Get-Mt5Date $valStart
      ValidationEnd = Get-Mt5Date $oosStart
      OosStart = Get-Mt5Date $oosStart
      OosPrimaryEnd = Get-Mt5Date ($oosStart.AddMonths($PrimaryOosMonths))
      OosEnd = Get-Mt5Date $oosEnd
    })

    $index++
    $oosStart = $oosStart.AddMonths($StepMonths)
  }

  return $rows
}

function New-OptimizerConfig {
  param([object]$Window, [string]$ConfigPath, [string]$Report, [string]$TemplateSetFileName)

  $configContent = @(
    '[Tester]',
    'Expert=ThreeDayTrendSignal\ThreeDayTrendSignalEA.ex5',
    "Symbol=$Symbol",
    "Period=$Period",
    '',
    "FromDate=$($Window.ISStart)",
    "ToDate=$($Window.ISEnd)",
    '',
    'Model=4',
    'Optimization=2',
    'Visual=0',
    '',
    "ExpertParameters=$TemplateSetFileName",
    "Report=$Report",
    '',
    '; ForwardMode intentionally omitted. Validation is a separate fixed-test ranking stage.',
    'OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $configContent | Set-Content -LiteralPath $ConfigPath -Encoding ASCII
}

function Invoke-OptimizerRun {
  param([object]$Window, [string]$ConfigPath, [string]$Report, [string]$ExpectedReportPath, [string]$TemplateSetFileName)

  New-OptimizerConfig -Window $Window -ConfigPath $ConfigPath -Report $Report -TemplateSetFileName $TemplateSetFileName

  Write-Host "Running optimizer $($Window.WindowId): $Symbol $($Window.ISStart) -> $($Window.ISEnd)"
  $startTime = Get-Date
  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$ConfigPath`"" -PassThru
  while (-not $process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    $process.Refresh()
    if (((Get-Date) - $startTime).TotalMinutes -ge $OptimizationTimeoutMinutes) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw "Optimizer timed out after $OptimizationTimeoutMinutes minutes for $($Window.WindowId)."
    }
  }

  Start-Sleep -Seconds 2
  if (-not (Test-Path -LiteralPath $ExpectedReportPath)) {
    throw "Optimizer finished but report was not found: $ExpectedReportPath"
  }
}

function New-OptimizerCandidates {
  param([object[]]$OptimizerRows)

  foreach ($is in $OptimizerRows) {
    $pass = [int](Get-PropValue -Object $is -Names @('Pass') -Default 0)
    $isProfit = [double](Get-PropValue -Object $is -Names @('Profit') -Default 0.0)
    $isDD = [double](Get-PropValue -Object $is -Names @('Equity DD %') -Default 0.0)
    $isTrades = [int](Get-PropValue -Object $is -Names @('Trades') -Default 0)
    $isRatio = if ($isDD -gt 0) { $isProfit / ($StartingDeposit * $isDD / 100.0) } else { if ($isProfit -gt 0) { 999.0 } else { -999.0 } }
    $isReturnPct = ($isProfit / $StartingDeposit) * 100.0
    $isScore = ($isReturnPct * 100.0) + ($isRatio * 25.0) + ([Math]::Log(1.0 + [Math]::Max(0, $isTrades)) * 10.0) - ($isDD * 5.0)

    [pscustomobject]@{
      Pass = $pass
      ManifoldId = "TDTS_Pass$pass"
      ISScore = [Math]::Round($isScore, 6)
      ISProfit = [Math]::Round($isProfit, 2)
      ISReturnPct = [Math]::Round($isReturnPct, 3)
      ISDD = [Math]::Round($isDD, 2)
      ISRatio = [Math]::Round($isRatio, 3)
      ISTrades = $isTrades
      ATR = [int](Get-PropValue -Object $is -Names @('g_ATR_Period') -Default 0)
      ATRMult = [double](Get-PropValue -Object $is -Names @('g_ATR_Multiplier') -Default 0.0)
      ContiguousCandles = [int](Get-PropValue -Object $is -Names @('g_ContiguousCandles') -Default 0)
      StopLossATRMultiple = [double](Get-PropValue -Object $is -Names @('g_StopLossATRMultiple') -Default 0.0)
      TakeProfitSLMultiple = [double](Get-PropValue -Object $is -Names @('g_TakeProfitSLMultiple') -Default 0.0)
    }
  }
}

function New-ValidationManifest {
  param([object]$Window, [object[]]$Candidates, [string]$ReportSubdir)

  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  foreach ($candidate in $Candidates) {
    $dateLabel = ($Window.ValidationStart -replace '\.', '') + '_' + ($Window.ValidationEnd -replace '\.', '')
    $report = "$ReportSubdir\validation\$($Window.WindowId)_$Symbol`_$($candidate.ManifoldId)_VAL_$dateLabel.xml"
    $rows.Add([pscustomobject]@{
      TestIndex = $index
      TestId = ('{0}_{1:D5}_{2}_VAL' -f $Window.WindowId, $index, $candidate.ManifoldId)
      WindowIndex = $Window.WindowIndex
      WindowId = $Window.WindowId
      Stage = 'VAL'
      ManifoldId = $candidate.ManifoldId
      Pass = $candidate.Pass
      Symbol = $Symbol
      Segment = 'VAL'
      FromDate = $Window.ValidationStart
      ToDate = $Window.ValidationEnd
      Report = $report
      ExpectedReport = "$report.htm"
      ATR = $candidate.ATR
      ATRMult = $candidate.ATRMult
      ContiguousCandles = $candidate.ContiguousCandles
      StopLossATRMultiple = $candidate.StopLossATRMultiple
      TakeProfitSLMultiple = $candidate.TakeProfitSLMultiple
      ISScore = $candidate.ISScore
      ISProfit = $candidate.ISProfit
      ISReturnPct = $candidate.ISReturnPct
      ISDD = $candidate.ISDD
      ISRatio = $candidate.ISRatio
      ISTrades = $candidate.ISTrades
    })
    $index++
  }

  return $rows
}

function New-OosManifest {
  param([object]$Window, [object]$Selected, [string]$ReportSubdir)

  $oosStart = [datetime]::ParseExact($Window.OosStart, 'yyyy.MM.dd', [System.Globalization.CultureInfo]::InvariantCulture)
  $periods = @(
    [pscustomobject]@{ Segment = 'OOS_0_90'; From = $oosStart; To = $oosStart.AddMonths(3); HorizonType = 'PrimaryAndSlice'; MonthsFrom = 0; MonthsTo = 3 },
    [pscustomobject]@{ Segment = 'OOS_91_180'; From = $oosStart.AddMonths(3); To = $oosStart.AddMonths(6); HorizonType = 'Slice'; MonthsFrom = 3; MonthsTo = 6 },
    [pscustomobject]@{ Segment = 'OOS_181_270'; From = $oosStart.AddMonths(6); To = $oosStart.AddMonths(9); HorizonType = 'Slice'; MonthsFrom = 6; MonthsTo = 9 },
    [pscustomobject]@{ Segment = 'OOS_271_360'; From = $oosStart.AddMonths(9); To = $oosStart.AddMonths(12); HorizonType = 'Slice'; MonthsFrom = 9; MonthsTo = 12 },
    [pscustomobject]@{ Segment = 'OOS_0_180'; From = $oosStart; To = $oosStart.AddMonths(6); HorizonType = 'Cumulative'; MonthsFrom = 0; MonthsTo = 6 },
    [pscustomobject]@{ Segment = 'OOS_0_270'; From = $oosStart; To = $oosStart.AddMonths(9); HorizonType = 'Cumulative'; MonthsFrom = 0; MonthsTo = 9 },
    [pscustomobject]@{ Segment = 'OOS_0_360'; From = $oosStart; To = $oosStart.AddMonths(12); HorizonType = 'Cumulative'; MonthsFrom = 0; MonthsTo = 12 }
  )

  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  foreach ($periodDef in $periods) {
    $fromText = Get-Mt5Date $periodDef.From
    $toText = Get-Mt5Date $periodDef.To
    $dateLabel = ($fromText -replace '\.', '') + '_' + ($toText -replace '\.', '')
    $report = "$ReportSubdir\oos\$($Window.WindowId)_$Symbol`_$($Selected.ManifoldId)_$($periodDef.Segment)_$dateLabel.xml"
    $rows.Add([pscustomobject]@{
      TestIndex = $index
      TestId = ('{0}_{1:D5}_{2}_{3}' -f $Window.WindowId, $index, $Selected.ManifoldId, $periodDef.Segment)
      WindowIndex = $Window.WindowIndex
      WindowId = $Window.WindowId
      Stage = 'OOS'
      ManifoldId = $Selected.ManifoldId
      Pass = $Selected.Pass
      Symbol = $Symbol
      Segment = $periodDef.Segment
      HorizonType = $periodDef.HorizonType
      MonthsFrom = $periodDef.MonthsFrom
      MonthsTo = $periodDef.MonthsTo
      FromDate = $fromText
      ToDate = $toText
      Report = $report
      ExpectedReport = "$report.htm"
      ATR = $Selected.ATR
      ATRMult = $Selected.ATRMult
      ContiguousCandles = $Selected.ContiguousCandles
      StopLossATRMultiple = $Selected.StopLossATRMultiple
      TakeProfitSLMultiple = $Selected.TakeProfitSLMultiple
      ValidationScore = $Selected.ValidationScore
      ValidationRank = $Selected.ValidationRank
    })
    $index++
  }

  return $rows
}

function Append-Progress {
  param([object]$Test, [string]$Status, [double]$DurationSeconds, [string]$ReportPath, [string]$Note, [string]$ProgressPath)

  $row = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('s')
    WindowIndex = $Test.WindowIndex
    WindowId = $Test.WindowId
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
  param([object[]]$Manifest, [string]$ProgressPath, [string]$ReportRoot, [string]$TemplateSetPath, [string]$TempSetPath, [int]$RemainingFixedTests)

  $completedStatuses = @('Completed', 'SkippedExistingReport')
  $completedByProgress = @{}
  if (Test-Path -LiteralPath $ProgressPath) {
    Import-Csv -LiteralPath $ProgressPath | ForEach-Object {
      if ($completedStatuses -contains $_.Status) { $completedByProgress[$_.TestId] = $true }
    }
  }

  $testsRunThisSession = 0
  foreach ($test in ($Manifest | Sort-Object { [int]$_.TestIndex })) {
    if ($RemainingFixedTests -ge 0 -and $testsRunThisSession -ge $RemainingFixedTests) { break }

    $expectedReportPath = Convert-ReportPathToFullPath -ReportRoot $ReportRoot -ExpectedReport $test.ExpectedReport
    if (-not $RunExistingReports -and ($completedByProgress.ContainsKey($test.TestId) -or (Test-Path -LiteralPath $expectedReportPath))) {
      if (-not $completedByProgress.ContainsKey($test.TestId)) {
        Append-Progress -Test $test -Status 'SkippedExistingReport' -DurationSeconds 0 -ReportPath $expectedReportPath -Note 'Report already existed before run.' -ProgressPath $ProgressPath
      }
      continue
    }

    Write-Host ''
    Write-Host '====================================='
    Write-Host "Running $($test.TestId)"
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
      "Period=$Period",
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
      '; Fixed run generated by TDTS ephemeral generator.',
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
      if (-not $note) { $note = 'Report file found.' }
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
    if (-not (Test-Path -LiteralPath $path)) { continue }

    $metrics = Read-Mt5ReportMetrics -Path $path -Deposit $StartingDeposit
    [pscustomobject]@{
      WindowIndex = $test.WindowIndex
      WindowId = $test.WindowId
      TestIndex = $test.TestIndex
      TestId = $test.TestId
      Stage = $test.Stage
      ManifoldId = $test.ManifoldId
      Pass = $test.Pass
      Symbol = $test.Symbol
      Segment = $test.Segment
      HorizonType = if ($test.PSObject.Properties['HorizonType']) { $test.HorizonType } else { '' }
      MonthsFrom = if ($test.PSObject.Properties['MonthsFrom']) { $test.MonthsFrom } else { '' }
      MonthsTo = if ($test.PSObject.Properties['MonthsTo']) { $test.MonthsTo } else { '' }
      FromDate = $test.FromDate
      ToDate = $test.ToDate
      Profit = $metrics.Profit
      ReturnPct = $metrics.ReturnPct
      EquityDDPct = $metrics.EquityDDPct
      Ratio = $metrics.Ratio
      Trades = $metrics.Trades
      ProfitFactor = $metrics.ProfitFactor
      WinRatePct = $metrics.WinRatePct
      ReportPath = $path
      ATR = $test.ATR
      ATRMult = $test.ATRMult
      ContiguousCandles = $test.ContiguousCandles
      StopLossATRMultiple = $test.StopLossATRMultiple
      TakeProfitSLMultiple = $test.TakeProfitSLMultiple
    }
  }
}

function Get-ValidationScore {
  param([object]$Row)

  $profit = if ($null -ne $Row.Profit) { [double]$Row.Profit } else { -1000000.0 }
  $returnPct = if ($null -ne $Row.ReturnPct) { [double]$Row.ReturnPct } else { ($profit / $StartingDeposit) * 100.0 }
  $dd = if ($null -ne $Row.EquityDDPct -and [double]$Row.EquityDDPct -gt 0) { [double]$Row.EquityDDPct } else { 100.0 }
  $ratio = if ($null -ne $Row.Ratio) { [double]$Row.Ratio } else { $returnPct / [Math]::Max($dd, 0.01) }
  $pf = if ($null -ne $Row.ProfitFactor -and -not [double]::IsInfinity([double]$Row.ProfitFactor)) { [double]$Row.ProfitFactor } else { 10.0 }
  $trades = if ($null -ne $Row.Trades) { [int]$Row.Trades } else { 0 }
  $profitBonus = if ($profit -gt 0) { 10000.0 } else { 0.0 }

  return [Math]::Round($profitBonus + ($ratio * 1000.0) + ($returnPct * 100.0) + ($pf * 25.0) + ([Math]::Log(1.0 + [Math]::Max(0, $trades)) * 20.0) - ($dd * 25.0), 6)
}

function Select-OneValidationCandidate {
  param([object[]]$ValidationRows)

  $ranked = @($ValidationRows | ForEach-Object {
    $score = Get-ValidationScore -Row $_
    $_ | Add-Member -NotePropertyName ValidationScore -NotePropertyValue $score -Force
    $_
  } | Sort-Object @{ Expression = 'ValidationScore'; Descending = $true }, @{ Expression = 'Profit'; Descending = $true }, @{ Expression = 'EquityDDPct'; Ascending = $true }, @{ Expression = 'Trades'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })

  $rank = 1
  foreach ($row in $ranked) {
    $row | Add-Member -NotePropertyName ValidationRank -NotePropertyValue $rank -Force
    $rank++
  }

  if ($ranked.Count -eq 0) { return $null }
  return $ranked[0]
}

function Export-WindowSelection {
  param([object]$Window, [object]$Selected, [string]$Path)

  $row = [pscustomobject]@{
    WindowIndex = $Window.WindowIndex
    WindowId = $Window.WindowId
    Symbol = $Symbol
    ISStart = $Window.ISStart
    ISEnd = $Window.ISEnd
    ValidationStart = $Window.ValidationStart
    ValidationEnd = $Window.ValidationEnd
    OosStart = $Window.OosStart
    OosPrimaryEnd = $Window.OosPrimaryEnd
    OosEnd = $Window.OosEnd
    SelectionStatus = if ($null -ne $Selected) { 'SelectedOne' } else { 'NoValidationRows' }
    ManifoldId = if ($null -ne $Selected) { $Selected.ManifoldId } else { '' }
    Pass = if ($null -ne $Selected) { $Selected.Pass } else { '' }
    ValidationScore = if ($null -ne $Selected) { $Selected.ValidationScore } else { '' }
    ValidationProfit = if ($null -ne $Selected) { $Selected.Profit } else { '' }
    ValidationReturnPct = if ($null -ne $Selected) { $Selected.ReturnPct } else { '' }
    ValidationDDPct = if ($null -ne $Selected) { $Selected.EquityDDPct } else { '' }
    ValidationRatio = if ($null -ne $Selected) { $Selected.Ratio } else { '' }
    ValidationTrades = if ($null -ne $Selected) { $Selected.Trades } else { '' }
    ValidationProfitFactor = if ($null -ne $Selected) { $Selected.ProfitFactor } else { '' }
    ValidationWinRatePct = if ($null -ne $Selected) { $Selected.WinRatePct } else { '' }
    ATR = if ($null -ne $Selected) { $Selected.ATR } else { '' }
    ATRMult = if ($null -ne $Selected) { $Selected.ATRMult } else { '' }
    ContiguousCandles = if ($null -ne $Selected) { $Selected.ContiguousCandles } else { '' }
    StopLossATRMultiple = if ($null -ne $Selected) { $Selected.StopLossATRMultiple } else { '' }
    TakeProfitSLMultiple = if ($null -ne $Selected) { $Selected.TakeProfitSLMultiple } else { '' }
  }

  $row | Export-Csv -LiteralPath $Path -NoTypeInformation -Encoding ASCII
}

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$templateSetPath = Join-Path $testerProfilesDir $TemplateSetFile
$tempSetPath = Join-Path $testerProfilesDir $TempSetFile
$experimentDir = Join-Path $terminalDataRoot "reports\$ExperimentId"
$reportSubdir = "reports\$ExperimentId"
$windowsPath = Join-Path $experimentDir 'windows.csv'
$selectionSummaryPath = Join-Path $experimentDir 'selection_summary.csv'
$oosSummaryPath = Join-Path $experimentDir 'oos_summary.csv'
$fixedProgressPath = Join-Path $experimentDir 'fixed_test_progress.csv'
$optimizerProgressPath = Join-Path $experimentDir 'optimizer_progress.csv'

if (-not (Test-Path -LiteralPath $experimentDir)) { New-Item -ItemType Directory -Path $experimentDir -Force | Out-Null }
foreach ($subdir in @('optimizer', 'validation', 'oos')) {
  $full = Join-Path $terminalDataRoot "$reportSubdir\$subdir"
  if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}

if (-not (Test-Path -LiteralPath $templateSetPath)) { throw "Template set file not found: $templateSetPath" }
if (-not (Test-Path -LiteralPath $TerminalPath) -and -not $PrepareOnly) { throw "MT5 terminal not found: $TerminalPath" }
if ($ISYears -le 0 -or $ValidationMonths -le 0 -or $OosMonths -le 0 -or $PrimaryOosMonths -le 0 -or $StepMonths -le 0) { throw 'Window lengths must be positive.' }
if ($PrimaryOosMonths -gt $OosMonths) { throw 'PrimaryOosMonths cannot be greater than OosMonths.' }
if ($TopOptimizerCandidates -le 0) { throw 'TopOptimizerCandidates must be positive.' }

$windows = @(New-Windows)
$windows | Export-Csv -LiteralPath $windowsPath -NoTypeInformation -Encoding ASCII

Write-Host "Experiment: $ExperimentId"
Write-Host "Directory: $experimentDir"
Write-Host "Symbol: $Symbol $Period"
Write-Host "Hyperparameters: IS=$ISYears years, VAL=$ValidationMonths months, OOS=$OosMonths months, primary OOS=$PrimaryOosMonths months, step=$StepMonths month(s)"
Write-Host "Windows: $($windows.Count) ($($windows[0].OosStart) -> $($windows[-1].OosStart))"
Write-Host "Validation rule: rank every completed VAL report and select exactly one candidate per window. No VAL pass/fail filter is applied."

if ($PrepareOnly) {
  $firstRunnable = @($windows | Where-Object { [int]$_.WindowIndex -ge $StartAtWindow } | Select-Object -First 1)
  if ($firstRunnable.Count -gt 0) {
    $dateLabel = ($firstRunnable[0].ISStart -replace '\.', '') + '_' + ($firstRunnable[0].ISEnd -replace '\.', '')
    $optimizerReport = "$reportSubdir\optimizer\$($firstRunnable[0].WindowId)_$Symbol`_$Period`_Genetic_$dateLabel.xml"
    New-OptimizerConfig -Window $firstRunnable[0] -ConfigPath (Join-Path $PSScriptRoot 'tdts_ephemeral_optimizer_current.ini') -Report $optimizerReport -TemplateSetFileName $TemplateSetFile
  }
  Write-Host 'PrepareOnly set. No MT5 optimizers or fixed tests were run.'
  return
}

$windowsProcessedThisSession = 0
$fixedTestsRunThisSession = 0
$stopForFixedLimit = $false

foreach ($window in ($windows | Sort-Object { [int]$_.WindowIndex })) {
  if ([int]$window.WindowIndex -lt $StartAtWindow) { continue }
  if ($MaxWindows -gt 0 -and $windowsProcessedThisSession -ge $MaxWindows) { break }
  if ($MaxFixedTests -gt 0 -and $fixedTestsRunThisSession -ge $MaxFixedTests) { break }

  Write-Host ''
  Write-Host '#####################################'
  Write-Host "Window $($window.WindowIndex): $($window.WindowId)"
  Write-Host "IS $($window.ISStart) -> $($window.ISEnd); VAL $($window.ValidationStart) -> $($window.ValidationEnd); OOS $($window.OosStart) -> $($window.OosEnd)"
  Write-Host '#####################################'

  $windowDir = Join-Path $experimentDir $window.WindowId
  if (-not (Test-Path -LiteralPath $windowDir)) { New-Item -ItemType Directory -Path $windowDir -Force | Out-Null }

  $isDateLabel = ($window.ISStart -replace '\.', '') + '_' + ($window.ISEnd -replace '\.', '')
  $optimizerReport = "$reportSubdir\optimizer\$($window.WindowId)_$Symbol`_$Period`_Genetic_$isDateLabel.xml"
  $optimizerXml = Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $optimizerReport
  $optimizerConfigPath = Join-Path $PSScriptRoot 'tdts_ephemeral_optimizer_current.ini'

  if (-not (Test-Path -LiteralPath $optimizerXml)) {
    Invoke-OptimizerRun -Window $window -ConfigPath $optimizerConfigPath -Report $optimizerReport -ExpectedReportPath $optimizerXml -TemplateSetFileName $TemplateSetFile
    [pscustomobject]@{
      Timestamp = (Get-Date).ToString('s')
      WindowIndex = $window.WindowIndex
      WindowId = $window.WindowId
      Status = 'Completed'
      OptimizerXml = $optimizerXml
    } | Export-Csv -LiteralPath $optimizerProgressPath -NoTypeInformation -Append -Encoding ASCII
  } else {
    Write-Host "Optimizer report already exists: $optimizerXml"
  }

  $optimizerRows = @(Read-Mt5Spreadsheet -Path $optimizerXml)
  $allCandidates = @(New-OptimizerCandidates -OptimizerRows $optimizerRows | Sort-Object @{ Expression = 'ISScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
  $candidateCsv = Join-Path $windowDir 'optimizer_candidates_ranked.csv'
  $selectedForValidationCsv = Join-Path $windowDir 'validation_candidates.csv'
  $allCandidates | Export-Csv -LiteralPath $candidateCsv -NoTypeInformation -Encoding ASCII

  $validationCandidates = @($allCandidates | Select-Object -First $TopOptimizerCandidates)
  $validationCandidates | Export-Csv -LiteralPath $selectedForValidationCsv -NoTypeInformation -Encoding ASCII

  if ($validationCandidates.Count -eq 0) {
    Write-Host "No optimizer candidates found for $($window.WindowId). Skipping VAL/OOS for this window."
    Export-WindowSelection -Window $window -Selected $null -Path (Join-Path $windowDir 'selected_candidate.csv')
    $windowsProcessedThisSession++
    continue
  }

  $validationManifest = @(New-ValidationManifest -Window $window -Candidates $validationCandidates -ReportSubdir $reportSubdir)
  $validationManifestPath = Join-Path $windowDir 'validation_manifest.csv'
  $validationResultsPath = Join-Path $windowDir 'validation_results_ranked.csv'
  $validationManifest | Export-Csv -LiteralPath $validationManifestPath -NoTypeInformation -Encoding ASCII

  if ($MaxFixedTests -gt 0 -and $fixedTestsRunThisSession -ge $MaxFixedTests) {
    Write-Host "Fixed-test session limit reached before VAL stage completed for $($window.WindowId). Rerun the same command to resume."
    return
  }
  $remainingFixed = if ($MaxFixedTests -gt 0) { $MaxFixedTests - $fixedTestsRunThisSession } else { -1 }
  $fixedTestsRunThisSession += Invoke-TestManifest -Manifest $validationManifest -ProgressPath $fixedProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -RemainingFixedTests $remainingFixed
  $validationMissing = @($validationManifest | Where-Object { -not (Test-Path -LiteralPath (Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $_.ExpectedReport)) })
  if ($validationMissing.Count -gt 0) {
    Write-Host "VAL stage incomplete for $($window.WindowId). Missing reports: $($validationMissing.Count). Rerun the same command to resume."
    return
  }

  $validationRows = @(Read-ManifestReportRows -Manifest $validationManifest -ReportRoot $reportRoot)
  $selected = Select-OneValidationCandidate -ValidationRows $validationRows
  if ($null -eq $selected) {
    Write-Host "No validation rows could be read for $($window.WindowId). OOS skipped."
    Export-WindowSelection -Window $window -Selected $null -Path (Join-Path $windowDir 'selected_candidate.csv')
    $windowsProcessedThisSession++
    continue
  }

  $validationRows | Sort-Object @{ Expression = 'ValidationScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true } | Export-Csv -LiteralPath $validationResultsPath -NoTypeInformation -Encoding ASCII
  Export-WindowSelection -Window $window -Selected $selected -Path (Join-Path $windowDir 'selected_candidate.csv')
  Write-Host "Selected exactly one OOS candidate: $($selected.ManifoldId) score=$($selected.ValidationScore) VAL profit=$($selected.Profit) DD=$($selected.EquityDDPct) trades=$($selected.Trades)"

  $oosManifest = @(New-OosManifest -Window $window -Selected $selected -ReportSubdir $reportSubdir)
  $oosManifestPath = Join-Path $windowDir 'oos_manifest.csv'
  $oosResultsPath = Join-Path $windowDir 'oos_results.csv'
  $oosManifest | Export-Csv -LiteralPath $oosManifestPath -NoTypeInformation -Encoding ASCII

  if ($MaxFixedTests -gt 0 -and $fixedTestsRunThisSession -ge $MaxFixedTests) {
    Write-Host "Fixed-test session limit reached before OOS stage completed for $($window.WindowId). Rerun the same command to resume."
    return
  }
  $remainingFixed = if ($MaxFixedTests -gt 0) { $MaxFixedTests - $fixedTestsRunThisSession } else { -1 }
  $fixedTestsRunThisSession += Invoke-TestManifest -Manifest $oosManifest -ProgressPath $fixedProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -RemainingFixedTests $remainingFixed
  $oosMissing = @($oosManifest | Where-Object { -not (Test-Path -LiteralPath (Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $_.ExpectedReport)) })
  if ($oosMissing.Count -gt 0) {
    Write-Host "OOS stage incomplete for $($window.WindowId). Missing reports: $($oosMissing.Count). Rerun the same command to resume."
    return
  }

  $oosRows = @(Read-ManifestReportRows -Manifest $oosManifest -ReportRoot $reportRoot)
  $oosRows | Export-Csv -LiteralPath $oosResultsPath -NoTypeInformation -Encoding ASCII
  Write-Host "OOS metrics recorded for $($window.WindowId). OOS profitability is not a stop condition."

  $windowsProcessedThisSession++
}

$selectionRows = @()
$oosRowsAll = @()
foreach ($window in $windows) {
  $windowDir = Join-Path $experimentDir $window.WindowId
  $selectionPath = Join-Path $windowDir 'selected_candidate.csv'
  $oosPath = Join-Path $windowDir 'oos_results.csv'
  if (Test-Path -LiteralPath $selectionPath) { $selectionRows += @(Import-Csv -LiteralPath $selectionPath) }
  if (Test-Path -LiteralPath $oosPath) { $oosRowsAll += @(Import-Csv -LiteralPath $oosPath) }
}
if ($selectionRows.Count -gt 0) { $selectionRows | Export-Csv -LiteralPath $selectionSummaryPath -NoTypeInformation -Encoding ASCII }
if ($oosRowsAll.Count -gt 0) { $oosRowsAll | Export-Csv -LiteralPath $oosSummaryPath -NoTypeInformation -Encoding ASCII }

Write-Host ''
Write-Host "Session complete or paused by limits. Windows processed this session: $windowsProcessedThisSession. Fixed tests run this session: $fixedTestsRunThisSession."
Write-Host "Selection summary: $selectionSummaryPath"
Write-Host "OOS summary: $oosSummaryPath"
Write-Host 'Rerun the same command to resume from existing optimizer and fixed-test reports.'
