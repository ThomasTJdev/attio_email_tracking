
when NimMajor >= 2:
  import std/envvars
else:
  import std/os


import
  std/[
    base64,
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
    "epoch": toInt(epochTime()),
    "opens": 0,
    "clicks": {}
  }
  cacheSet(CacheKey.emailData, ident, data)
  when defined(dev):
    echo("Added email to cache: " & ident & " - " & $data)

  resp Http204


proc isBlockedDueInit(epoch: int): bool =
  ## Check if the time is blocked
  return toInt(epochTime()) - epoch < 5


proc handlerWebhookAttioEmailOpen*(request: Request) =
  ## Handle an email open event

  let ident = @"ident"

  #
  # Get email data from cache
  #
  var (exists, data) = cacheGet(CacheKey.emailData, ident)
  if exists:

    if data.hasKey("epoch") and isBlockedDueInit(data["epoch"].getInt()):
      discard
    else:
      # Incr open
      var times = 1
      if data.hasKey("opens"):
        times = data["opens"].getInt() + 1
      data["opens"] = times.newJInt()
      cacheSet(CacheKey.emailData, ident, data)
      # Action
      emailAction(data, MailAction.open, userAgent = (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: ""), actionTimes = times)
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

  var (exists, data) = cacheGet(CacheKey.emailData, ident)
  if exists:

    if data.hasKey("epoch") and isBlockedDueInit(data["epoch"].getInt()):
      discard
    else:
      # Incr click
      var times: int = 1
      if data["clicks"].hasKey(link):
        times = data["clicks"][link].getInt() + 1
        data["clicks"][link] = times.newJInt()
      else:
        data["clicks"][link] = 1.newJInt()
      cacheSet(CacheKey.emailData, ident, data)

      # Action
      clickedUrl = decode(link)
      emailAction(data, MailAction.click, userAgent = (if request.headers.hasKey("User-Agent"): request.headers["User-Agent"] else: ""), clickedUrl = clickedUrl, actionTimes = times)
  else:
    when defined(dev):
      echo("Error: event email_clicked for ident: " & ident & " not found in cache")

  if clickedUrl != "":
    redirect(clickedUrl)
  else:
    redirect("https://google.com")

