
import
  std/[
    envvars,
    parseopt,
    strutils
  ]

import
  mummy, mummy/routers,
  mummy_utils

import
  src/attio_email_tracking/routes

from src/attio_email_tracking/caching import cacheClear


var router: Router
router.get("/assets/attio/mail_button.png", handlerAssetsMailButton)
router.get("/status", handlerHealthchecksConnection)
router.get("/healthchecks/connection", handlerHealthchecksConnection)
router.post("/webhook/attio/email", handlerWebhookAttioEmail)
router.get("/webhook/attio/email_opened.png", handlerWebhookAttioEmailOpen)
router.get("/webhook/attio/email_clicked", handlerWebhookAttioEmailClick)


when isMainModule:
  for kind, key, val in getOpt():
    echo "CLI_RUN: running on"

    case kind
    of cmdShortOption, cmdLongOption:
      case key
      of "v", "version":
        echo "\nVersion: v1"
        quit(0)

      of "clear-cache":
        echo "Clearing cache"
        cacheClear()
        quit(0)

      else:
        echo "Unknown option: " & key
        quit(1)

    else:
      echo "Unknown option: " & key
      quit(1)


  let
    server = newServer(router)
    host = getEnv("WEBSERVER_HOST", "localhost")
    port = parseInt(getEnv("WEBSERVER_PORT", "2884"))

  echo "Serving attio_email_tracking on http://" & host & ":" & $port

  server.serve(Port(port), host)