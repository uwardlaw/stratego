# Grab the package name
$packageName = (get-item .).parent.name

#wget https://www.python.org/ftp/python/3.11.4/python-3.11.4-amd64.exe -o python.exe
#New-Item -ItemType Directory -Force -Path .\python | Out-Null
#$pythonPath = ((Get-Location).Path)+"\python\"
#./python-install.exe /quiet DefaultJustForMeTargetDir=$pythonPath Include_launcher=0 
#rm ./python-install.exe

# Grab a fresh python installation
wget https://www.python.org/ftp/python/3.11.1/python-3.11.1-embed-amd64.zip -o python.zip
expand-archive python.zip
mv .\python\python311._pth .\python\python311.pth
mkdir .\python\DLLs
wget https://bootstrap.pypa.io/get-pip.py -o get-pip.py
python\python.exe get-pip.py

# Install tkinter
expand-archive tk-files.zip .\tk-files

copy-item .\tk-files\tcl\tcl8.6\ .\python\Lib\ -recurse
copy-item .\tk-files\tcl\tk8.6\ .\python\Lib\ -recurse
mv .\tk-files\tcl .\python\
mv .\tk-files\tkinter .\python\
mv .\tk-files\_tkinter.pyd .\python\DLLs
mv .\tk-files\tcl86t.dll .\python\DLLs
mv .\tk-files\tk86t.dll .\python\DLLs
rm tk-files*

$exePath = "$env:TEMP\git.exe"

#Check if git is installed, and if it's not, go and install it
try{
    git | Out-Null
   "Git is installed"
}
catch [System.Management.Automation.CommandNotFoundException]{
   # Download git installer
   Invoke-WebRequest -Uri https://github.com/git-for-windows/git/releases/download/v2.38.1.windows.1/Git-2.38.1-64-bit.exe -UseBasicParsing -OutFile $exePath

   # Execute git installer
   Start-Process $exePath -ArgumentList '/VERYSILENT /NORESTART /NOCANCEL /SP- /CLOSEAPPLICATIONS /RESTARTAPPLICATIONS /COMPONENTS="icons,ext\reg\shellhere,assoc,assoc_sh"' -Wait

   # Make new environment variables available in the current PowerShell session:
   foreach($level in "Machine","User") {
      [Environment]::GetEnvironmentVariables($level).GetEnumerator() | % {
         # For Path variables, append the new values, if they're not already in there
         if($_.Name -match 'Path$') { 
            $_.Value = ($((Get-Content "Env:$($_.Name)") + ";$($_.Value)") -split ';' | Select -unique) -join ';'
         }
         $_
      } | Set-Content -Path { "Env:$($_.Name)" }
   }
}

# Clean up python install
rm python.zip
rm get-pip.py

# Install and activate virtualenv
python\python.exe -m pip install virtualenv
python\python.exe -m virtualenv ..\venv
cp python\python311.zip ..\venv\Scripts\
..\venv\Scripts\Activate.ps1

get-location

# Install initial requirements
pip install -r ..\requirements.txt

# Create a sublime build file for this project
$packageBuildPath = "$env:USERPROFILE\AppData\Roaming\Sublime Text\Packages\User\$packageName.sublime-build"

if (-not (Test-Path -Path $packageBuildPath -PathType Leaf)){
   New-Item $packageBuildPath

   Add-content -Path $packageBuildPath -Value "{"
   $secondLine = '    "cmd": ["' + (Get-item .).parent.fullname + "\venv\Scripts\python.exe" + '", "$file"],'
   $secondLine = $secondLine.replace('\', '/')
   Add-content -Path $packageBuildPath -Value $secondLine
   Add-content -Path $packageBuildPath -Value '    "file_regex": "^[ ]File \"(...?)\", line ([0-9]*)",'
   Add-content -Path $packageBuildPath -Value '    "selector": "source.activate",'
   Add-content -Path $packageBuildPath -Value '    "env": {"PYTHONIOENCODING": "utf8"}'
   Add-content -Path $packageBuildPath -Value "}" 
}
