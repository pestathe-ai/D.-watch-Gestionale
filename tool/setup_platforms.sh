#!/usr/bin/env bash
# Crea la parte Android del progetto (cartella android/) e prepara l'icona.
set -euo pipefail
cd "$(dirname "$0")/.."

flutter create --project-name d_watch_gestionale --org dev.dwatch --platforms=android .
rm -f test/widget_test.dart

MANIFEST=android/app/src/main/AndroidManifest.xml
sed -i 's|android:label="[^"]*"|android:label="D. Watch Gestionale"|' "$MANIFEST"

# Android Lint va in crash su alcuni plugin (bug degli strumenti): lo disattiviamo.
mkdir -p "$HOME/.gradle/init.d"
cat > "$HOME/.gradle/init.d/no-lint.gradle" <<'GRADLE'
allprojects {
  tasks.configureEach { t ->
    if (t.name.startsWith('lintVital') || t.name.startsWith('lintAnalyze') || t.name.startsWith('lintReport')) {
      t.enabled = false
    }
  }
}
GRADLE

flutter pub get
dart run flutter_launcher_icons
