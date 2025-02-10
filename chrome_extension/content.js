


// Get constants

// Initialize InboxSDK
InboxSDK.load(2, 'sdk_TrackForAttio_665d14e77e').then(async (sdk) => {
  let CONSTANTS;
  try {
    CONSTANTS = await getConstants();
    console.log("✅ Loaded Constants:", CONSTANTS);
  } catch (error) {
    console.error("❌ Failed to load constants:", error);
    return; // Exit if constants are missing
  }

  // Register a handler for compose views
  sdk.Compose.registerComposeViewHandler((composeView) => {
    if (CONSTANTS.TRACKING_MANUALLY) {
      // On manual tracking but with auto set for specific email
      if (
        CONSTANTS.TRACKING_AUTO_FOR_OWNER &&
        CONSTANTS.TRACKING_AUTO_FOR_OWNER === sdk.User.getEmailAddress()
      ) {
        attachSendListeners(composeView, CONSTANTS);
      } else {
        // Add a custom "Inject Tracking" button to the compose toolbar
        composeView.addButton({
          title: 'Inject Attio email open and click tracking',
          iconUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/wcAAwAB/atRngAAAABJRU5ErkJggg==', // 1x1 transparent PNG
          iconClass: 'custom-text-button',
          onClick: () => {
            handleTracking(composeView, CONSTANTS);
            composeView.getElement().querySelector(".custom-text-button").parentElement.style.display = "none";
          },
        });

        const buttons = document.querySelectorAll('.custom-text-button');
        buttons.forEach((button) => {
          modifyInboxSdkButton(button);
        });
      }

    } else {
      // Attach event listeners to native Send and Schedule Send buttons
      attachSendListeners(composeView, CONSTANTS);
    }
  });
});


// Function to get constants from storage (returns a Promise)
async function getConstants() {
  return new Promise((resolve, reject) => {
    // Check if the Chrome extension API is available
    if (!chrome || !chrome.storage || !chrome.storage.local) {
      console.error("❌ Chrome storage API is not available.");
      reject("Chrome storage API is not available.");
      return;
    }

    chrome.storage.local.get("CONSTANTS", (data) => {
      if (chrome.runtime.lastError) {
        console.error("❌ Error accessing storage:", chrome.runtime.lastError);
        reject(chrome.runtime.lastError);
        return;
      }

      if (data.CONSTANTS) {
        resolve(data.CONSTANTS);
      } else {
        console.error("❌ Failed to load constants from storage.");
        resolve(null);
      }
    });
  });
}



// Function to modify the button when it's detected
function modifyInboxSdkButton(button) {
  button.innerText = 'Inject Tracking'; // Replace icon with text
  button.style.width = 'auto';
  // button.style.minWidth = '120px';
  button.style.fontSize = '14px';
  button.style.padding = '6px 12px';
  button.style.textAlign = 'center';
  button.style.opacity = '.9';
  button.style.cursor = 'pointer';

  let parent = button.parentElement;
  parent.style.width = '100px';
  parent.style.minWidth = '100px';
  parent.style.fontSize = '14px';
  parent.style.padding = '6px 12px';
  parent.style.textAlign = 'center';
  parent.style.backgroundColor = '#2d2626e3';
  parent.style.color = 'white';
  parent.style.borderRadius = '8px';
}


// Function to handle tracking
async function handleTracking(composeView, CONSTANTS) {
  // Get the first recipient's email address
  const recipients = composeView.getToRecipients();
  if (recipients.length === 0) {
    alert('No recipient email found. Please add a recipient.');handleTracking
    return;
  }
  const email = recipients[0].emailAddress;

  // Get the email subject
  const subject = composeView.getSubject() || 'No Subject';

  // Generate a unique 10-character tracking ID
  const trackingId = generateUniqueId();

  // Send tracking data to backend
  console.log("📡 Sending tracking data");
  sendTrackingData(email, subject, trackingId);

  // Insert tracking pixel and rewrite links
  console.log("🖼️ Inserting tracking pixel");
  insertTrackingPixel(composeView, trackingId, CONSTANTS.SERVER_URL, CONSTANTS.CUSTOM_IMAGE_URL);
  console.log("🔗 Rewriting links");
  rewriteLinks(composeView, trackingId, CONSTANTS.SERVER_URL);
  console.log("✅ Tracking completed");
}

