function Select-ZtAssessmentFramework {
	[CmdletBinding()]
	param()

	$available = @('ZeroTrust', 'CyberEssentialsPlus', 'SecureModernWorkplace', 'MonthlyServiceReport')
	Write-Host
	Write-Host 'Select assessment modules to include in this report:' -ForegroundColor Cyan
	for ($i = 0; $i -lt $available.Count; $i++) {
		Write-Host ("[{0}] {1}" -f ($i + 1), $available[$i])
	}
	Write-Host '[A] All modules'
	Write-Host

	$selection = Read-Host 'Enter one or more values (e.g. 1,2 or A). Press Enter for default [1]'
	if ([string]::IsNullOrWhiteSpace($selection)) {
		return @('ZeroTrust')
	}

	if ($selection.Trim().ToUpperInvariant() -eq 'A') {
		return $available
	}

	$selected = [System.Collections.Generic.List[string]]::new()
	foreach ($token in ($selection -split ',')) {
		$trimmed = $token.Trim()
		if ($trimmed -match '^\d+$') {
			$index = [int]$trimmed - 1
			if ($index -ge 0 -and $index -lt $available.Count) {
				$selected.Add($available[$index])
			}
		}
	}

	if ($selected.Count -eq 0) {
		Write-Host 'No valid module selection provided. Defaulting to ZeroTrust.' -ForegroundColor Yellow
		return @('ZeroTrust')
	}

	return @($selected | Select-Object -Unique)
}
