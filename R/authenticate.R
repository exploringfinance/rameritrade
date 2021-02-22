#' Auth Step 1: Generate LogIn URL
#'
#' Create URL to grant App access to a TD Brokerage account
#'
#' To use the TD Ameritrade API, both a TD Brokerage account and a registered
#' developer app are required. The developer app functions as a middle layer
#' between the brokerage account and the API. A developer app should be
#' registered on the \href{https://developer.tdameritrade.com/}{TD Ameritrade
#' Developer} site. Once logged in to the developer site, use My Apps to
#' register an application. An App will have a Consumer Key provided by TD that
#' functions as an API key. The Consumer Key is auto generated and can be found
#' under My Apps > Keys. The user must also create a Callback URL. The Callback
#' URL can be anything. The example below assumes the Callback URL is
#' https://myTDapp.
#'
#' This function will use these two inputs to generate a URL where the user can
#' log in to their standard TD Ameritrade Brokerage Account and grant the
#' application access to the brokerage account, enabling the API. The
#' Authorization Code generated at the end of the log in process will feed into
#' \code{\link{td_auth_refreshToken}}. For questions, please reference the
#' \href{https://developer.tdameritrade.com/content/authentication-faq}{TD
#' Ameritrade Authentication FAQ} or see the examples in the rameritrade readme.
#' If the callback URL uses punctuation, numbers, or an IP (e.g. 127.0.0.0.1),
#' the output of this function may not work. Please reference the TD
#' documentation to create the appropriate URL.
#'
#' @seealso \code{\link{td_auth_loginURL}} to generate a login url which leads
#'   to an authorization code, \code{\link{td_auth_refreshToken}} to generate a
#'   Refresh Token using an existing Refresh Token or an authorization code with
#'   a callback URL when loggin in manually,  \code{\link{td_auth_accessToken}}
#'   to generate a new Access Token
#'
#' @param consumerKey TD generated Consumer key for the registered TD app.
#'   Essentially an API key.
#' @param callbackURL User generated Callback URL for the registered TD app
#'
#' @return login url to grant app permission to TD Brokerage account
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Visit the URL generated from the function below to log in to a TD Brokerage account
#' # Once a successful log in is completed the landing page will be a blank page
#' # The full URL of the landing page is the Authorization Code for td_auth_refreshToken
#'
#' loginURL = td_auth_loginURL('https://myTDapp','consumerKey')
#'
#' }
td_auth_loginURL = function(consumerKey, callbackURL) {
  
  # Generate URL specific to the registered TD Application
  url = paste0('https://auth.tdameritrade.com/auth?response_type=code&redirect_uri=',
               callbackURL,'&client_id=',consumerKey,'%40AMER.OAUTHAP')
  url
  
}




#' Auth Step 2: Obtain Refresh Token
#'
#' Get a Refresh Token using the Authorization Code or an existing Refresh Token
#'
#' Once a URL has been generated using \code{\link{td_auth_loginURL}}, a user
#' can visit that URL to log into a TD brokerage account, granting the TD app
#' access to the account. Once the button "Allow" is pressed, the user will be
#' redirected, potentially to "This site can't be reached". This indicates a
#' successful log in. The URL of this page contains the Authorization Code.
#' Paste the entire URL, not just the Authorization Code, into
#' td_auth_refreshToken. The authorization code will be an extremely long alpha
#' numeric string starting with 'https'.
#'
#' The output of td_auth_refreshToken will be a Refresh Token which will be used
#' to gain access to the TD Brokerage account(s) going forward. The Refresh
#' Token will be valid for 90 days. Be sure to save the Refresh Token to a safe
#' location or the manual log in process will be required again. The user can use
#' td_auth_refreshToken to reset the token before expiration.
#'
#' The Refresh Token output should be saved in a very safe location, but also
#' accessible. It will be needed to generate an Access Token using
#' \code{\link{td_auth_accessToken}}, which is used for general account access.
#' The Access Token expires after 30 minutes.
#'
#' Note: When running this function interactively (e.g. through RStudio) using
#' an existing Refresh Token, the function will check the days left until
#' expiration for the Refresh Token being passed. If the remaining time is
#' greater than 15 days, the user will be prompted to verify that a new Refresh
#' Token should be created. The user can select to request a new token, but
#' there is no net benefit in doing so and TD encourages limiting new token
#' generation. When running this function in a non-interactive environment (e.g.
#' CRON Job), if the remaining time until expiration is greater than 15 days,
#' the default behavior will be to NOT reset the Refresh Token because the new
#' token will have the same access and capabilities as the existing token.
#'
#'
#' @inheritParams td_auth_loginURL
#' @param codeToken Will be either an authorization code when manually logging
#'   in or a Refresh Token if the current Refresh Token is nearing expiration.
#'
#' @seealso \code{\link{td_auth_loginURL}} to generate a login url which leads
#'   to an authorization code, \code{\link{td_auth_refreshToken}} to generate a
#'   Refresh Token using an existing Refresh Token or an authorization code with
#'   a callback URL when logging in manually,  \code{\link{td_auth_accessToken}}
#'   to generate a new Access Token
#'
#' @return Refresh Token that is valid for 90 days
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Initial access will require manually logging in to the URL from td_auth_loginURL
#' # After a successful log in, the URL authorization code can be fed with a callbackURL
#' refreshToken = td_auth_refreshToken(consumerKey = 'TD_CONSUMER_KEY',
#'                                     callbackURL = 'https://myTDapp',
#'                                     codeToken = 'https://myTDapp/?code=Auhtorizationcode')
#'
#' # If an existing Refresh Token exists. Pass this. CallbackURL is not needed.
#' refreshToken = readRDS('/secure/location/')
#' refreshToken = td_auth_refreshToken(consumerKey = 'TD_CONSUMER_KEY',
#'                                     codeToken = refreshToken)
#'
#' # Save the Refresh Token somewhere safe where it can be retrieved
#' saveRDS(refreshToken,'/secure/location/')
#'
#' }
td_auth_refreshToken = function(consumerKey, callbackURL, codeToken) {

  # Check if codeToken is authorization code or refresh token
  if (class(codeToken) == 'list') {
    # when a refresh token - use new refreshtoken
    refreshToken = ram_new_refreshToken(consumerKey = consumerKey, refreshToken = codeToken)
  } else {
    # when auth code - use init refresh token
    if (missing(callbackURL)) stop('When generating a Refresh Token using an authoriation code, a callbackURL must be supplied.')
    refreshToken = ram_init_refreshToken(consumerKey = consumerKey, callbackURL = callbackURL, authcode_url = codeToken)
  }
  
  # Return full token sequence
  refreshToken
  
}




