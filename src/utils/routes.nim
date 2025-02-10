
import
  std/[
    base64,
    envvars,
    json,
    strutils,
    times
  ]

import
  mummy, mummy/routers,
  mummy_utils

import
  ./attio,
  ./caching

const imageData = staticRead("../assets/mail_logo.png")
const mailButton = staticRead("../assets/mail_button.png")

# # Should we just keep it open?
# var apiclientLock: Lock
# initLock(apiclientLock)
# let client = attioApiClient(getEnv("ATTIO_API_KEY", "attio"))


proc handlerHealthchecksConnection*(request: Request) =
  resp Http200, ( %* { "server_time": $(now().utc) } )


proc handlerAssetsMailButton*(request: Request) =
  var headers: HttpHeaders
  headers["Content-Type"] = "image/png"
  request.respond(200, headers, mailButton)
  return


proc handlerWebhookAttioEmail*(request: Request) =
  ## Adding a new email to the cache

  #
  # Check the webhook secret
  #
  if @"secret" != getEnv("ATTIO_WEBHOOK_SECRET", "gmail_tracker_attio"):
    echo("ATTIO_WEBHOOK_SECRET not set")
    resp Http404

  #
  # Parse the JSON body
  #
  var
    jsonBody: JsonNode
    email: string
    subject: string
    ident: string
  try:
    jsonBody = parseJson(request.body)
    email = jsonBody["email"].getStr()
    subject = jsonBody["subject"].getStr()
    ident = jsonBody["ident"].getStr()
  except:
    echo("Invalid JSON: " & request.body)
    resp Http400, "Invalid JSON"


  #
  # Add the email to the cache
  #
  let data = %*{
    "email": email,
    "subject": subject,
    "epoch": toInt(epochTime())
  }
  cacheSet(CacheKey.emailData, ident, data)
  when defined(dev):
    echo("Added email to cache: " & ident & " - " & $data)

  resp Http204


proc handlerWebhookAttioEmailOpen*(request: Request) =
  ## Handle an email open event

  let ident = @"ident"

  #
  # Get email data from cache
  #
  let (exists, data) = cacheGet(CacheKey.emailData, ident)
  if exists:
    emailAction(data, MailAction.open, userAgent = (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: ""))
  else:
    when defined(dev):
      echo("Error: event email_opened for ident: " & ident & " not found in cache")

  let ext = @"ciurl"
  if ext != "":
    var headers: HttpHeaders
    headers["Location"] = decode(ext)
    request.respond(302, headers)
    return

  else:
    var headers: HttpHeaders
    headers["Content-Type"] = "image/png"
    request.respond(200, headers, imageData)
    return



proc handlerWebhookAttioEmailClick*(request: Request) =
  ## Handle an email click event

  let ident = @"ident"
  let link  = @"link"

  #
  # Get email data from cache
  #
  var clickedUrl = ""

  let (exists, data) = cacheGet(CacheKey.emailData, ident)
  if exists:
    clickedUrl = decode(link)
    emailAction(data, MailAction.click, userAgent = (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: ""), clickedUrl = clickedUrl)
  else:
    when defined(dev):
      echo("Error: event email_clicked for ident: " & ident & " not found in cache")

  if clickedUrl != "":
    redirect(clickedUrl)
  else:
    redirect("https://google.com")

