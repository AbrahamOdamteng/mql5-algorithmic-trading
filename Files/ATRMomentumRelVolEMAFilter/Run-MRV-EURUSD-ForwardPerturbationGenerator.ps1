param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$ExperimentId = 'mrv_ema_fp_eurusd_2025_is24m_val24m_oos3m_step1m',
  [string]$SourceOptimizerExperimentId = '',
  [string]$Symbol = 'EURUSD',
  [string]$Period = 'H1',
  [string]$TemplateSetFile = 'ATRMomentumRelVolEMAFilter_WalkForward_Current.set',
  [string]$TempSetFile = 'ATRMomentumRelVolEMAFilter_ForwardPerturbation_Generated.set',
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'mrv_ema_forward_perturbation_current.ini'),
  [datetime]$FirstOosStart = '2025-01-01',
  [datetime]$LastOosStart = '2025-04-01',
  [int]$ISMonths = 24,
  [int]$ValidationMonths = 24,
  [int]$OosMonths = 3,
  [int]$StepMonths = 1,
  [double]$MinISProfit = 0.0,
  [double]$MaxISDDPct = 30.0,
  [int]$MinISTrades = 40,
  [double]$MinValidationProfit = 0.0,
  [double]$MinValidationProfitFactor = 1.10,
  [double]$MaxValidationDDPct = 25.0,
  [int]$MinValidationTrades = 40,
  [double]$GroupDistanceThreshold = 0.10,
  [double]$PerturbationPercent = 10.0,
  [double]$MinPerturbationProfitRate = 0.70,
  [double]$MaxPerturbationDDPct = 30.0,
  [double]$CatastrophicDDMultiple = 1.50,
  [int]$MaxGroupsToPerturb = 10,
  [double]$StartingDeposit = 100000.0,
  [ValidateSet('ValidationScore', 'PositiveBestRatio', 'ValidationProfit', 'LowestValidationDD', 'HighestValidationPF', 'LowestValidationTrades', 'BackForwardScoreThenLowestDD', 'BackForwardScoreThenHighestProfit', 'BackForwardScoreThenHighestTrades', 'BackForwardScoreThenHighestTotalTrades', 'BackForwardScoreThenLowestTrades', 'BackForwardScoreThenHighestPF', 'BackForwardScoreThenHighestDD', 'BackForwardScoreFallbackHighestTrades')]
  [string]$ForwardSelectionMode = 'PositiveBestRatio',
  [double]$MinBackScore = 80.0,
  [double]$MinForwardScore = 80.0,
  [int]$OptimizationTimeoutMinutes = 1440,
  [int]$MaxRuntimeMinutes = 20,
  [int]$PollSeconds = 30,
  [int]$StartAtWindow = 1,
  [int]$MaxWindows = 0,
  [int]$MaxFixedTests = 0,
  [switch]$SkipPerturbation,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$StrictScoreGates,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'
$optimizedParameterNames = @(
  'ATR',
  'MomentumATRMultiplier',
  'ContiguousCandles',
  'RelVolLength',
  'RelVolSignalCandles',
  'RelVolThreshold',
  'FastEMALength',
  'SlowEMALength',
  'MinEMASeparationCandles',
  'TakeProfitSLMultiple',
  'MaxStopLossATRMultiple'
)

$inputNameByParam = @{
  ATR = 'g_ATR_Period'
  MomentumATRMultiplier = 'g_MomentumATRMultiplier'
  ContiguousCandles = 'g_ContiguousCandles'
  RelVolLength = 'g_RelVolLength'
  RelVolSignalCandles = 'g_RelVolSignalCandles'
  RelVolThreshold = 'g_RelVolThreshold'
  FastEMALength = 'g_FastEMALength'
  SlowEMALength = 'g_SlowEMALength'
  MinEMASeparationCandles = 'g_MinEMASeparationCandles'
  RiskPercentOfBalance = 'g_RiskPercentOfBalance'
  TakeProfitSLMultiple = 'g_TakeProfitSLMultiple'
  MaxStopLossATRMultiple = 'g_MaxStopLossATRMultiple'
}

$integerParams = @('ATR', 'ContiguousCandles', 'RelVolLength', 'RelVolSignalCandles', 'FastEMALength', 'SlowEMALength', 'MinEMASeparationCandles')

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