#' Auth Step 3: Get Access Token
#'
#' Get a new Access Token using a valid Refresh Token
#'
#' An Access Token is required for the functions within rameritrade. It serves
#' as a user login to a TD Brokerage account. The token is valid for 30 minutes
#' and allows the user to place trades, get account information, get order
#' history, pull historical stock prices, etc. A Refresh Token is required to
#' generate an Access Token. \code{\link{td_auth_refreshToken}}  can be used to
#' generate Refresh Tokens which stay valid for 90 days. The Consumer Key is
#' generated automatically when an App is registered on the
#' \href{https://developer.tdameritrade.com/}{TD Ameritrade Developer} site. By
#' default, the Access Token is stored into options and will automatically be
#' passed to downstream functions. However, the user can also submit an Access
#' Token manually if multiple tokens are in use (for example: when managing more
#' than one log in.)
#'
#' When running this function manually (i.e. through RStudio), the function will
#' check for a default Access Token. If the default Access Token has not
#' expired, the user will be prompted to verify a new Access Token is desired.
#' This may be the case if more than one TD login is being used. When running
#' this function in a non-interactive environment (i.e. CRON Job), the default
#' behavior will be to refresh the Access Token.
#'
#' DISCLOSURE: This software is in no way affiliated, endorsed, or approved by
#' TD Ameritrade or any of its affiliates. It comes with absolutely no warranty
#' and should not be used in actual trading unless the user can read and
#' understand the source code. The functions within this package have been
#' tested under basic scenarios. There may be bugs or issues that could prevent
#' a user from executing trades or canceling trades. It is also possible trades
#' could be submitted in error. The user will use this package at their own
#' risk.
#'
#'
#' @param refreshToken An existing Refresh Token generated using
#'   \code{\link{td_auth_refreshToken}}
#' @inheritParams td_auth_loginURL
#'
##' @seealso \code{\link{td_auth_loginURL}} to generate a login url which leads
#'   to an authorization code, \code{\link{td_auth_refreshToken}} to generate a
#'   Refresh Token using an existing Refresh Token or an authorization code with
#'   a callback URL when logging in manually,  \code{\link{td_auth_accessToken}}
#'   to generate a new Access Token
#'
#' @return Access Token that is valid for 30 minutes. By default it is stored in
#'   options.
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # A valid Refresh Token can be fed into the function below for a new Access Token
#' refreshToken = readRDS('/secure/location/')
#' accessToken = td_auth_accessToken('TD_CONSUMER_KEY', refreshToken)
#'
#' }
td_auth_accessToken = function(consumerKey, refreshToken) {
  
  # Get default Access Token in environment if available
  accessToken <- getOption("td_access_token")
  
  # If default Access Token is not null and environment is interactive, check for expiration
  if (!is.null(accessToken) & interactive()) {
    
    # If Access Token has not expired, ask if new Access Token should be generated if more than 5 minutes left
    MinTillExp = round(as.numeric(accessToken$expireTime-Sys.time()),1)
    if (MinTillExp>5) {
      ChkRef = utils::menu(c('Yes','No'),
                           title = paste0('Your default Access Token has ',MinTillExp,' minutes until expiration, ',
                                          'are you sure you want a new Access Token?'))
      
      # If user selects No or exits, return default accessToken otherwise get new token
      if (ChkRef %in% c(0,2)) return(accessToken)
    }
  }
  
  # Validate Refresh Token
  ram_checkRefresh(refreshToken)
  
  # Get a new Access Token using a Refresh Token
  accessreq = list(grant_type='refresh_token',
                   refresh_token=refreshToken$refresh_token,
                   client_id=consumerKey)
  
  # Post Refresh Token and retrieve Access Token
  getaccess = httr::POST('https://api.tdameritrade.com/v1/oauth2/token', 
                         httr::add_headers('Content-Type'='application/x-www-form-urlencoded'),body=accessreq,encode='form')
  
  # Confirm status code of 200
  ram_status(getaccess)
  print("Successful Login. Access Token has been stored and will be valid for 30 minutes")
  
  # Extract content and add expiration time to Access Token 
  accessToken = httr::content(getaccess)
  accessToken$expireTime = Sys.time() + lubridate::seconds(accessToken$expires_in) - lubridate::seconds(5)
  accessToken$createTime = Sys.time()
  
  # Set Access Token to a default option
  options(td_access_token = accessToken)
  
  # Return Access Token
  accessToken
}


