
/*
  UPDATE THESE VARIABLES:
*/

// Secret key for authenticating tracking requests
const SECRET_KEY    = "gmail_tracker_attio"

// Tracking host URL
const trackingHost  = "https://your-attio-tracking-url.com";

// Set to true if you want to manually track emails using a custom button,
// or false if you want to automatically track all emails
const trackingManual = true;

// Insert your email below if you want AUTO TRACKING for that. This is
// especially if you have multiple GMail accounts open. Leave it empty
// if `trackingManual` needs to manage it completely.
const trackingAutoForOwner = "";

/*
  UPDATE THE VARIABLES ABOVE
*/


// Define tracking URLs
const trackingSetup = trackingHost + "/webhook/attio/email";
const trackingImage = trackingHost + "/webhook/attio/email_opened.png";
const trackingLinks = trackingHost + "/webhook/attio/email_clicked";

// Initialize InboxSDK
InboxSDK.load(2, 'sdk_TrackForAttio_665d14e77e').then((sdk) => {
  // Register a handler for compose views
  sdk.Compose.registerComposeViewHandler((composeView) => {
    if (trackingManual) {

      // On manual tracking but with auto set for specific email
      if (trackingAutoForOwner && trackingAutoForOwner === sdk.User.getEmailAddress()) {
        attachSendListeners(composeView);
      } else {
        // Add a custom "Inject Tracking" button to the compose toolbar
        composeView.addButton({
          title: 'Inject Tracking',
          iconUrl: trackingHost + '/assets/attio/mail_button.png', // Replace with your icon URL
          onClick: () => {
            handleTracking(composeView);
          },
        });
      }

    } else {
      // Attach event listeners to native Send and Schedule Send buttons
      attachSendListeners(composeView);
    }
  });
});

// Function to handle tracking
function handleTracking(composeView) {
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
  sendTrackingData(email, subject, trackingId);

  // Insert tracking pixel and rewrite links
  insertTrackingPixel(composeView, trackingId);
  rewriteLinks(composeView, trackingId);
}

// Function to attach event listeners to native Send and Schedule Send buttons
function attachSendListeners(composeView) {
  // Listen for the 'presending' event to trigger tracking before sending
  composeView.on('presending', (event) => {
    handleTracking(composeView);
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
    ident: trackingId,
    secret_key: SECRET_KEY, // Replace with your actual secret key
    };

  fetch(trackingSetup, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(trackingData),
    keepalive: true,
  })
    .then((response) => {
      if (response.ok) {
        console.log('Tracking data successfully sent.');
      } else {
        console.error('Failed to send tracking data.');
      }
    })
    .catch((error) => {
      console.error('Error sending tracking data:', error);
    });
}

// Function to insert a tracking pixel into the email body
function insertTrackingPixel(composeView, trackingId) {
  const trackingUrl = trackingImage + `?ident=${trackingId}&nocache=${Date.now()}`;
  const trackingPixel = `<img src="${trackingUrl}" width="1" height="1" style="display:none;" />`;

  composeView.insertHTMLIntoBodyAtCursor(trackingPixel);
}

// Function to rewrite links in the email body with tracking ID
function rewriteLinks(composeView, trackingId) {
  const bodyElement = composeView.getBodyElement();
  const links = bodyElement.querySelectorAll('a');

  links.forEach((link) => {
    const originalUrl = link.href;
    if (originalUrl.startsWith('http')) {
      const encodedUrl = btoa(originalUrl);
      const trackingUrl = trackingLinks + `?link=${encodedUrl}&ident=${trackingId}`;
      link.href = trackingUrl;
    }
  });
}