function Get-ForwardReportName {
  param([string]$Report)
  if ($Report.EndsWith('.xml')) { return $Report.Substring(0, $Report.Length - 4) + '.forward.xml' }
  return "$Report.forward.xml"
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
    if ($null -ne $prop -and $null -ne $prop.Value -and $prop.Value -ne '') { return $prop.Value }
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
  if ($null -ne $profit -and $Deposit -ne 0) { $returnPct = [Math]::Round(($profit / $Deposit) * 100.0, 3) }

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

function Get-OptimizerRanges {
  param([string]$SetPath)

  $encoding = Get-SetFileEncoding -Path $SetPath
  $ranges = @{}
  foreach ($line in [System.IO.File]::ReadAllLines($SetPath, $encoding)) {
    if ($line -notmatch '^(g_[A-Za-z0-9_]+)=([^|]+)\|\|([^|]+)\|\|([^|]+)\|\|([^|]+)\|\|([YN])') { continue }
    if ($matches[6] -ne 'Y') { continue }
    $ranges[$matches[1]] = [pscustomobject]@{
      Default = Convert-Mt5Number $matches[2]
      Start = Convert-Mt5Number $matches[3]
      Step = Convert-Mt5Number $matches[4]
      Stop = Convert-Mt5Number $matches[5]
    }
  }
  return $ranges
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

function Format-Invariant {
  param($Value)

  if ($Value -is [double] -or $Value -is [decimal] -or $Value -is [single]) {
    return [string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $Value)
  }
  return "$Value"
}

function New-TestSetFile {
  param([object]$Test, [string]$TemplateSetPath, [string]$TempSetPath)

  $encoding = Get-SetFileEncoding -Path $TemplateSetPath
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($TemplateSetPath, $encoding)) { $lines.Add($line) }

  Set-InputLine -Lines $lines -Name 'g_ATR_Period' -Value (Format-Invariant $Test.ATR)
  Set-InputLine -Lines $lines -Name 'g_MomentumATRMultiplier' -Value (Format-Invariant $Test.MomentumATRMultiplier)
  Set-InputLine -Lines $lines -Name 'g_ContiguousCandles' -Value (Format-Invariant $Test.ContiguousCandles)
  Set-InputLine -Lines $lines -Name 'g_RelVolLength' -Value (Format-Invariant (Get-PropValue -Object $Test -Names @('RelVolLength') -Default 20))
  Set-InputLine -Lines $lines -Name 'g_RelVolSignalCandles' -Value (Format-Invariant (Get-PropValue -Object $Test -Names @('RelVolSignalCandles') -Default 1))
  Set-InputLine -Lines $lines -Name 'g_RelVolThreshold' -Value (Format-Invariant (Get-PropValue -Object $Test -Names @('RelVolThreshold') -Default 1.5))
  Set-InputLine -Lines $lines -Name 'g_FastEMALength' -Value (Format-Invariant $Test.FastEMALength)
  Set-InputLine -Lines $lines -Name 'g_SlowEMALength' -Value (Format-Invariant $Test.SlowEMALength)
  Set-InputLine -Lines $lines -Name 'g_MinEMASeparationCandles' -Value (Format-Invariant $Test.MinEMASeparationCandles)
  Set-InputLine -Lines $lines -Name 'g_RiskPercentOfBalance' -Value (Format-Invariant $Test.RiskPercentOfBalance)
  Set-InputLine -Lines $lines -Name 'g_TakeProfitSLMultiple' -Value (Format-Invariant $Test.TakeProfitSLMultiple)
  Set-InputLine -Lines $lines -Name 'g_MaxStopLossATRMultiple' -Value (Format-Invariant $Test.MaxStopLossATRMultiple)
  Set-InputLine -Lines $lines -Name 'g_EnableTrading' -Value 'true'
  Set-InputLine -Lines $lines -Name 'g_StartingBalance' -Value (Format-Invariant $StartingDeposit)

  [System.IO.File]::WriteAllLines($TempSetPath, $lines, $encoding)
  return $TempSetFile
}

function New-Windows {
  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  $oosStart = [datetime]::new($FirstOosStart.Year, $FirstOosStart.Month, 1)
  $lastStart = [datetime]::new($LastOosStart.Year, $LastOosStart.Month, 1)

  while ($oosStart -le $lastStart) {
    $valEnd = $oosStart
    $valStart = $valEnd.AddMonths(-1 * $ValidationMonths)
    $isEnd = $valStart
    $isStart = $isEnd.AddMonths(-1 * $ISMonths)
    $windowId = ('W{0:D4}_{1}' -f $index, (Get-DateLabel $oosStart))

    $rows.Add([pscustomobject]@{
      WindowIndex = $index
      WindowId = $windowId
      Symbol = $Symbol
      ISStart = Get-Mt5Date $isStart
      ISEnd = Get-Mt5Date $isEnd
      ValidationStart = Get-Mt5Date $valStart
      ValidationEnd = Get-Mt5Date $valEnd
      OptimizerStart = Get-Mt5Date $isStart
      OptimizerEnd = Get-Mt5Date $valEnd
      OosStart = Get-Mt5Date $oosStart
      OosEnd = Get-Mt5Date ($oosStart.AddMonths($OosMonths))
    })

    $index++
    $oosStart = $oosStart.AddMonths($StepMonths)
  }

  return $rows
}

function New-ForwardOptimizerConfig {
  param([object]$Window, [string]$ConfigPath, [string]$Report, [string]$TemplateSetFileName)

  $configContent = @(
    '[Tester]',
    'Expert=ATRMomentumRelVolEMAFilter\ATRMomentumRelVolEMAFilterEA.ex5',
    "Symbol=$Symbol",
    "Period=$Period",
    '',
    "FromDate=$($Window.OptimizerStart)",
    "ToDate=$($Window.OptimizerEnd)",
    '',
    '; Use 1 minute OHLC for optimizer speed; fixed OOS tests still use Model=4 real ticks.',
    'Model=1',
    'Optimization=2',
    'Visual=0',
    '',
    "ExpertParameters=$TemplateSetFileName",
    "Report=$Report",
    '',
    '; ForwardMode=1 uses the second half of the date range as validation.',
    'ForwardMode=1',
    'OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $configContent | Set-Content -LiteralPath $ConfigPath -Encoding ASCII
}

function Invoke-ForwardOptimizerRun {
  param([object]$Window, [string]$ConfigPath, [string]$Report, [string]$ExpectedOptimizerPath, [string]$ExpectedForwardPath, [string]$TemplateSetFileName)

  New-ForwardOptimizerConfig -Window $Window -ConfigPath $ConfigPath -Report $Report -TemplateSetFileName $TemplateSetFileName

  Write-Host "Running optimizer+forward $($Window.WindowId): $Symbol $($Window.OptimizerStart) -> $($Window.OptimizerEnd)"
  $startTime = Get-Date
  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$ConfigPath`"" -PassThru
  while (-not $process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    $process.Refresh()
    if (((Get-Date) - $startTime).TotalMinutes -ge $OptimizationTimeoutMinutes) {
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      throw "Optimizer+forward timed out after $OptimizationTimeoutMinutes minutes for $($Window.WindowId)."
    }
  }

  Start-Sleep -Seconds 2
  if (-not (Test-Path -LiteralPath $ExpectedOptimizerPath)) { throw "Optimizer finished but optimizer report was not found: $ExpectedOptimizerPath" }
  if (-not (Test-Path -LiteralPath $ExpectedForwardPath)) { throw "Optimizer finished but forward report was not found: $ExpectedForwardPath" }

  $finishedTime = Get-Date
  $durationSeconds = ($finishedTime - $startTime).TotalSeconds
  $durationMinutes = $durationSeconds / 60.0
  Write-Host ("Finished optimizer+forward {0}: Completed in {1:N2} minutes" -f $Window.WindowId, $durationMinutes)

  return [pscustomobject]@{
    StartedAt = $startTime.ToString('s')
    FinishedAt = $finishedTime.ToString('s')
    DurationSeconds = [Math]::Round($durationSeconds, 2)
    DurationMinutes = [Math]::Round($durationMinutes, 2)
    Note = 'Optimizer and forward reports found.'
  }
}

function Get-ReportRatio {
  param([double]$Profit, [double]$DDPct)
  if ($DDPct -gt 0.0) { return $Profit / ($StartingDeposit * $DDPct / 100.0) }
  if ($Profit -gt 0.0) { return 999.0 }
  return -999.0
}

function New-ForwardCandidates {
  param([object[]]$OptimizerRows, [object[]]$ForwardRows)

  $optByPass = @{}
  foreach ($row in $OptimizerRows) { $optByPass[[int](Get-PropValue -Object $row -Names @('Pass') -Default 0)] = $row }

  foreach ($val in $ForwardRows) {
    $pass = [int](Get-PropValue -Object $val -Names @('Pass') -Default 0)
    if (-not $optByPass.ContainsKey($pass)) { continue }
    $is = $optByPass[$pass]

    $isProfit = [double](Get-PropValue -Object $is -Names @('Profit') -Default 0.0)
    $backScore = [double](Get-PropValue -Object $val -Names @('Back Result', 'Result') -Default (Get-PropValue -Object $is -Names @('Result') -Default 0.0))
    $isDD = [double](Get-PropValue -Object $is -Names @('Equity DD %') -Default 0.0)
    $isTrades = [int](Get-PropValue -Object $is -Names @('Trades') -Default 0)
    $isRatio = Get-ReportRatio -Profit $isProfit -DDPct $isDD
    $isPF = [double](Get-PropValue -Object $is -Names @('Profit Factor') -Default 0.0)

    $valProfit = [double](Get-PropValue -Object $val -Names @('Profit') -Default 0.0)
    $forwardScore = [double](Get-PropValue -Object $val -Names @('Forward Result', 'Result') -Default 0.0)
    $valDD = [double](Get-PropValue -Object $val -Names @('Equity DD %') -Default 0.0)
    $valTrades = [int](Get-PropValue -Object $val -Names @('Trades') -Default 0)
    $valRatio = Get-ReportRatio -Profit $valProfit -DDPct $valDD
    $valPF = [double](Get-PropValue -Object $val -Names @('Profit Factor') -Default 0.0)
    $valScore = (($valProfit / $StartingDeposit) * 10000.0) + ($valRatio * 1000.0) + ([Math]::Log(1.0 + [Math]::Max(0, $valTrades)) * 20.0) - ($valDD * 25.0)

    [pscustomobject]@{
      Pass = $pass
      ManifoldId = "MRV_EMA_Pass$pass"
      BackScore = [Math]::Round($backScore, 2)
      ISProfit = [Math]::Round($isProfit, 2)
      ISDD = [Math]::Round($isDD, 2)
      ISRatio = [Math]::Round($isRatio, 3)
      ISTrades = $isTrades
      ISProfitFactor = [Math]::Round($isPF, 3)
      ForwardScore = [Math]::Round($forwardScore, 2)
      ValidationProfit = [Math]::Round($valProfit, 2)
      ValidationDDPct = [Math]::Round($valDD, 2)
      ValidationRatio = [Math]::Round($valRatio, 3)
      ValidationTrades = $valTrades
      SumTradeCount = $isTrades + $valTrades
      ValidationProfitFactor = [Math]::Round($valPF, 3)
      ValidationScore = [Math]::Round($valScore, 6)
      ATR = [int](Get-PropValue -Object $val -Names @('g_ATR_Period') -Default (Get-PropValue -Object $is -Names @('g_ATR_Period') -Default 0))
      MomentumATRMultiplier = [double](Get-PropValue -Object $val -Names @('g_MomentumATRMultiplier') -Default (Get-PropValue -Object $is -Names @('g_MomentumATRMultiplier') -Default 0.0))
      ContiguousCandles = [int](Get-PropValue -Object $val -Names @('g_ContiguousCandles') -Default (Get-PropValue -Object $is -Names @('g_ContiguousCandles') -Default 0))
      RelVolLength = [int](Get-PropValue -Object $val -Names @('g_RelVolLength') -Default (Get-PropValue -Object $is -Names @('g_RelVolLength') -Default 20))
      RelVolSignalCandles = [int](Get-PropValue -Object $val -Names @('g_RelVolSignalCandles') -Default (Get-PropValue -Object $is -Names @('g_RelVolSignalCandles') -Default 1))
      RelVolThreshold = [double](Get-PropValue -Object $val -Names @('g_RelVolThreshold') -Default (Get-PropValue -Object $is -Names @('g_RelVolThreshold') -Default 1.5))
      FastEMALength = [int](Get-PropValue -Object $val -Names @('g_FastEMALength') -Default (Get-PropValue -Object $is -Names @('g_FastEMALength') -Default 100))
      SlowEMALength = [int](Get-PropValue -Object $val -Names @('g_SlowEMALength') -Default (Get-PropValue -Object $is -Names @('g_SlowEMALength') -Default 400))
      MinEMASeparationCandles = [int](Get-PropValue -Object $val -Names @('g_MinEMASeparationCandles') -Default (Get-PropValue -Object $is -Names @('g_MinEMASeparationCandles') -Default 0))
      RiskPercentOfBalance = [double](Get-PropValue -Object $val -Names @('g_RiskPercentOfBalance') -Default (Get-PropValue -Object $is -Names @('g_RiskPercentOfBalance') -Default 1.0))
      TakeProfitSLMultiple = [double](Get-PropValue -Object $val -Names @('g_TakeProfitSLMultiple') -Default (Get-PropValue -Object $is -Names @('g_TakeProfitSLMultiple') -Default 0.0))
      MaxStopLossATRMultiple = [double](Get-PropValue -Object $val -Names @('g_MaxStopLossATRMultiple') -Default (Get-PropValue -Object $is -Names @('g_MaxStopLossATRMultiple') -Default 3.0))
    }
  }
}

function Get-CandidateDistance {
  param([object]$A, [object]$B, [hashtable]$Ranges)

  $sum = 0.0
  $count = 0
  foreach ($paramName in $optimizedParameterNames) {
    $inputName = $inputNameByParam[$paramName]
    if (-not $Ranges.ContainsKey($inputName)) { continue }
    $range = $Ranges[$inputName]
    $span = [double]$range.Stop - [double]$range.Start
    if ($span -le 0.0) { continue }
    $av = [double](Get-PropValue -Object $A -Names @($paramName) -Default 0.0)
    $bv = [double](Get-PropValue -Object $B -Names @($paramName) -Default 0.0)
    $sum += [Math]::Abs($av - $bv) / $span
    $count++
  }
  if ($count -le 0) { return 999.0 }
  return $sum / $count
}

function New-CandidateGroups {
  param([object[]]$Candidates, [hashtable]$Ranges)

  $groups = [System.Collections.Generic.List[object]]::new()
  foreach ($candidate in ($Candidates | Sort-Object @{ Expression = 'ValidationScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })) {
    $assigned = $false
    for ($i = 0; $i -lt $groups.Count; $i++) {
      $members = @($groups[$i].Members)
      foreach ($member in $members) {
        if ((Get-CandidateDistance -A $candidate -B $member -Ranges $Ranges) -le $GroupDistanceThreshold) {
          $members += $candidate
          $groups[$i] = [pscustomobject]@{ Members = $members }
          $assigned = $true
          break
        }
      }
      if ($assigned) { break }
    }
    if (-not $assigned) { $groups.Add([pscustomobject]@{ Members = @($candidate) }) }
  }

  $index = 1
  foreach ($group in $groups) {
    $members = @($group.Members)
    $medoid = $members[0]
    $bestAverageDistance = [double]::PositiveInfinity
    foreach ($candidate in $members) {
      $distanceSum = 0.0
      foreach ($other in $members) { $distanceSum += Get-CandidateDistance -A $candidate -B $other -Ranges $Ranges }
      $avgDistance = if ($members.Count -gt 0) { $distanceSum / $members.Count } else { 0.0 }
      if ($avgDistance -lt $bestAverageDistance) {
        $bestAverageDistance = $avgDistance
        $medoid = $candidate
      }
    }

    [pscustomobject]@{
      GroupId = ('G{0:D3}' -f $index)
      GroupSize = $members.Count
      AverageMedoidDistance = [Math]::Round($bestAverageDistance, 6)
      Medoid = $medoid
    }
    $index++
  }
}

function Test-BackForwardScoreGate {
  param([object]$Candidate, [double]$BackThreshold, [double]$ForwardThreshold)

  if ($StrictScoreGates) {
    return ([double]$Candidate.BackScore -gt $BackThreshold -and [double]$Candidate.ForwardScore -gt $ForwardThreshold)
  }

  return ([double]$Candidate.BackScore -ge $BackThreshold -and [double]$Candidate.ForwardScore -ge $ForwardThreshold)
}

function Select-ForwardCandidate {
  param([object[]]$Candidates)

  if ($Candidates.Count -eq 0) { return @() }

  $scoreGateThreshold = ''
  $ranked = switch ($ForwardSelectionMode) {
    'PositiveBestRatio' {
      @($Candidates | Sort-Object @{ Expression = 'ValidationRatio'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'ValidationProfit' {
      @($Candidates | Sort-Object @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationRatio'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'LowestValidationDD' {
      @($Candidates | Sort-Object @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationRatio'; Descending = $true }, @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'HighestValidationPF' {
      @($Candidates | Sort-Object @{ Expression = 'ValidationProfitFactor'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'LowestValidationTrades' {
      @($Candidates | Sort-Object @{ Expression = 'ValidationTrades'; Ascending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ValidationRatio'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenLowestDD' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenHighestProfit' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenHighestTrades' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenHighestTotalTrades' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'SumTradeCount'; Descending = $true }, @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'ISTrades'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenLowestTrades' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationTrades'; Ascending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenHighestPF' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationProfitFactor'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreThenHighestDD' {
      $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $MinBackScore -ForwardThreshold $MinForwardScore })
      @($qualified | Sort-Object @{ Expression = 'ValidationDDPct'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationProfitFactor'; Descending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
    'BackForwardScoreFallbackHighestTrades' {
      foreach ($threshold in @(90.0, 85.0, 80.0, 75.0)) {
        $qualified = @($Candidates | Where-Object { Test-BackForwardScoreGate -Candidate $_ -BackThreshold $threshold -ForwardThreshold $threshold })
        if ($qualified.Count -gt 0) {
          $scoreGateThreshold = $threshold
          @($qualified | Sort-Object @{ Expression = 'ValidationTrades'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'ForwardScore'; Descending = $true }, @{ Expression = 'BackScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
          break
        }
      }
      break
    }
    default {
      @($Candidates | Sort-Object @{ Expression = 'ValidationScore'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'Pass'; Ascending = $true })
      break
    }
  }

  $selected = @($ranked | Select-Object -First 1)
  if ($selected.Count -eq 0) { return @() }

  $selected[0] | Add-Member -NotePropertyName GroupId -NotePropertyValue 'FORWARD' -Force
  $selected[0] | Add-Member -NotePropertyName GroupSize -NotePropertyValue 1 -Force
  $selected[0] | Add-Member -NotePropertyName ScoreGateThreshold -NotePropertyValue $scoreGateThreshold -Force
  $selected[0] | Add-Member -NotePropertyName PerturbationTests -NotePropertyValue '' -Force
  $selected[0] | Add-Member -NotePropertyName ProfitablePerturbations -NotePropertyValue '' -Force
  $selected[0] | Add-Member -NotePropertyName PerturbationProfitRate -NotePropertyValue '' -Force
  $selected[0] | Add-Member -NotePropertyName MedianPerturbationProfit -NotePropertyValue '' -Force
  $selected[0] | Add-Member -NotePropertyName MedianPerturbationRatio -NotePropertyValue '' -Force
  $selected[0] | Add-Member -NotePropertyName CatastrophicPerturbations -NotePropertyValue '' -Force

  return $selected
}

function Copy-CandidateWithChange {
  param([object]$Candidate, [string]$ParamName, $Value, [string]$VariantId)

  $props = [ordered]@{}
  foreach ($prop in $Candidate.PSObject.Properties) { $props[$prop.Name] = $prop.Value }
  $props[$ParamName] = $Value
  $props['PerturbationVariantId'] = $VariantId
  $props['PerturbedParameter'] = $ParamName
  return [pscustomobject]$props
}

function Get-PerturbedValue {
  param([string]$ParamName, [double]$Value, [double]$Factor, [hashtable]$Ranges)

  $inputName = $inputNameByParam[$ParamName]
  $newValue = $Value * $Factor
  if ($integerParams -contains $ParamName) {
    $delta = [Math]::Max(1, [Math]::Abs([int][Math]::Round($Value * ($Factor - 1.0))))
    if ($Factor -gt 1.0) { $newValue = [Math]::Round($Value + $delta) } else { $newValue = [Math]::Round($Value - $delta) }
  }
  if ($Ranges.ContainsKey($inputName)) {
    $range = $Ranges[$inputName]
    $newValue = [Math]::Max([double]$range.Start, [Math]::Min([double]$range.Stop, $newValue))
    if ($integerParams -contains $ParamName -and [double]$range.Step -gt 0) {
      $step = [double]$range.Step
      $newValue = [Math]::Round(([Math]::Round(($newValue - [double]$range.Start) / $step) * $step) + [double]$range.Start)
    }
  }
  if ($integerParams -contains $ParamName) { return [int][Math]::Round($newValue) }
  return [Math]::Round($newValue, 6)
}

function New-PerturbationManifest {
  param([object]$Window, [object[]]$Groups, [string]$ReportSubdir, [hashtable]$Ranges)

  $rows = [System.Collections.Generic.List[object]]::new()
  $index = 1
  foreach ($group in $Groups) {
    $candidate = $group.Medoid
    foreach ($paramName in $optimizedParameterNames) {
      $baseValue = [double](Get-PropValue -Object $candidate -Names @($paramName) -Default 0.0)
      foreach ($direction in @('minus', 'plus')) {
        $factor = if ($direction -eq 'plus') { 1.0 + ($PerturbationPercent / 100.0) } else { 1.0 - ($PerturbationPercent / 100.0) }
        $newValue = Get-PerturbedValue -ParamName $paramName -Value $baseValue -Factor $factor -Ranges $Ranges
        if ([double]$newValue -eq $baseValue) { continue }

        $variantId = "$($group.GroupId)_$($candidate.ManifoldId)_${paramName}_$direction"
        $variant = Copy-CandidateWithChange -Candidate $candidate -ParamName $paramName -Value $newValue -VariantId $variantId
        if ([int]$variant.FastEMALength -ge [int]$variant.SlowEMALength) { continue }

        $dateLabel = ($Window.ValidationStart -replace '\.', '') + '_' + ($Window.ValidationEnd -replace '\.', '')
        $safeVariant = Get-SafeId $variantId
        $report = "$ReportSubdir\perturbation\$($Window.WindowId)_$Symbol`_$safeVariant`_PERT_$dateLabel.xml"
        $rows.Add([pscustomobject]@{
          TestIndex = $index
          TestId = ('{0}_{1:D5}_{2}_PERT' -f $Window.WindowId, $index, $safeVariant)
          WindowIndex = $Window.WindowIndex
          WindowId = $Window.WindowId
          Stage = 'PERT'
          GroupId = $group.GroupId
          GroupSize = $group.GroupSize
          ManifoldId = $candidate.ManifoldId
          Pass = $candidate.Pass
          Symbol = $Symbol
          Segment = 'PERT'
          FromDate = $Window.ValidationStart
          ToDate = $Window.ValidationEnd
          PerturbationVariantId = $variantId
          PerturbedParameter = $paramName
          Report = $report
          ExpectedReport = "$report.htm"
          ATR = $variant.ATR
          MomentumATRMultiplier = $variant.MomentumATRMultiplier
          ContiguousCandles = $variant.ContiguousCandles
          RelVolLength = $variant.RelVolLength
          RelVolSignalCandles = $variant.RelVolSignalCandles
          RelVolThreshold = $variant.RelVolThreshold
          FastEMALength = $variant.FastEMALength
          SlowEMALength = $variant.SlowEMALength
          MinEMASeparationCandles = $variant.MinEMASeparationCandles
          RiskPercentOfBalance = $variant.RiskPercentOfBalance
          TakeProfitSLMultiple = $variant.TakeProfitSLMultiple
          MaxStopLossATRMultiple = $variant.MaxStopLossATRMultiple
          MedoidValidationProfit = $candidate.ValidationProfit
          MedoidValidationDDPct = $candidate.ValidationDDPct
          MedoidValidationRatio = $candidate.ValidationRatio
        })
        $index++
      }
    }
  }
  return $rows
}

function New-OosManifest {
  param([object]$Window, [object]$Selected, [string]$ReportSubdir)

  $dateLabel = ($Window.OosStart -replace '\.', '') + '_' + ($Window.OosEnd -replace '\.', '')
  $report = "$ReportSubdir\oos\$($Window.WindowId)_$Symbol`_$($Selected.ManifoldId)_OOS_0_$($OosMonths)M_$dateLabel.xml"
  return @([pscustomobject]@{
    TestIndex = 1
    TestId = ('{0}_{1:D5}_{2}_OOS_0_{3}M' -f $Window.WindowId, 1, $Selected.ManifoldId, $OosMonths)
    WindowIndex = $Window.WindowIndex
    WindowId = $Window.WindowId
    Stage = 'OOS'
    GroupId = $Selected.GroupId
    GroupSize = $Selected.GroupSize
    ManifoldId = $Selected.ManifoldId
    Pass = $Selected.Pass
    Symbol = $Symbol
    Segment = "OOS_0_$($OosMonths)M"
    FromDate = $Window.OosStart
    ToDate = $Window.OosEnd
    Report = $report
    ExpectedReport = "$report.htm"
    ATR = $Selected.ATR
    MomentumATRMultiplier = $Selected.MomentumATRMultiplier
    ContiguousCandles = $Selected.ContiguousCandles
    RelVolLength = $Selected.RelVolLength
    RelVolSignalCandles = $Selected.RelVolSignalCandles
    RelVolThreshold = $Selected.RelVolThreshold
    FastEMALength = $Selected.FastEMALength
    SlowEMALength = $Selected.SlowEMALength
    MinEMASeparationCandles = $Selected.MinEMASeparationCandles
    RiskPercentOfBalance = $Selected.RiskPercentOfBalance
    TakeProfitSLMultiple = $Selected.TakeProfitSLMultiple
    MaxStopLossATRMultiple = $Selected.MaxStopLossATRMultiple
  })
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

function Append-OptimizerProgress {
  param([object]$Row, [string]$ProgressPath)

  $columns = @(
    'Timestamp',
    'WindowIndex',
    'WindowId',
    'Status',
    'StartedAt',
    'FinishedAt',
    'DurationSeconds',
    'DurationMinutes',
    'OptimizerXml',
    'ForwardXml',
    'Note'
  )

  $rows = @()
  if (Test-Path -LiteralPath $ProgressPath) { $rows += @(Import-Csv -LiteralPath $ProgressPath) }
  $rows += $Row
  $rows | Select-Object $columns | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Encoding ASCII
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
      'Expert=ATRMomentumRelVolEMAFilter\ATRMomentumRelVolEMAFilterEA.ex5',
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
      '; Fixed run generated by MRV EMA forward perturbation generator.',
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
    $ratio = if ($null -ne $metrics.Ratio) { $metrics.Ratio } else { Get-ReportRatio -Profit ([double]$metrics.Profit) -DDPct ([double]$metrics.EquityDDPct) }
    $test | Add-Member -NotePropertyName Profit -NotePropertyValue $metrics.Profit -Force
    $test | Add-Member -NotePropertyName ReturnPct -NotePropertyValue $metrics.ReturnPct -Force
    $test | Add-Member -NotePropertyName EquityDDPct -NotePropertyValue $metrics.EquityDDPct -Force
    $test | Add-Member -NotePropertyName Ratio -NotePropertyValue $ratio -Force
    $test | Add-Member -NotePropertyName Trades -NotePropertyValue $metrics.Trades -Force
    $test | Add-Member -NotePropertyName ProfitFactor -NotePropertyValue $metrics.ProfitFactor -Force
    $test | Add-Member -NotePropertyName WinRatePct -NotePropertyValue $metrics.WinRatePct -Force
    $test | Add-Member -NotePropertyName ReportPath -NotePropertyValue $path -Force
    $test
  }
}

function Get-Median {
  param([double[]]$Values)
  $sorted = @($Values | Sort-Object)
  if ($sorted.Count -eq 0) { return $null }
  $middle = [int][Math]::Floor($sorted.Count / 2)
  if ($sorted.Count % 2 -eq 1) { return $sorted[$middle] }
  return ($sorted[$middle - 1] + $sorted[$middle]) / 2.0
}

function Select-PerturbationCandidate {
  param([object[]]$Groups, [object[]]$PerturbationRows)

  $summaries = [System.Collections.Generic.List[object]]::new()
  foreach ($group in $Groups) {
    $medoid = $group.Medoid
    $rows = @($PerturbationRows | Where-Object { $_.GroupId -eq $group.GroupId })
    if ($rows.Count -eq 0) { continue }
    $profitable = @($rows | Where-Object { [double]$_.Profit -gt 0.0 })
    $catastrophic = @($rows | Where-Object { [double]$_.EquityDDPct -gt $MaxPerturbationDDPct -or [double]$_.EquityDDPct -gt ([double]$medoid.ValidationDDPct * $CatastrophicDDMultiple) })
    $medianProfit = Get-Median -Values @($rows | ForEach-Object { [double]$_.Profit })
    $medianRatio = Get-Median -Values @($rows | ForEach-Object { [double]$_.Ratio })
    $profitRate = $profitable.Count / [Math]::Max(1, $rows.Count)
    $passed = ($profitRate -ge $MinPerturbationProfitRate -and $medianProfit -gt 0.0 -and $medianRatio -gt 0.0 -and $catastrophic.Count -eq 0)

    $summaries.Add([pscustomobject]@{
      GroupId = $group.GroupId
      GroupSize = $group.GroupSize
      ManifoldId = $medoid.ManifoldId
      Pass = $medoid.Pass
      BackScore = $medoid.BackScore
      ForwardScore = $medoid.ForwardScore
      PerturbationTests = $rows.Count
      ProfitablePerturbations = $profitable.Count
      PerturbationProfitRate = [Math]::Round($profitRate, 3)
      MedianPerturbationProfit = [Math]::Round($medianProfit, 2)
      MedianPerturbationRatio = [Math]::Round($medianRatio, 3)
      CatastrophicPerturbations = $catastrophic.Count
      PerturbationPassed = $passed
      ValidationProfit = $medoid.ValidationProfit
      ValidationDDPct = $medoid.ValidationDDPct
      ValidationRatio = $medoid.ValidationRatio
      ValidationTrades = $medoid.ValidationTrades
      ATR = $medoid.ATR
      MomentumATRMultiplier = $medoid.MomentumATRMultiplier
      ContiguousCandles = $medoid.ContiguousCandles
      RelVolLength = $medoid.RelVolLength
      RelVolSignalCandles = $medoid.RelVolSignalCandles
      RelVolThreshold = $medoid.RelVolThreshold
      FastEMALength = $medoid.FastEMALength
      SlowEMALength = $medoid.SlowEMALength
      MinEMASeparationCandles = $medoid.MinEMASeparationCandles
      RiskPercentOfBalance = $medoid.RiskPercentOfBalance
      TakeProfitSLMultiple = $medoid.TakeProfitSLMultiple
      MaxStopLossATRMultiple = $medoid.MaxStopLossATRMultiple
    })
  }

  $ranked = @($summaries | Sort-Object @{ Expression = 'PerturbationPassed'; Descending = $true }, @{ Expression = 'PerturbationProfitRate'; Descending = $true }, @{ Expression = 'MedianPerturbationRatio'; Descending = $true }, @{ Expression = 'ValidationRatio'; Descending = $true }, @{ Expression = 'ValidationProfit'; Descending = $true }, @{ Expression = 'ValidationDDPct'; Ascending = $true }, @{ Expression = 'GroupSize'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
  return [pscustomobject]@{ Ranked = $ranked; Selected = @($ranked | Where-Object { $_.PerturbationPassed -eq $true } | Select-Object -First 1) }
}

function Export-Selection {
  param([object]$Window, [object]$Selected, [string]$Status, [string]$Path)

  $row = [pscustomobject]@{
    WindowIndex = $Window.WindowIndex
    WindowId = $Window.WindowId
    Symbol = $Symbol
    ISStart = $Window.ISStart
    ISEnd = $Window.ISEnd
    ValidationStart = $Window.ValidationStart
    ValidationEnd = $Window.ValidationEnd
    OosStart = $Window.OosStart
    OosEnd = $Window.OosEnd
    SelectionStatus = $Status
    GroupId = if ($null -ne $Selected) { $Selected.GroupId } else { '' }
    GroupSize = if ($null -ne $Selected) { $Selected.GroupSize } else { '' }
    ManifoldId = if ($null -ne $Selected) { $Selected.ManifoldId } else { '' }
    Pass = if ($null -ne $Selected) { $Selected.Pass } else { '' }
    BackScore = if ($null -ne $Selected) { $Selected.BackScore } else { '' }
    ForwardScore = if ($null -ne $Selected) { $Selected.ForwardScore } else { '' }
    ScoreGateThreshold = if ($null -ne $Selected -and $null -ne $Selected.PSObject.Properties['ScoreGateThreshold']) { $Selected.ScoreGateThreshold } else { '' }
    PerturbationTests = if ($null -ne $Selected) { $Selected.PerturbationTests } else { '' }
    ProfitablePerturbations = if ($null -ne $Selected) { $Selected.ProfitablePerturbations } else { '' }
    PerturbationProfitRate = if ($null -ne $Selected) { $Selected.PerturbationProfitRate } else { '' }
    MedianPerturbationProfit = if ($null -ne $Selected) { $Selected.MedianPerturbationProfit } else { '' }
    MedianPerturbationRatio = if ($null -ne $Selected) { $Selected.MedianPerturbationRatio } else { '' }
    CatastrophicPerturbations = if ($null -ne $Selected) { $Selected.CatastrophicPerturbations } else { '' }
    ValidationProfit = if ($null -ne $Selected) { $Selected.ValidationProfit } else { '' }
    ValidationDDPct = if ($null -ne $Selected) { $Selected.ValidationDDPct } else { '' }
    ValidationRatio = if ($null -ne $Selected) { $Selected.ValidationRatio } else { '' }
    ISTrades = if ($null -ne $Selected) { $Selected.ISTrades } else { '' }
    ValidationTrades = if ($null -ne $Selected) { $Selected.ValidationTrades } else { '' }
    SumTradeCount = if ($null -ne $Selected) { $Selected.SumTradeCount } else { '' }
    ATR = if ($null -ne $Selected) { $Selected.ATR } else { '' }
    MomentumATRMultiplier = if ($null -ne $Selected) { $Selected.MomentumATRMultiplier } else { '' }
    ContiguousCandles = if ($null -ne $Selected) { $Selected.ContiguousCandles } else { '' }
    RelVolLength = if ($null -ne $Selected) { $Selected.RelVolLength } else { '' }
    RelVolSignalCandles = if ($null -ne $Selected) { $Selected.RelVolSignalCandles } else { '' }
    RelVolThreshold = if ($null -ne $Selected) { $Selected.RelVolThreshold } else { '' }
    FastEMALength = if ($null -ne $Selected) { $Selected.FastEMALength } else { '' }
    SlowEMALength = if ($null -ne $Selected) { $Selected.SlowEMALength } else { '' }
    MinEMASeparationCandles = if ($null -ne $Selected) { $Selected.MinEMASeparationCandles } else { '' }
    RiskPercentOfBalance = if ($null -ne $Selected) { $Selected.RiskPercentOfBalance } else { '' }
    TakeProfitSLMultiple = if ($null -ne $Selected) { $Selected.TakeProfitSLMultiple } else { '' }
    MaxStopLossATRMultiple = if ($null -ne $Selected) { $Selected.MaxStopLossATRMultiple } else { '' }
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
$sourceOptimizerReportSubdir = if ([string]::IsNullOrWhiteSpace($SourceOptimizerExperimentId)) { $reportSubdir } else { "reports\$SourceOptimizerExperimentId" }
$windowsPath = Join-Path $experimentDir 'windows.csv'
$selectionSummaryPath = Join-Path $experimentDir 'selection_summary.csv'
$oosSummaryPath = Join-Path $experimentDir 'oos_summary.csv'
$fixedProgressPath = Join-Path $experimentDir 'fixed_test_progress.csv'
$optimizerProgressPath = Join-Path $experimentDir 'optimizer_progress.csv'

if (-not (Test-Path -LiteralPath $experimentDir)) { New-Item -ItemType Directory -Path $experimentDir -Force | Out-Null }
foreach ($subdir in @('optimizer', 'perturbation', 'oos')) {
  $full = Join-Path $terminalDataRoot "$reportSubdir\$subdir"
  if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Path $full -Force | Out-Null }
}

if (-not (Test-Path -LiteralPath $templateSetPath)) { throw "Template set file not found: $templateSetPath" }
if (-not (Test-Path -LiteralPath $TerminalPath) -and -not $PrepareOnly) { throw "MT5 terminal not found: $TerminalPath" }
if ($ISMonths -le 0 -or $ValidationMonths -le 0 -or $OosMonths -le 0 -or $StepMonths -le 0) { throw 'Window lengths must be positive.' }
if ($ISMonths -ne $ValidationMonths) { throw 'This runner uses ForwardMode=1, so ISMonths and ValidationMonths must be equal.' }
if ($GroupDistanceThreshold -lt 0.0) { throw 'GroupDistanceThreshold must be non-negative.' }
if ($PerturbationPercent -le 0.0) { throw 'PerturbationPercent must be positive.' }

$ranges = Get-OptimizerRanges -SetPath $templateSetPath
$windows = @(New-Windows)
$windows | Export-Csv -LiteralPath $windowsPath -NoTypeInformation -Encoding ASCII

Write-Host "Experiment: $ExperimentId"
Write-Host "Directory: $experimentDir"
if ($sourceOptimizerReportSubdir -ne $reportSubdir) { Write-Host "Source optimizer reports: $sourceOptimizerReportSubdir" }
Write-Host "Symbol: $Symbol $Period"
Write-Host "Hyperparameters: IS=$ISMonths months, VAL=$ValidationMonths months via MT5 forward, OOS=$OosMonths months, step=$StepMonths month(s)"
Write-Host "Validation gates: IS profit > $MinISProfit, IS DD <= $MaxISDDPct%, IS trades >= $MinISTrades; VAL profit > $MinValidationProfit, VAL PF >= $MinValidationProfitFactor, VAL DD <= $MaxValidationDDPct%, VAL trades >= $MinValidationTrades"
if ($SkipPerturbation) {
  $scoreOperator = if ($StrictScoreGates) { '>' } else { '>=' }
  Write-Host "Forward selection mode: $ForwardSelectionMode. Score gates: back $scoreOperator $MinBackScore, forward $scoreOperator $MinForwardScore. Perturbation stage disabled."
} else {
  Write-Host "Perturbation: +/-$PerturbationPercent% one-parameter variants, pass rate >= $MinPerturbationProfitRate, max DD <= $MaxPerturbationDDPct% and <= $CatastrophicDDMultiple x medoid VAL DD"
}
Write-Host "Windows: $($windows.Count) ($($windows[0].OosStart) -> $($windows[-1].OosStart))"

if ($PrepareOnly) {
  $firstRunnable = @($windows | Where-Object { [int]$_.WindowIndex -ge $StartAtWindow } | Select-Object -First 1)
  if ($firstRunnable.Count -gt 0) {
    $dateLabel = ($firstRunnable[0].OptimizerStart -replace '\.', '') + '_' + ($firstRunnable[0].OptimizerEnd -replace '\.', '')
    $optimizerReport = "$reportSubdir\optimizer\$($firstRunnable[0].WindowId)_$Symbol`_$Period`_GeneticForward_$dateLabel.xml"
    New-ForwardOptimizerConfig -Window $firstRunnable[0] -ConfigPath $TempConfigPath -Report $optimizerReport -TemplateSetFileName $TemplateSetFile
  }
  Write-Host 'PrepareOnly set. No MT5 optimizers or fixed tests were run.'
  return
}

$windowsProcessedThisSession = 0
$fixedTestsRunThisSession = 0

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

  $dateLabel = ($window.OptimizerStart -replace '\.', '') + '_' + ($window.OptimizerEnd -replace '\.', '')
  $optimizerReport = "$reportSubdir\optimizer\$($window.WindowId)_$Symbol`_$Period`_GeneticForward_$dateLabel.xml"
  $sourceOptimizerReport = "$sourceOptimizerReportSubdir\optimizer\$($window.WindowId)_$Symbol`_$Period`_GeneticForward_$dateLabel.xml"
  $sourceForwardReport = Get-ForwardReportName -Report $sourceOptimizerReport
  $optimizerXml = Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $sourceOptimizerReport
  $forwardXml = Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $sourceForwardReport

  if (-not (Test-Path -LiteralPath $optimizerXml) -or -not (Test-Path -LiteralPath $forwardXml)) {
    if ($sourceOptimizerReportSubdir -ne $reportSubdir) {
      throw "Source optimizer/forward reports missing for $($window.WindowId): $optimizerXml / $forwardXml"
    }
    $forwardReport = Get-ForwardReportName -Report $optimizerReport
    $optimizerRun = Invoke-ForwardOptimizerRun -Window $window -ConfigPath $TempConfigPath -Report $optimizerReport -ExpectedOptimizerPath $optimizerXml -ExpectedForwardPath $forwardXml -TemplateSetFileName $TemplateSetFile
    Append-OptimizerProgress -ProgressPath $optimizerProgressPath -Row ([pscustomobject]@{
      Timestamp = $optimizerRun.FinishedAt
      WindowIndex = $window.WindowIndex
      WindowId = $window.WindowId
      Status = 'Completed'
      StartedAt = $optimizerRun.StartedAt
      FinishedAt = $optimizerRun.FinishedAt
      DurationSeconds = $optimizerRun.DurationSeconds
      DurationMinutes = $optimizerRun.DurationMinutes
      OptimizerXml = $optimizerXml
      ForwardXml = $forwardXml
      Note = $optimizerRun.Note
    })
  } else {
    Write-Host "Optimizer and forward reports already exist: $optimizerXml"
  }

  $optimizerRows = @(Read-Mt5Spreadsheet -Path $optimizerXml)
  $forwardRows = @(Read-Mt5Spreadsheet -Path $forwardXml)
  $allCandidates = @(New-ForwardCandidates -OptimizerRows $optimizerRows -ForwardRows $forwardRows)
  $allCandidates | Export-Csv -LiteralPath (Join-Path $windowDir 'forward_candidates_all.csv') -NoTypeInformation -Encoding ASCII

  $survivors = @($allCandidates | Where-Object {
    [double]$_.ISProfit -gt $MinISProfit -and
    [double]$_.ISDD -le $MaxISDDPct -and
    [int]$_.ISTrades -ge $MinISTrades -and
    [double]$_.ValidationProfit -gt $MinValidationProfit -and
    [double]$_.ValidationProfitFactor -ge $MinValidationProfitFactor -and
    [double]$_.ValidationDDPct -le $MaxValidationDDPct -and
    [int]$_.ValidationTrades -ge $MinValidationTrades
  } | Sort-Object @{ Expression = 'ValidationScore'; Descending = $true }, @{ Expression = 'Pass'; Ascending = $true })
  $survivors | Export-Csv -LiteralPath (Join-Path $windowDir 'forward_candidates_survivors.csv') -NoTypeInformation -Encoding ASCII

  if ($survivors.Count -eq 0) {
    Write-Host "No candidates passed IS/VAL gates for $($window.WindowId). OOS skipped."
    Export-Selection -Window $window -Selected $null -Status 'NoForwardCandidatesPassedGates' -Path (Join-Path $windowDir 'selected_candidate.csv')
    $windowsProcessedThisSession++
    continue
  }

  if ($SkipPerturbation) {
    $selected = @(Select-ForwardCandidate -Candidates $survivors | Select-Object -First 1)
    if ($selected.Count -eq 0) {
      Write-Host "No forward candidate selected for $($window.WindowId). OOS skipped."
      Export-Selection -Window $window -Selected $null -Status 'NoForwardCandidateSelected' -Path (Join-Path $windowDir 'selected_candidate.csv')
      $windowsProcessedThisSession++
      continue
    }

    Export-Selection -Window $window -Selected $selected[0] -Status "SelectedOneForwardCandidate_$ForwardSelectionMode" -Path (Join-Path $windowDir 'selected_candidate.csv')
    Write-Host "Selected forward candidate: $($selected[0].ManifoldId) mode=$ForwardSelectionMode VAL profit=$($selected[0].ValidationProfit) DD=$($selected[0].ValidationDDPct)% ratio=$($selected[0].ValidationRatio)"

    $oosManifest = @(New-OosManifest -Window $window -Selected $selected[0] -ReportSubdir $reportSubdir)
    $oosManifest | Export-Csv -LiteralPath (Join-Path $windowDir 'oos_manifest.csv') -NoTypeInformation -Encoding ASCII
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
    $oosRows | Export-Csv -LiteralPath (Join-Path $windowDir 'oos_results.csv') -NoTypeInformation -Encoding ASCII
    Write-Host "OOS metrics recorded for $($window.WindowId). OOS profitability is not a stop condition."
    $windowsProcessedThisSession++
    continue
  }

  $groups = @(New-CandidateGroups -Candidates $survivors -Ranges $ranges)
  if ($MaxGroupsToPerturb -gt 0) { $groups = @($groups | Select-Object -First $MaxGroupsToPerturb) }
  $groups | ForEach-Object {
    [pscustomobject]@{
      GroupId = $_.GroupId
      GroupSize = $_.GroupSize
      AverageMedoidDistance = $_.AverageMedoidDistance
      ManifoldId = $_.Medoid.ManifoldId
      Pass = $_.Medoid.Pass
      BackScore = $_.Medoid.BackScore
      ForwardScore = $_.Medoid.ForwardScore
      ValidationProfit = $_.Medoid.ValidationProfit
      ValidationDDPct = $_.Medoid.ValidationDDPct
      ValidationRatio = $_.Medoid.ValidationRatio
      ISTrades = $_.Medoid.ISTrades
      ValidationTrades = $_.Medoid.ValidationTrades
      SumTradeCount = $_.Medoid.SumTradeCount
      ATR = $_.Medoid.ATR
      MomentumATRMultiplier = $_.Medoid.MomentumATRMultiplier
      ContiguousCandles = $_.Medoid.ContiguousCandles
      RelVolLength = $_.Medoid.RelVolLength
      RelVolSignalCandles = $_.Medoid.RelVolSignalCandles
      RelVolThreshold = $_.Medoid.RelVolThreshold
      FastEMALength = $_.Medoid.FastEMALength
      SlowEMALength = $_.Medoid.SlowEMALength
      MinEMASeparationCandles = $_.Medoid.MinEMASeparationCandles
      RiskPercentOfBalance = $_.Medoid.RiskPercentOfBalance
      TakeProfitSLMultiple = $_.Medoid.TakeProfitSLMultiple
      MaxStopLossATRMultiple = $_.Medoid.MaxStopLossATRMultiple
    }
  } | Export-Csv -LiteralPath (Join-Path $windowDir 'candidate_groups.csv') -NoTypeInformation -Encoding ASCII

  $perturbationManifest = @(New-PerturbationManifest -Window $window -Groups $groups -ReportSubdir $reportSubdir -Ranges $ranges)
  $perturbationManifest | Export-Csv -LiteralPath (Join-Path $windowDir 'perturbation_manifest.csv') -NoTypeInformation -Encoding ASCII

  if ($perturbationManifest.Count -eq 0) {
    Write-Host "No valid perturbation tests generated for $($window.WindowId). OOS skipped."
    Export-Selection -Window $window -Selected $null -Status 'NoPerturbationTestsGenerated' -Path (Join-Path $windowDir 'selected_candidate.csv')
    $windowsProcessedThisSession++
    continue
  }

  if ($MaxFixedTests -gt 0 -and $fixedTestsRunThisSession -ge $MaxFixedTests) {
    Write-Host "Fixed-test session limit reached before perturbation stage completed for $($window.WindowId). Rerun the same command to resume."
    return
  }
  $remainingFixed = if ($MaxFixedTests -gt 0) { $MaxFixedTests - $fixedTestsRunThisSession } else { -1 }
  $fixedTestsRunThisSession += Invoke-TestManifest -Manifest $perturbationManifest -ProgressPath $fixedProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -RemainingFixedTests $remainingFixed
  $perturbationMissing = @($perturbationManifest | Where-Object { -not (Test-Path -LiteralPath (Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $_.ExpectedReport)) })
  if ($perturbationMissing.Count -gt 0) {
    Write-Host "Perturbation stage incomplete for $($window.WindowId). Missing reports: $($perturbationMissing.Count). Rerun the same command to resume."
    return
  }

  $perturbationRows = @(Read-ManifestReportRows -Manifest $perturbationManifest -ReportRoot $reportRoot)
  $perturbationRows | Export-Csv -LiteralPath (Join-Path $windowDir 'perturbation_results.csv') -NoTypeInformation -Encoding ASCII
  $selectionResult = Select-PerturbationCandidate -Groups $groups -PerturbationRows $perturbationRows
  $rankedPerturbation = @($selectionResult.Ranked)
  $rankedPerturbation | Export-Csv -LiteralPath (Join-Path $windowDir 'perturbation_group_summary.csv') -NoTypeInformation -Encoding ASCII
  $selected = @($selectionResult.Selected | Select-Object -First 1)

  if ($selected.Count -eq 0) {
    Write-Host "No group medoid passed perturbation gates for $($window.WindowId). OOS skipped."
    Export-Selection -Window $window -Selected $null -Status 'NoPerturbationCandidatePassedGates' -Path (Join-Path $windowDir 'selected_candidate.csv')
    $windowsProcessedThisSession++
    continue
  }

  Export-Selection -Window $window -Selected $selected[0] -Status 'SelectedOnePerturbationRobustMedoid' -Path (Join-Path $windowDir 'selected_candidate.csv')
  Write-Host "Selected perturbation-robust medoid: $($selected[0].ManifoldId) group=$($selected[0].GroupId) passRate=$($selected[0].PerturbationProfitRate) medianRatio=$($selected[0].MedianPerturbationRatio)"

  $oosManifest = @(New-OosManifest -Window $window -Selected $selected[0] -ReportSubdir $reportSubdir)
  $oosManifest | Export-Csv -LiteralPath (Join-Path $windowDir 'oos_manifest.csv') -NoTypeInformation -Encoding ASCII
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
  $oosRows | Export-Csv -LiteralPath (Join-Path $windowDir 'oos_results.csv') -NoTypeInformation -Encoding ASCII
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
Write-Host 'Rerun the same command to resume from existing optimizer, forward, perturbation, and OOS reports.'