############### =============================
############### =============================
############### =============================


# ----------- Helper function
# This function uses an authorization code and callbackURL to generate an initial Refresh Token
ram_init_refreshToken = function(consumerKey, callbackURL, authcode_url) {
  
  
  # Check if Authorization code meets basic criteria
  if( nchar(authcode_url) < 500 | !grepl('code=',authcode_url) | substr(authcode_url,1,5) != 'https' ) {
    
    stop(paste0('The auth code provided does not appear to be a valid auth code. ',
                'Please confirm the URL link from a successful login was passed.'),
         call. = FALSE)
  }
  
  
  # Parse Access Token from URL and Decode the token
  decodedtoken = urltools::url_decode(gsub('.*code=','',authcode_url))
  
  # Get Refresh Token using URL Authorization Code and registered TD Application
  # Access Token is good for 30 minutes, the Refresh Token is good for 90 days
  authreq = list(grant_type='authorization_code',
                 refresh_token='',
                 access_type='offline',
                 code=decodedtoken,
                 client_id=consumerKey,
                 redirect_uri=callbackURL)
  
  # Post authorization request either using a verbose request or non-verbose
  authresponse = httr::POST('https://api.tdameritrade.com/v1/oauth2/token', 
                            httr::add_headers('Content-Type'='application/x-www-form-urlencoded'),
                            body=authreq,encode='form')
  
  # Confirm status code of 200
  ram_status(authresponse,
             '. Review the TD Auth FAQ or the Auth Guide at https://developer.tdameritrade.com/ for more details')
  
  # Send message if Refresh Token generated successfully
  print("Successful Refresh Token Generated")
  
  # Modify Refresh Token with expire times and by removing the access token details
  refreshToken = httr::content(authresponse)
  refreshToken$access_token = NULL
  refreshToken$expires_in = NULL
  refreshToken$refreshExpire = Sys.time() + refreshToken$refresh_token_expires_in
  refreshToken$createTime = Sys.time()
  
  # Return full token sequence
  refreshToken
  
}


# ----------- Helper function
# This function uses an existing Refresh Token to generate a new Refresh Token
ram_new_refreshToken = function(consumerKey, refreshToken) {
  
  # Validate Refresh Token
  ram_checkRefresh(refreshToken)
  
  # Check age of Refresh Token
  daysUntilExp = as.numeric(as.Date(refreshToken$refreshExpire)-Sys.Date())
  
  # If Refresh Token has more than 15 days check if refresh required
  if (daysUntilExp>15) {
    
    # If non-interactive and Refresh Token has more than 15 days, do not refresh
    if (interactive()==FALSE) return(refreshToken)
    
    # If interactive, ask user if refresh is still needed
    ChkRef = utils::menu(c('Yes','No'),title = paste0('Your token still has ',daysUntilExp,' days until expiration.\n',
                                                      'Are you sure you want to reset your Refresh Token?'))
    
    # If user selects no, return current Refresh Token
    if (ChkRef %in% c(0,2)) return(refreshToken)
    }
  
  
  # Get a New Refresh Token using existing Refresh Token before 90 day expiration
  refreshreq = list(grant_type='refresh_token',
                    refresh_token=refreshToken$refresh_token,
                    access_type='offline',
                    client_id=consumerKey)
  
  # Post authorization request
  newrefresh = httr::POST('https://api.tdameritrade.com/v1/oauth2/token', 
                          httr::add_headers('Content-Type'='application/x-www-form-urlencoded'),
                          body=refreshreq,encode='form') 
  
  # Confirm status code of 200
  ram_status(newrefresh,'. If the current Refresh Token has expired. Re-authenticate using the auth_init functions.')
  print("Successful Refresh Token Generated")
  
  # Modify Refresh Token with expire times and by removing the access token details
  new_refreshToken = httr::content(newrefresh)
  new_refreshToken$access_token = NULL
  new_refreshToken$expires_in = NULL
  new_refreshToken$refreshExpire = Sys.time() + new_refreshToken$refresh_token_expires_in
  new_refreshToken$createTime = Sys.time()
  
  
  # Return only the Refresh Token even though an Access Token is also provided
  new_refreshToken
  
}




