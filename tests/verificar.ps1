# Verificación compacta: import -> smoke -> autotest (+ diag opcionales). Imprime solo errores y FALLOS.
param([string[]]$Diag = @(), [string]$Godot = $env:GODOT)
# Ruta de Godot: -Godot, variable de entorno GODOT o la primera de estas que exista en la PC.
$g = $Godot
if (-not $g) {
	$g = @("C:\Users\Usuario\Downloads\Godot_v4.7-stable_win64_console.exe",
		"$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe") |
		Where-Object { Test-Path $_ } | Select-Object -First 1
}
function Run($a) { & $g --headless @a 2>&1 | Select-String -Pattern 'ERROR|SCRIPT ERROR|Parse Error|FALLOS|FAIL' | Select-Object -First 15 }
"== import";  Run @('--import')
"== smoke";   Run @('--path','.','--quit-after','5')
"== autotest"; Run @('--path','.','--script','res://tests/autotest.gd')
foreach ($d in ($Diag -split ',' | Where-Object { $_ })) { "== $d"; Run @('--path','.','--script',"res://tests/$d.gd") }
"== fin"
