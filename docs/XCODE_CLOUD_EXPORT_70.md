# Xcode Cloud: Export-Fehler „Exit Code 70“ beheben

Wenn der **Archive**-Schritt erfolgreich ist, aber **Export archive for … distribution** mit **exit code 70** fehlschlägt, liegt das fast immer an **Code Signing / Provisioning**, nicht am Build.

## In diesem Projekt verwendete Bundle-IDs

Diese müssen im [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list) unter **Certificates, Identifiers & Profiles → Identifiers** angelegt sein:

| App/Target              | Bundle-ID                                  |
|-------------------------|--------------------------------------------|
| iOS-App                 | `com.iaha.mvgcommuter`                     |
| Watch-App               | `com.iaha.mvgcommuter.watchkitapp`         |
| Watch Widgets Extension | `com.iaha.mvgcommuter.watchkitapp.widgets` |

## Checkliste

1. **Alle Bundle-IDs anlegen**
   - [Identifiers](https://developer.apple.com/account/resources/identifiers/list) öffnen.
   - Prüfen, ob **alle drei** obigen IDs existieren.
   - Fehlende anlegen:
     - **App IDs** für die iOS-App und die Watch-App.
     - **App IDs** mit „App Extension“ für die Watch Widgets Extension.

2. **Watch-App als „Watch App“ registrieren**
   - Die ID `com.iaha.mvgcommuter.watchkitapp` sollte als **Watch App** (nicht nur als normale App) konfiguriert sein und zur iOS-App `com.iaha.mvgcommuter` gehören.

3. **Xcode Cloud Signing**
   - In **App Store Connect** → dein App-Projekt → **Xcode Cloud** → Workflow: **Automatic** (managed) signing verwenden.
   - Sicherstellen, dass die **gleiche Development Team ID** (z. B. `9HS2528ANW`) für alle Targets genutzt wird.

4. **Zertifikate bereinigen (häufige Lösung)**
   - Im [Developer Portal](https://developer.apple.com/account/resources/certificates/list) unter **Certificates**:
     - **Apple Distribution** und **Apple Development** Zertifikate, die von Xcode/Xcode Cloud verwaltet werden, **revoken**.
   - Nächsten Xcode-Cloud-Build auslösen; Xcode Cloud legt neue Zertifikate an.
   - Hinweis: Es gibt Limits pro Account; alte/ungenutzte Zertifikate zu revoken kann Platz schaffen.

5. **Lokal prüfen**
   - In Xcode: **Product → Archive** mit Scheme **MunichCommuter**.
   - Danach **Distribute App** (z. B. Ad Hoc oder App Store) durchspielen.
   - Wenn der Export lokal mit dem gleichen Team fehlschlägt, liegt das Problem bei Signing/Provisioning im Account, nicht speziell an Xcode Cloud.

## Scheme-Anpassung (bereits umgesetzt)

Im Scheme **MunichCommuter** sind für **Archiving** jetzt alle relevanten Targets eingetragen:

- MunichCommuterWatchWidgets  
- MunichCommuterWatch  
- MunichCommuter  

So stellt Xcode Cloud sicher, dass Watch-App und Widget-Extension beim Archivieren und beim Export korrekt berücksichtigt werden.

## Weitere Infos

- [Xcode Cloud: All export archive steps fail with exit code 70](https://developer.apple.com/forums/thread/816085) (Apple Developer Forums)
- [Identifiers (Bundle IDs) anlegen](https://developer.apple.com/account/resources/identifiers/list)
