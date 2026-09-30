# Verificación compacta: import -> smoke -> autotest (+ diag opcionales). Imprime solo errores y FALLOS.
param([string[]]$Diag = @())
$g = "C:\Users\Usuario\Downloads\Godot_v4.7-stable_win64_console.exe"
function Run($a) { & $g --headless @a 2>&1 | Select-String -Pattern 'ERROR|SCRIPT ERROR|Parse Error|FALLOS|FAIL' | Select-Object -First 15 }
"== import";  Run @('--import')
"== smoke";   Run @('--path','.','--quit-after','5')
"== autotest"; Run @('--path','.','--script','res://tests/autotest.gd')
foreach ($d in $Diag) { "== $d"; Run @('--path','.','--script',"res://tests/$d.gd") }
"== fin"
