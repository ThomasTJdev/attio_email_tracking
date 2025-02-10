
chrome.runtime.onStartup.addListener(() => {
  chrome.storage.local.get("CONSTANTS", (data) => {
    if (!data.CONSTANTS || !data.CONSTANTS.SERVER_URL) {
      console.warn("⚠️ SERVER_URL is empty. Opening settings...");
      chrome.runtime.openOptionsPage(); // Opens settings automatically
    }
  });
});


chrome.runtime.onInstalled.addListener(() => {
  chrome.storage.local.get("CONSTANTS", (data) => {
    if (!data.CONSTANTS) {
      // If no stored settings, initialize with defaults
      const CONSTANTS = {
        SERVER_URL: "https://your-attio-tracking-url.com",
        SECRET_KEY: "xxx",
        TRACKING_MANUALLY: true,
        TRACKING_AUTO_FOR_OWNER: "you@main.crm.email",
      };

      chrome.storage.local.set({ CONSTANTS }, () => {
        console.log("✅ Default constants stored.");
      });
    }
  });

  // ✅ Reload content scripts on extension update
  chrome.tabs.query({ url: "https://mail.google.com/*" }, (tabs) => {
    for (let tab of tabs) {
      chrome.scripting.executeScript({
        target: { tabId: tab.id },
        files: ["content.js"],
      });
    }
  });
});


/* global chrome */
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === 'inboxsdk__injectPageWorld' && sender.tab) {
    if (chrome.scripting) {
      // MV3
      let documentIds;
      let frameIds;
      if (sender.documentId) {
        // Protect against https://github.com/w3c/webextensions/issues/8 in
        // browsers (Chrome 106+) that support the documentId property.
        // Protections for other browsers happen inside the injected script.
        documentIds = [sender.documentId];
      } else {
        frameIds = [sender.frameId];
      }
      chrome.scripting.executeScript({
        target: { tabId: sender.tab.id, documentIds, frameIds },
        world: 'MAIN',
        files: ['pageWorld.js'],
      });
      sendResponse(true);
    } else {
      // MV2 fallback. Tell content script it needs to figure things out.
      sendResponse(false);
    }
  }
});



chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === "sendTrackingData") {
    const trackingData = message.trackingData;

    fetch(CONSTANTS.SERVER_URL + "/webhook/attio/email" + "?secret=" + CONSTANTS.SECRET_KEY, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(trackingData),
      keepalive: true,
    })
    .then(async (response) => {
      const responseText = await response.text(); // Read raw response

      console.log("🔄 Raw Server Response:", responseText);
      console.log("📡 Response Status:", response.status);

      if (response.ok) {
        sendResponse({ success: true, data: responseText });
      } else {
        console.error("❌ Server returned an error:", response.status, responseText);
        sendResponse({ success: false, error: responseText, msg: "❌ Server returned an error" });
      }
    })
    .catch((error) => {
      console.error("❌ Network or Fetch Error:", error);
      sendResponse({ success: false, error: error.message, msg: "❌ Network or Fetch Error" });
    });
    return true; // **Important!** Keeps `sendResponse` valid for async operations
  }
});