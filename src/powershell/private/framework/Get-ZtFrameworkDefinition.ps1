function Get-ZtFrameworkDefinition {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,

		[string[]]$Suffix = @('controls', 'policies')
	)

	foreach ($fileSuffix in $Suffix) {
		$frameworkDir = Join-Path -Path $script:ModuleRoot -ChildPath 'assets/frameworks'
		$exactPath = Join-Path -Path $frameworkDir -ChildPath "$Name.$fileSuffix.json"

		if ($fileSuffix -eq 'policies') {
			$matchedFiles = @()
			if (Test-Path -Path $exactPath -PathType Leaf) {
				$matchedFiles += Get-Item -Path $exactPath
			}
			$matchedFiles += Get-ChildItem -Path $frameworkDir -Filter "$Name.*.$fileSuffix.json" -File -ErrorAction SilentlyContinue
			$matchedFiles = @($matchedFiles | Sort-Object FullName -Unique)

			if ($matchedFiles.Count -gt 0) {
				$definitions = foreach ($file in $matchedFiles) {
					Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -Depth 30
				}

				$mergedPolicies = foreach ($definition in $definitions) {
					@($definition.Policies)
				}

				$versions = @($definitions | ForEach-Object { $_.Version } | Where-Object { $_ } | Select-Object -Unique)
				return [PSCustomObject]@{
					Framework = $Name
					Version   = ($versions -join ', ')
					Policies  = @($mergedPolicies)
					SourceFiles = @($matchedFiles | ForEach-Object FullName)
				}
			}
		}
		elseif (Test-Path -Path $exactPath -PathType Leaf) {
			return (Get-Content -Path $exactPath -Raw | ConvertFrom-Json -Depth 30)
		}
	}

	return $null
}
