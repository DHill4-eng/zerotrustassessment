function Get-ZtFrameworkDefinition {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name,

		[string[]]$Suffix = @('controls', 'policies')
	)

	foreach ($fileSuffix in $Suffix) {
		$frameworkFile = Join-Path -Path $script:ModuleRoot -ChildPath "assets/frameworks/$Name.$fileSuffix.json"
		if (Test-Path -Path $frameworkFile -PathType Leaf) {
			return (Get-Content -Path $frameworkFile -Raw | ConvertFrom-Json -Depth 20)
		}
	}

	return $null
}