// Function to attach event listeners to native Send and Schedule Send buttons
async function attachSendListeners(composeView, CONSTANTS) {

  // Listen for the 'presending' event to trigger tracking before sending
  composeView.on('presending', (event) => {
    handleTracking(composeView, CONSTANTS);
  });
}

// Function to generate a unique character ID
function generateUniqueId() {
  const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  let uniqueId = '';
  for (let i = 0; i < 20; i++) {
    uniqueId += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return uniqueId;
}

// Function to send tracking data to backend
function sendTrackingData(email, subject, trackingId) {

  const trackingData = {
    email: email.toLowerCase().trim(),
    subject: subject.trim(),
    ident: trackingId
  };

  console.info("📡 Sending tracking data:", trackingData);

  // Send the data to background.js
  chrome.runtime.sendMessage(
    {
      action: "sendTrackingData",
      trackingData: trackingData,
    },
    (response) => {
      if (chrome.runtime.lastError) {
        console.error("❌ Error sending message to background.js:", chrome.runtime.lastError);
      } else {
        console.log("📡 Response from background.js:", response);
      }
    }
  );

  console.log("📡 Tracking data sent background worker");
}

// Function to insert a tracking pixel into the email body
function insertTrackingPixel(composeView, trackingId, SERVER_URL, CUSTOM_IMAGE_URL) {
  let trackingUrl = SERVER_URL + "/webhook/attio/email_opened.png" + `?ident=${trackingId}&nocache=${Date.now()}`;
  if (CUSTOM_IMAGE_URL !== "") {
    const customImageBase64 = btoa(CUSTOM_IMAGE_URL);
    trackingUrl += `&ciurl=${customImageBase64}`;
  }

  let trackingPixel = `<img class="attio-tracking-pixel" src="${trackingUrl}" width="1" height="1" style="display:none;" />`;
  if (CUSTOM_IMAGE_URL != "") {
    trackingPixel = `<div class="attio-tracking-pixel" style="text-align: center"><img src="${trackingUrl}" width="auto" height="10" style="max-height: 10px; width: auto; padding-top: 10px;" /></div>`;
  }

  // 🗑️ Remove existing tracking pixels before inserting a new one
  removeExistingTrackingPixels(composeView);

  // ✅ Insert the new tracking pixel
  //composeView.insertHTMLIntoBodyAtCursor(trackingPixel);
  const bodyElement = composeView.getBodyElement();
  if (bodyElement) {
    bodyElement.insertAdjacentHTML('beforeend', trackingPixel);
  }
}

// Function to remove old tracking pixels from the email body
function removeExistingTrackingPixels(composeView) {
  const body = composeView.getBodyElement();
  if (!body) return;

  const existingPixels = body.querySelectorAll(".attio-tracking-pixel");
  existingPixels.forEach((pixel) => pixel.remove());
}

// Function to rewrite links in the email body with tracking ID
function rewriteLinks(composeView, trackingId, SERVER_URL) {
  const bodyElement = composeView.getBodyElement();
  const links = bodyElement.querySelectorAll('a');

  links.forEach((link) => {
    const originalUrl = link.href;
    if (originalUrl.startsWith('http')) {
      const encodedUrl = btoa(originalUrl);
      const trackingUrl = SERVER_URL + "/webhook/attio/email_clicked" + `?link=${encodedUrl}&ident=${trackingId}`;
      link.href = trackingUrl;
    }
  });
}
