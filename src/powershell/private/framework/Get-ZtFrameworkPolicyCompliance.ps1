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

		if ([string]::IsNullOrWhiteSpace($Path)) {
			return $InputObject
		}

		$current = $InputObject
		foreach ($segment in ($Path -split '\.')) {
			if ($null -eq $current) { return $null }

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
			[Parameter(Mandatory = $true)]$Item,
			[Parameter(Mandatory = $true)]$Rule
		)

		$actualValue = Get-ZtpValueByPath -InputObject $Item -Path $Rule.Path
		$operator = if ($Rule.Operator) { $Rule.Operator } else { 'Equals' }
		$expected = $Rule.ExpectedValue

		switch ($operator) {
			'Equals' { return ($actualValue -eq $expected) }
			'NotEquals' { return ($actualValue -ne $expected) }
			'Contains' {
				if ($actualValue -is [System.Collections.IEnumerable] -and -not ($actualValue -is [string])) { return ($actualValue -contains $expected) }
				if ($null -eq $actualValue) { return $false }
				return ("$actualValue" -like "*$expected*")
			}
			'NotContains' {
				if ($actualValue -is [System.Collections.IEnumerable] -and -not ($actualValue -is [string])) { return (-not ($actualValue -contains $expected)) }
				if ($null -eq $actualValue) { return $true }
				return (-not ("$actualValue" -like "*$expected*"))
			}
			'In' { return (@($expected) -contains $actualValue) }
			'NotIn' { return (-not (@($expected) -contains $actualValue)) }
			'Exists' { return ($null -ne $actualValue) }
			'GreaterThan' { return ([double]$actualValue -gt [double]$expected) }
			'GreaterOrEquals' { return ([double]$actualValue -ge [double]$expected) }
			'LessThan' { return ([double]$actualValue -lt [double]$expected) }
			'LessOrEquals' { return ([double]$actualValue -le [double]$expected) }
			'MatchesRegex' {
				if ($null -eq $actualValue) { return $false }
				return ([regex]::IsMatch("$actualValue", "$expected"))
			}
			default { throw "Unsupported operator '$operator' in rule path '$($Rule.Path)'" }
		}
	}

	function Test-ZtpPolicyMatch {
		[CmdletBinding()]
		param(
			[Parameter(Mandatory = $true)]$Item,
			[Parameter(Mandatory = $true)]$Rules,
			[string]$LogicalOperator = 'All'
		)

		$logicalOperator = if ($LogicalOperator) { $LogicalOperator } else { 'All' }
		$results = foreach ($rule in @($Rules)) { Test-ZtpRule -Item $Item -Rule $rule }
		if ($logicalOperator -eq 'Any') {
			return ($results -contains $true)
		}
		return (-not ($results -contains $false))
	}
	#endregion Utility Functions

	$definition = Get-ZtFrameworkDefinition -Name $Name
	if (-not $definition) { return $null }

	if (-not $definition.Policies) {
		return [PSCustomObject]@{
			Framework = $Name
			Version = 'Unknown'
			GeneratedAt = Get-Date
			Summary = [PSCustomObject]@{ Present = 0; Missing = 0; Error = 0; Total = 0 }
			Policies = @()
			SourceFiles = @($definition.SourceFiles)
		}
	}

	$policyResults = foreach ($policy in @($definition.Policies)) {
		try {
			$apiVersion = if ($policy.ApiVersion) { $policy.ApiVersion } else { 'v1.0' }
			$requestParams = @{
				RelativeUri = $policy.RelativeUri
				ApiVersion  = $apiVersion
			}
			if ($policy.QueryParameters) { $requestParams.QueryParameters = $policy.QueryParameters }
			if ($policy.Filter) { $requestParams.Filter = $policy.Filter }
			if ($policy.Select) { $requestParams.Select = @($policy.Select) }
			if ($policy.Top) { $requestParams.Top = "$($policy.Top)" }

			$response = Invoke-ZtGraphRequest @requestParams

			$collectionPath = if ($policy.CollectionPath) { $policy.CollectionPath } else { 'value' }
			$items = Get-ZtpValueByPath -InputObject $response -Path $collectionPath
			if ($null -eq $items) { $items = @($response) }
			$items = @($items)

			$matchMode = if ($policy.MatchMode) { $policy.MatchMode } else { 'AnyObjectMatchesAllRules' }
			$logicalOperator = if ($policy.LogicalOperator) { $policy.LogicalOperator } else { 'All' }
			$matchedItems = @()

			switch ($matchMode) {
				'AnyObjectMatchesAllRules' {
					$matchedItems = @($items | Where-Object { Test-ZtpPolicyMatch -Item $_ -Rules $policy.Rules -LogicalOperator $logicalOperator })
				}
				'FirstObjectMatchesAllRules' {
					if ($items.Count -gt 0 -and (Test-ZtpPolicyMatch -Item $items[0] -Rules $policy.Rules -LogicalOperator $logicalOperator)) {
						$matchedItems = @($items[0])
					}
				}
				'AllObjectsMatchAllRules' {
					if ($items.Count -gt 0 -and -not (@($items | Where-Object { -not (Test-ZtpPolicyMatch -Item $_ -Rules $policy.Rules -LogicalOperator $logicalOperator) }).Count)) {
						$matchedItems = @($items)
					}
				}
				default { throw "Unsupported MatchMode '$matchMode' in policy '$($policy.PolicyId)'" }
			}

			$status = if ($matchedItems.Count -gt 0) { 'Present' } else { 'Missing' }
			[PSCustomObject]@{
				PolicyId            = $policy.PolicyId
				Title               = $policy.Title
				RelativeUri         = $policy.RelativeUri
				ApiVersion          = $apiVersion
				Status              = $status
				RuleCount           = @($policy.Rules).Count
				MatchedObjectCount  = $matchedItems.Count
				MatchedObjects      = @($matchedItems)
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
		SourceFiles = @($definition.SourceFiles)
		Summary     = [PSCustomObject]@{
			Present = @($policyResults | Where-Object Status -eq 'Present').Count
			Missing = @($policyResults | Where-Object Status -eq 'Missing').Count
			Error   = @($policyResults | Where-Object Status -eq 'Error').Count
			Total   = @($policyResults).Count
		}
		Policies    = @($policyResults)
	}
}
