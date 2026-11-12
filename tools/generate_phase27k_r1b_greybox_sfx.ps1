param(
    [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\audio\sfx')
)

$ErrorActionPreference = 'Stop'
$sampleRate = 44100
$specs = [ordered]@{
    ui_click = @(620.0, 0.09, 0.34, 0.05)
    ui_error = @(220.0, 0.18, 0.38, -0.18)
    card_play = @(420.0, 0.20, 0.42, 0.20)
    monster_land = @(150.0, 0.24, 0.46, -0.10)
    spell_cast = @(520.0, 0.32, 0.40, 0.45)
    monster_attack = @(260.0, 0.18, 0.46, 0.35)
    monster_hit = @(120.0, 0.16, 0.50, -0.20)
    shield_block = @(760.0, 0.20, 0.38, -0.32)
    building_land = @(180.0, 0.28, 0.44, -0.08)
    counter_set = @(680.0, 0.22, 0.36, 0.22)
    od_up = @(480.0, 0.18, 0.38, 0.28)
    od_charge_tick = @(700.0, 0.10, 0.30, 0.08)
    enter_heated = @(340.0, 0.34, 0.42, 0.42)
    enter_overdrive = @(210.0, 0.46, 0.48, 0.70)
    od_release_extract = @(300.0, 0.30, 0.42, 0.50)
    od_release_conduit = @(560.0, 0.34, 0.38, 0.18)
    od_release_impact = @(105.0, 0.38, 0.52, -0.18)
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

function Write-PcmWave {
    param(
        [string]$Path,
        [double]$Frequency,
        [double]$Duration,
        [double]$Amplitude,
        [double]$Sweep
    )
    $sampleCount = [int][Math]::Round($sampleRate * $Duration)
    $dataBytes = $sampleCount * 2
    $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write)
    $writer = [System.IO.BinaryWriter]::new($stream)
    try {
        $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
        $writer.Write([int](36 + $dataBytes))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
        $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
        $writer.Write([int]16)
        $writer.Write([int16]1)
        $writer.Write([int16]1)
        $writer.Write([int]$sampleRate)
        $writer.Write([int]($sampleRate * 2))
        $writer.Write([int16]2)
        $writer.Write([int16]16)
        $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
        $writer.Write([int]$dataBytes)
        for ($i = 0; $i -lt $sampleCount; $i++) {
            $t = $i / [double]$sampleRate
            $u = $i / [double][Math]::Max(1, $sampleCount - 1)
            $attack = [Math]::Min(1.0, $u / 0.08)
            $release = [Math]::Min(1.0, (1.0 - $u) / 0.28)
            $envelope = $attack * $release
            $phase = 2.0 * [Math]::PI * $Frequency * $t * (1.0 + $Sweep * $u * 0.5)
            $tone = [Math]::Sin($phase) * 0.72 + [Math]::Sin($phase * 2.01) * 0.18 + [Math]::Sin($phase * 0.503) * 0.10
            $value = [Math]::Max(-0.94, [Math]::Min(0.94, $tone * $Amplitude * $envelope))
            $writer.Write([int16][Math]::Round($value * 32767.0))
        }
    }
    finally {
        $writer.Dispose()
        $stream.Dispose()
    }
}

foreach ($entry in $specs.GetEnumerator()) {
    $values = $entry.Value
    Write-PcmWave -Path (Join-Path $OutputDirectory ($entry.Key + '.wav')) -Frequency $values[0] -Duration $values[1] -Amplitude $values[2] -Sweep $values[3]
}

Get-ChildItem -LiteralPath $OutputDirectory -Filter '*.wav' | Sort-Object Name | ForEach-Object {
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
    Write-Output ("{0} {1} {2}" -f $_.Name, $_.Length, $hash)
}
