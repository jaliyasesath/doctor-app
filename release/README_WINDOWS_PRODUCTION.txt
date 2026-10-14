PP App - Windows Production Build Preparation

STATUS: Build tooling prepared. No Windows EXE/installer has been compiled here.
Flutter, PowerShell and Inno Setup unavailable in this environment. Installer,
upgrade/uninstall and signing must be tested on Windows before public release.
No existing Flutter/mobile/API files are replaced by this ZIP.

COPY NEW FILES TO:
release/build_windows_release.ps1
release/prepare_windows_branding.ps1
release/pp_app_setup.iss
release/README_WINDOWS_PRODUCTION.txt
Keep the three scripts in the same release folder.

PREREQUISITES:
- Complete current Flutter project with all prior patches applied.
- Flutter Windows toolchain: Visual Studio Desktop development with C++.
- Inno Setup 6.3+ compiler (ISCC.exe).
- Working production HTTPS API URL and valid certificate. Never use the current
  HTTP VPS UAT address for this script. URL values are compiled into the app;
  these defines are configuration, not secret storage.
- Approved Windows ICO icon (multiple sizes incl. 256px recommended).
- Supported Microsoft Visual C++ x64 runtime on target machines. This installer
  does not install/download that prerequisite. Verify on a clean Windows PC.

RUN FROM YOUR PROJECT ROOT IN POWERSHELL:

1. Prepare Windows name (preserves binary/package/storage identity):
   .\release\prepare_windows_branding.ps1 -ProjectRoot .

   With an approved icon:
   .\release\prepare_windows_branding.ps1 -ProjectRoot . -IconPath 'C:\Brand\pp_app.ico'

   Only native window title and FileDescription/ProductName are changed.
   Existing native files are backed up in release-backups. Existing icon retained
   if no ICO supplied. This script validates expected template patterns before
   changing files and stops on unfamiliar runner code. It does not update company
   legal metadata, package IDs, encryption keys or user-data folders.

2. Confirm pubspec.yaml version. Current source: 1.1.1+14.
   Keep this for current preparation; increment before a new published release.
   Changing the shared pubspec version also affects future mobile builds.

3. Build using YOUR actual HTTPS base URL (example only):
   .\release\build_windows_release.ps1 -ProjectRoot . -ApiUrl 'https://YOUR-DOMAIN/api'

   Optional explicit compiler path:
   .\release\build_windows_release.ps1 -ProjectRoot . -ApiUrl 'https://YOUR-DOMAIN/api' -IsccPath 'C:\Program Files (x86)\Inno Setup 6\ISCC.exe'

   Default runs pub get, analyze, all Flutter tests, release build, installer.
   First failed command stops the script. -SkipTests exists only for local build
   diagnosis; it is recorded in the manifest. Do not skip tests for release.
   Windows defines: PP_CLOUD_API_URL=<your URL>, PP_ALLOW_INSECURE_HTTP=false.
   Existing mobile config is untouched. Existing auto/LAN security still requires
   separate review: these flags alone do not certify all connection paths.

OUTPUTS:
- build/windows/x64/runner/Release/ : entire Flutter release bundle.
- dist/windows/PP_App_Setup_1.1.1_14.exe (name follows pubspec version).
- installer .sha256 and release_build_info.json.
- Missing ISCC: script reports built bundle, stops without claiming an installer.
- No automatic clean or native regeneration. x64 only; ARM64/flavors need a
  reviewed output-path/installer adaptation.

INSTALLER / UPDATES:
- Per-user install, no admin prompt, start menu shortcut, optional desktop shortcut.
- Permanent installer AppId retained between releases. Do not regenerate it.
- Before replacing an old release, close PP App normally; installer uses Windows
  Restart Manager and does not force-close the app.
- User database/secure storage/log folders are not deleted by installer scripts.
- Existing data preservation still needs an upgrade test: back up test data, install
  old version, add records, update, log in and confirm records and keys still work.
- Downgrade/data migration compatibility is NOT implemented here; do not install
  older builds over a migrated database without a tested restore procedure.
- No auto-update agent. Users run the next signed installer manually.
- Bundle must be tested with existing printing and encrypted SQLite plugins on a
  clean target. An executable alone is insufficient.

ERROR / CRASH LOGGING:
Existing main.dart has FlutterError, PlatformDispatcher, zone and ErrorWidget
handlers using AppErrorHandler/AppLogger. Existing logger stores a rotating local
support-directory logs/doctor_app_errors.log (~1 MiB threshold, retains ~512 KiB).
Logger was NOT replaced. It can include raw exception/context details, so patient
information/token redaction still needs security review before support sharing.
Dart exception capture is not native process-crash/minidump collection; remote crash
monitoring, consent, retention and native dump handling are not configured here.

RELEASE CHECKS STILL PENDING:
- Full Windows regression and License/Subscription test cases.
- Security review (cloud HTTPS enforcement on all modes, doctor/role isolation,
  local pairing, secure storage, logs and exported patient PDFs).
- Real Canon G3730 print and PDF export tests.
- Installer fresh install, update, uninstall, restart and clean-machine prerequisites.
- Authenticode code signing with your signing certificate; build here is unsigned.
  Sign executable before packaging, then sign installer and regenerate SHA256.
- Backend capacity/load tests for 5000 simultaneous users; desktop installer work
  does not establish server capacity.

References:
https://docs.flutter.dev/platform-integration/windows/setup
https://docs.flutter.dev/platform-integration/windows/building
https://docs.flutter.dev/release/breaking-changes/windows-build-architecture
https://jrsoftware.org/ishelp/topic_setup_privilegesrequired.htm
https://jrsoftware.org/ishelp/topic_setup_closeapplications.htm

UPDATE - HTTP UAT INSTALLER OPTION
Domain/HTTPS not available yet? Run from your project root:

.\release\build_windows_release.ps1 -ProjectRoot . -ApiUrl 'http://169.58.40.160/api' -AllowInsecureHttpForTesting

This explicit switch builds Windows with insecure HTTP allowed and labels output
_UAT.exe in dist/windows/UAT. Without the switch HTTPS remains required and HTTP
is disabled. Production output is in dist/windows/Production.
UAT and production share the same installer identity and app data: this is an
upgrade path, NOT an isolated test installation. Use a test PC/account with test
data. HTTP traffic is unencrypted. No domain is required for this UAT build.
Installer shows PP App; _UAT is an artifact label, not a permanent in-app banner.
All previous compilation, signing, prerequisites and runtime caveats still apply.
