Write-Host "Deploying to server..."
Write-Host $PSScriptRoot
cd $PSScriptRoot

$keyPath = (Convert-Path "~/.ssh/id_rsa")
$knownHostsPath = (Convert-Path "~/.ssh/known_hosts")
$target = "outerplanet@conryclan.com:~/conryclan.com/projects/satellite/sstv/"
rsync -av -e "/usr/bin/ssh -i $keyPath -o UserKnownHostsFile=$knownHostsPath" `
	--include="*/" --include="*.php" --include=".htaccess" --exclude="*" `
	--chmod=D755,F644 `
	./ $target
