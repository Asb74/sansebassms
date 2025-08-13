# Codemagic App Store Connect environment variables (example)

Define the following variables in Codemagic under **App settings → Environment variables** inside a group named `app_store_connect`:

```
APP_STORE_CONNECT_ISSUER_ID=...
APP_STORE_CONNECT_KEY_IDENTIFIER=...
APP_STORE_CONNECT_PRIVATE_KEY=*** (contenido del .p8) ***
APPLE_TEAM_ID=...
APP_STORE_APPLE_ID=...
BUNDLE_ID=com.tu.bundle
```

Use placeholders here; do not commit secrets.
