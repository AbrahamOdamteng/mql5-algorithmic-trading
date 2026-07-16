param(
  [string]$TerminalPath = 'C:\Program Files\MetaTrader 5\terminal64.exe',
  [string]$CycleId = '',
  [string]$ResultRoot = '',
  [string]$DiscoverySymbol = 'EURUSD',
  [string[]]$Symbols = @(),
  [string]$OptimizationStart,
  [string]$OptimizationEnd,
  [string]$ValidationStart,
  [string]$ValidationEnd,
  [string]$DeployStart,
  [string]$DeployEnd,
  [string]$TemplateSetFile = 'ImpulseContinuation_EURUSD_FTMO_Genetic.set',
  [string]$TempSetFile = 'ImpulseContinuation_RollingManifold_Current.set',
  [string]$TempConfigPath = (Join-Path $PSScriptRoot 'rolling_manifold_current.ini'),
  [string]$ExistingOptimizerXml = '',
  [int]$TopCandidateCount = 25,
  [int]$MaxCandidatesAfterSanity = 10,
  [double]$CandidateMinRatio = 2.0,
  [double]$CandidateMaxDrawdownPct = 30.0,
  [int]$CandidateMinTrades = 50,
  [double]$SanityMinRatio = 1.0,
  [double]$SanityMaxDrawdownPct = 60.0,
  [int]$SanityMinPassingSymbols = 2,
  [switch]$SanityRequireDiscoverySymbol,
  [double]$ValidationMinRatio = 2.0,
  [double]$ValidationMaxDrawdownPct = 30.0,
  [int]$ValidationMinPassingSymbols = 2,
  [switch]$ValidationRequireDiscoverySymbol,
  [switch]$AllowValidationWithoutDiscoverySymbol,
  [double]$StartingDeposit = 100000.0,
  [double]$RiskPercentage = 1.0,
  [int]$OptimizationTimeoutMinutes = 1440,
  [int]$MaxRuntimeMinutes = 10,
  [int]$PollSeconds = 30,
  [int]$StartAtIndex = 1,
  [int]$MaxTests = 0,
  [switch]$SkipOptimizationRun,
  [switch]$SkipFixedRuns,
  [switch]$PrepareOnly,
  [switch]$RunExistingReports,
  [switch]$ClearTesterCache
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$testerCachePath = 'C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\D0E8209F77C8CF37AD8BF550E51FF075\Tester\cache\*'

function Assert-DateText {
  param([string]$Name, [string]$Value)

  if ([string]::IsNullOrWhiteSpace($Value)) {
    throw "$Name is required. Use MT5 date format such as 2012.01.01."
  }
  if ($Value -notmatch '^\d{4}\.\d{2}\.\d{2}$') {
    throw "$Name must use MT5 date format yyyy.MM.dd. Value: $Value"
  }
}

function Expand-FilterValues {
  param([string[]]$Values)

  @($Values | ForEach-Object {
    $_ -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  })
}

function Get-Fx28Symbols {
  @(
    'EURUSD', 'GBPUSD', 'USDJPY', 'USDCHF', 'USDCAD', 'AUDUSD', 'NZDUSD',
    'EURGBP', 'EURJPY', 'EURCHF', 'EURCAD', 'EURAUD', 'EURNZD',
    'GBPJPY', 'GBPCHF', 'GBPCAD', 'GBPAUD', 'GBPNZD',
    'CHFJPY', 'CADJPY', 'AUDJPY', 'NZDJPY',
    'CADCHF', 'AUDCHF', 'NZDCHF',
    'AUDCAD', 'NZDCAD', 'AUDNZD'
  )
}

function Get-SafeId {
  param([string]$Text)

  return ($Text -replace '[^A-Za-z0-9_\-]', '_')
}

function Get-DateLabel {
  param([string]$FromDate, [string]$ToDate)

  return (($FromDate -replace '\.', '') + '_' + ($ToDate -replace '\.', ''))
}

function Convert-ReportPathToFullPath {
  param([string]$ReportRoot, [string]$ExpectedReport)

  $relative = $ExpectedReport -replace '/', '\'
  return Join-Path $ReportRoot $relative
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

  $result = New-Object System.Collections.Generic.List[object]
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

  return $result.ToArray()
}

function Get-PropValue {
  param(
    [Parameter(Mandatory = $true)]$Object,
    [string[]]$Names,
    $Default = $null
  )

  foreach ($name in $Names) {
    if ($Object.PSObject.Properties.Name -contains $name) {
      $value = $Object.$name
      if ($null -ne $value -and "$value" -ne '') {
        return $value
      }
    }
  }

  return $Default
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

function Round-Nullable {
  param($Value, [int]$Digits = 2)

  if ($null -eq $Value) {
    return $null
  }

  return [Math]::Round([double]$Value, $Digits)
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
    ProfitFactor = Round-Nullable (Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Profit Factor'))
    Recovery = Round-Nullable (Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Recovery Factor'))
    Sharpe = Round-Nullable (Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Sharpe Ratio'))
    GrossProfit = Round-Nullable (Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Gross Profit'))
    GrossLoss = Round-Nullable (Convert-Mt5Number (Get-ReportMetric -Html $html -Label 'Gross Loss'))
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
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [string]$Name,
    [string]$Value,
    [switch]$PlainString
  )

  if ($null -eq $Value) {
    return
  }

  $line = "$Name=$Value||$Value||0||$Value||N"
  if ($PlainString) {
    $line = "$Name=$Value"
  }

  for ($i = 0; $i -lt $Lines.Count; $i++) {
    if ($Lines[$i] -like "$Name=*") {
      $Lines[$i] = $line
      return
    }
  }

  $Lines.Add($line)
}

function Set-CandidateInputIfPresent {
  param(
    [System.Collections.Generic.List[string]]$Lines,
    [object]$Candidate,
    [string]$InputName,
    [string[]]$CandidateNames
  )

  $value = Get-PropValue -Object $Candidate -Names $CandidateNames -Default $null
  if ($null -ne $value -and "$value" -ne '') {
    Set-InputLine -Lines $Lines -Name $InputName -Value "$value"
  }
}

function New-TestSetFile {
  param(
    [object]$Test,
    [string]$TemplateSetPath,
    [string]$TempSetPath,
    [string]$TempSetFileName,
    [bool]$EnableCsv,
    [double]$RiskPct
  )

  $encoding = Get-SetFileEncoding -Path $TemplateSetPath
  $lines = [System.Collections.Generic.List[string]]::new()
  foreach ($line in [System.IO.File]::ReadAllLines($TemplateSetPath, $encoding)) {
    $lines.Add($line)
  }

  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_HighLowPeriod' -CandidateNames @('g_HighLowPeriod', 'HighLowPeriod')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_HighLowPeriodOptimizationIndex' -CandidateNames @('g_HighLowPeriodOptimizationIndex', 'HighLowPeriodOptimizationIndex')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_ATR_Period' -CandidateNames @('g_ATR_Period', 'ATRPeriod')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_MinClusterSize' -CandidateNames @('g_MinClusterSize', 'MinCluster')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_ATR_Cluster_multiplier' -CandidateNames @('g_ATR_Cluster_multiplier', 'ClusterMult')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_ATR_StopLoss_multiplier' -CandidateNames @('g_ATR_StopLoss_multiplier', 'StopLossMult')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_impulse_lookback_hours' -CandidateNames @('g_impulse_lookback_hours', 'ImpulseLookback')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_pullback_lookforward_hours' -CandidateNames @('g_pullback_lookforward_hours', 'PullbackLookforward')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_Impulse_ATR_multiplier' -CandidateNames @('g_Impulse_ATR_multiplier', 'ImpulseMult')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_MinPullback_ATR_multiplier' -CandidateNames @('g_MinPullback_ATR_multiplier', 'PullbackMult')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_TakeProfitMultiplier' -CandidateNames @('g_TakeProfitMultiplier', 'TP')
  Set-CandidateInputIfPresent -Lines $lines -Candidate $Test -InputName 'g_TradeDirectionMode' -CandidateNames @('g_TradeDirectionMode', 'TradeDirectionMode')

  Set-InputLine -Lines $lines -Name 'g_Risk_Percentage' -Value ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, '{0}', $RiskPct))
  Set-InputLine -Lines $lines -Name 'g_EnableTradeCsvLogging' -Value ($(if ($EnableCsv) { 'true' } else { 'false' }))
  Set-InputLine -Lines $lines -Name 'g_TradeCsvManifoldId' -Value $Test.ManifoldId -PlainString
  Set-InputLine -Lines $lines -Name 'g_TradeCsvTestId' -Value $Test.TestId -PlainString

  [System.IO.File]::WriteAllLines($TempSetPath, $lines, $encoding)
  return $TempSetFileName
}

function New-OptimizerConfig {
  param(
    [string]$Path,
    [string]$Symbol,
    [string]$FromDate,
    [string]$ToDate,
    [string]$SetFile,
    [string]$Report
  )

  $configContent = @(
    '[Tester]',
    'Expert=WeekHighLow\WeekHighLowEA.ex5',
    "Symbol=$Symbol",
    'Period=H1',
    '',
    "FromDate=$FromDate",
    "ToDate=$ToDate",
    '',
    'Model=4',
    'Optimization=2',
    'Visual=0',
    '',
    "ExpertParameters=$SetFile",
    "Report=$Report",
    '',
    '; ForwardMode intentionally omitted for rolling-manifold discovery.',
    'OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )

  $configContent | Set-Content -LiteralPath $Path -Encoding ASCII
}

function New-FixedConfigContent {
  param([object]$Test, [string]$ExpertParameters)

  @(
    '[Tester]',
    'Expert=WeekHighLow\WeekHighLowEA.ex5',
    "Symbol=$($Test.Symbol)",
    'Period=H1',
    '',
    "FromDate=$($Test.FromDate)",
    "ToDate=$($Test.ToDate)",
    '',
    'Model=4',
    'Optimization=0',
    'Visual=0',
    '',
    "ExpertParameters=$ExpertParameters",
    "Report=$($Test.Report)",
    '',
    '; ForwardMode=2',
    '; OptimizationCriterion=7',
    '',
    'ShutdownTerminal=1'
  )
}

function Invoke-Mt5Config {
  param(
    [string]$ConfigPath,
    [string]$ExpectedReportPath,
    [int]$TimeoutMinutes,
    [string]$Description
  )

  if (-not (Test-Path -LiteralPath $TerminalPath)) {
    throw "MT5 terminal not found: $TerminalPath"
  }

  Write-Host "Starting $Description"
  $startTime = Get-Date
  $status = 'FailedNoReport'
  $note = ''
  $process = Start-Process -FilePath $TerminalPath -ArgumentList "/config:`"$ConfigPath`"" -PassThru

  while (-not $process.HasExited) {
    Start-Sleep -Seconds $PollSeconds
    $process.Refresh()
    $elapsed = (Get-Date) - $startTime
    if ($elapsed.TotalMinutes -ge $TimeoutMinutes) {
      $status = 'TimedOut'
      $note = "Timeout after $TimeoutMinutes minutes."
      Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
      break
    }
  }

  Start-Sleep -Seconds 2
  $duration = ((Get-Date) - $startTime).TotalSeconds
  if (Test-Path -LiteralPath $ExpectedReportPath) {
    $status = 'Completed'
    if (-not $note) {
      $note = 'Expected report file found.'
    }
  } elseif (-not $note) {
    $note = 'MT5 exited but expected report was not found.'
  }

  return [pscustomobject]@{
    Status = $status
    DurationSeconds = [math]::Round($duration, 2)
    ReportPath = $ExpectedReportPath
    Note = $note
  }
}

function Append-Progress {
  param(
    [string]$ProgressPath,
    [object]$Test,
    [string]$Status,
    [double]$DurationSeconds,
    [string]$ReportPath,
    [string]$Note
  )

  $row = [pscustomobject]@{
    Timestamp = (Get-Date).ToString('s')
    TestIndex = $Test.TestIndex
    TestId = $Test.TestId
    ManifoldId = $Test.ManifoldId
    Pass = $Test.Pass
    Symbol = $Test.Symbol
    Stage = $Test.Stage
    FromDate = $Test.FromDate
    ToDate = $Test.ToDate
    Status = $Status
    DurationSeconds = [math]::Round($DurationSeconds, 2)
    ReportPath = $ReportPath
    Note = $Note
  }

  if (Test-Path -LiteralPath $ProgressPath) {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Append -Encoding ASCII
  } else {
    $row | Export-Csv -LiteralPath $ProgressPath -NoTypeInformation -Encoding ASCII
  }
}

function Invoke-FixedManifest {
  param(
    [object[]]$Manifest,
    [string]$ProgressPath,
    [string]$ReportRoot,
    [string]$TemplateSetPath,
    [string]$TempSetPath,
    [string]$TempSetFileName,
    [bool]$EnableCsv
  )

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
  $overallStart = Get-Date

  foreach ($test in $Manifest) {
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
        Append-Progress -ProgressPath $ProgressPath -Test $test -Status 'SkippedExistingReport' -DurationSeconds 0 -ReportPath $expectedReportPath -Note 'Report already existed before run.'
      }
      continue
    }

    Write-Host ''
    Write-Host '====================================='
    Write-Host "Running $($test.TestIndex)/$($Manifest.Count): $($test.TestId)"
    Write-Host "$($test.Symbol) $($test.Stage) $($test.FromDate) -> $($test.ToDate)"
    Write-Host '====================================='

    if ($ClearTesterCache) {
      Write-Host 'Clearing tester cache'
      Remove-Item $testerCachePath -Recurse -Force -ErrorAction SilentlyContinue
      Start-Sleep -Seconds 5
    }

    $expertParameters = New-TestSetFile -Test $test -TemplateSetPath $TemplateSetPath -TempSetPath $TempSetPath -TempSetFileName $TempSetFileName -EnableCsv $EnableCsv -RiskPct $RiskPercentage
    $configContent = New-FixedConfigContent -Test $test -ExpertParameters $expertParameters
    $configContent | Set-Content -LiteralPath $TempConfigPath -Encoding ASCII

    $result = Invoke-Mt5Config -ConfigPath $TempConfigPath -ExpectedReportPath $expectedReportPath -TimeoutMinutes $MaxRuntimeMinutes -Description $test.TestId
    Append-Progress -ProgressPath $ProgressPath -Test $test -Status $result.Status -DurationSeconds $result.DurationSeconds -ReportPath $result.ReportPath -Note $result.Note
    $testsRunThisSession++

    Write-Host "Finished $($test.TestId): $($result.Status)"
    Write-Host "Test duration: $([TimeSpan]::FromSeconds($result.DurationSeconds).ToString())"
    Write-Host "Total elapsed: $(((Get-Date) - $overallStart).ToString())"
  }

  Write-Host "Tests run this session: $testsRunThisSession"
}

function Get-MissingManifestReports {
  param([object[]]$Manifest, [string]$ReportRoot)

  @($Manifest | Where-Object {
    $expectedReportPath = Convert-ReportPathToFullPath -ReportRoot $ReportRoot -ExpectedReport $_.ExpectedReport
    -not (Test-Path -LiteralPath $expectedReportPath)
  })
}

function Get-SumProperty {
  param([object[]]$Rows, [string]$PropertyName)

  $sum = 0.0
  foreach ($row in @($Rows)) {
    if ($row.PSObject.Properties.Name -contains $PropertyName -and $null -ne $row.$PropertyName) {
      $sum += [double]$row.$PropertyName
    }
  }

  return $sum
}

function Get-MaxProperty {
  param([object[]]$Rows, [string]$PropertyName)

  $hasValue = $false
  $max = 0.0
  foreach ($row in @($Rows)) {
    if ($row.PSObject.Properties.Name -contains $PropertyName -and $null -ne $row.$PropertyName) {
      $value = [double]$row.$PropertyName
      if (-not $hasValue -or $value -gt $max) {
        $max = $value
        $hasValue = $true
      }
    }
  }

  return $max
}

function New-CandidateRowsFromOptimizer {
  param([object[]]$OptimizerRows)

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($row in $OptimizerRows) {
    $profit = [double](Get-PropValue -Object $row -Names @('Profit') -Default 0.0)
    $dd = [double](Get-PropValue -Object $row -Names @('Equity DD %') -Default 0.0)
    $trades = [int](Get-PropValue -Object $row -Names @('Trades') -Default 0)
    $ratio = if ($dd -gt 0) { [Math]::Round(($profit / ($StartingDeposit / 100.0)) / $dd, 3) } else { [double]::PositiveInfinity }
    $pass = [int](Get-PropValue -Object $row -Names @('Pass') -Default 0)
    $manifoldId = "${CycleId}_Pass$pass"

    $rows.Add([pscustomobject]@{
      ManifoldId = $manifoldId
      Pass = $pass
      OptimizerProfit = [Math]::Round($profit, 2)
      OptimizerDD = [Math]::Round($dd, 2)
      OptimizerRatio = $ratio
      OptimizerTrades = $trades
      ProfitFactor = [Math]::Round(([double](Get-PropValue -Object $row -Names @('Profit Factor') -Default 0.0)), 2)
      g_HighLowPeriod = Get-PropValue -Object $row -Names @('g_HighLowPeriod') -Default $null
      g_HighLowPeriodOptimizationIndex = Get-PropValue -Object $row -Names @('g_HighLowPeriodOptimizationIndex') -Default $null
      g_ATR_Period = Get-PropValue -Object $row -Names @('g_ATR_Period') -Default $null
      g_MinClusterSize = Get-PropValue -Object $row -Names @('g_MinClusterSize') -Default $null
      g_ATR_Cluster_multiplier = Get-PropValue -Object $row -Names @('g_ATR_Cluster_multiplier') -Default $null
      g_ATR_StopLoss_multiplier = Get-PropValue -Object $row -Names @('g_ATR_StopLoss_multiplier') -Default $null
      g_impulse_lookback_hours = Get-PropValue -Object $row -Names @('g_impulse_lookback_hours') -Default $null
      g_pullback_lookforward_hours = Get-PropValue -Object $row -Names @('g_pullback_lookforward_hours') -Default $null
      g_Impulse_ATR_multiplier = Get-PropValue -Object $row -Names @('g_Impulse_ATR_multiplier') -Default $null
      g_MinPullback_ATR_multiplier = Get-PropValue -Object $row -Names @('g_MinPullback_ATR_multiplier') -Default $null
      g_TakeProfitMultiplier = Get-PropValue -Object $row -Names @('g_TakeProfitMultiplier') -Default $null
      g_TradeDirectionMode = Get-PropValue -Object $row -Names @('g_TradeDirectionMode') -Default $null
    })
  }

  return $rows.ToArray()
}

function New-TestManifest {
  param(
    [string]$Stage,
    [object[]]$Candidates,
    [string[]]$TestSymbols,
    [string]$FromDate,
    [string]$ToDate,
    [string]$ReportSubdir,
    [int]$StartIndex
  )

  $manifestRows = New-Object System.Collections.Generic.List[object]
  $testIndex = $StartIndex
  $dateLabel = Get-DateLabel -FromDate $FromDate -ToDate $ToDate
  foreach ($candidate in $Candidates) {
    foreach ($symbol in $TestSymbols) {
      $safeSymbol = Get-SafeId -Text $symbol
      $report = "$ReportSubdir\$safeSymbol`_$($candidate.ManifoldId)_$Stage`_$dateLabel.xml"
      $testId = ('{0:D5}_{1}_{2}_{3}' -f $testIndex, $candidate.ManifoldId, $safeSymbol, $Stage)
      $manifestRows.Add([pscustomobject]@{
        TestIndex = $testIndex
        TestId = $testId
        ManifoldId = $candidate.ManifoldId
        Pass = $candidate.Pass
        Symbol = $symbol
        Stage = $Stage
        FromDate = $FromDate
        ToDate = $ToDate
        Report = $report
        ExpectedReport = "$report.htm"
        OptimizerProfit = $candidate.OptimizerProfit
        OptimizerDD = $candidate.OptimizerDD
        OptimizerRatio = $candidate.OptimizerRatio
        OptimizerTrades = $candidate.OptimizerTrades
        g_HighLowPeriod = $candidate.g_HighLowPeriod
        g_HighLowPeriodOptimizationIndex = $candidate.g_HighLowPeriodOptimizationIndex
        g_ATR_Period = $candidate.g_ATR_Period
        g_MinClusterSize = $candidate.g_MinClusterSize
        g_ATR_Cluster_multiplier = $candidate.g_ATR_Cluster_multiplier
        g_ATR_StopLoss_multiplier = $candidate.g_ATR_StopLoss_multiplier
        g_impulse_lookback_hours = $candidate.g_impulse_lookback_hours
        g_pullback_lookforward_hours = $candidate.g_pullback_lookforward_hours
        g_Impulse_ATR_multiplier = $candidate.g_Impulse_ATR_multiplier
        g_MinPullback_ATR_multiplier = $candidate.g_MinPullback_ATR_multiplier
        g_TakeProfitMultiplier = $candidate.g_TakeProfitMultiplier
        g_TradeDirectionMode = $candidate.g_TradeDirectionMode
      })
      $testIndex++
    }
  }

  return $manifestRows.ToArray()
}

function Read-ManifestReports {
  param(
    [object[]]$Manifest,
    [string]$ReportRoot,
    [double]$MinRatio,
    [double]$MaxDd
  )

  $rows = New-Object System.Collections.Generic.List[object]
  foreach ($test in $Manifest) {
    $path = Convert-ReportPathToFullPath -ReportRoot $ReportRoot -ExpectedReport $test.ExpectedReport
    if (-not (Test-Path -LiteralPath $path)) {
      $rows.Add([pscustomobject]@{
        TestIndex = $test.TestIndex; TestId = $test.TestId; ManifoldId = $test.ManifoldId; Pass = $test.Pass; Symbol = $test.Symbol; Stage = $test.Stage; FromDate = $test.FromDate; ToDate = $test.ToDate; ReportPath = $path; Parsed = $false; Accepted = $false; Profit = $null; EquityDDPct = $null; Ratio = $null; Trades = $null; ProfitFactor = $null; Recovery = $null; Sharpe = $null
      })
      continue
    }

    $metrics = Read-Mt5ReportMetrics -Path $path -Deposit $StartingDeposit
    $accepted = ($metrics.Profit -gt 0 -and $metrics.Ratio -ge $MinRatio -and $metrics.EquityDDPct -le $MaxDd)
    $rows.Add([pscustomobject]@{
      TestIndex = $test.TestIndex
      TestId = $test.TestId
      ManifoldId = $test.ManifoldId
      Pass = $test.Pass
      Symbol = $test.Symbol
      Stage = $test.Stage
      FromDate = $test.FromDate
      ToDate = $test.ToDate
      ReportPath = $path
      Parsed = $true
      Accepted = $accepted
      Profit = $metrics.Profit
      EquityDDPct = $metrics.EquityDDPct
      Ratio = $metrics.Ratio
      Trades = $metrics.Trades
      ProfitFactor = $metrics.ProfitFactor
      Recovery = $metrics.Recovery
      Sharpe = $metrics.Sharpe
    })
  }

  return $rows.ToArray()
}

function New-ManifoldSummary {
  param([object[]]$ReportRows, [string]$RequiredSymbol, [bool]$RequireRequiredSymbol)

  $summary = New-Object System.Collections.Generic.List[object]
  foreach ($group in ($ReportRows | Group-Object ManifoldId)) {
    $rows = @($group.Group | Where-Object { $_.Parsed })
    $acceptedRows = @($rows | Where-Object { $_.Accepted })
    $requiredRow = @($rows | Where-Object { $_.Symbol -eq $RequiredSymbol }) | Select-Object -First 1
    $requiredAccepted = ($null -ne $requiredRow -and $requiredRow.Accepted)
    $aggregateProfit = Get-SumProperty -Rows $acceptedRows -PropertyName 'Profit'
    $aggregateTrades = Get-SumProperty -Rows $acceptedRows -PropertyName 'Trades'
    $maxDd = Get-MaxProperty -Rows $acceptedRows -PropertyName 'EquityDDPct'
    $aggregateRatio = if ($maxDd -gt 0) { [Math]::Round(($aggregateProfit / ($StartingDeposit / 100.0)) / $maxDd, 3) } else { 0.0 }
    $eligible = $true
    if ($RequireRequiredSymbol -and -not $requiredAccepted) {
      $eligible = $false
    }
    $score = ([double]$acceptedRows.Count * 1000000000.0) + ([double]$aggregateRatio * 1000000.0) + [double]$aggregateProfit

    $summary.Add([pscustomobject]@{
      ManifoldId = $group.Name
      ParsedRows = $rows.Count
      AcceptedSymbols = $acceptedRows.Count
      RequiredSymbolAccepted = $requiredAccepted
      Eligible = $eligible
      AggregateAcceptedProfit = [Math]::Round($aggregateProfit, 2)
      AggregateAcceptedTrades = [int]$aggregateTrades
      MaxAcceptedDDPct = [Math]::Round($maxDd, 2)
      AggregateAcceptedRatio = $aggregateRatio
      Score = [Math]::Round($score, 3)
      AcceptedSymbolList = (($acceptedRows | Sort-Object Symbol | Select-Object -ExpandProperty Symbol) -join ',')
    })
  }

  return $summary.ToArray()
}

function Select-CandidatesByManifoldId {
  param([object[]]$Candidates, [string[]]$Ids)

  @($Candidates | Where-Object { $Ids -contains $_.ManifoldId })
}

Assert-DateText -Name 'OptimizationStart' -Value $OptimizationStart
Assert-DateText -Name 'OptimizationEnd' -Value $OptimizationEnd
Assert-DateText -Name 'ValidationStart' -Value $ValidationStart
Assert-DateText -Name 'ValidationEnd' -Value $ValidationEnd
Assert-DateText -Name 'DeployStart' -Value $DeployStart
Assert-DateText -Name 'DeployEnd' -Value $DeployEnd

$mql5Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$terminalDataRoot = Split-Path -Parent $mql5Root
$reportRoot = $terminalDataRoot
$testerProfilesDir = Join-Path $mql5Root 'Profiles\Tester'
$templateSetPath = Join-Path $testerProfilesDir $TemplateSetFile
$tempSetPath = Join-Path $testerProfilesDir $TempSetFile

if (-not (Test-Path -LiteralPath $templateSetPath)) {
  throw "Template set file not found: $templateSetPath"
}
if (-not (Test-Path -LiteralPath $TerminalPath) -and -not $PrepareOnly -and -not $SkipFixedRuns -and -not $SkipOptimizationRun) {
  throw "MT5 terminal not found: $TerminalPath"
}

if (-not $CycleId) {
  $CycleId = 'RM_' + (Get-DateLabel -FromDate $OptimizationStart -ToDate $OptimizationEnd) + '_VAL_' + (Get-DateLabel -FromDate $ValidationStart -ToDate $ValidationEnd) + '_DEP_' + (Get-DateLabel -FromDate $DeployStart -ToDate $DeployEnd)
}
$CycleId = Get-SafeId -Text $CycleId
$requireDiscoveryInValidation = (-not [bool]$AllowValidationWithoutDiscoverySymbol) -or [bool]$ValidationRequireDiscoverySymbol

if (-not $ResultRoot) {
  $ResultRoot = Join-Path $terminalDataRoot 'reports\rolling_manifold'
}
$cycleDir = Join-Path $ResultRoot $CycleId
if (-not (Test-Path -LiteralPath $cycleDir)) {
  New-Item -ItemType Directory -Path $cycleDir -Force | Out-Null
}

$cycleReportSubdir = "reports\rolling_manifold\$CycleId"
$cycleReportDir = Join-Path $terminalDataRoot $cycleReportSubdir
foreach ($sub in @('optimizer', 'sanity', 'validation', 'deploy')) {
  $path = Join-Path $cycleReportDir $sub
  if (-not (Test-Path -LiteralPath $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
  }
}

$Symbols = @(Expand-FilterValues $Symbols)
if ($Symbols.Count -eq 0) {
  $Symbols = @(Get-Fx28Symbols)
}
if ($Symbols -notcontains $DiscoverySymbol) {
  $Symbols = @($DiscoverySymbol) + $Symbols
}

$optimizerReport = "$cycleReportSubdir\optimizer\$DiscoverySymbol`_$CycleId`_OPT_$(Get-DateLabel -FromDate $OptimizationStart -ToDate $OptimizationEnd).xml"
$optimizerXml = Convert-ReportPathToFullPath -ReportRoot $reportRoot -ExpectedReport $optimizerReport
if ($ExistingOptimizerXml) {
  $optimizerXml = $ExistingOptimizerXml
}

$optimizerConfigPath = Join-Path $cycleDir 'optimizer.ini'
New-OptimizerConfig -Path $optimizerConfigPath -Symbol $DiscoverySymbol -FromDate $OptimizationStart -ToDate $OptimizationEnd -SetFile $TemplateSetFile -Report $optimizerReport

Write-Host "Cycle: $CycleId"
Write-Host "Cycle directory: $cycleDir"
Write-Host "Symbols: $($Symbols.Count)"
Write-Host "Optimizer XML: $optimizerXml"

if (-not (Test-Path -LiteralPath $optimizerXml)) {
  if ($PrepareOnly) {
    Write-Host 'PrepareOnly set and optimizer XML does not exist. Optimizer config was created; stopping before candidate selection.'
    return
  }
  if ($SkipOptimizationRun) {
    throw "Optimizer XML not found and SkipOptimizationRun is set: $optimizerXml"
  }

  $optResult = Invoke-Mt5Config -ConfigPath $optimizerConfigPath -ExpectedReportPath $optimizerXml -TimeoutMinutes $OptimizationTimeoutMinutes -Description "optimizer $CycleId"
  if ($optResult.Status -ne 'Completed') {
    throw "Optimization did not complete successfully: $($optResult.Status) $($optResult.Note)"
  }
} else {
  Write-Host 'Optimizer XML already exists; using existing optimizer result.'
}

$optimizerRows = @(Read-Mt5Spreadsheet -Path $optimizerXml)
if ($optimizerRows.Count -eq 0) {
  throw "Optimizer XML contained no result rows: $optimizerXml"
}

$allCandidates = @(New-CandidateRowsFromOptimizer -OptimizerRows $optimizerRows)
$allCandidatesPath = Join-Path $cycleDir 'optimizer_all_candidates.csv'
$allCandidates | Sort-Object OptimizerRatio -Descending | Export-Csv -LiteralPath $allCandidatesPath -NoTypeInformation -Encoding ASCII

$mStar = @($allCandidates |
  Where-Object { $_.OptimizerProfit -gt 0 -and $_.OptimizerRatio -ge $CandidateMinRatio -and $_.OptimizerDD -le $CandidateMaxDrawdownPct -and $_.OptimizerTrades -ge $CandidateMinTrades } |
  Sort-Object OptimizerRatio, OptimizerProfit -Descending |
  Select-Object -First $TopCandidateCount)

if ($mStar.Count -eq 0) {
  throw 'No M* candidates passed optimizer filters.'
}

$mStarPath = Join-Path $cycleDir 'm_star_candidates.csv'
$mStar | Export-Csv -LiteralPath $mStarPath -NoTypeInformation -Encoding ASCII
Write-Host "M* candidates: $($mStar.Count)"

$sanityReportSubdir = "$cycleReportSubdir\sanity"
$sanityManifest = @(New-TestManifest -Stage 'SANITY_OPT' -Candidates $mStar -TestSymbols $Symbols -FromDate $OptimizationStart -ToDate $OptimizationEnd -ReportSubdir $sanityReportSubdir -StartIndex 1)
$sanityManifestPath = Join-Path $cycleDir 'sanity_manifest.csv'
$sanityProgressPath = Join-Path $cycleDir 'sanity_progress.csv'
$sanityManifest | Export-Csv -LiteralPath $sanityManifestPath -NoTypeInformation -Encoding ASCII
Write-Host "Sanity manifest tests: $($sanityManifest.Count)"

if (-not $PrepareOnly -and -not $SkipFixedRuns) {
  Invoke-FixedManifest -Manifest $sanityManifest -ProgressPath $sanityProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -TempSetFileName $TempSetFile -EnableCsv $false
} else {
  Write-Host 'Skipping sanity fixed-test execution.'
}

if ($PrepareOnly) {
  Write-Host 'PrepareOnly set. Sanity manifest was created; stopping before report-based selection.'
  return
}

$missingSanityReports = @(Get-MissingManifestReports -Manifest $sanityManifest -ReportRoot $reportRoot)
if ($missingSanityReports.Count -gt 0) {
  Write-Host "Sanity stage incomplete. Missing reports: $($missingSanityReports.Count). Rerun this script to resume."
  return
}

$sanityRows = @(Read-ManifestReports -Manifest $sanityManifest -ReportRoot $reportRoot -MinRatio $SanityMinRatio -MaxDd $SanityMaxDrawdownPct)
$sanityRowsPath = Join-Path $cycleDir 'sanity_reports.csv'
$sanityRows | Export-Csv -LiteralPath $sanityRowsPath -NoTypeInformation -Encoding ASCII
$sanitySummary = @(New-ManifoldSummary -ReportRows $sanityRows -RequiredSymbol $DiscoverySymbol -RequireRequiredSymbol ([bool]$SanityRequireDiscoverySymbol))
$sanitySummaryPath = Join-Path $cycleDir 'sanity_manifold_summary.csv'
$sanitySummary | Sort-Object Eligible, AcceptedSymbols, AggregateAcceptedRatio, AggregateAcceptedProfit -Descending | Export-Csv -LiteralPath $sanitySummaryPath -NoTypeInformation -Encoding ASCII

$saneIds = @($sanitySummary |
  Where-Object { $_.Eligible -and $_.AcceptedSymbols -ge $SanityMinPassingSymbols } |
  Sort-Object AcceptedSymbols, AggregateAcceptedRatio, AggregateAcceptedProfit -Descending |
  Select-Object -First $MaxCandidatesAfterSanity |
  Select-Object -ExpandProperty ManifoldId)

if ($saneIds.Count -eq 0) {
  throw 'No manifolds survived the optimization-window non-EURUSD sanity filter.'
}

$mSane = @(Select-CandidatesByManifoldId -Candidates $mStar -Ids $saneIds)
$mSanePath = Join-Path $cycleDir 'm_sane_candidates.csv'
$mSane | Export-Csv -LiteralPath $mSanePath -NoTypeInformation -Encoding ASCII
Write-Host "M_sane candidates: $($mSane.Count)"

$validationManifestRows = New-Object System.Collections.Generic.List[object]
$validationIndex = 1
foreach ($candidate in $mSane) {
  $candidateSanitySymbols = @($sanityRows | Where-Object { $_.ManifoldId -eq $candidate.ManifoldId -and $_.Accepted } | Select-Object -ExpandProperty Symbol -Unique)
  if ($candidateSanitySymbols -notcontains $DiscoverySymbol) {
    $candidateSanitySymbols = @($DiscoverySymbol) + $candidateSanitySymbols
  }
  $candidateManifest = @(New-TestManifest -Stage 'VALIDATION' -Candidates @($candidate) -TestSymbols $candidateSanitySymbols -FromDate $ValidationStart -ToDate $ValidationEnd -ReportSubdir "$cycleReportSubdir\validation" -StartIndex $validationIndex)
  foreach ($row in $candidateManifest) {
    $validationManifestRows.Add($row)
    $validationIndex++
  }
}

$validationManifest = @($validationManifestRows.ToArray())
$validationManifestPath = Join-Path $cycleDir 'validation_manifest.csv'
$validationProgressPath = Join-Path $cycleDir 'validation_progress.csv'
$validationManifest | Export-Csv -LiteralPath $validationManifestPath -NoTypeInformation -Encoding ASCII
Write-Host "Validation manifest tests: $($validationManifest.Count)"

if (-not $PrepareOnly -and -not $SkipFixedRuns) {
  Invoke-FixedManifest -Manifest $validationManifest -ProgressPath $validationProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -TempSetFileName $TempSetFile -EnableCsv $false
} else {
  Write-Host 'Skipping validation fixed-test execution.'
}

$missingValidationReports = @(Get-MissingManifestReports -Manifest $validationManifest -ReportRoot $reportRoot)
if ($missingValidationReports.Count -gt 0) {
  Write-Host "Validation stage incomplete. Missing reports: $($missingValidationReports.Count). Rerun this script to resume."
  return
}

$validationRows = @(Read-ManifestReports -Manifest $validationManifest -ReportRoot $reportRoot -MinRatio $ValidationMinRatio -MaxDd $ValidationMaxDrawdownPct)
$validationRowsPath = Join-Path $cycleDir 'validation_reports.csv'
$validationRows | Export-Csv -LiteralPath $validationRowsPath -NoTypeInformation -Encoding ASCII
$validationSummary = @(New-ManifoldSummary -ReportRows $validationRows -RequiredSymbol $DiscoverySymbol -RequireRequiredSymbol $requireDiscoveryInValidation)
$validationSummaryPath = Join-Path $cycleDir 'validation_manifold_summary.csv'
$validationSummary | Sort-Object Eligible, AcceptedSymbols, AggregateAcceptedRatio, AggregateAcceptedProfit -Descending | Export-Csv -LiteralPath $validationSummaryPath -NoTypeInformation -Encoding ASCII

$finalSummary = @($validationSummary |
  Where-Object { $_.Eligible -and $_.AcceptedSymbols -ge $ValidationMinPassingSymbols } |
  Sort-Object AcceptedSymbols, AggregateAcceptedRatio, AggregateAcceptedProfit -Descending |
  Select-Object -First 1)

if ($finalSummary.Count -eq 0) {
  throw 'No final manifold passed validation.'
}

$finalManifoldId = $finalSummary[0].ManifoldId
$mHat = @(Select-CandidatesByManifoldId -Candidates $mSane -Ids @($finalManifoldId))
if ($mHat.Count -ne 1) {
  throw "Could not resolve final manifold candidate: $finalManifoldId"
}

$sHat = @($validationRows | Where-Object { $_.ManifoldId -eq $finalManifoldId -and $_.Accepted } | Sort-Object Symbol | Select-Object -ExpandProperty Symbol -Unique)
if ($sHat.Count -eq 0) {
  throw "Final manifold has no accepted validation symbols: $finalManifoldId"
}

$finalSelection = [pscustomobject]@{
  CycleId = $CycleId
  FinalManifoldId = $finalManifoldId
  FinalPass = $mHat[0].Pass
  ValidationAcceptedSymbols = $sHat.Count
  ValidationRequiredDiscoverySymbol = $requireDiscoveryInValidation
  ValidationSymbolList = ($sHat -join ',')
  DeployStart = $DeployStart
  DeployEnd = $DeployEnd
  ExpectedCommonCsvFile = "manifold_trades_$finalManifoldId.csv"
}
$finalSelectionPath = Join-Path $cycleDir 'final_selection.csv'
$finalSelection | Export-Csv -LiteralPath $finalSelectionPath -NoTypeInformation -Encoding ASCII
$sHat | ForEach-Object { [pscustomobject]@{ CycleId = $CycleId; ManifoldId = $finalManifoldId; Symbol = $_ } } | Export-Csv -LiteralPath (Join-Path $cycleDir 's_hat_symbols.csv') -NoTypeInformation -Encoding ASCII

Write-Host "Final m^: $finalManifoldId"
Write-Host "Final S^ symbols: $($sHat -join ', ')"
Write-Host "Expected deployment CSV in MT5 common files: manifold_trades_$finalManifoldId.csv"

$deployManifest = @(New-TestManifest -Stage 'DEPLOY' -Candidates $mHat -TestSymbols $sHat -FromDate $DeployStart -ToDate $DeployEnd -ReportSubdir "$cycleReportSubdir\deploy" -StartIndex 1)
$deployManifestPath = Join-Path $cycleDir 'deploy_manifest.csv'
$deployProgressPath = Join-Path $cycleDir 'deploy_progress.csv'
$deployManifest | Export-Csv -LiteralPath $deployManifestPath -NoTypeInformation -Encoding ASCII
Write-Host "Deploy manifest tests: $($deployManifest.Count)"

if (-not $PrepareOnly -and -not $SkipFixedRuns) {
  Invoke-FixedManifest -Manifest $deployManifest -ProgressPath $deployProgressPath -ReportRoot $reportRoot -TemplateSetPath $templateSetPath -TempSetPath $tempSetPath -TempSetFileName $TempSetFile -EnableCsv $true
} else {
  Write-Host 'Skipping deploy fixed-test execution.'
}

$missingDeployReports = @(Get-MissingManifestReports -Manifest $deployManifest -ReportRoot $reportRoot)
if ($missingDeployReports.Count -gt 0) {
  Write-Host "Deploy stage incomplete. Missing reports: $($missingDeployReports.Count). Rerun this script to resume."
  return
}

$deployRows = @(Read-ManifestReports -Manifest $deployManifest -ReportRoot $reportRoot -MinRatio $ValidationMinRatio -MaxDd $ValidationMaxDrawdownPct)
$deployRowsPath = Join-Path $cycleDir 'deploy_reports.csv'
$deployRows | Export-Csv -LiteralPath $deployRowsPath -NoTypeInformation -Encoding ASCII

Write-Host 'Rolling manifold cycle complete.'
Write-Host "Outputs: $cycleDir"
