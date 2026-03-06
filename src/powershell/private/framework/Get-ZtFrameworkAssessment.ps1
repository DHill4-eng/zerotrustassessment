function Get-ZtFrameworkAssessment {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,

		[Parameter(Mandatory = $true)]
		[object[]]$TestResults
	)

	$definition = Get-ZtFrameworkDefinition -Name $Name
	if (-not $definition) {
		return $null
	}

	$controls = foreach ($control in @($definition.Controls)) {
		$mappedIds = @($control.MappedTestIds | ForEach-Object { "$_" })
		$mappedResults = @($TestResults | Where-Object { $_.TestId -in $mappedIds })

		$status = 'NotAssessed'
		$gapReason = 'No mapped tests were executed for this control.'

		if ($mappedResults.Count -gt 0) {
			if ($mappedResults.TestStatus -contains 'Failed' -or $mappedResults.TestStatus -contains 'Investigate') {
				$status = 'Gap'
				$gapReason = 'One or more mapped checks failed or require investigation.'
			}
			elseif ($mappedResults.TestStatus -contains 'Passed') {
				$status = 'Pass'
				$gapReason = $null
			}
		}

		[PSCustomObject]@{
			ControlId       = $control.ControlId
			Title           = $control.Title
			Description     = $control.Description
			Status          = $status
			GapReason       = $gapReason
			MappedTestIds   = $mappedIds
			MappedTestCount = $mappedResults.Count
			MappedTests     = @($mappedResults | Select-Object TestId, TestTitle, TestStatus, TestRisk, TestPillar)
		}
	}

	[PSCustomObject]@{
		Framework      = $definition.Framework
		Version        = $definition.Version
		GeneratedAt    = Get-Date
		ControlSummary = [PSCustomObject]@{
			Pass        = @($controls | Where-Object Status -eq 'Pass').Count
			Gap         = @($controls | Where-Object Status -eq 'Gap').Count
			NotAssessed = @($controls | Where-Object Status -eq 'NotAssessed').Count
			Total       = @($controls).Count
		}
		Controls       = @($controls)
	}
}
