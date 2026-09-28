# Native Windows lifecycle entry point used by the Minikube addon.
param(
    [ValidateSet('build', 'init', 'enable', 'disable', 'test', 'status', 'bridge', 'resume', 'help')]
    [string]$Action = 'help'
)
$ErrorActionPreference = 'Stop'
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AddonProfile = if ($env:MINIKUBE_AUTOSCALER_PROFILE) { $env:MINIKUBE_AUTOSCALER_PROFILE } else { 'minikube' }
$StateHome = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path ([Environment]::GetFolderPath('UserProfile')) '.local/state' }
$StateDir = if ($env:MINIKUBE_AUTOSCALER_STATE_DIR) { $env:MINIKUBE_AUTOSCALER_STATE_DIR } else { Join-Path $StateHome "minikube-cluster-autoscaler-addon/$AddonProfile" }
$Binary = if ($env:MINIKUBE_AUTOSCALER_BINARY) { $env:MINIKUBE_AUTOSCALER_BINARY } else { Join-Path $ProjectRoot 'bin/minikube-cluster-autoscaler-addon.exe' }
$Image = if ($env:MINIKUBE_AUTOSCALER_IMAGE) { $env:MINIKUBE_AUTOSCALER_IMAGE } else { 'minikube-cluster-autoscaler-addon:local' }
$ConfigPath = if ($env:MINIKUBE_AUTOSCALER_CONFIG) { $env:MINIKUBE_AUTOSCALER_CONFIG } else { Join-Path $StateDir 'config.json' }
$Container = "minikube-cluster-autoscaler-addon-$AddonProfile"
$Release = 'minikube-cluster-autoscaler-addon'
$Chart = Join-Path $ProjectRoot 'charts/minikube-cluster-autoscaler-addon'

function Invoke-Tool([string]$Program, [string[]]$Arguments) {
    & $Program @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed with exit code $LASTEXITCODE" }
}

function Protect-Base {
    $state = Get-Content -Raw (Join-Path $StateDir 'provider/state.json') | ConvertFrom-Json
    foreach ($node in $state.Base.PSObject.Properties.Name) {
        Invoke-Tool 'kubectl' @('--context', $AddonProfile, 'label', 'node', $node, 'minikube-autoscaler.astrivant.com/pool=base', '--overwrite')
    }
    # A patch file avoids native-command JSON quoting differences between
    # Windows PowerShell 5.1 and PowerShell 7.
    $patch = Join-Path $StateDir 'base-placement.json'
    '{"spec":{"template":{"spec":{"nodeSelector":{"minikube-autoscaler.astrivant.com/pool":"base"}}}}}' | Set-Content -Encoding ASCII $patch
    try {
        foreach ($namespace in @($Settings.namespace, 'kube-system') | Select-Object -Unique) {
            $controllers = Invoke-Tool 'kubectl' @('--context', $AddonProfile, '--namespace', $namespace, 'get', 'deployments,statefulsets', '-o', 'name')
            foreach ($controller in $controllers) {
                if ($controller) {
                    Invoke-Tool 'kubectl' @('--context', $AddonProfile, '--namespace', $namespace, 'patch', $controller, '--type=merge', '--patch-file', $patch)
                }
            }
        }
    } finally { Remove-Item -ErrorAction SilentlyContinue $patch }
}

function Prepare-Chart {
    if (Test-Path (Join-Path $Chart 'charts/cluster-autoscaler-9.59.0.tgz')) { return }
    $cache = Join-Path $ProjectRoot '.cache/helm'
    New-Item -ItemType Directory -Force (Join-Path $cache 'repository-cache') | Out-Null
    $env:HELM_REPOSITORY_CONFIG = Join-Path $cache 'repositories.yaml'
    $env:HELM_REPOSITORY_CACHE = Join-Path $cache 'repository-cache'
    Invoke-Tool 'helm' @('repo', 'add', 'autoscaler', 'https://kubernetes.github.io/autoscaler', '--force-update')
    Invoke-Tool 'helm' @('dependency', 'build', $Chart, '--skip-refresh')
}

