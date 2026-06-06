# MT5 Result Utilities

These PowerShell scripts parse MT5 tester result files so review logic does not need to be recreated each session.

## Optimizer + Forward Review

Use `Analyze-Mt5OptimizerForward.ps1` for MT5 optimizer XML spreadsheets and matching `.forward.xml` spreadsheets.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-Mt5OptimizerForward.ps1 `
  -OptimizerXml .\docs\results\example.xml `
  -ForwardXml .\docs\results\example.forward.xml
```

Useful options:

- `-Csv` outputs the loose-filter candidates as CSV.
- `-Top 50` changes how many candidates are printed.
- `-MinRatio`, `-MaxDrawdownPct`, `-StrictMinInSampleTrades`, `-StrictMinForwardTrades`, `-LooseMinInSampleTrades`, and `-LooseMinForwardTrades` adjust review thresholds.

## Fixed OOS Report Review

Use `Analyze-Mt5OosReports.ps1` for fixed single-test `.xml.htm` reports.

```powershell
powershell -ExecutionPolicy Bypass -File .\docs\utils\Analyze-Mt5OosReports.ps1 `
  -ReportsDir .\docs\results\reports `
  -Pattern 'EURUSD_D1HighLow_Clustered_Pass*_OOS_*.xml.htm'
```

Useful options:

- `-Csv` outputs all parsed reports as CSV sorted by ratio.
- `-Top 50` changes how many profitable candidates are printed.
- `-MinRatio`, `-MaxDrawdownPct`, and `-StartingDeposit` adjust acceptance calculations.

## Notes

- Files in `docs/results` are treated as ephemeral working artifacts.
- Record durable findings in `docs/experiment-log.md`, not only in generated reports.
