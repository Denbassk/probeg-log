# deploy.ps1 — публикация ПробегЛог на GitHub Pages
Set-Location 'D:\ProbegLog'
$app  = 'probeg-log'        # репозиторий с приложением (публичный)
$data = 'probeg-log-data'   # репозиторий с данными (приватный)

# 1. Проверка инструментов
$needRestart = $false
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $needRestart = $true
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements
    $needRestart = $true
}
if ($needRestart) {
    Write-Host 'Git / GitHub CLI установлены. Закройте PowerShell, откройте заново и запустите скрипт ещё раз.' -ForegroundColor Yellow
    exit
}

# 2. Вход в GitHub
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { gh auth login --hostname github.com --git-protocol https --web }
gh auth setup-git
$user = gh api user --jq .login
$uid  = gh api user --jq .id
Write-Host "Аккаунт: $user" -ForegroundColor Cyan

# 3. Имя/почта для коммитов (если ещё не заданы)
if (-not (git config --global user.name))  { git config --global user.name  $user }
if (-not (git config --global user.email)) { git config --global user.email "$uid+$user@users.noreply.github.com" }

# 4. Репозиторий с приложением
if (-not (Test-Path '.git')) { git init -b main | Out-Null }
git add -A
git commit -m "ПробегЛог: первая версия" 2>$null
gh repo view "$user/$app" *> $null
if ($LASTEXITCODE -ne 0) {
    gh repo create $app --public --description "Журнал пробега автомобиля" --source . --remote origin --push
} else {
    git remote get-url origin *> $null
    if ($LASTEXITCODE -ne 0) { git remote add origin "https://github.com/$user/$app.git" }
    git push -u origin main
}

# 5. Включение GitHub Pages
gh api -X POST "repos/$user/$app/pages" -f "source[branch]=main" -f "source[path]=/" *> $null
if ($LASTEXITCODE -eq 0) { Write-Host 'GitHub Pages включён' -ForegroundColor Green }
else { Write-Host 'GitHub Pages уже был включён (или включите вручную: Settings - Pages)' -ForegroundColor Yellow }

# 6. Приватный репозиторий для данных
gh repo view "$user/$data" *> $null
if ($LASTEXITCODE -ne 0) {
    gh repo create $data --private --description "Данные журнала пробега" --add-readme
    Write-Host "Создан приватный репозиторий $data" -ForegroundColor Green
}

# 7. Итог
$url = "https://$user.github.io/$app/"
Write-Host "`n============================================" -ForegroundColor Cyan
Write-Host "Приложение (заработает через 1-2 минуты): $url"
Write-Host "Данные будут храниться в: https://github.com/$user/$data"
Write-Host "Сейчас откроется страница создания токена." -ForegroundColor Yellow
Write-Host "============================================"
Start-Process "https://github.com/settings/personal-access-tokens/new"
