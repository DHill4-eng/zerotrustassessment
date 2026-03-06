function Get-ZtFrameworkPolicyCompliance {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true)]
		[string]$Name
	)

	#region Utility Functions
	function Get-ZtpValueByPath {
		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)]
			$InputObject,

			[Parameter(Mandatory = $true)]
			[string]$Path
		)

		$current = $InputObject
		foreach ($segment in ($Path -split '\.')) {
			if ($null -eq $current) {
				return $null
			}

			if ($current -is [System.Collections.IDictionary]) {
				$current = $current[$segment]
				continue
			}

			if ($current.PSObject.Properties.Name -contains $segment) {
				$current = $current.$segment
			}
			else {
				return $null
			}
		}

		$current
	}

	function Test-ZtpRule {
		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)]
			$Item,

			[Parameter(Mandatory = $true)]
			$Rule
		)

		$actualValue = Get-ZtpValueByPath -InputObject $Item -Path $Rule.Path
		$operator = $Rule.Operator
		if (-not $operator) {
			$operator = 'Equals'
		}

		switch ($operator) {
			'Equals' {
				return ($actualValue -eq $Rule.ExpectedValue)
			}
			'Contains' {
				if ($actualValue -is [System.Collections.IEnumerable] -and -not ($actualValue -is [string])) {
					return ($actualValue -contains $Rule.ExpectedValue)
				}
				if ($null -eq $actualValue) {
					return $false
				}
				return ("$actualValue" -like "*$($Rule.ExpectedValue)*")
			}
			'Exists' {
				return ($null -ne $actualValue)
			}
			default {
				throw "Unsupported operator '$operator' in rule path '$($Rule.Path)'"
			}
		}
	}

	function Test-ZtpPolicyMatch {
		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)]
			$Item,

			[Parameter(Mandatory = $true)]
			$Rules
		)

		foreach ($rule in @($Rules)) {
			if (-not (Test-ZtpRule -Item $Item -Rule $rule)) {
				return $false
			}
		}
		return $true
	}
	#endregion Utility Functions

	$definition = Get-ZtFrameworkDefinition -Name $Name
	if (-not $definition) {
		return $null
	}

	if (-not $definition.Policies) {
		return [PSCustomObject]@{
			Framework = $Name
			Version = 'Unknown'
			GeneratedAt = Get-Date
			Summary = [PSCustomObject]@{ Present = 0; Missing = 0; Error = 0; Total = 0 }
			Policies = @()
		}
	}

	$policyResults = foreach ($policy in @($definition.Policies)) {
		try {
			$apiVersion = if ($policy.ApiVersion) { $policy.ApiVersion } else { 'v1.0' }
			$response = Invoke-ZtGraphRequest -RelativeUri $policy.RelativeUri -ApiVersion $apiVersion

			$collectionPath = if ($policy.CollectionPath) { $policy.CollectionPath } else { 'value' }
			$items = Get-ZtpValueByPath -InputObject $response -Path $collectionPath
			if ($null -eq $items) {
				$items = @($response)
			}
			$items = @($items)

			$matchMode = if ($policy.MatchMode) { $policy.MatchMode } else { 'AnyObjectMatchesAllRules' }
			$matchedItems = @()

			switch ($matchMode) {
				'AnyObjectMatchesAllRules' {
					$matchedItems = @($items | Where-Object { Test-ZtpPolicyMatch -Item $_ -Rules $policy.Rules })
				}
				'FirstObjectMatchesAllRules' {
					if ($items.Count -gt 0 -and (Test-ZtpPolicyMatch -Item $items[0] -Rules $policy.Rules)) {
						$matchedItems = @($items[0])
					}
				}
				default {
					throw "Unsupported MatchMode '$matchMode' in policy '$($policy.PolicyId)'"
				}
			}

			$status = if ($matchedItems.Count -gt 0) { 'Present' } else { 'Missing' }
			[PSCustomObject]@{
				PolicyId          = $policy.PolicyId
				Title             = $policy.Title
				RelativeUri       = $policy.RelativeUri
				ApiVersion        = $apiVersion
				Status            = $status
				RuleCount         = @($policy.Rules).Count
				MatchedObjectCount = $matchedItems.Count
				MatchedObjects    = @($matchedItems)
			}
		}
		catch {
			[PSCustomObject]@{
				PolicyId           = $policy.PolicyId
				Title              = $policy.Title
				RelativeUri        = $policy.RelativeUri
				ApiVersion         = if ($policy.ApiVersion) { $policy.ApiVersion } else { 'v1.0' }
				Status             = 'Error'
				RuleCount          = @($policy.Rules).Count
				MatchedObjectCount = 0
				MatchedObjects     = @()
				Error              = $_.Exception.Message
			}
		}
	}

	[PSCustomObject]@{
		Framework   = $definition.Framework
		Version     = $definition.Version
		GeneratedAt = Get-Date
		Summary     = [PSCustomObject]@{
			Present = @($policyResults | Where-Object Status -eq 'Present').Count
			Missing = @($policyResults | Where-Object Status -eq 'Missing').Count
			Error   = @($policyResults | Where-Object Status -eq 'Error').Count
			Total   = @($policyResults).Count
		}
		Policies    = @($policyResults)
	}
}
