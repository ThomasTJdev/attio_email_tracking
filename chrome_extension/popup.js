document.addEventListener("DOMContentLoaded", () => {
  // Load stored constants
  chrome.storage.local.get("CONSTANTS", (data) => {
    if (data.CONSTANTS) {
      document.getElementById("serverUrl").value = data.CONSTANTS.SERVER_URL || "";
      document.getElementById("secretKey").value = data.CONSTANTS.SECRET_KEY || "";
      document.getElementById("trackingManually").checked = data.CONSTANTS.TRACKING_MANUALLY || false;
      document.getElementById("trackingOwner").value = data.CONSTANTS.TRACKING_AUTO_FOR_OWNER || "";
    }
  });

  // Save constants when the button is clicked
  document.getElementById("saveButton").addEventListener("click", () => {
    const CONSTANTS = {
      SERVER_URL: document.getElementById("serverUrl").value.trim(),
      SECRET_KEY: document.getElementById("secretKey").value.trim(),
      TRACKING_MANUALLY: document.getElementById("trackingManually").checked,
      TRACKING_AUTO_FOR_OWNER: document.getElementById("trackingOwner").value.trim(),
    };

    // Store constants
    chrome.storage.local.set({ CONSTANTS }, () => {
      document.getElementById("status").textContent = "Settings saved!";
      setTimeout(() => {
        document.getElementById("status").textContent = "";
      }, 2000);
    });
  });
});
