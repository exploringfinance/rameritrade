#' Get Options Chain
#'
#' Search an Option Chain for a specific ticker
#'
#' Return a list containing two data frames. The first is the underlying data
#' for the symbol. The second item in the list is a data frame that contains the
#' options chain for the specified ticker.
#'
#' @param ticker underlying ticker for the options chain
#' @param strikes the number of strikes above and below the current strike
#' @param inclQuote set TRUE to include pricing details (will be delayed if
#'   account is set for delayed quotes)
#' @param startDate the start date for expiration (should be greater than or
#'   equal to today). Format: yyyy-mm-dd
#' @param endDate the end date for expiration (should be greater than or equal
#'   to today). Format: yyyy-mm-dd
#' @inheritParams td_accountData
#'
#' @return a list of 2 data frames - underlying and options chain
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Pull all option contracts expiring over the next 6 months
#' # with 5 strikes above and below the at-the-money price
#' td_optionChain(ticker = 'SPY',
#'              strikes = 5,
#'              endDate = Sys.Date() + 180)
#'
#' }
td_optionChain = function(ticker, strikes = 10, inclQuote = TRUE, startDate = Sys.Date(),
                        endDate = Sys.Date() + 360, accessToken = NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Set value to NULL to pass check()
  daysToExpiration <- NULL
  
  # Create URL
  optionURL = base::paste0('https://api.tdameritrade.com/v1/marketdata/chains?symbol=',ticker,
                           '&strikeCount=',strikes,
                           '&includeQuotes=',inclQuote,
                           '&fromDate=',startDate,
                           '&toDate=',endDate)
  options =  httr::GET(optionURL,ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(options)
  
  # Parse Data
  jsonOptions <- httr::content(options, as = "text",encoding = 'UTF-8')
  jsonOptions <- jsonlite::fromJSON(jsonOptions)
  
  # Extract underlying data
  underlying = data.frame(jsonOptions$underlying) %>% 
    dplyr::as_tibble()
  # Extract PUT data
  puts =  dplyr::bind_rows(lapply(jsonOptions$putExpDateMap,dplyr::bind_rows)) %>%
    dplyr::mutate(expireDate = Sys.Date() + lubridate::days(daysToExpiration))
  # Extract CALL data
  calls = dplyr::bind_rows(lapply(jsonOptions$callExpDateMap,dplyr::bind_rows)) %>%
    dplyr::mutate(expireDate = Sys.Date() + lubridate::days(daysToExpiration))
  # Bind Put and Call data into a single data frame
  fullChain = dplyr::bind_rows(puts,calls) %>% 
    dplyr::as_tibble()
  
  returnVal = list(underlying = underlying, fullChain = fullChain)
  
  returnVal
}


#' Search for all Transaction types
#'
#' Can pull trades as well as transfers, dividend reinvestment, interest, etc.
#' Any activity associated with the account.
#'
#' @inheritParams td_orderDetail
#' @param startDate Transactions after a certain date. Will not pull back
#'   transactions older than 1 year. format yyyy-mm-dd
#' @param endDate Filter transactions that occurred before a certain date.
#'   format yyyy-mm-dd
#' @param transType Filter for a specific Transaction type. No entry will return
#'   all types. For example: TRADE, CASH_IN_OR_CASH_OUT, CHECKING, DIVIDEND,
#'   INTEREST, OTHER
#'
#' @return a jsonlite data frame of transactions
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Access Token must be set using td_auth_accessToken
#' # Transactions for the last 5 days
#' td_transactSearch(accountNumber = 987654321, 
#'                 startDate = Sys.Date()-days(5))
#'
#' }
td_transactSearch = function(accountNumber, startDate = Sys.Date()-30,
                           endDate = Sys.Date(), transType = 'All', 
                           accessToken = NULL){
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Construct URL
  transactURL = paste0('https://api.tdameritrade.com/v1/accounts/',accountNumber,
                       '/transactions?startDate=',as.Date(startDate),
                       '&endDate=',as.Date(endDate),'&type=',transType)
  
  # Make GET request for transactions
  searchTransact = httr::GET(transactURL,ram_headers(accessToken),encode='json')
  
  # Confirm status code of 200
  ram_status(searchTransact)
  
  # Parse Data
  jsonTransact <- httr::content(searchTransact, as = "text",encoding = 'UTF-8')
  jsonTransact <- jsonlite::fromJSON(jsonTransact)
  
  dplyr::as_tibble(jsonTransact)
}



#' Get Market Hours
#'
#' Returns a list output for current day and specified market that details the
#' trading window
#'
#' @inheritParams td_accountData
#' @param marketType The asset class to pull:
#'   'EQUITY','OPTION','BOND','FUTURE','FOREX'. Default is EQUITY
#'
#' @return List output of times and if the current date is a trading day
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Access Token must be set using td_auth_accessToken
#' # Market hours for the current date
#' td_marketHours()
#' td_marketHours('2020-06-24', 'OPTION')
#'
#' }
td_marketHours = function(marketType = c('EQUITY','OPTION','BOND','FUTURE','FOREX'),
                        accessToken = NULL){
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Create URL for market
  if (missing(marketType)) marketType='EQUITY'
  marketURL = paste0('https://api.tdameritrade.com/v1/marketdata/',marketType,'/hours')
  
  # Make Get Request using token
  marketHours = httr::GET(marketURL, ram_headers(accessToken), encode='json')
  
  # Confirm status code of 200
  ram_status(marketHours)
  
  # Return raw content - market hours in list form
  httr::content(marketHours)
}


#' Get ticker details
#'
#' Get identifiers and fundamental data for a specific ticker
#'
#' @inheritParams td_accountData
#' @param ticker a valid ticker or symbol
#'
#' @return data frame of ticker details
#' @export
#'
#' @examples
#' \dontrun{
#'
#' # Details for Apple
#' td_symbolDetail('AAPL')
#'
#' }
td_symbolDetail = function(ticker, accessToken = NULL) {
  
  # Get access token from options if one is not passed
  accessToken = ram_accessToken(accessToken)
  
  # Construct URL
  tickerURL = paste0('https://api.tdameritrade.com/v1/instruments?symbol=',
                     ticker,'&projection=fundamental')
  
  # Make Get Request using token
  tickerDet = httr::GET(tickerURL, ram_headers(accessToken))
  
  # Confirm status code of 200
  ram_status(tickerDet)
  
  # Get Content
  tickCont = httr::content(tickerDet)
  if (length(tickCont)==0) stop('Ticker not valid')
  
  Fund = data.frame(tickCont[[1]]$fundamental)
  Tick = tickCont[[1]]
  Tick$fundamental = NULL
  TickOut = merge(data.frame(Tick),Fund) %>% 
    dplyr::as_tibble()
  
  # Return data as a data frame
  TickOut
}
      
