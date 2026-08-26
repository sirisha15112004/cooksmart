$root = "C:\Users\Thirumalesh .K\OneDrive\Desktop\app_1"

Get-ChildItem -Path $root -Recurse -Filter *.dart | ForEach-Object {
    $path = $_.FullName
    $text = Get-Content -Path $path -Raw
    $updated = $text.Replace(".withOpacity(", ".withValues(")
    if ($updated -ne $text) {
        Set-Content -Path $path -Value $updated -Encoding utf8
    }
}

$chat = Join-Path $root "lib\services\chat_service.dart"
$text = Get-Content -Path $chat -Raw
if ($text.Contains("package:flutter/foundation.dart") -eq $false) {
    $text = $text.Replace("import 'dart:convert';`nimport 'dart:io';`n", "import 'dart:convert';`nimport 'dart:io';`nimport 'package:flutter/foundation.dart';`n")
}
$text = $text.Replace("print('Exception with API key ${i + 1}: $e');", "debugPrint('Exception with API key ${i + 1}: $e');")
Set-Content -Path $chat -Value $text -Encoding utf8

Write-Host "updated deprecated APIs"
