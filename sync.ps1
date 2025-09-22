# sync.ps1
# 一键同步 fork 仓库（fetch upstream -> merge -> push origin）

Write-Host "⏳ Start syncing upstream..." -ForegroundColor Cyan

# 拉取上游更新
git fetch upstream
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to fetch upstream"; exit }

# 切换到 main 分支
git checkout main
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to checkout main"; exit }

# 合并上游更新
git merge upstream/main
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to merge upstream/main"; exit }

# 推送到自己的 fork
git push origin main
if ($LASTEXITCODE -ne 0) { Write-Host "❌ Failed to push to origin"; exit }

Write-Host "✅ Sync completed!" -ForegroundColor Green