try {
    if ($Action -eq 'help') {
        Write-Output 'Usage: addon.ps1 -Action build|init|enable|disable|test|status|bridge|resume'
        Write-Output 'Use minikube addons enable cluster-autoscaler for automatic setup and background bridge management.'
        exit 0
    }
    if ($AddonProfile -notmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$' -or $AddonProfile.Length -gt 40) { throw 'Invalid profile' }
    if (-not [IO.Path]::IsPathRooted($StateDir)) { throw 'State directory must be absolute' }
    if ($Action -eq 'build') {
        $buildProfile = if ($env:MINIKUBE_AUTOSCALER_BUILD_PROFILE) { $env:MINIKUBE_AUTOSCALER_BUILD_PROFILE } elseif (Test-Path (Join-Path $ProjectRoot 'go.mod')) { 'development' } else { 'production' }
        if ($buildProfile -eq 'development') {
            New-Item -ItemType Directory -Force (Split-Path -Parent $Binary) | Out-Null
            Invoke-Tool 'go' @('-C', $ProjectRoot, 'build', '-mod=readonly', '-trimpath', '-o', $Binary, '.')
        } elseif ($buildProfile -eq 'production') {
            if (-not (Test-Path $Binary) -or -not (Test-Path (Join-Path $ProjectRoot 'bin/provider-linux'))) { throw 'Release archive is missing its bridge or Linux provider binary' }
        } else { throw 'Build profile must be development or production' }
        Invoke-Tool 'docker' @('build', '--file', (Join-Path $ProjectRoot 'Dockerfile'), '--target', $buildProfile, '--tag', $Image, $ProjectRoot)
        exit 0
    }
    $Settings = Get-Content -Raw $ConfigPath | ConvertFrom-Json
    if ($Settings.profile -ne $AddonProfile) { throw 'Configuration profile differs from the selected Minikube profile' }
    if ($Settings.namespace -notmatch '^[a-z0-9]([a-z0-9-]*[a-z0-9])?$') { throw 'Invalid namespace' }
    $KubeArguments = @('--context', $AddonProfile, '--namespace', $Settings.namespace)
    $BridgeArguments = @("--config=$ConfigPath", "--state-dir=$StateDir")
    switch ($Action) {
        'init' {
            Invoke-Tool $Binary (@('--mode=init') + $BridgeArguments)
            Protect-Base
        }
        'bridge' { Invoke-Tool $Binary (@('--mode=bridge') + $BridgeArguments) }
        'resume' {
            $existing = Invoke-Tool 'docker' @('container', 'ls', '--filter', "name=^/$Container`$", '--format', '{{.ID}}')
            if ($existing) { throw 'Disable the addon before resuming' }
            Invoke-Tool $Binary (@('--mode=resume') + $BridgeArguments)
        }
        'enable' {
            $state = Get-Content -Raw (Join-Path $StateDir 'provider/state.json') | ConvertFrom-Json
            if ([string]$state.Error -ne '') { throw 'Provider is paused; inspect status and recover before enabling' }
            Protect-Base
            Invoke-Tool $Binary (@('--mode=bridge-check') + $BridgeArguments)
            $existing = Invoke-Tool 'docker' @('container', 'ls', '--all', '--filter', "name=^/$Container`$", '--format', '{{.ID}}')
            if ($existing) {
                Invoke-Tool 'docker' @('start', $Container)
            } else {
                # Docker Desktop supplies host.docker.internal. Its node-facing
                # IP is not a Windows interface, so publish through Desktop's
                # port forwarding. Both network links still require mutual TLS.
                $providerDir = Join-Path $StateDir 'provider'
                Invoke-Tool 'docker' @('run', '--detach', '--name', $Container, '--read-only', '--cap-drop=ALL', '--security-opt=no-new-privileges', '--pids-limit=64', '--memory=256m', '--cpus=0.5', '--user=65532:65532', '--publish=50051:50051', '--mount', "type=bind,src=$providerDir,dst=/state", $Image)
            }
            Invoke-Tool $Binary (@('--mode=check') + $BridgeArguments)
            $tlsDir = Join-Path $StateDir 'client/tls'
            $secret = Invoke-Tool 'kubectl' ($KubeArguments + @('create', 'secret', 'generic', "$Release-client", "--from-file=$tlsDir/ca.crt", "--from-file=$tlsDir/autoscaler-client.crt", "--from-file=$tlsDir/autoscaler-client.key", '--dry-run=client', '-o', 'yaml'))
            $secret | & kubectl @KubeArguments apply -f -
            if ($LASTEXITCODE -ne 0) { throw 'Could not install autoscaler client credentials' }
            Prepare-Chart
            Invoke-Tool 'kubectl' ($KubeArguments + @('apply', '--server-side', '--field-manager=minikube-cluster-autoscaler-addon', '-f', (Join-Path $Chart 'provisioningrequests.yaml')))
            $timeout = [int]$Settings.provisionTimeoutSeconds + 60
            Invoke-Tool 'helm' @('upgrade', '--install', $Release, $Chart, '--kube-context', $AddonProfile, '--namespace', $Settings.namespace, '--set-string', "provider.address=$($Settings.listen)", '--set-string', "cluster-autoscaler.autoDiscovery.clusterName=$AddonProfile", '--set-string', "cluster-autoscaler.extraArgs.max-node-provision-time=$($timeout)s", '--wait', '--timeout', '5m')
        }
        'test' {
            Invoke-Tool $Binary (@('--mode=check') + $BridgeArguments)
            Invoke-Tool 'kubectl' ($KubeArguments + @('rollout', 'status', "deployment/$Release", '--timeout=2m'))
        }
        'status' {
            Get-Content -Raw (Join-Path $StateDir 'provider/state.json')
            Invoke-Tool 'docker' @('ps', '-a', '--filter', "name=^/$Container`$")
            Invoke-Tool 'kubectl' ($KubeArguments + @('get', 'nodes', '-L', 'minikube-autoscaler.astrivant.com/pool'))
        }
        'disable' {
            Invoke-Tool 'helm' @('uninstall', $Release, '--kube-context', $AddonProfile, '--namespace', $Settings.namespace, '--ignore-not-found', '--wait', '--timeout', '5m')
            $existing = Invoke-Tool 'docker' @('container', 'ls', '--all', '--filter', "name=^/$Container`$", '--format', '{{.ID}}')
            if ($existing) {
                Invoke-Tool 'docker' @('stop', '--timeout', '30', $Container)
                Invoke-Tool 'docker' @('rm', $Container)
            }
            Write-Output 'Addon disabled. Nodes, base placement, credentials and journals were retained.'
        }
    }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
