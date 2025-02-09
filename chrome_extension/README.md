# General

1. Manifest: Update your with your trackerURL
2. content.js: Update your trackerURLs
3. Open: chrome://extensions/ and load the extension (select the folder)


# Future

Dynamic setting of tracker URL's and API keys. Besides that also dynamic setting
of external tracker URL in the manifest.

```
"contextMenus", "storage"
// Retrieve settings from chrome.storage
chrome.storage.local.get(
  ['secretKey', 'trackerUrlClick', 'trackerUrlImage', 'autoOn'],
  (items) => {
    const secretKey = items.secretKey || '';
    const trackerUrlClick = items.trackerUrlClick || '';
    const trackerUrlImage = items.trackerUrlImage || '';
    const autoOn = items.autoOn || false;

    // Use these settings as needed in your content script
    // For example, you can check if autoOn is enabled and proceed accordingly
    if (autoOn) {
      // Auto-On mode is enabled, perform automatic tracking
    } else {
      // Manual mode, perhaps add a button for users to trigger tracking
    }
  }
);
```
